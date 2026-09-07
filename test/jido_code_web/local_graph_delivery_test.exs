defmodule JidoCodeWeb.LocalGraphDeliveryTest do
  use ExUnit.Case, async: false
  alias JidoCode.Identity.{Administration, Store}
  alias JidoCode.Knowledge.{GraphRegistry, QueryRunner, ResourceIdentity, StoreServer, Writer}
  alias JidoCode.Knowledge.Repositories.{Enrollment, Locator}
  alias JidoCode.TestSupport.HypermediaStreamHTTPFixture, as: HTTP
  @moduletag :graph_store
  @token "d4-real-local-bootstrap-test-token"
  @admin %{
    source: :governed_identity_admin,
    actor_ref: "human_identity_administrator",
    assurance: :action_bound_step_up
  }

  setup do
    root = Path.join(System.tmp_dir!(), "hui-d4-graph-#{System.unique_integer([:positive])}")
    keys = [:knowledge_store, :authority_bootstrap]
    old = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})
    identity = :sys.get_state(Store)
    :ok = Supervisor.terminate_child(JidoCode.Supervisor, JidoCode.Knowledge.Supervisor)

    Application.put_env(:jido_code, :knowledge_store,
      enabled: true,
      root: Path.join(root, "graph"),
      backup_root: Path.join(root, "backups"),
      test_instance_id: "d4-real-local"
    )

    Application.put_env(:jido_code, :authority_bootstrap, %{
      enabled?: true,
      token_digest: :crypto.hash(:sha256, @token)
    })

    {:ok, _} = Supervisor.restart_child(JidoCode.Supervisor, JidoCode.Knowledge.Supervisor)

    on_exit(fn ->
      :ok = Supervisor.terminate_child(JidoCode.Supervisor, JidoCode.Knowledge.Supervisor)

      for {key, value} <- old do
        if value,
          do: Application.put_env(:jido_code, key, value),
          else: Application.delete_env(:jido_code, key)
      end

      {:ok, _} = Supervisor.restart_child(JidoCode.Supervisor, JidoCode.Knowledge.Supervisor)
      :sys.replace_state(Store, fn _ -> identity end)
      File.rm_rf!(root)
    end)

    # Use the production adapter and default real query/store processes, not the
    # D3 fixture bridge or an allow-all provider. No principal is substituted.
    :sys.replace_state(
      Store,
      &%{&1 | config: %{&1.config | authority_adapter: JidoCode.Identity.Authority.LocalGraph}}
    )

    surface = Application.fetch_env!(:jido_code, :product_surface)
    human = "https://jido.run/id/human/human_test_operator"

    {:ok, bootstrap} =
      JidoCode.Install.bootstrap(@token,
        identity: %{
          factory_iri: surface[:factory_iri],
          factory_scope_iri: surface[:factory_scope_iri],
          principal_iri: human,
          actor_iri: human
        }
      )

    {:ok, factory} = Store.resolve_resource(:factory)

    resources =
      for {label, project} <- [{"visible", "browser_alpha"}, {"hidden", "d4_hidden"}] do
        {:ok, repository} = ResourceIdentity.conceptual_repository("d4-#{label}")
        {:ok, scope} = ResourceIdentity.scope(:repository, repository)

        {:ok, resource} =
          Administration.register_resource(@admin, %{
            resource_ref: "d4_#{label}",
            kind: :project,
            iri: repository,
            tenant_ref: factory.tenant_ref,
            project_ref: project,
            parent_ref: factory.resource_ref,
            graph_scope_iri: scope
          })

        {label, resource}
      end

    base = HTTP.start!()

    %{
      client: HTTP.sign_in(base),
      resources: Map.new(resources),
      bootstrap: bootstrap,
      surface: surface,
      human: human
    }
  end

  test "real scoped enrollment changes converge without principal substitution or hidden links",
       context do
    stream = HTTP.connect(context.client)
    for label <- ["hidden", "visible"], do: enroll!(context, context.resources[label], label)
    revision = StoreServer.summary().dataset_revision

    body =
      HTTP.until(stream, fn body ->
        HTTP.documents(body)
        |> Enum.any?(fn doc ->
          doc
          |> LazyHTML.query("[data-projection-trust] dl > div:first-child dd")
          |> LazyHTML.text()
          |> String.trim()
          |> Kernel.==(Integer.to_string(revision))
        end)
      end)

    documents = HTTP.documents(body)
    assert Enum.any?(documents, &(Enum.count(LazyHTML.query(&1, "a[href*='d4_visible']")) > 0))
    refute Enum.any?(documents, &(Enum.count(LazyHTML.query(&1, "a[href*='d4_hidden']")) > 0))
    assert StoreServer.summary().dataset_revision == revision

    hidden =
      Req.get!(context.client.base <> "/projects/d4_hidden",
        retry: false,
        headers: %{"cookie" => context.client.cookie}
      )

    assert hidden.status == 404
    :ok = JidoCode.Product.StreamCoordinator.drain()
    HTTP.finish(stream)
  end

  defp enroll!(context, resource, label) do
    # Preserve precision: truncation can backdate this command before the
    # real bootstrap grant created earlier in the same second.
    now = DateTime.utc_now()
    {:ok, command_iri} = ResourceIdentity.generate_local(:command)
    {:ok, correlation} = ResourceIdentity.generate_local(:activity)

    {:ok, locator} =
      Locator.new(%{
        provider: "https://github.com",
        external_id: "d4-#{label}",
        owner: "fixture",
        name: label,
        state: :active,
        observed_at: now,
        relationships: []
      })

    {:ok, enrollment} =
      Enrollment.new(%{
        factory_iri: context.surface[:factory_iri],
        repository_iri: resource.iri,
        repository_scope_iri: resource.graph_scope_iri,
        policy_boundary_iri: context.surface[:policy_boundary_iri],
        policy_iris: context.surface[:policy_iris],
        locator: locator,
        actor_iri: context.human,
        cause_iri: command_iri,
        reason: "D4 scoped qualification",
        valid_from: now,
        valid_to: DateTime.add(now, 86_400)
      })

    {:ok, catalog} = GraphRegistry.graph_iri(:factory_catalog, %{})
    {:ok, metadata} = QueryRunner.graph_metadata(catalog)

    {:ok, command} =
      Enrollment.enroll_command(
        enrollment,
        %{
          command_iri: command_iri,
          principal_iri: context.human,
          factory_scope_iri: context.surface[:factory_scope_iri],
          idempotency_key: "d4-#{label}",
          correlation_iri: correlation,
          causation_iri: command_iri,
          expected_dataset_revision: StoreServer.summary().dataset_revision,
          catalog_graph_iri: catalog,
          expected_catalog_revision: metadata.graph_revision,
          reason: "D4 scoped qualification"
        },
        clock: fn -> now end
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(command)
  end
end

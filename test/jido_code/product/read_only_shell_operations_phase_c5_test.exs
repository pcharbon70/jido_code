defmodule JidoCode.Product.ReadOnlyShellOperationsPhaseC5Test do
  use ExUnit.Case, async: false

  alias JidoCode.Identity.Resource
  alias JidoCode.Identity.Store, as: IdentityStore
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Product.GraphReadProjectionProvider
  alias JidoCode.Product.ReadProjectionCache
  alias JidoCode.TestSupport.Filesystem
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture

  @moduletag :graph_store
  @now ~U[2026-09-06 12:00:00Z]

  test "persistent named identity and the real TripleStore survive restart without effectful reads",
       context do
    identity_root =
      Path.join(System.tmp_dir!(), "hui-c5-identity-#{System.unique_integer([:positive])}")

    identity_path = Path.join(identity_root, "identity.snapshot")
    on_exit(fn -> Filesystem.remove_root!(identity_root) end)
    integrity_key = :crypto.strong_rand_bytes(32)

    {:ok, identity_store} =
      IdentityStore.start_link(
        name: nil,
        config: identity_config(identity_path, integrity_key)
      )

    {:ok, account} =
      IdentityStore.bootstrap(
        identity_store,
        %{display_name: "Phase Five Operator", login: "phase-five@example.test"},
        "production-like test credential",
        local_ceremony: true,
        now: @now
      )

    GenServer.stop(identity_store)

    {:ok, restored_identity_store} =
      IdentityStore.start_link(
        name: nil,
        config: identity_config(identity_path, integrity_key)
      )

    assert {:ok, ^account} = IdentityStore.account(restored_identity_store, account.subject_ref)
    GenServer.stop(restored_identity_store)

    fixture = Phase08ExecutionFixture.completed!(context)
    project = project_resource(fixture)
    before_revision = StoreServer.summary(fixture.store_server).dataset_revision

    {elapsed_us, {:ok, projection}} =
      :timer.tc(fn ->
        GraphReadProjectionProvider.load(page_context(),
          authorize: allow_all(fixture),
          resources: fn :project, 100 -> {:ok, [project]} end,
          query: real_query(fixture),
          health: %Health{state: :ready, store_verified?: true, ontology_verified?: true},
          cache_server: nil,
          clock: fn -> fixture.issued_at end
        )
      end)

    assert projection.state in [:ready, :empty, :stale, :incomplete, :truncated]
    assert div(elapsed_us, 1_000) <= 5_500
    assert byte_size(:erlang.term_to_binary(projection)) <= 262_144
    assert StoreServer.summary(fixture.store_server).dataset_revision == before_revision
  end

  test "large fleets and parallel user-tab reads stay inside scan, row, time, and byte bounds" do
    resources = Enum.map(1..100, &resource/1)
    counters = start_supervised!({Agent, fn -> %{queries: 0, project_authorizations: 0} end})

    options = [
      authorize: bounded_authorizer(counters),
      resources: fn :project, 100 -> {:ok, resources} end,
      query: bounded_query(counters, resources),
      health: %Health{state: :ready, store_verified?: true, ontology_verified?: true},
      cache_server: nil,
      clock: fn -> @now end
    ]

    {elapsed_us, results} =
      :timer.tc(fn ->
        1..8
        |> Task.async_stream(
          fn user ->
            Enum.map(1..4, fn tab ->
              GraphReadProjectionProvider.load(
                page_context(%{"page" => rem(user + tab, 5) + 1}),
                options
              )
            end)
          end,
          max_concurrency: 8,
          ordered: false,
          timeout: :infinity
        )
        |> Enum.to_list()
      end)

    projections =
      for {:ok, user_results} <- results,
          {:ok, projection} <- user_results,
          do: projection

    assert length(projections) == 32
    assert Enum.all?(projections, &(length(&1.fleet) <= 20))
    assert Enum.all?(projections, &(byte_size(:erlang.term_to_binary(&1)) <= 262_144))
    assert div(elapsed_us, 1_000) <= 5_500

    counters = Agent.get(counters, & &1)
    assert counters.project_authorizations <= 32 * 100
    assert counters.queries <= 32 * 121
  end

  test "cache contention remains bounded by capacity, memory, and p95 operation thresholds" do
    cache = start_supervised!({ReadProjectionCache, name: nil})
    projection = HypermediaUIPhaseC4Fixture.projection(:factory)
    {:memory, before_bytes} = Process.info(cache, :memory)

    timings =
      1..8
      |> Task.async_stream(
        fn user ->
          Enum.flat_map(1..80, fn tab ->
            key = "user-#{user}-tab-#{tab}"

            {put_us, :ok} =
              :timer.tc(fn -> ReadProjectionCache.put(cache, key, projection, 0) end)

            {fetch_us, result} =
              :timer.tc(fn -> ReadProjectionCache.fetch(cache, key, 1) end)

            assert result in [{:fresh, projection}, :miss]
            [put_us, fetch_us]
          end)
        end,
        max_concurrency: 8,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, values} -> values end)
      |> Enum.sort()

    {:memory, after_bytes} = Process.info(cache, :memory)
    p95_us = Enum.at(timings, floor(length(timings) * 0.95))

    assert ReadProjectionCache.size(cache) == 512
    assert max(after_bytes - before_bytes, 0) <= 16_777_216
    assert p95_us <= 25_000
    assert :miss = ReadProjectionCache.fetch(cache, "user-1-tab-1", 30_001)
  end

  defp identity_config(path, integrity_key) do
    [
      enabled: true,
      persistence: true,
      path: path,
      integrity_key: integrity_key,
      policy_revision: "hui.identity.v1",
      pbkdf2_iterations: 1_000,
      max_failed_attempts: 5,
      lockout_seconds: 300,
      recovery_adapter: JidoCode.Identity.Recovery.Unconfigured,
      bootstrap: nil,
      authority_adapter: JidoCode.Identity.Authority.Unconfigured
    ]
  end

  defp page_context(query \\ %{}) do
    %{
      session_ref: "phase-c5-real-store",
      page: %{
        key: :factory,
        route_params: %{},
        query: query,
        canonical_url: "https://example.test/factory"
      }
    }
  end

  defp allow_all(fixture) do
    fn _context, _operation, _area, _action, _point, _resource_ref ->
      {:ok,
       %{
         decision: :allowed,
         product_identity: %{
           factory_iri: fixture.factory_iri,
           factory_scope_iri: fixture.factory_scope
         },
         authority_context: fixture.authority
       }}
    end
  end

  defp real_query(fixture) do
    fn name, version, parameters, authority, scope, _options ->
      JidoCode.Knowledge.QueryRunner.execute(name, version, parameters, authority, scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )
    end
  end

  defp project_resource(fixture) do
    %Resource{
      resource_ref: "project_phase_c5_real_store",
      kind: :project,
      iri: fixture.repository,
      tenant_ref: "tenant_phase_c5",
      project_ref: "phase_c5",
      parent_ref: "factory_phase_c5",
      graph_scope_iri: fixture.repository_scope,
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 1
    }
  end

  defp bounded_authorizer(counters) do
    identity = identity()
    authority = authority()

    fn _context, _operation, _area, _action, _point, resource_ref ->
      if resource_ref != :factory do
        Agent.update(
          counters,
          &Map.update!(&1, :project_authorizations, fn value -> value + 1 end)
        )
      end

      {:ok, %{decision: :allowed, product_identity: identity, authority_context: authority}}
    end
  end

  defp bounded_query(counters, resources) do
    fn name, _version, parameters, _authority, scope, _options ->
      Agent.update(counters, &Map.update!(&1, :queries, fn value -> value + 1 end))

      data =
        if name == :factory_repository_cohort do
          Enum.map(resources, &%{"repository" => &1.iri, "enrollment" => &1.iri <> "/enrollment"})
        else
          []
        end

      {:ok, query_result(name, data, parameters, scope)}
    end
  end

  defp query_result(name, data, parameters, scope) do
    graph_revisions =
      parameters
      |> Enum.filter(fn {key, _value} -> key in [:graph, :control_graph, :wiki_graph] end)
      |> Map.new(fn {_key, graph} -> {graph, 1} end)

    %QueryResult{
      query_name: name,
      query_version: "2.11.0",
      scope_iri: scope,
      dataset_revision: 1,
      graph_revisions: graph_revisions,
      ontology_version: "1.5.0",
      completeness: %{complete?: true},
      freshness: :current,
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: %{status: :current},
      evaluated_at: @now,
      data: data
    }
  end

  defp resource(index) do
    suffix = index |> Integer.to_string() |> String.pad_leading(3, "0")

    %Resource{
      resource_ref: "project_phase_c5_#{suffix}",
      kind: :project,
      iri: "https://jido.run/id/repository/phase-c5-#{suffix}",
      tenant_ref: "tenant_phase_c5",
      project_ref: "phase_c5_#{suffix}",
      parent_ref: "factory_phase_c5",
      graph_scope_iri: "https://jido.run/id/scope/project/phase-c5-#{suffix}",
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 1
    }
  end

  defp identity do
    %{
      factory_iri: "https://jido.run/id/repository-factory/default",
      factory_scope_iri: "https://jido.run/id/scope/factory/default"
    }
  end

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: "https://jido.run/id/human/phase-c5",
        actor_iri: "https://jido.run/id/human/phase-c5",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end
end

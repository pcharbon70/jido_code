defmodule JidoCode.Product.GraphReadProjectionProviderPhaseC4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.Resource
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Product.GraphReadProjectionProvider

  test "derives bounded attention and fleet rows only from independently authorized projects" do
    test_pid = self()
    authority = authority()
    identity = identity()
    resources = resources()
    alpha_scope = Enum.at(resources, 0).graph_scope_iri
    hidden_scope = Enum.at(resources, 2).graph_scope_iri

    authorize = fn _context, operation, area, action, point, resource_ref ->
      send(test_pid, {:authorize, operation, area, action, point, resource_ref})

      if resource_ref == "project_hidden" do
        {:error, :concealed_not_found}
      else
        {:ok,
         %{
           decision: :allowed,
           product_identity: identity,
           authority_context: authority
         }}
      end
    end

    query = fn name, version, parameters, query_authority, scope, options ->
      send(test_pid, {:query, name, version, parameters, query_authority, scope, options})
      {:ok, result(name, query_data(name, parameters, scope, alpha_scope), parameters)}
    end

    assert {:ok, projection} =
             GraphReadProjectionProvider.load(context(:factory),
               authorize: authorize,
               resources: fn :project, 100 -> {:ok, resources} end,
               query: query,
               health: ready_health(),
               clock: fn -> ~U[2026-09-06 00:00:00Z] end
             )

    assert projection.state == :ready
    assert projection.dataset_revision == 77
    assert Enum.map(projection.fleet, & &1.project) == ["alpha", "beta"]
    assert Enum.any?(projection.attention, &(&1.title == "Blocked work"))
    assert Enum.any?(projection.attention, &(&1.title == "Failed attempt"))
    assert Enum.any?(projection.attention, &(&1.title == "Verification or decision needed"))
    assert projection.summaries.authorized_rows == 2
    refute inspect(projection) =~ "repository/hidden"

    assert_receive {:authorize, :factory_shell, :developer, :query, :before_query_execution,
                    :factory}

    assert_receive {:authorize, :project_page, :developer, :query, :before_query_execution,
                    "project_hidden"}

    refute_receive {:query, _, _, _, _, ^hidden_scope, _}
  end

  test "filters, sorts, and paginates only the authorized cohort without global totals" do
    resources = resources() |> Enum.take(2)

    assert {:ok, projection} =
             GraphReadProjectionProvider.load(
               context(:fleet, %{"q" => "beta", "sort" => "stage", "direction" => "descending"}),
               authorize: allow_all(),
               resources: fn :project, 100 -> {:ok, resources} end,
               query: query_fixture(resources, truncated?: true),
               health: ready_health()
             )

    assert projection.state == :truncated
    assert Enum.map(projection.fleet, & &1.project) == ["beta"]
    assert projection.pagination.known_total == nil
    assert projection.summaries.totals_known? == false
    assert projection.summaries.sort_column == "stage"
  end

  test "maps readiness failures and timeouts to cleared safe outcomes" do
    assert {:ok, maintenance} =
             GraphReadProjectionProvider.load(context(:projects),
               authorize: allow_all(),
               health: %Health{state: :maintenance}
             )

    assert maintenance.state == :maintenance
    assert maintenance.projects == []

    assert {:ok, timed_out} =
             GraphReadProjectionProvider.load(context(:fleet),
               surface_timeout_ms: 5,
               health: ready_health(),
               authorize: allow_all(),
               resources: fn :project, 100 -> {:ok, resources()} end,
               query: fn _name, _version, _params, _authority, _scope, _options ->
                 Process.sleep(50)
                 flunk("timed-out query must not complete")
               end
             )

    assert timed_out.state == :unavailable
    assert timed_out.source_outcome == :error
    assert timed_out.fleet == []
  end

  defp context(surface, query \\ %{}) do
    %{
      session_ref: "session-phase-c4",
      page: %{
        key: surface,
        query: query,
        canonical_url: "https://example.test/#{surface}"
      }
    }
  end

  defp allow_all do
    authority = authority()
    identity = identity()

    fn _context, _operation, _area, _action, _point, _resource_ref ->
      {:ok, %{decision: :allowed, product_identity: identity, authority_context: authority}}
    end
  end

  defp query_fixture(resources, options) do
    scopes = Map.new(resources, &{&1.graph_scope_iri, &1.project_ref})
    truncated? = Keyword.get(options, :truncated?, false)

    fn name, _version, parameters, _authority, scope, _query_options ->
      data =
        if name == :factory_repository_cohort do
          Enum.map(resources, &%{"repository" => &1.iri, "enrollment" => &1.iri <> "/enrollment"})
        else
          project = Map.get(scopes, scope)
          query_data(name, parameters, scope, if(project == "alpha", do: scope, else: ""))
        end

      {:ok, result(name, data, parameters, truncated?)}
    end
  end

  defp query_data(:factory_repository_cohort, _parameters, _scope, _alpha_scope) do
    [
      %{
        "repository" => "https://jido.run/id/repository/alpha",
        "enrollment" => "urn:enrollment:alpha"
      },
      %{
        "repository" => "https://jido.run/id/repository/beta",
        "enrollment" => "urn:enrollment:beta"
      },
      %{
        "repository" => "https://jido.run/id/repository/hidden",
        "enrollment" => "urn:enrollment:hidden"
      }
    ]
  end

  defp query_data(:work_lens, %{state: :blocked}, scope, alpha_scope) when scope == alpha_scope,
    do: [%{"work" => "urn:work:blocked", "successor" => nil}]

  defp query_data(:work_lens, %{state: :awaiting_decision}, scope, alpha_scope)
       when scope != alpha_scope,
       do: [%{"work" => "urn:work:verify", "successor" => nil}]

  defp query_data(:active_attempts, _parameters, scope, alpha_scope) when scope == alpha_scope,
    do: [
      %{
        "attempt" => "urn:attempt:alpha",
        "state" => "urn:state:running",
        "successorState" => "urn:state:failed"
      }
    ]

  defp query_data(_name, _parameters, _scope, _alpha_scope), do: []

  defp result(name, data, parameters, truncated? \\ false) do
    graph_revisions =
      parameters
      |> Enum.filter(fn {key, _value} -> key in [:graph, :control_graph, :wiki_graph] end)
      |> Map.new(fn {_key, graph} -> {graph, 3} end)

    %QueryResult{
      query_name: name,
      query_version: "2.11.0",
      scope_iri: "https://jido.run/id/scope/factory/default",
      dataset_revision: 77,
      graph_revisions: graph_revisions,
      ontology_version: "1.5.0",
      completeness: %{complete?: true},
      freshness: :current,
      truncated?: truncated?,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: %{status: :current},
      evaluated_at: ~U[2026-09-06 00:00:00Z],
      data: data
    }
  end

  defp resources do
    [
      resource("project_alpha", "alpha", "https://jido.run/id/repository/alpha"),
      resource("project_beta", "beta", "https://jido.run/id/repository/beta"),
      resource("project_hidden", "hidden", "https://jido.run/id/repository/hidden")
    ]
  end

  defp resource(ref, project_ref, iri) do
    %Resource{
      resource_ref: ref,
      kind: :project,
      iri: iri,
      tenant_ref: "tenant_phase_c4",
      project_ref: project_ref,
      parent_ref: "factory_phase_c4",
      graph_scope_iri: "https://jido.run/id/scope/project/#{project_ref}",
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
        principal_iri: "https://jido.run/id/human/phase-c4",
        actor_iri: "https://jido.run/id/human/phase-c4",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end

  defp ready_health do
    %Health{state: :ready, store_verified?: true, ontology_verified?: true}
  end
end

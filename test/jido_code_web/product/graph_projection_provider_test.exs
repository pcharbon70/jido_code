defmodule JidoCode.Product.GraphProjectionProviderTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.GraphProjectionProvider

  test "builds a bounded projection from reviewed graph queries" do
    test_pid = self()

    query = fn name, version, parameters, authority, scope, options ->
      send(test_pid, {:query, name, version, parameters, authority, scope, options})
      {:ok, query_result(name, data(name), 12)}
    end

    {:ok, projection} =
      GraphProjectionProvider.load(authority(), identity(),
        health: ready_health(),
        query: query
      )

    assert projection.state == :ready
    assert projection.dataset_revision == 12

    assert [%{label: "alpha", iri: "https://jido.run/id/repository/alpha"}] =
             projection.repositories

    assert_receive {:query, :dataset_revision, "1.7.0", %{}, _authority, _scope, []}

    assert_receive {:query, :factory_repository_cohort, "1.7.0",
                    %{graph: "https://jido.run/graph/factory/catalog", resource: factory},
                    _authority, _scope, []}

    assert factory == identity().factory_iri
    refute_receive {:query, :raw_sparql, _, _, _, _, _}
  end

  test "loads only accepted repository-scoped product lenses" do
    test_pid = self()
    repository = "https://jido.run/id/repository/alpha"
    {:ok, repository_scope} = ResourceIdentity.scope(:repository, repository)

    query = fn name, _version, parameters, _authority, scope, _options ->
      send(test_pid, {:query, name, parameters, scope})
      {:ok, query_result(name, data(name), 15)}
    end

    metadata = fn _graph ->
      {:ok,
       %{
         owner_scope: repository_scope,
         lifecycle_state: :open
       }}
    end

    {:ok, projection} =
      GraphProjectionProvider.load(authority(), identity(),
        health: ready_health(),
        query: query,
        metadata: metadata,
        repository: repository
      )

    assert projection.state == :ready
    assert length(projection.work.eligible) == 1
    assert length(projection.attempts) == 1
    assert length(projection.knowledge) == 1

    assert_receive {:query, :work_lens, %{state: :eligible}, ^repository_scope}
    assert_receive {:query, :work_lens, %{state: :blocked}, ^repository_scope}
    assert_receive {:query, :work_lens, %{state: :executing}, ^repository_scope}
    assert_receive {:query, :work_lens, %{state: :awaiting_decision}, ^repository_scope}
    assert_receive {:query, :active_attempts, %{graph: control_graph}, ^repository_scope}
    assert String.contains?(control_graph, "/control")

    assert_receive {:query, :knowledge_by_scope, %{graph: memory_graph, resource: _repository},
                    ^repository_scope}

    assert String.contains?(memory_graph, "/memory")
  end

  test "renders authorized repositories with not-yet-created graphs as empty" do
    test_pid = self()

    query = fn name, _version, _parameters, _authority, _scope, _options ->
      send(test_pid, {:query, name})
      {:ok, query_result(name, data(name), 16)}
    end

    {:ok, projection} =
      GraphProjectionProvider.load(authority(), identity(),
        health: ready_health(),
        query: query,
        metadata: fn _graph -> {:ok, nil} end,
        repository: "https://jido.run/id/repository/alpha"
      )

    assert projection.state == :ready
    assert projection.work == JidoCode.Product.Projection.empty_work()
    assert projection.attempts == []
    assert projection.knowledge == []
    refute_receive {:query, :work_lens}
    refute_receive {:query, :active_attempts}
    refute_receive {:query, :knowledge_by_scope}
  end

  test "conceals repository selections outside the authorized cohort" do
    query = fn name, _version, _parameters, _authority, _scope, _options ->
      {:ok, query_result(name, data(name), 9)}
    end

    {:ok, projection} =
      GraphProjectionProvider.load(authority(), identity(),
        health: ready_health(),
        query: query,
        repository: "https://jido.run/id/repository/not-visible"
      )

    assert projection.state == :unauthorized
    assert projection.repositories == []
    assert projection.dataset_revision == nil
  end

  test "fails closed during maintenance without issuing a query" do
    query = fn _name, _version, _parameters, _authority, _scope, _options ->
      flunk("query must not run during maintenance")
    end

    health = %{ready_health() | state: :maintenance, maintenance_reason: :schema_migration}

    {:ok, projection} =
      GraphProjectionProvider.load(authority(), identity(), health: health, query: query)

    assert projection.state == :maintenance
    assert projection.repositories == []
  end

  defp data(:dataset_revision), do: [%{"revision" => term(12)}]

  defp data(:factory_repository_cohort) do
    [
      %{
        "enrollment" => term("https://jido.run/id/enrollment/alpha"),
        "repository" => term("https://jido.run/id/repository/alpha")
      }
    ]
  end

  defp data(:work_lens) do
    [%{"task" => term("https://jido.run/id/task/1"), "revision" => term(2)}]
  end

  defp data(:active_attempts) do
    [%{"attempt" => term("https://jido.run/id/attempt/1"), "state" => term("running")}]
  end

  defp data(:knowledge_by_scope) do
    [%{"assertion" => term("https://jido.run/id/knowledge/1"), "state" => term("adopted")}]
  end

  defp query_result(name, data, revision) do
    %QueryResult{
      query_name: name,
      query_version: "1.7.0",
      dataset_revision: revision,
      graph_revisions: %{},
      ontology_version: "1.0.0",
      completeness: %{complete?: true},
      freshness: %{state: :current},
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: :snapshot,
      evaluated_at: ~U[2026-08-04 10:00:00Z],
      data: data
    }
  end

  defp term(value), do: %{type: :literal, value: value}

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: "https://jido.run/id/principal/operator",
        actor_iri: "https://jido.run/id/actor/operator",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end

  defp identity do
    %{
      factory_iri: "https://jido.run/id/repository-factory/default",
      factory_scope_iri: "https://jido.run/id/scope/factory/default"
    }
  end

  defp ready_health do
    %Health{state: :ready, store_verified?: true, ontology_verified?: true}
  end
end

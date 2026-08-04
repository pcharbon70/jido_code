defmodule JidoCode.Product.QuerySecurityTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.QuerySecurity
  alias JidoCode.Product.SurfaceContract

  test "admits only the closed product query and parameter matrix" do
    assert :ok = QuerySecurity.validate(:dataset_revision, "1.7.0", %{})

    assert :ok =
             QuerySecurity.validate(:factory_repository_cohort, "1.7.0", %{
               graph: "https://jido.run/graph/factory/catalog",
               resource: "https://jido.run/id/repository-factory/default"
             })

    assert :ok =
             QuerySecurity.validate(:work_lens, "1.7.0", %{
               graph: control_graph(),
               state: :eligible
             })
  end

  test "rejects raw query names, version widening, extra keys, and graph-family confusion" do
    invalid = [
      {:raw_sparql, "1.7.0", %{}},
      {:dataset_revision, "latest", %{}},
      {:dataset_revision, "1.7.0", %{query: "SELECT * WHERE {?s ?p ?o}"}},
      {:work_lens, "1.7.0", %{graph: control_graph(), state: :owner}},
      {:active_attempts, "1.7.0", %{graph: "https://jido.run/graph/factory/catalog"}},
      {:knowledge_by_scope, "1.7.0",
       %{graph: control_graph(), resource: "https://jido.run/id/repository/alpha"}}
    ]

    for {name, version, parameters} <- invalid do
      assert {:error, error} = QuerySecurity.validate(name, version, parameters)
      assert error.kind == :invalid_input
    end
  end

  test "does not call the query adapter for malformed scope, options, or inputs" do
    query = fn _name, _version, _parameters, _authority, _scope, _options ->
      flunk("query adapter must not run")
    end

    assert {:error, _error} =
             QuerySecurity.execute(
               query,
               :dataset_revision,
               "1.7.0",
               %{},
               authority(),
               "not-an-iri",
               []
             )

    assert {:error, _error} =
             QuerySecurity.execute(
               query,
               :dataset_revision,
               "1.7.0",
               %{},
               authority(),
               "https://jido.run/id/scope/factory/default",
               timeout: :infinity
             )
  end

  test "presentation ref fuzzing never creates query or command selectors" do
    values = [
      "",
      "%%",
      String.duplicate("a", 1_401),
      Base.url_encode64("javascript:alert(1)", padding: false),
      Base.url_encode64("https://jido.run/id/repository/alpha\nSELECT", padding: false),
      Base.url_encode64(<<0, 1, 2, 3>>, padding: false)
    ]

    for value <- values do
      assert SurfaceContract.decode_resource(value) == :error
    end
  end

  defp control_graph do
    {:ok, graph} =
      JidoCode.Knowledge.GraphRegistry.graph_iri(:repository_control, %{
        repository: "https://jido.run/id/repository/alpha"
      })

    graph
  end

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
end

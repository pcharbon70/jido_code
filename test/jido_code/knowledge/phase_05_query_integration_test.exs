defmodule JidoCode.Knowledge.Phase05QueryIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CompletenessBoundary
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryParameters
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.TestSupport.Phase05Fixture

  setup context do
    {:ok, fixture: Phase05Fixture.complete!(context)}
  end

  test "executes every initial catalog query over an authorized multi-graph dataset", %{
    fixture: fixture
  } do
    matrix = Phase05Fixture.query_matrix(fixture)
    assert matrix |> Enum.map(& &1.name) |> Enum.sort() == QueryCatalog.names()

    results =
      Enum.map(matrix, fn query ->
        assert {:ok, result} = execute(fixture, query)
        assert result.query_name == query.name
        assert result.query_version == QueryCatalog.version()
        assert result.dataset_revision > 0
        assert result.consistency.status == :satisfied
        refute result.truncated?
        result
      end)

    by_name = Map.new(results, &{&1.query_name, &1})
    assert by_name.graph_health.data
    assert by_name.ontology_compatibility.data != []
    assert by_name.command_receipt.data != []
    assert by_name.audit_reference.data != []
    assert by_name.resource_description.data != []
    assert by_name.semantic_neighborhood.data != []
    assert by_name.provenance_chain.data != []
    assert by_name.supporting_claims.data != []
    assert by_name.contradicting_claims.data != []
    assert by_name.supersession.data != []
    assert by_name.transition_endpoint.data != []
    assert by_name.transition_history.data != []
    assert by_name.temporal_as_of.data != []
    assert by_name.graph_completeness.data == []
    assert by_name.derived_graph_freshness.freshness == :current
  end

  test "all catalog queries fail closed after substituting an ungranted actor", %{
    fixture: fixture
  } do
    {:ok, stranger_iri} = ResourceIdentity.repository("phase-05-unauthorized-matrix")

    {:ok, stranger} =
      AuthorityContext.new(%{
        principal_iri: stranger_iri,
        actor_iri: stranger_iri,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    for query <- Phase05Fixture.query_matrix(fixture) do
      assert {:error, %{kind: :unauthorized, operation: :catalog_query}} =
               QueryRunner.execute(
                 query.name,
                 QueryCatalog.version(),
                 query.params,
                 stranger,
                 query.scope,
                 server: fixture.query_runner,
                 evaluated_at: fixture.issued_at
               )
    end
  end

  test "rejects injection, graph widening, malformed cursors, and excessive historical scope", %{
    fixture: fixture
  } do
    attacks = [
      "https://jido.run/id/repository/x%7D%20UNION",
      "https://jido.run/id/repository/x\nSERVICE",
      "https://jido.run/id/repository/x> #",
      "https://jido.run/id/repository/x%0aDELETE",
      "\" } { SELECT * WHERE { ?s ?p ?o } }"
    ]

    for attack <- attacks do
      assert {:error, %{kind: :invalid_input}} =
               QueryRunner.execute(
                 :resource_description,
                 QueryCatalog.version(),
                 %{graph: fixture.evidence_graph, resource: attack},
                 fixture.authority,
                 fixture.repository_scope,
                 server: fixture.query_runner,
                 evaluated_at: fixture.issued_at
               )
    end

    assert {:error, %{kind: :invalid_input}} =
             QueryRunner.execute(
               :graph_metadata,
               QueryCatalog.version(),
               %{graph: fixture.evidence_graph, graph_clause: "GRAPH ?g"},
               fixture.authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert {:error, %{kind: :unauthorized}} =
             QueryRunner.execute(
               :graph_metadata,
               QueryCatalog.version(),
               %{graph: fixture.evidence_graph},
               fixture.authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert {:error, %{kind: :invalid_input}} = QueryParameters.decode_cursor("not-a-cursor")

    assert {:error, %{kind: :invalid_input}} =
             QueryRunner.execute(
               :graph_metadata,
               QueryCatalog.version(),
               %{graph: fixture.evidence_graph},
               fixture.authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at,
               consistency: %{
                 mode: :historical,
                 historical_graphs: List.duplicate(fixture.evidence_graph, 21)
               }
             )
  end

  test "concurrent writes never produce mixed dataset and graph revision receipts", %{
    fixture: fixture
  } do
    query = %{
      name: :resource_description,
      params: %{graph: fixture.evidence_graph, resource: fixture.evidence_resource},
      scope: fixture.repository_scope
    }

    before = StoreServer.summary(fixture.store_server).dataset_revision
    parent = self()

    writer =
      Task.async(fn ->
        Process.sleep(5)
        updated = Phase05Fixture.append_evidence!(fixture, 611)
        send(parent, {:write_complete, updated.append_receipt.dataset_revision})
        updated
      end)

    results =
      1..40
      |> Task.async_stream(
        fn _index ->
          {:ok, result} = execute(fixture, query)
          {result.dataset_revision, result.graph_revisions[fixture.evidence_graph]}
        end,
        max_concurrency: 10,
        ordered: false,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, receipt} -> receipt end)

    updated = Task.await(writer, 30_000)
    after_revision = updated.append_receipt.dataset_revision
    assert_receive {:write_complete, ^after_revision}

    {:ok, final_result} = execute(fixture, query)

    results =
      [
        {final_result.dataset_revision, final_result.graph_revisions[fixture.evidence_graph]}
        | results
      ]

    assert Enum.all?(results, fn receipt ->
             receipt in [{before, 1}, {after_revision, 2}]
           end)

    assert {after_revision, 2} in results
  end

  test "closed-world absence remains unknown without exact retained coverage", %{
    fixture: fixture
  } do
    {:ok, assertion_iri} =
      ResourceIdentity.deterministic(:validation_report, "phase-05-integration-completeness")

    {:ok, boundary} =
      CompletenessBoundary.new(%{
        assertion_iri: assertion_iri,
        subject_iri: fixture.goal,
        scope_iri: fixture.repository_scope,
        graph_family: :evidence,
        source_graph_iri: fixture.evidence_graph,
        source_revision: 1,
        predicate_coverage: ["https://jido.run/ontology/factory#waivedBy"],
        class_coverage: [],
        producer_iri: fixture.actor,
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 1, :day),
        invalidated_at: nil
      })

    requirement = %{
      subject_iri: fixture.goal,
      scope_iri: fixture.repository_scope,
      graph_family: :evidence,
      source_graph_iri: fixture.evidence_graph,
      source_revision: 1,
      predicates: ["https://jido.run/ontology/factory#waivedBy"],
      classes: []
    }

    assert {:unknown, _gaps} =
             CompletenessBoundary.closed_world_result(
               false,
               %{requirement | source_revision: 2},
               [boundary],
               fixture.issued_at
             )

    assert {:known, false, ^boundary} =
             CompletenessBoundary.closed_world_result(
               false,
               requirement,
               [boundary],
               fixture.issued_at
             )
  end

  defp execute(fixture, query) do
    QueryRunner.execute(
      query.name,
      QueryCatalog.version(),
      query.params,
      fixture.authority,
      query.scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end
end

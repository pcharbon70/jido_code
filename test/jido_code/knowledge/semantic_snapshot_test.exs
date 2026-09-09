defmodule JidoCode.Knowledge.SemanticSnapshotTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.{GraphMetadata, GraphRegistry, StoreServer}
  alias JidoCode.TestSupport.Phase04Fixture

  test "fresh snapshots retain current metadata revisions across committed changes", context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()
    caller = self()

    :sys.replace_state(fixture.store_server, fn state ->
      %{state | authorized_callers: Map.update!(state.authorized_callers, :write, &[caller | &1])}
    end)

    graph = fixture.graphs.catalog

    {:ok, absent} =
      GraphRegistry.graph_iri(:run_attempt, %{attempt: "https://jido.run/id/attempt/absent"})

    assert {:ok, before} =
             StoreServer.request(fixture.store_server, {:semantic_snapshot, [graph, absent]})

    assert before.graph_revisions[graph] == before.graph_metadata[graph].graph_revision
    assert before.graph_revisions[absent] == 0
    assert before.graph_metadata[absent] == nil

    store = :sys.get_state(fixture.store_server).store

    assert GraphMetadata.read(store, graph) ==
             GraphMetadata.read_from_snapshot(store, graph, before.dataset)

    duplicate_owner =
      RDF.Dataset.add(
        before.dataset,
        {RDF.iri(graph), RDF.iri("https://jido.run/ontology/factory#ownerScope"),
         RDF.iri("https://jido.run/id/other"), RDF.iri(graph)}
      )

    assert {:error, _} = GraphMetadata.read_from_snapshot(store, graph, duplicate_owner)

    other_graph =
      RDF.Dataset.add(
        before.dataset,
        {RDF.iri(graph), RDF.iri("https://jido.run/ontology/factory#ownerScope"),
         RDF.iri("https://jido.run/id/other"), RDF.iri(absent)}
      )

    assert GraphMetadata.read(store, graph) ==
             GraphMetadata.read_from_snapshot(store, graph, other_graph)

    oversized =
      Enum.reduce(1..50, before.dataset, fn index, dataset ->
        RDF.Dataset.add(
          dataset,
          {RDF.iri(graph), RDF.iri("https://example.test/extra/#{index}"), RDF.literal(index),
           RDF.iri(graph)}
        )
      end)

    assert {:error, _} = GraphMetadata.read_from_snapshot(store, graph, oversized)
    assert {:ok, nil} = GraphMetadata.read_from_snapshot(store, absent, before.dataset)

    Phase04Fixture.enroll!(fixture)

    assert {:ok, after_commit} =
             StoreServer.request(fixture.store_server, {:semantic_snapshot, [graph, absent]})

    assert after_commit.graph_revisions[graph] > before.graph_revisions[graph]

    assert after_commit.graph_revisions[graph] ==
             after_commit.graph_metadata[graph].graph_revision

    assert after_commit.dataset_revision > before.dataset_revision
    assert after_commit.graph_revisions[absent] == 0
  end
end

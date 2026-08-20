defmodule JidoCode.Knowledge.Memory.Phase03HistoryCatalogTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CatalogQueryRequest
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @history_queries ~w[
    attempt_capture_completeness task_attempt_lineage attempt_event_range segment_event_range
    exact_failure_occurrences issue_change_test_lineage incident_linkage why_does_this_exist
  ]a

  test "publishes the reviewed 2.0.0 history catalog without changing legacy versions" do
    assert QueryCatalog.history_version() == "2.0.0"
    assert :attempt_timeline in QueryCatalog.names(QueryCatalog.history_version())

    assert Enum.all?(
             @history_queries,
             &(&1 in QueryCatalog.names(QueryCatalog.history_version()))
           )

    refute Enum.any?(
             @history_queries,
             &(&1 in QueryCatalog.names(QueryCatalog.knowledge_version()))
           )

    assert {:error, %{kind: :invalid_input}} = QueryCatalog.fetch(:attempt_event_range, "1.7.0")
    assert :ok = QueryCatalog.verify()
  end

  test "history definitions are bounded, source-linked, temporal, and content-free" do
    for name <- @history_queries do
      assert {:ok, definition} = QueryCatalog.fetch(name, QueryCatalog.history_version())
      assert definition.version == "2.0.0"
      assert definition.execution_class == :product
      assert definition.limits.row_limit == 200
      assert definition.limits.byte_limit == 256_000
      assert String.contains?(definition.source, "LIMIT {{row_limit}}")
      refute String.contains?(definition.source, "episodeContent")
      refute String.contains?(definition.source, "contentCiphertext")
    end

    for name <-
          ~w[exact_failure_occurrences issue_change_test_lineage incident_linkage why_does_this_exist]a do
      {:ok, definition} = QueryCatalog.fetch(name, QueryCatalog.history_version())
      assert Map.has_key?(definition.parameters, :instant)
      assert String.contains?(definition.source, "{{instant}}")
    end

    for name <- ~w[attempt_event_range segment_event_range]a do
      {:ok, definition} = QueryCatalog.fetch(name, QueryCatalog.history_version())
      assert definition.parameters.sequence_start.max == 1_000_000
      assert definition.parameters.sequence_end.max == 1_000_000
      assert String.contains?(definition.source, "GRAPH {{graph}}")
    end
  end

  test "typed binding accepts bounded event ranges and rejects excessive ranges" do
    assert {:ok, authority} =
             AuthorityContext.new(%{
               principal_iri: "https://jido.run/id/actor/01J00000000000000000000001",
               actor_iri: "https://jido.run/id/actor/01J00000000000000000000001",
               delegated_agent_iri: nil,
               delegation_iri: nil
             })

    assert {:ok, attempt} = ResourceIdentity.deterministic(:execution_attempt, "phase-03-range")

    assert {:ok, graph} =
             GraphRegistry.graph_iri(:run_event_segment, %{attempt: attempt, segment: 0})

    scope = "https://jido.run/id/repository/01J00000000000000000000003"

    assert {:ok, request} =
             CatalogQueryRequest.new(
               :attempt_event_range,
               QueryCatalog.history_version(),
               %{graph: graph, resource: attempt, sequence_start: 0, sequence_end: 80},
               authority,
               scope
             )

    assert request.parameters.sequence_start == 0
    assert request.parameters.sequence_end == 80
    assert request.graph_iris == [graph]

    assert {:error, %{kind: :invalid_input}} =
             CatalogQueryRequest.new(
               :attempt_event_range,
               QueryCatalog.history_version(),
               %{graph: graph, resource: attempt, sequence_start: 0, sequence_end: 1_000_001},
               authority,
               scope
             )
  end
end

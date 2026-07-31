defmodule JidoCode.Knowledge.WriteBatchTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Vocabulary
  alias JidoCode.Knowledge.WriteBatch

  @graph_a "https://jido.code/tests/graphs/a"
  @graph_b "https://jido.code/tests/graphs/b"

  test "normalizes a backend-neutral batch and computes an order-independent digest" do
    additions = [quad("one", @graph_a), quad("two", @graph_b)]

    options = [
      expected_dataset_revision: 3,
      expected_graph_revisions: %{@graph_a => 1, RDF.iri(@graph_b) => 2},
      operation_metadata: %{trace: "opaque"}
    ]

    assert {:ok, batch} = WriteBatch.new(additions, options)
    assert batch.target_graphs == [@graph_a, @graph_b]
    assert batch.expected_graph_revisions == %{@graph_a => 1, @graph_b => 2}
    assert batch.operation_metadata == %{trace: "opaque"}
    assert byte_size(batch.batch_digest) == 64

    assert {:ok, reordered} =
             WriteBatch.new(Enum.reverse(additions),
               expected_dataset_revision: 3,
               expected_graph_revisions: %{@graph_b => 2, @graph_a => 1},
               operation_metadata: %{different: "not-authoritative"},
               commit_id: batch.commit_id
             )

    assert reordered.batch_digest == batch.batch_digest
  end

  test "requires named application graphs and exact expected revisions" do
    assert {:error, %Error{kind: :invalid_input, operation: :validate_write_quads}} =
             WriteBatch.new(
               [RDF.quad("https://jido.code/s", "https://jido.code/p", "value", nil)],
               expected_dataset_revision: 0,
               expected_graph_revisions: %{}
             )

    assert {:error, %Error{kind: :invalid_input, operation: :validate_write_quads}} =
             WriteBatch.new([quad("system", Vocabulary.system_graph())],
               expected_dataset_revision: 0,
               expected_graph_revisions: %{Vocabulary.system_graph() => 0}
             )

    blank_subject = RDF.bnode("subject")

    assert {:error, %Error{kind: :invalid_input, operation: :validate_write_quads}} =
             WriteBatch.new(
               [RDF.quad(blank_subject, "https://jido.code/p", "value", @graph_a)],
               expected_dataset_revision: 0,
               expected_graph_revisions: %{@graph_a => 0}
             )

    assert {:error, %Error{kind: :invalid_input, operation: :validate_expected_revision}} =
             WriteBatch.new([quad("one", @graph_a)],
               expected_dataset_revision: 0,
               expected_graph_revisions: %{@graph_b => 0}
             )
  end

  test "represents removals only when explicit maintenance policy owns them" do
    removal = quad("old", @graph_a)
    addition = quad("new", @graph_a)

    assert {:error, %Error{kind: :invalid_input, operation: :validate_removal_policy}} =
             WriteBatch.new([addition],
               removals: [removal],
               expected_dataset_revision: 1,
               expected_graph_revisions: %{@graph_a => 1}
             )

    assert {:ok, batch} =
             WriteBatch.new([addition],
               removals: [removal],
               removal_policy: :maintenance,
               expected_dataset_revision: 1,
               expected_graph_revisions: %{@graph_a => 1}
             )

    assert batch.removals == [removal]
    assert batch.removal_policy == :maintenance
  end

  test "rejects invalid commit identities and unbounded opaque metadata" do
    assert {:error, %Error{operation: :validate_commit_identity}} =
             WriteBatch.new([quad("one", @graph_a)],
               commit_id: "not-an-iri",
               expected_dataset_revision: 0,
               expected_graph_revisions: %{@graph_a => 0}
             )

    assert {:error, %Error{operation: :validate_operation_metadata}} =
             WriteBatch.new([quad("one", @graph_a)],
               expected_dataset_revision: 0,
               expected_graph_revisions: %{@graph_a => 0},
               operation_metadata: %{payload: String.duplicate("x", 5_000)}
             )
  end

  defp quad(id, graph) do
    RDF.quad(
      "https://jido.code/tests/resources/#{id}",
      "https://jido.code/tests/vocab/value",
      id,
      graph
    )
  end
end

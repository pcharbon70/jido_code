defmodule JidoCode.Knowledge.Memory.Phase07DatasetConstructionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.CrossRepositoryAuthorization
  alias JidoCode.Knowledge.Memory.MemoryDatasetBuilder
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.Memory.MemoryDatasetRow
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @cutoff ~U[2026-08-01 00:00:00Z]
  @created_at ~U[2026-08-03 00:00:00Z]

  test "pins a source-complete chronological manifest and dataset graph" do
    assert {:ok, authorization} = authorization()
    assert {:ok, manifest} = manifest(authorization)

    assert manifest.cutoff == @cutoff
    assert manifest.source_graph_iris == Enum.sort(source_graphs())
    assert manifest.source_resource_iris == Enum.sort(source_resources())
    assert manifest.classifications == [:experience_record]
    assert manifest.exact_content_states == exact_content_states()
    assert MemoryDatasetManifest.statements(manifest) |> length() > 20

    assert {:ok, graph} =
             GraphRegistry.graph_iri(:memory_dataset, %{
               cohort: authorization.cohort_iri,
               dataset: manifest.iri
             })

    assert {:ok, :memory_dataset} = GraphRegistry.identify(graph)
    assert {:ok, %{capability: :dataset_writer}} = GraphRegistry.fetch(:memory_dataset)
    assert GraphRegistry.allowed_link?(:memory_dataset, :experience)
    refute GraphRegistry.allowed_link?(:episode_content, :memory_dataset)
    assert DataPolicy.durable_allowed?(:export_derivative, :memory_dataset)
  end

  test "excludes future and forbidden evidence, deduplicates overlap, and isolates repositories" do
    assert {:ok, authorization} = authorization()
    assert {:ok, manifest} = manifest(authorization)
    [first, second] = repositories()

    first_row = candidate(first, 0, :success)

    second_row =
      candidate(second, 1, :failure)
      |> Map.put(:task_iri, Enum.at(source_resources(), 3))
      |> Map.put(:source_resource_iris, [Enum.at(source_resources(), 3)])

    future =
      candidate(first, 2, :success)
      |> Map.put(:effective_at, ~U[2026-08-02 00:00:00Z])

    future_review =
      candidate(second, 3, :ambiguous)
      |> Map.put(:task_iri, Enum.at(source_resources(), 4))
      |> Map.put(:source_resource_iris, [Enum.at(source_resources(), 4)])
      |> Map.put(:future_evidence_at, ~U[2026-08-04 00:00:00Z])

    secret = candidate(first, 4, :success) |> Map.put(:secret, true)

    unresolved =
      candidate(second, 5, :infrastructure)
      |> Map.put(:task_iri, Enum.at(source_resources(), 5))
      |> Map.put(:source_resource_iris, [Enum.at(source_resources(), 5)])
      |> Map.put(:unresolved_deletion?, true)

    duplicate =
      candidate(second, 6, :revert)
      |> Map.put(:task_iri, Enum.at(source_resources(), 4))
      |> Map.put(:source_resource_iris, [Enum.at(source_resources(), 4)])
      |> Map.put(:semantic_digest, first_row.semantic_digest)
      |> Map.put(:effective_at, ~U[2026-07-21 00:00:00Z])

    assert {:ok, result} =
             MemoryDatasetBuilder.build(manifest, [
               first_row,
               second_row,
               future,
               future_review,
               secret,
               unresolved,
               duplicate
             ])

    assert length(result.rows) == 2
    assert length(result.exclusions) == 5
    assert result.class_balance == %{failure: 1, success: 1}
    assert result.repository_splits[first] == [:development]
    assert result.repository_splits[second] == [:evaluation]
    assert result.source_complete?
    assert result.temporal_leakage_count == 0

    assert Enum.sort(Enum.map(result.exclusions, & &1.reason)) ==
             Enum.sort([
               :post_cutoff_evidence,
               :future_evidence,
               :forbidden_content,
               :unresolved_deletion,
               :duplicate
             ])

    for row <- result.rows do
      assert %MemoryDatasetRow{} = row
      assert DateTime.compare(row.effective_at, @cutoff) in [:lt, :eq]
      assert row.source_resource_iris != []
      refute Map.has_key?(Map.from_struct(row), :payload)
      assert MemoryDatasetRow.statements(row) |> length() >= 14
    end
  end

  test "rejects personal data and split or erasure drift at manifest construction" do
    assert {:ok, authorization} = authorization()

    assert {:error, %{kind: :invalid_input}} =
             manifest(authorization, %{classifications: [:personal]})

    [first, second] = repositories()

    assert {:error, %{kind: :invalid_input}} =
             manifest(authorization, %{
               split_policy: %{first => :development, second => :development}
             })

    assert {:error, %{kind: :invalid_input}} =
             manifest(authorization, %{erasure_generations: %{first => 4, second => 8}})
  end

  test "versions the dataset writer boundary without authorizing model training" do
    assert GraphRegistry.revision() == "2.5.0"
    assert DataPolicy.revision() == "2.2.0"
    assert CommandRegistry.dataset_version() == "2.5.0"
    assert :dataset_writer in Authorization.capabilities()

    for command <- [
          "StoreMemoryDatasetManifest",
          "RecordMemoryDatasetRows",
          "InvalidateMemoryDatasetRows"
        ] do
      assert {:ok, definition} = CommandRegistry.resolve(command, "2.5.0")
      assert definition.capability == :dataset_writer
    end

    refute Enum.any?(CommandRegistry.names("2.5.0"), fn command ->
             String.contains?(command, ["Train", "Checkpoint", "Deploy"])
           end)
  end

  defp authorization do
    CrossRepositoryAuthorization.new(%{
      cohort_iri: resource(:repository_cohort, "dataset-cohort"),
      repository_iris: repositories(),
      actor_iris: [resource(:authorization_grant, "dataset-actor")],
      purpose: :dataset_construction,
      allowed_uses: [:candidate_generation, :dataset_construction, :export],
      data_classes: [:experience_record, :personal],
      effective_cutoff: @cutoff,
      valid_from: ~U[2026-08-02 00:00:00Z],
      expires_at: ~U[2026-09-01 00:00:00Z],
      policy_revision: "2.1.0",
      decision_iri: resource(:authorization_grant, "dataset-decision"),
      decision: :authorized,
      erasure_generations: erasure_generations()
    })
  end

  defp manifest(authorization, overrides \\ %{}) do
    defaults = %{
      cohort_iri: authorization.cohort_iri,
      purpose: authorization.purpose,
      authorization_iri: authorization.iri,
      repository_iris: repositories(),
      source_graph_iris: source_graphs(),
      source_resource_iris: source_resources(),
      cutoff: @cutoff,
      classifications: [:experience_record],
      extractor_revision: "1.0.0",
      query_revision: "2.4.0",
      split_policy: split_policy(),
      erasure_generations: erasure_generations(),
      exact_content_states: exact_content_states(),
      created_at: @created_at
    }

    MemoryDatasetManifest.new(authorization, Map.merge(defaults, overrides))
  end

  defp candidate(repository, index, outcome) do
    %{
      iri: resource(:experience_case, "candidate-#{index}"),
      repository_iri: repository,
      task_iri: Enum.at(source_resources(), rem(index, length(source_resources()))),
      patch_digest: digest("patch-#{index}"),
      incident_iri: nil,
      classification: :experience_record,
      outcome: outcome,
      effective_at: ~U[2026-07-20 00:00:00Z],
      source_resource_iris: [Enum.at(source_resources(), rem(index, length(source_resources())))],
      semantic_digest: digest("semantic-#{index}"),
      representation_digest: digest("representation-#{index}"),
      erasure_generation: Map.fetch!(erasure_generations(), repository),
      source_complete?: true
    }
  end

  defp repositories do
    [
      resource(:repository_snapshot, "dataset-repository-a"),
      resource(:repository_snapshot, "dataset-repository-b")
    ]
  end

  defp source_graphs do
    Enum.map(repositories(), fn repository ->
      {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: repository})
      graph
    end)
  end

  defp source_resources do
    Enum.map(0..5, &resource(:experience_case, "dataset-source-#{&1}"))
  end

  defp split_policy do
    [first, second] = repositories()
    %{first => :development, second => :evaluation}
  end

  defp erasure_generations do
    [first, second] = repositories()
    %{first => 3, second => 7}
  end

  defp exact_content_states do
    %{resource(:episode_content, "dataset-content") => :authorized_reference}
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

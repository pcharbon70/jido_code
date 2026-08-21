defmodule JidoCode.Knowledge.Memory.Phase07DatasetExportTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.CrossRepositoryAuthorization
  alias JidoCode.Knowledge.Memory.DatasetExportPermit
  alias JidoCode.Knowledge.Memory.DatasetExportVerifier
  alias JidoCode.Knowledge.Memory.DatasetLifecycle
  alias JidoCode.Knowledge.Memory.DatasetTrainingBoundary
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.Memory.MemoryDatasetArtifact
  alias JidoCode.Knowledge.Memory.MemoryDatasetBuilder
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @cutoff ~U[2026-08-01 00:00:00Z]
  @now ~U[2026-08-03 12:00:00Z]

  test "releases only a verified manifest through an expiring approved-sink permit" do
    result = dataset_result()
    assert {:ok, permit} = permit(result.manifest)
    attributes = artifact_attributes(result)

    assert {:ok, verified} = DatasetExportVerifier.verify(result, permit, attributes, @now)
    assert %MemoryDatasetArtifact{} = verified.artifact
    assert verified.chronology_verified?
    assert verified.split_isolation_verified?
    assert verified.deduplication_verified?
    assert verified.source_completeness_verified?
    assert verified.class_balance_verified?
    assert verified.forbidden_content_absent?
    assert verified.artifact.payload_external?
    assert MemoryDatasetArtifact.statements(verified.artifact) |> length() >= 15

    refute Map.has_key?(Map.from_struct(verified.artifact), :payload)

    assert {:error, %{kind: :unauthorized}} =
             DatasetExportVerifier.verify(
               result,
               permit,
               %{attributes | class_balance: %{success: 2}},
               @now
             )

    assert {:ok, consumed} = DatasetExportPermit.consume(permit, @now)
    assert consumed.state == :consumed
    assert {:error, %{kind: :unauthorized}} = DatasetExportPermit.consume(consumed, @now)
  end

  test "propagates hold, revocation, invalidation, and erasure to every external copy" do
    result = dataset_result()
    assert {:ok, permit} = permit(result.manifest)

    assert {:ok, verified} =
             DatasetExportVerifier.verify(result, permit, artifact_attributes(result), @now)

    evidence = resource(:authorization_grant, "dataset-lifecycle-evidence")

    assert {:ok, held} =
             DatasetLifecycle.transition(verified.artifact, :hold_placed, %{
               evidence_iri: evidence,
               recorded_at: @now
             })

    assert held.next_state == :quarantined
    assert Enum.all?(held.external_copy_actions, &(&1.action == :quarantine))

    assert {:ok, released} =
             DatasetLifecycle.transition(held.artifact, :hold_released, %{
               evidence_iri: evidence,
               recorded_at: DateTime.add(@now, 1, :second)
             })

    assert released.next_state == :available

    for event <- [:authorization_revoked, :source_invalidated, :erasure_requested] do
      assert {:ok, removal} =
               DatasetLifecycle.transition(released.artifact, event, %{
                 evidence_iri: evidence,
                 recorded_at: DateTime.add(@now, 2, :second)
               })

      assert removal.next_state == :deletion_required
      assert Enum.all?(removal.external_copy_actions, &(&1.action == :delete))
    end

    assert {:ok, requested} =
             DatasetLifecycle.transition(released.artifact, :erasure_requested, %{
               evidence_iri: evidence,
               recorded_at: DateTime.add(@now, 3, :second)
             })

    assert {:ok, deleted} =
             DatasetLifecycle.transition(requested.artifact, :deletion_attested, %{
               evidence_iri: evidence,
               recorded_at: DateTime.add(@now, 4, :second)
             })

    assert deleted.next_state == :deleted
  end

  test "keeps training, checkpoints, registries, and deployment outside this phase" do
    manifest = dataset_result().manifest
    digest = digest("pinned-manifest")

    assert {:ok, boundary} =
             DatasetTrainingBoundary.requirements(
               manifest.iri,
               digest,
               resource(:plan_proposal, "future-training-plan"),
               [resource(:evidence_bundle, "future-training-gate")]
             )

    refute boundary.training_authorized?
    refute boundary.checkpoint_authorized?
    refute boundary.deployment_authorized?
    assert boundary.next_required_decision == :separate_training_plan_acceptance

    assert {:error, %{kind: :conflict, operation: :separate_training_plan_required}} =
             DatasetTrainingBoundary.authorize_training(%{})

    for feature <- [
          :broad_cohort_access,
          :automatic_dataset_export,
          :model_training,
          :model_deployment
        ] do
      refute Guardrails.feature_enabled?(feature)
      assert Map.has_key?(Guardrails.disabled_features(), feature)
    end

    assert Guardrails.feature_enabled?(:governed_dataset_construction)
    assert Guardrails.feature_enabled?(:governed_dataset_export)
  end

  test "pins export commands without adding an automatic export command" do
    assert CommandRegistry.dataset_export_version() == "2.6.0"
    assert :dataset_exporter in Authorization.capabilities()

    for command <- [
          "AuthorizeMemoryDatasetExport",
          "RecordMemoryDatasetExport",
          "TransitionMemoryDatasetLifecycle"
        ] do
      assert {:ok, definition} = CommandRegistry.resolve(command, "2.6.0")
      assert definition.capability == :dataset_exporter
    end

    refute "AutomaticallyExportDataset" in CommandRegistry.names("2.6.0")
  end

  defp dataset_result do
    assert {:ok, authorization} =
             CrossRepositoryAuthorization.new(%{
               cohort_iri: resource(:repository_cohort, "export-cohort"),
               repository_iris: repositories(),
               actor_iris: [actor()],
               purpose: :dataset_construction,
               allowed_uses: [:dataset_construction, :export],
               data_classes: [:experience_record],
               effective_cutoff: @cutoff,
               valid_from: ~U[2026-08-02 00:00:00Z],
               expires_at: ~U[2026-09-01 00:00:00Z],
               policy_revision: "2.1.0",
               decision_iri: resource(:authorization_grant, "export-decision"),
               decision: :authorized,
               erasure_generations: erasure_generations()
             })

    sources = [
      resource(:experience_case, "export-source-a"),
      resource(:experience_case, "export-source-b")
    ]

    source_graphs =
      Enum.map(repositories(), fn repository ->
        {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: repository})
        graph
      end)

    [first, second] = repositories()

    assert {:ok, manifest} =
             MemoryDatasetManifest.new(authorization, %{
               cohort_iri: authorization.cohort_iri,
               purpose: authorization.purpose,
               authorization_iri: authorization.iri,
               repository_iris: repositories(),
               source_graph_iris: source_graphs,
               source_resource_iris: sources,
               cutoff: @cutoff,
               classifications: [:experience_record],
               extractor_revision: "1.0.0",
               query_revision: "2.5.0",
               split_policy: %{first => :development, second => :evaluation},
               erasure_generations: erasure_generations(),
               exact_content_states: %{},
               created_at: @now
             })

    candidates = [
      candidate(first, Enum.at(sources, 0), 0, :success),
      candidate(second, Enum.at(sources, 1), 1, :failure)
    ]

    assert {:ok, result} = MemoryDatasetBuilder.build(manifest, candidates)
    result
  end

  defp permit(manifest) do
    DatasetExportPermit.new(manifest, %{
      manifest_iri: manifest.iri,
      authorization_iri: manifest.authorization_iri,
      actor_iri: actor(),
      sink_iri: resource(:dataset_external_copy, "approved-evaluation-sink"),
      purpose: manifest.purpose,
      classifications: manifest.classifications,
      row_limit: 10,
      byte_limit: 1_000_000,
      issued_at: @now,
      expires_at: DateTime.add(@now, 3_600, :second)
    })
  end

  defp artifact_attributes(result) do
    %{
      dataset_digest: digest("external-dataset-payload"),
      schema_revision: "1.0.0",
      row_count: length(result.rows),
      byte_count: 4_096,
      source_row_iris: Enum.map(result.rows, & &1.iri) |> Enum.sort(),
      external_copy_iris: [resource(:dataset_external_copy, "evaluation-copy")],
      class_balance: result.class_balance,
      created_at: @now
    }
  end

  defp candidate(repository, source, index, outcome) do
    %{
      iri: resource(:experience_case, "export-candidate-#{index}"),
      repository_iri: repository,
      task_iri: source,
      patch_digest: digest("export-patch-#{index}"),
      incident_iri: nil,
      classification: :experience_record,
      outcome: outcome,
      effective_at: ~U[2026-07-20 00:00:00Z],
      source_resource_iris: [source],
      semantic_digest: digest("export-semantic-#{index}"),
      representation_digest: digest("export-representation-#{index}"),
      erasure_generation: Map.fetch!(erasure_generations(), repository),
      source_complete?: true
    }
  end

  defp repositories do
    [
      resource(:repository_snapshot, "export-repository-a"),
      resource(:repository_snapshot, "export-repository-b")
    ]
  end

  defp erasure_generations do
    [first, second] = repositories()
    %{first => 2, second => 4}
  end

  defp actor, do: resource(:authorization_grant, "export-actor")
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

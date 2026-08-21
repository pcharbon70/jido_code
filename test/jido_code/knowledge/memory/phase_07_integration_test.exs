defmodule JidoCode.Knowledge.Memory.Phase07IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.Memory.ContentBackupManifest
  alias JidoCode.Knowledge.Memory.CrossRepositoryAuthorization
  alias JidoCode.Knowledge.Memory.CrossRepositoryPolicy
  alias JidoCode.Knowledge.Memory.DatasetExportPermit
  alias JidoCode.Knowledge.Memory.DatasetExportVerifier
  alias JidoCode.Knowledge.Memory.DatasetLifecycle
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.Memory.InMemoryContentKeyProvider
  alias JidoCode.Knowledge.Memory.MemoryDatasetBuilder
  alias JidoCode.Knowledge.Memory.MemoryDatasetCommand
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.Memory.MemoryEvaluationProgram
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Security.DataPolicy
  alias JidoCode.TestSupport.Phase03RetrievalFixture
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    fixture = Phase03RetrievalFixture.complete!(context)

    {:ok, keys} =
      start_supervised(
        {InMemoryContentKeyProvider,
         random_bytes: fn count -> :crypto.hash(:sha256, "phase-7-key-#{count}") end}
      )

    %{fixture: fixture, keys: keys}
  end

  test "commits the authorized graph-to-dataset-to-export-to-evaluation path and revokes it",
       %{fixture: fixture} do
    setup = dataset_setup(fixture)
    manifest = setup.result.manifest
    graph = dataset_graph!(setup.authorization, manifest)

    assert {:ok, command} =
             MemoryDatasetCommand.store_manifest(
               manifest,
               graph,
               0,
               command_attributes(fixture, graph, 0, setup.now, "manifest"),
               clock: fn -> setup.now end
             )

    commit!(fixture, command)

    assert {:ok, command} =
             MemoryDatasetCommand.record_rows(
               manifest,
               setup.result.rows,
               graph,
               1,
               command_attributes(fixture, graph, 1, DateTime.add(setup.now, 1, :second), "rows"),
               clock: fn -> DateTime.add(setup.now, 1, :second) end
             )

    commit!(fixture, command)

    assert {:ok, permit} = export_permit(manifest, fixture.actor, setup.now)

    assert {:ok, command} =
             MemoryDatasetCommand.authorize_export(
               manifest,
               permit,
               graph,
               2,
               command_attributes(
                 fixture,
                 graph,
                 2,
                 DateTime.add(setup.now, 2, :second),
                 "permit"
               ),
               clock: fn -> DateTime.add(setup.now, 2, :second) end
             )

    commit!(fixture, command)

    artifact_attributes = artifact_attributes(setup.result)

    assert {:ok, verification} =
             DatasetExportVerifier.verify(
               setup.result,
               permit,
               artifact_attributes,
               DateTime.add(setup.now, 3, :second)
             )

    assert {:ok, command} =
             MemoryDatasetCommand.record_export(
               manifest,
               verification.artifact,
               graph,
               3,
               command_attributes(
                 fixture,
                 graph,
                 3,
                 DateTime.add(setup.now, 3, :second),
                 "export"
               ),
               clock: fn -> DateTime.add(setup.now, 3, :second) end
             )

    commit!(fixture, command)

    assert {:ok, evaluation} = evaluation(manifest, fixture.actor, setup.now)
    assert evaluation.accepted?

    assert {:ok, command} =
             MemoryDatasetCommand.record_evaluation(
               manifest,
               evaluation,
               graph,
               4,
               command_attributes(
                 fixture,
                 graph,
                 4,
                 DateTime.add(setup.now, 4, :second),
                 "evaluation"
               ),
               clock: fn -> DateTime.add(setup.now, 4, :second) end
             )

    commit!(fixture, command)

    evidence = resource(:authorization_grant, "phase-7-source-invalidation")

    assert {:ok, invalidated} =
             DatasetLifecycle.transition(verification.artifact, :source_invalidated, %{
               evidence_iri: evidence,
               recorded_at: DateTime.add(setup.now, 5, :second)
             })

    assert invalidated.next_state == :deletion_required
    assert Enum.all?(invalidated.external_copy_actions, &(&1.action == :delete))

    assert {:ok, command} =
             MemoryDatasetCommand.transition_lifecycle(
               manifest,
               invalidated,
               graph,
               5,
               command_attributes(
                 fixture,
                 graph,
                 5,
                 DateTime.add(setup.now, 5, :second),
                 "invalidate"
               ),
               clock: fn -> DateTime.add(setup.now, 5, :second) end
             )

    commit!(fixture, command)

    Phase04Fixture.kill_writer!(fixture)
    Phase04Fixture.restart_writer!(fixture)

    assert {:ok, metadata} = QueryRunner.graph_metadata(graph, server: fixture.query_runner)
    assert metadata.graph_revision == 6
    assert metadata.lifecycle_state == :open
    assert metadata.completeness_state == :complete

    trace = %{
      capture: fixture.memory_capture.iri,
      history: fixture.memory_event.iri,
      case: setup.trace.case,
      claim: setup.trace.claim,
      procedure: setup.trace.procedure,
      exact_content: setup.trace.exact_content,
      content_access: setup.trace.content_access,
      dataset: manifest.iri,
      export: verification.artifact.iri,
      evaluation: evaluation.iri,
      revocation: invalidated.transition_iri
    }

    assert Enum.all?(trace, fn {_stage, iri} -> ResourceIdentity.validate(iri) == :ok end)

    refute inspect(MemoryEvaluationProgram.statements(evaluation), limit: :infinity) =~
             "phase-7-protected-payload-canary"
  end

  test "conceals denied repositories and survives rebuild, rotation, restore, hold, expiry, and deletion",
       %{fixture: fixture, keys: keys} do
    setup = dataset_setup(fixture)
    authorization = setup.authorization
    partition = CrossRepositoryPolicy.partition_key(authorization)
    denied_repository = resource(:repository_snapshot, "phase-7-denied-repository")

    request = %{
      actor_iri: fixture.actor,
      purpose: :dataset_construction,
      use: :candidate_generation,
      repository_iris: authorization.repository_iris,
      data_class: :experience_record
    }

    indexes = %{partition => setup.candidates, "denied" => [%{repository_iri: denied_repository}]}

    assert {:ok, candidates} =
             CrossRepositoryPolicy.candidates(authorization, indexes, request, setup.now)

    assert Enum.all?(candidates, &(&1.repository_iri != denied_repository))

    assert {:error, %{kind: :unauthorized}} =
             CrossRepositoryPolicy.candidates(
               authorization,
               indexes,
               %{request | repository_iris: [denied_repository]},
               setup.now
             )

    hostile = [
      Map.put(List.first(setup.candidates), :secret, true),
      Map.put(List.first(setup.candidates), :personal, true),
      Map.put(List.first(setup.candidates), :provider_private, true),
      Map.put(List.first(setup.candidates), :hidden_reasoning, true),
      Map.put(
        List.first(setup.candidates),
        :future_evidence_at,
        DateTime.add(setup.cutoff, 60, :second)
      ),
      Map.put(List.first(setup.candidates), :unresolved_deletion?, true)
    ]

    assert {:ok, adversarial} = MemoryDatasetBuilder.build(setup.result.manifest, hostile)
    assert adversarial.rows == []
    assert length(adversarial.exclusions) == 6

    assert {:ok, rebuilt} =
             MemoryDatasetBuilder.build(setup.result.manifest, Enum.reverse(setup.candidates))

    assert Enum.map(rebuilt.rows, & &1.iri) |> Enum.sort() ==
             Enum.map(setup.result.rows, & &1.iri) |> Enum.sort()

    content = resource(:episode_content, "phase-7-keyed-content")

    assert {:ok, first_key} =
             InMemoryContentKeyProvider.create_key(keys, fixture.factory_scope, content)

    assert {:ok, rotated_key} =
             InMemoryContentKeyProvider.rotate_key(keys, fixture.factory_scope, content)

    assert rotated_key.generation == first_key.generation + 1
    assert :ok = InMemoryContentKeyProvider.destroy_key(keys, first_key.reference_iri)

    assert {:error, %{kind: :unavailable}} =
             InMemoryContentKeyProvider.fetch_key(keys, first_key.reference_iri)

    assert {:ok, backup} =
             ContentBackupManifest.new(%{
               backup_iri: resource(:content_backup_manifest, "phase-7-backup"),
               erasure_generation: 9,
               excluded_content_iris: [setup.result.manifest.iri],
               excluded_key_iris: [first_key.reference_iri],
               created_at: setup.now
             })

    refute ContentBackupManifest.restore_allowed?(backup, %{
             erasure_generation: 9,
             content_iris: [setup.result.manifest.iri],
             key_iris: []
           })

    assert {:ok, permit} = export_permit(setup.result.manifest, fixture.actor, setup.now)
    refute DatasetExportPermit.current?(permit, permit.expires_at)

    assert {:ok, verification} =
             DatasetExportVerifier.verify(
               setup.result,
               permit,
               artifact_attributes(setup.result),
               DateTime.add(setup.now, 1, :second)
             )

    evidence = resource(:authorization_grant, "phase-7-hold-evidence")

    assert {:ok, held} =
             DatasetLifecycle.transition(verification.artifact, :hold_placed, %{
               evidence_iri: evidence,
               recorded_at: DateTime.add(setup.now, 2, :second)
             })

    assert held.next_state == :quarantined

    assert {:ok, erased} =
             DatasetLifecycle.transition(held.artifact, :erasure_requested, %{
               evidence_iri: evidence,
               recorded_at: DateTime.add(setup.now, 3, :second)
             })

    assert erased.next_state == :deletion_required

    refute DataPolicy.profile_enabled?(:diagnostic_capture)
    refute DataPolicy.profile_enabled?(:project_total_history)

    for feature <- [
          :broad_cohort_access,
          :automatic_dataset_export,
          :model_training,
          :model_deployment
        ] do
      refute Guardrails.feature_enabled?(feature)
    end
  end

  defp dataset_setup(fixture) do
    cutoff = fixture.issued_at
    now = DateTime.add(cutoff, 2, :second)
    other_repository = resource(:repository_snapshot, "phase-7-other-repository")
    repositories = Enum.sort([fixture.repository, other_repository])
    generations = %{fixture.repository => 4, other_repository => 6}

    assert {:ok, authorization} =
             CrossRepositoryAuthorization.new(%{
               cohort_iri: resource(:repository_cohort, "phase-7-integration-cohort"),
               repository_iris: repositories,
               actor_iris: [fixture.actor],
               purpose: :dataset_construction,
               allowed_uses: [:query, :candidate_generation, :dataset_construction, :export],
               data_classes: [:experience_record],
               effective_cutoff: cutoff,
               valid_from: DateTime.add(cutoff, 1, :second),
               expires_at: DateTime.add(cutoff, 86_000, :second),
               policy_revision: DataPolicy.revision(),
               decision_iri: resource(:authorization_grant, "phase-7-integration-decision"),
               decision: :authorized,
               erasure_generations: generations
             })

    trace = %{
      case: resource(:experience_case, "phase-7-trace-case"),
      claim: resource(:artifact_claim, "phase-7-trace-claim"),
      procedure: resource(:procedure_revision, "phase-7-trace-procedure"),
      exact_content: resource(:episode_content, "phase-7-trace-content"),
      content_access: resource(:content_access_permit, "phase-7-trace-access")
    }

    source_resources =
      [fixture.memory_event.iri | Map.values(trace)]
      |> Enum.uniq()
      |> Enum.sort()

    {:ok, other_experience_graph} =
      GraphRegistry.graph_iri(:experience, %{repository: other_repository})

    source_graphs = Enum.sort([fixture.memory_segment_graph, other_experience_graph])
    [first_repository, second_repository] = repositories

    split_policy = %{first_repository => :development, second_repository => :evaluation}

    assert {:ok, manifest} =
             MemoryDatasetManifest.new(authorization, %{
               cohort_iri: authorization.cohort_iri,
               purpose: authorization.purpose,
               authorization_iri: authorization.iri,
               repository_iris: repositories,
               source_graph_iris: source_graphs,
               source_resource_iris: source_resources,
               cutoff: cutoff,
               classifications: [:experience_record],
               extractor_revision: "1.0.0",
               query_revision: QueryCatalog.dataset_version(),
               split_policy: split_policy,
               erasure_generations: generations,
               exact_content_states: %{trace.exact_content => :authorized_reference},
               created_at: now
             })

    candidates = [
      candidate(first_repository, trace.case, fixture.memory_event.iri, 0, :success, generations),
      candidate(second_repository, trace.procedure, trace.claim, 1, :failure, generations)
    ]

    assert {:ok, result} = MemoryDatasetBuilder.build(manifest, candidates)

    %{
      authorization: authorization,
      result: result,
      candidates: candidates,
      trace: trace,
      cutoff: cutoff,
      now: now
    }
  end

  defp candidate(repository, task, source, index, outcome, generations) do
    %{
      iri: resource(:experience_case, "phase-7-integration-candidate-#{index}"),
      repository_iri: repository,
      task_iri: task,
      patch_digest: digest("phase-7-integration-patch-#{index}"),
      incident_iri: nil,
      classification: :experience_record,
      outcome: outcome,
      effective_at: ~U[2026-01-01 00:00:00Z],
      source_resource_iris: [source],
      semantic_digest: digest("phase-7-integration-semantic-#{index}"),
      representation_digest: digest("phase-7-integration-representation-#{index}"),
      erasure_generation: Map.fetch!(generations, repository),
      source_complete?: true,
      non_authoritative?: true
    }
  end

  defp export_permit(manifest, actor, now) do
    DatasetExportPermit.new(manifest, %{
      manifest_iri: manifest.iri,
      authorization_iri: manifest.authorization_iri,
      actor_iri: actor,
      sink_iri: resource(:dataset_external_copy, "phase-7-approved-sink"),
      purpose: manifest.purpose,
      classifications: manifest.classifications,
      row_limit: 100,
      byte_limit: 1_000_000,
      issued_at: now,
      expires_at: DateTime.add(now, 3_600, :second)
    })
  end

  defp artifact_attributes(result) do
    %{
      dataset_digest: digest("phase-7-external-payload"),
      schema_revision: "1.0.0",
      row_count: length(result.rows),
      byte_count: 8_192,
      source_row_iris: Enum.map(result.rows, & &1.iri) |> Enum.sort(),
      external_copy_iris: [resource(:dataset_external_copy, "phase-7-external-copy")],
      class_balance: result.class_balance,
      created_at: DateTime.add(result.manifest.created_at, 3, :second)
    }
  end

  defp evaluation(manifest, actor, now) do
    MemoryEvaluationProgram.evaluate(%{
      manifest_iri: manifest.iri,
      evaluator_iri: actor,
      ablations: Map.new(MemoryEvaluationProgram.ablations(), &{&1, evaluation_metrics(&1)}),
      zero_tolerance: Map.new(MemoryEvaluationProgram.zero_tolerance_metrics(), &{&1, 0}),
      launch_products: [
        %{
          product: :hybrid_memory_packet,
          ablation: :hybrid_retrieval,
          effect_size: 0.11,
          confidence_low: 0.03,
          p_value: 0.02,
          sample_size: 96,
          disable_path: %{
            command: "DisableMemoryProduct",
            owner_iri: actor,
            maximum_latency_seconds: 120
          }
        }
      ],
      recorded_at: DateTime.add(now, 4, :second)
    })
  end

  defp evaluation_metrics(ablation) do
    %{
      retrieval: %{
        precision: if(ablation == :no_memory, do: 0.0, else: 0.8),
        recall: if(ablation == :no_memory, do: 0.0, else: 0.75),
        ranking_quality: if(ablation == :no_memory, do: 0.0, else: 0.78),
        source_completeness: 1.0,
        authorization_denial_correctness: 1.0,
        invalidation_latency_ms: 20,
        retrieval_cost: if(ablation == :no_memory, do: 0, else: 10)
      },
      outcomes: %{
        task_success: if(ablation == :no_memory, do: 0.5, else: 0.62),
        time_to_accepted_patch: if(ablation == :no_memory, do: 900, else: 760),
        review_burden: 3.5,
        regression_rate: 0.01,
        recovery_quality: 0.9,
        token_cost: 1_100,
        operator_intervention: 0.05
      },
      harms: %{
        negative_transfer: 0,
        procedure_misuse: 0,
        invalidation_misses: 0,
        hallucinated_memory: 0,
        poisoned_memory_uptake: 0,
        scope_leakage: 0,
        erasure_misses: 0,
        temporal_leakage: 0
      }
    }
  end

  defp dataset_graph!(authorization, manifest) do
    {:ok, graph} =
      GraphRegistry.graph_iri(:memory_dataset, %{
        cohort: authorization.cohort_iri,
        dataset: manifest.iri
      })

    graph
  end

  defp command_attributes(fixture, graph, revision, recorded_at, seed) do
    %{
      scope_iri: fixture.repository_scope,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "phase-7-#{seed}-correlation"),
      causation_iri: fixture.enrollment_envelope.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: %{graph => revision},
      recorded_at: recorded_at,
      reason: "phase 7 #{seed} integration"
    }
  end

  defp commit!(fixture, command) do
    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

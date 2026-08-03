defmodule JidoCode.Knowledge.Evidence.Phase09VerificationEvidenceTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase09EvidenceFixture

  @evidence_queries ~w[
    evidence_by_goal evidence_by_claim evidence_by_attempt evidence_by_artifact
    verification_timeline evidence_support evidence_sufficiency stale_evidence
    missing_evidence_requirements
  ]a

  test "records verified evidence and proposed claims atomically", context do
    fixture = Phase09EvidenceFixture.recorded!(context)

    assert fixture.evidence_receipt.outcome == :committed, inspect(fixture.evidence_receipt)
    assert fixture.evidence_command.command_type == "RecordVerificationEvidence"
    assert fixture.evidence_command.command_version == QueryCatalog.knowledge_version()
    assert fixture.evidence_bundle.classification == :supporting

    assert fixture.evidence_bundle.coverage == %{
             total: 2,
             passed: 2,
             failed: 0,
             skipped: 0,
             unknown: 0
           }

    assert [claim] = fixture.evidence_bundle.claims

    assert {:ok, result} =
             query(fixture, :resource_description, fixture.evidence_graph, claim.iri, "1.0.0")

    assert Enum.any?(result.data, fn triple ->
             triple.predicate.value ==
               "https://jido.run/ontology/factory#epistemicState" and
               triple.object.value ==
                 "https://jido.run/ontology/concept/ClaimProposed"
           end)

    refute Enum.any?(result.data, fn triple ->
             triple.predicate.value in [
               "https://jido.run/ontology/factory#accepts",
               "https://jido.run/ontology/factory#satisfies"
             ]
           end)

    assert {:ok, replay} = Writer.execute(fixture.writer, fixture.evidence_command)
    assert replay.outcome == :already_committed
  end

  test "rejects unsupported, mismatched, self-evaluated, and hidden-failure inputs", context do
    fixture = Phase09EvidenceFixture.prepared!(context)
    method_attributes = method_attributes(fixture)

    assert {:error, %{operation: :verification_method}} =
             Knowledge.verification_method(%{method_attributes | version: "2.0.0"})

    independent = %{method_attributes | independent_evaluator?: true}
    assert {:ok, independent_method} = Knowledge.verification_method(independent)

    assert {:error, %{operation: :verification_activity}} =
             Knowledge.verification_activity(
               independent_method,
               activity_attributes(fixture, independent_method)
             )

    assert {:error, %{operation: :verification_activity}} =
             Knowledge.verification_activity(
               fixture.verification_method,
               %{
                 activity_attributes(fixture, fixture.verification_method)
                 | environment: %{profile: "prod"}
               }
             )

    permissive = %{method_attributes | requires_complete?: false}
    assert {:ok, permissive_method} = Knowledge.verification_method(permissive)

    hidden_failure =
      activity_attributes(fixture, permissive_method)
      |> Map.put(:checks, [
        %{id: "mix-test", status: :failed, mandatory?: true, outcome_refs: []}
      ])

    assert {:ok, failed_activity} =
             Knowledge.verification_activity(permissive_method, hidden_failure)

    assert {:error, %{operation: :evidence_bundle}} =
             Knowledge.evidence_bundle(
               failed_activity,
               fixture.evidence_graph,
               bundle_attributes(fixture)
             )

    assert {:ok, stale_command} =
             Knowledge.record_verification_evidence(
               fixture.evidence_bundle,
               fixture.evidence_command_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, competing_bundle} =
             Knowledge.evidence_bundle(
               fixture.verification_activity,
               fixture.evidence_graph,
               bundle_attributes(fixture)
             )

    assert {:ok, competing_command} =
             Knowledge.record_verification_evidence(
               competing_bundle,
               fixture.evidence_command_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, competing_receipt} = Writer.execute(fixture.writer, competing_command)
    assert competing_receipt.outcome == :committed

    assert {:ok, stale_receipt} = Writer.execute(fixture.writer, stale_command)
    assert stale_receipt.outcome == :conflicted
    assert is_map(stale_receipt.current_revisions)
  end

  test "evaluates sufficiency without transition or acceptance authority", context do
    fixture = Phase09EvidenceFixture.prepared!(context)
    requirements = Phase09EvidenceFixture.requirements(fixture)

    evaluation_context = %{
      current_graph_revisions: fixture.verification_activity.source_graph_revisions,
      evaluated_at: DateTime.add(fixture.issued_at, 300, :second)
    }

    assert {:ok, sufficient} =
             Knowledge.evaluate_evidence_sufficiency(
               [fixture.evidence_bundle],
               requirements,
               evaluation_context
             )

    assert sufficient.status == :sufficient
    refute sufficient.transition_authority?
    refute sufficient.acceptance_authority?

    assert {:ok, projected} = Knowledge.project_evidence_sufficiency(sufficient)
    assert projected.status == "sufficient"
    refute projected.transition_authority?

    assert {:ok, waiver} =
             Knowledge.evaluate_evidence_sufficiency(
               [fixture.evidence_bundle],
               %{
                 requirements
                 | required_method_kinds: [:test_execution, :security_review],
                   waiver_allowed?: true
               },
               evaluation_context
             )

    assert waiver.status == :waiver_required

    stale_context = %{
      evaluation_context
      | evaluated_at: DateTime.add(fixture.evidence_bundle.valid_to, 1, :second)
    }

    assert {:ok, stale} =
             Knowledge.evaluate_evidence_sufficiency(
               [fixture.evidence_bundle],
               requirements,
               stale_context
             )

    assert stale.status == :stale
  end

  test "queries bounded evidence while retaining failed-check fields and redacting raw content",
       context do
    fixture = Phase09EvidenceFixture.recorded!(context)
    names = QueryCatalog.names(QueryCatalog.knowledge_version())

    for name <- @evidence_queries, do: assert(name in names)
    assert :ok = QueryCatalog.verify()

    assert {:ok, result} =
             query(
               fixture,
               :evidence_by_goal,
               fixture.evidence_graph,
               fixture.goal.iri,
               QueryCatalog.knowledge_version()
             )

    assert result.data != []

    assert {:ok, projection} =
             Knowledge.project_evidence(result, %{
               graph_iri: fixture.evidence_graph,
               resource_iri: fixture.goal.iri
             })

    assert projection.lens == "evidence_by_goal"
    assert projection.receipt.query_version == QueryCatalog.knowledge_version()
    assert projection.receipt.graph_revision == 1
    refute projection.raw_outputs_authorized?
    assert Enum.any?(projection.data, &Map.has_key?(&1, "coverageFailed"))

    rendered = inspect(projection)
    refute rendered =~ fixture.artifact.embedded_content
    refute rendered =~ "sandbox-applied"
  end

  defp query(fixture, name, graph, resource, version) do
    QueryRunner.execute(
      name,
      version,
      %{graph: graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp method_attributes(fixture) do
    method = fixture.verification_method

    %{
      name: method.name,
      kind: method.kind,
      version: method.version,
      input_classes: method.input_classes,
      expected_claim_iris: method.expected_claim_iris,
      requires_complete?: method.requires_complete?,
      evaluator_capability_iri: method.evaluator_capability_iri,
      environment: method.environment,
      bounds: method.bounds,
      interpretation_limits: method.interpretation_limits,
      independent_evaluator?: method.independent_evaluator?
    }
  end

  defp activity_attributes(fixture, method) do
    activity = fixture.verification_activity

    %{
      attempt_iri: activity.attempt_iri,
      task_iri: activity.task_iri,
      goal_iri: activity.goal_iri,
      run_graph_iri: activity.run_graph_iri,
      control_graph_iri: activity.control_graph_iri,
      source_graph_iri: activity.source_graph_iri,
      source_snapshot_iri: activity.source_snapshot_iri,
      proposed_snapshot_iri: activity.proposed_snapshot_iri,
      post_change_snapshot_iri: activity.post_change_snapshot_iri,
      artifacts: [fixture.artifact],
      source_graph_revisions: activity.source_graph_revisions,
      evaluator_iri: activity.evaluator_iri,
      execution_actor_iri: activity.execution_actor_iri,
      environment: method.environment,
      checks: activity.checks,
      completeness: activity.completeness,
      started_at: activity.started_at,
      ended_at: activity.ended_at,
      raw_outcome_refs: activity.raw_outcome_refs
    }
  end

  defp bundle_attributes(fixture) do
    recorded_at = fixture.evidence_command_attributes.recorded_at

    %{
      supports: [fixture.goal.iri],
      contradicts: [],
      strength: :moderate,
      generated_claims: [
        %{
          subject_iri: fixture.repository,
          predicate_iri: "https://jido.run/ontology/factory#defaultBranchProtected",
          object: %{type: :boolean, value: false},
          valid_from: recorded_at,
          valid_to: DateTime.add(recorded_at, 3_600),
          recorded_at: recorded_at
        }
      ],
      limitations: [],
      valid_from: recorded_at,
      valid_to: DateTime.add(recorded_at, 3_600),
      supersedes: []
    }
  end
end

defmodule JidoCode.Knowledge.Memory.Phase04MemoryUseAssessmentTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.MemoryUseAssessment
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 15:00:00Z]

  test "records every independently evidenced outcome against an exact withheld control" do
    experience = experience!()

    for outcome <- MemoryUseAssessment.outcomes() do
      assert {:ok, assessment} =
               outcome
               |> assessment_attributes(to_string(outcome), experience)
               |> Knowledge.memory_use_assessment()

      assert assessment.outcome == outcome
      refute assessment.self_report_evidence?
      assert assessment.withheld_control.packet_digest == digest("control-#{outcome}")
      assert assessment.case_iri == experience.iri

      assert Enum.any?(MemoryUseAssessment.statements(assessment), fn statement ->
               {subject, predicate, _object} = RDF.Triple.new(statement)

               to_string(subject) == assessment.iri and
                 String.ends_with?(to_string(predicate), "memoryUseOutcome")
             end)
    end

    attributes = assessment_attributes(:useful, "same-actor", experience)

    assert {:error, %{kind: :invalid_input}} =
             attributes
             |> Map.put(:evaluator_iri, attributes.attempt_actor_iri)
             |> Knowledge.memory_use_assessment()

    assert {:error, %{kind: :invalid_input}} =
             attributes
             |> Map.put(:basis, :model_self_report)
             |> Knowledge.memory_use_assessment()
  end

  test "demotes repeated harm and immediately disables suspicious poisoning without rewriting cases" do
    experience = experience!()
    validated = validated!(experience)

    harmful = [
      assessment!(:misleading, "harm-1", experience),
      assessment!(:stale, "harm-2", experience)
    ]

    assert {:ok, result} =
             Knowledge.evaluate_negative_transfer(experience, harmful, validated, %{
               actor_iri: resource(:authorization_grant, "lifecycle-evaluator"),
               cause_iri: harmful |> List.last() |> Map.fetch!(:iri),
               recorded_at: DateTime.add(@now, 3, :second)
             })

    assert result.transition.next_state == :stale
    assert result.negative_transfer == 1.0
    assert result.original_case == experience

    poisoning =
      assessment!(
        :neutral,
        "poisoning",
        experience,
        %{suspicious_trigger_concentration: 0.9, poisoning_success?: true}
      )

    assert {:ok, disabled} =
             Knowledge.evaluate_negative_transfer(experience, [poisoning], validated, %{
               actor_iri: resource(:authorization_grant, "poison-evaluator"),
               cause_iri: poisoning.iri,
               recorded_at: DateTime.add(@now, 4, :second)
             })

    assert disabled.immediate_disablement?
    assert disabled.transition.next_state == :invalidated
    assert experience.transition.next_state == :candidate
  end

  test "publishes assessment and negative-transfer queries and builds the assessment command" do
    for name <- [:memory_use_outcomes, :negative_transfer_cases] do
      assert {:ok, definition} = QueryCatalog.fetch(name, QueryCatalog.experience_version())
      assert definition.graph_families == [:experience]
      assert String.contains?(definition.source, "{{instant}}")
    end

    experience = experience!()
    assessment = assessment!(:useful, "command", experience)

    assert {:ok, envelope} =
             Knowledge.record_memory_use_assessment(
               assessment,
               experience.experience_graph_iri,
               1,
               %{
                 repository_scope_iri: experience.repository_scope_iri,
                 principal_iri: resource(:authorization_grant, "assessment-principal"),
                 correlation_iri: resource(:command_request, "assessment-correlation"),
                 expected_dataset_revision: 3,
                 expected_graph_revisions: %{experience.experience_graph_iri => 1},
                 reason: "record independent memory-use assessment"
               },
               clock: fn -> assessment.recorded_at end
             )

    assert envelope.command_type == "RecordMemoryUseAssessment"
    assert envelope.command_version == CommandRegistry.experience_version()
  end

  defp experience! do
    repository = resource(:repository_snapshot, "assessment-repository")
    {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: repository})

    {:ok, experience} =
      Knowledge.experience_case(%{
        repository_iri: repository,
        repository_scope_iri: resource(:execution_context, "assessment-scope"),
        experience_graph_iri: graph,
        repository_version: "tree-assessment",
        problem_signature: digest("assessment-problem"),
        task_class: :repair,
        plan_phase: "memory-phase-04",
        environment: %{framework: "phoenix", version: "1.8", os: "linux", runtime: "otp-28"},
        dependencies: [%{name: "phoenix", version: "1.8.1"}],
        symptoms: ["failure"],
        reproduction: ["reproduce"],
        inspected_files: [],
        inspected_symbols: [],
        interventions: ["intervene"],
        disproved_assumptions: [],
        terminal_intervention: "terminal intervention",
        verification_iris: [resource(:verification_check, "assessment-check")],
        delayed_outcome: %{
          outcome: :success,
          evidence_iri: resource(:evidence_claim, "assessment-delayed"),
          observed_at: @now
        },
        exceptions: [],
        limitations: [],
        source_event_iris: [resource(:execution_event, "assessment-event")],
        source_artifact_iris: [],
        source_evidence_iris: [resource(:evidence_claim, "assessment-evidence")],
        case_class: :success,
        effective_at: @now,
        recorded_at: @now,
        actor_iri: resource(:authorization_grant, "assessment-author"),
        cause_iri: resource(:evidence_claim, "assessment-cause")
      })

    experience
  end

  defp validated!(experience) do
    {:ok, transition} =
      Knowledge.experience_transition(%{
        case_iri: experience.iri,
        prior_state: :candidate,
        next_state: :validated,
        revision: 1,
        expected_predecessor: experience.transition.iri,
        actor_iri: resource(:authorization_grant, "assessment-validator"),
        cause_iri: resource(:evidence_claim, "assessment-validation"),
        reason: "validate assessment fixture",
        recorded_at: DateTime.add(@now, 1, :second)
      })

    transition
  end

  defp assessment!(outcome, seed, experience, signals \\ nil) do
    attributes = assessment_attributes(outcome, seed, experience)
    attributes = if signals, do: Map.put(attributes, :signals, signals), else: attributes
    {:ok, assessment} = Knowledge.memory_use_assessment(attributes)
    assessment
  end

  defp assessment_attributes(outcome, seed, experience) do
    attempt = resource(:execution_attempt, "assessment-attempt-#{seed}")
    {:ok, graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: attempt})

    %{
      case_iri: experience.iri,
      retrieval_packet_iri: resource(:memory_evidence_packet, "assessment-packet-#{seed}"),
      retrieval_packet_digest: digest("packet-#{seed}"),
      attempt_iri: attempt,
      attempt_outcome_iri: resource(:evidence_claim, "assessment-outcome-#{seed}"),
      attempt_actor_iri: resource(:authorization_grant, "assessment-actor-#{seed}"),
      evaluator_iri: resource(:authorization_grant, "assessment-evaluator-#{seed}"),
      policy_iri: resource(:policy_version, "assessment-policy"),
      policy_version: "1.0.0",
      source_graph_revisions: %{graph => 2},
      withheld_control: %{
        attempt_iri: resource(:execution_attempt, "control-attempt-#{seed}"),
        packet_digest: digest("control-#{outcome}"),
        outcome_iri: resource(:evidence_claim, "control-outcome-#{seed}")
      },
      independent_evidence_iris: [resource(:evidence_claim, "independent-#{seed}")],
      basis: :independent_evidence,
      outcome: outcome,
      signals: %{suspicious_trigger_concentration: 0.1, poisoning_success?: false},
      limitations: [],
      recorded_at: DateTime.add(@now, 2, :second)
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

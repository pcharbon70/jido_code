defmodule JidoCode.Knowledge.Memory.Phase05ProcedureRetrievalTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 19:00:00Z]

  test "selects each task phase only under exact current compatibility" do
    for phase <- ProcedureRevision.task_phases() do
      request = request(phase)
      applicable = candidate(request, "#{phase}-applicable", phase)

      ineligible = [
        %{candidate(request, "#{phase}-stale", phase) | lifecycle_state: :stale},
        %{candidate(request, "#{phase}-old-framework", phase) | framework_version: "1.7"},
        %{candidate(request, "#{phase}-old-policy", phase) | policy_version: "1.1.0"},
        %{candidate(request, "#{phase}-old-evidence", phase) | evidence_current?: false}
      ]

      assert {:ok, result} = Knowledge.retrieve_procedures(request, [applicable | ineligible])

      assert [%{iri: iri, steps: [_], stop_conditions: [_], outcome_counts: counts}] =
               result.selected

      assert iri == applicable.iri
      assert counts.failure == 1
      refute result.abstained?
    end
  end

  test "abstains, measures fixed baselines, and records use pending independent assessment" do
    request = request(:testing)

    assert {:ok, result} =
             Knowledge.retrieve_procedures(request, [
               %{
                 candidate(request, "foreign", :testing)
                 | repository_iri: resource(:repository_snapshot, "foreign")
               }
             ])

    assert result.abstained?

    assert {:ok, metrics} =
             Knowledge.evaluate_procedure_retrieval(result, %{
               selected_tests: 40,
               history_aware_selected_tests: 12,
               applicable?: false,
               negative_transfer: 0.0
             })

    assert metrics.history_aware_reduction == 28
    assert metrics.correct_abstention

    assert {:ok, observation} =
             Knowledge.procedure_use_observation(%{
               procedure_iri: resource(:procedure_revision, "used-procedure"),
               retrieval_packet_iri: resource(:memory_evidence_packet, "procedure-packet"),
               attempt_iri: resource(:execution_attempt, "procedure-use-attempt"),
               actor_iri: resource(:authorization_grant, "procedure-use-actor"),
               task_phase: :testing,
               recorded_at: @now
             })

    assert observation.assessment_state == :pending_independent_assessment

    repository = request.repository_iri
    {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: repository})

    assert {:ok, command} =
             Knowledge.record_procedure_use(observation, graph, 1, command_attributes(graph),
               clock: fn -> @now end
             )

    assert command.command_type == "RecordProcedureUseObservation"

    assert {:ok, _definition} =
             CommandRegistry.resolve(command.command_type, CommandRegistry.procedure_version())
  end

  test "publishes phase selection, evidence, contradiction, lifecycle, and use products" do
    names =
      ~w[procedures_for_task procedure_evidence procedure_contradictions procedure_lifecycle procedure_use_outcomes]a

    for name <- names do
      assert {:ok, definition} = QueryCatalog.fetch(name, QueryCatalog.procedure_version())
      assert definition.graph_families == [:experience]
      assert String.contains?(definition.source, "{{instant}}")
      assert String.contains?(definition.source, "LIMIT")
    end
  end

  defp request(phase),
    do: %{
      repository_iri: resource(:repository_snapshot, "retrieval-procedure-repository"),
      task_phase: phase,
      framework: "phoenix",
      framework_version: "1.8",
      environment: "otp-28/linux",
      policy_version: "1.2.0",
      tools: ["mix"],
      effective_at: @now,
      max_procedures: 3
    }

  defp candidate(request, seed, phase),
    do: %{
      iri: resource(:procedure_revision, seed),
      repository_iri: request.repository_iri,
      task_phases: [phase],
      framework: request.framework,
      framework_version: request.framework_version,
      environment: request.environment,
      policy_version: request.policy_version,
      required_tools: request.tools,
      lifecycle_state: :validated,
      evidence_current?: true,
      recorded_at: DateTime.add(@now, -2, :second),
      validated_at: DateTime.add(@now, -1, :second),
      negative_transfer: 0.0,
      steps: [%{index: 1, instruction: "run exact verification"}],
      decision_branches: [],
      stop_conditions: ["artifact stale"],
      escalation_conditions: [],
      rollback_conditions: [],
      exceptions: [],
      outcome_counts: %{
        success: 2,
        failure: 1,
        revert: 0,
        incident: 0,
        negative_transfer: 0,
        delayed_survival: 1
      },
      evidence_iris: [resource(:evidence_claim, "#{seed}-evidence")]
    }

  defp command_attributes(graph),
    do: %{
      repository_scope_iri: resource(:execution_context, "procedure-use-scope"),
      principal_iri: resource(:authorization_grant, "procedure-use-principal"),
      actor_iri: resource(:authorization_grant, "procedure-use-writer"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "procedure-use-correlation"),
      causation_iri: resource(:execution_attempt, "procedure-use-command-cause"),
      expected_dataset_revision: 9,
      expected_graph_revisions: %{graph => 1},
      reason: "record procedure use pending assessment"
    }

  defp resource(kind, seed),
    do:
      (
        {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
        iri
      )
end

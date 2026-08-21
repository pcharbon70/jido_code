defmodule JidoCode.Knowledge.Memory.Phase05ProcedureValidationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 18:00:00Z]

  test "validates independent exact-applicability executions and counts every outcome class" do
    procedure = procedure!()
    executions = [execution(:success, "success"), execution(:delayed_survival, "survival")]

    assert {:ok, validation} =
             Knowledge.validate_procedure(
               procedure,
               report(),
               executions,
               validation_attributes()
             )

    assert validation.transition.next_state == :validated
    assert validation.counts.success == 1
    assert validation.counts.delayed_survival == 1

    assert Map.keys(validation.counts) |> Enum.sort() ==
             ~w[delayed_survival failure incident negative_transfer revert success]a

    forged = [
      Map.put(List.first(executions), :policy_version, "wrong") | Enum.drop(executions, 1)
    ]

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.validate_procedure(procedure, report(), forged, validation_attributes())
  end

  test "stales exact precondition drift and preserves knowledge and policy boundaries" do
    procedure = procedure!()

    {:ok, validation} =
      Knowledge.validate_procedure(
        procedure,
        report(),
        [execution(:success, "1"), execution(:failure, "2")],
        validation_attributes()
      )

    current = %{
      applicability: procedure.applicability,
      framework: procedure.framework,
      framework_version: procedure.framework_version,
      required_tools: procedure.required_tools,
      policy_version: "1.2.0",
      artifact_current?: false
    }

    assert {:ok, stale} =
             Knowledge.evaluate_procedure_drift(procedure, current, validation.transition, %{
               actor_iri: resource(:authorization_grant, "drift-evaluator"),
               cause_iri: resource(:artifact_claim, "drifted-artifact"),
               recorded_at: DateTime.add(@now, 2, :second)
             })

    assert stale.next_state == :stale

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.procedure_knowledge_proposition(
               procedure,
               %{validation | transition: procedure.transition},
               %{
                 decision_iri: resource(:decision_follow_up, "candidate-decision"),
                 proposition: "candidate is true"
               }
             )

    assert {:ok, proposition} =
             Knowledge.procedure_knowledge_proposition(procedure, validation, %{
               decision_iri: resource(:decision_follow_up, "validated-decision"),
               proposition: "This procedure succeeded under the exact recorded applicability."
             })

    refute proposition.executable?
    assert proposition.adoptable_only_via == "AdoptKnowledge"

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.procedure_policy_representation(procedure, validation, %{
               policy_iri: resource(:policy_version, "procedure-policy"),
               authorized_policy_command?: false,
               sanitized_representation: %{effect: :deny},
               command_iri: nil
             })
  end

  test "builds separate governed procedure proposal and validation commands" do
    procedure = procedure!()
    {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: procedure.repository_iri})
    attrs = command_attributes(graph)

    assert {:ok, proposal} =
             Knowledge.record_procedure_proposal(procedure, graph, 0, report(), attrs,
               clock: fn -> @now end
             )

    assert proposal.command_type == "ProposeProcedureRevision"

    assert {:ok, definition} =
             CommandRegistry.resolve(proposal.command_type, CommandRegistry.procedure_version())

    assert definition.capability == :experience_writer

    {:ok, validation} =
      Knowledge.validate_procedure(
        procedure,
        report(),
        [execution(:success, "a"), execution(:failure, "b")],
        validation_attributes()
      )

    assert {:ok, command} =
             Knowledge.transition_procedure(
               procedure,
               validation.transition,
               graph,
               1,
               %{attrs | expected_graph_revisions: %{graph => 1}}, clock: fn -> @now end)

    assert command.command_type == "ValidateProcedureRevision"
  end

  defp procedure! do
    {:ok, procedure} =
      Knowledge.propose_procedure(
        %{
          purpose: "Verify a source-linked repair",
          task_class: :repair,
          task_phases: [:testing, :verification],
          triggers: ["verification required"],
          applicability: applicability(),
          repository_iri: resource(:repository_snapshot, "validation-repository"),
          language: "elixir",
          framework: "phoenix",
          framework_version: "1.8",
          steps: [%{index: 1, instruction: "Run the exact verification."}],
          required_tools: ["mix"],
          required_capabilities: [resource(:capability_declaration, "validation-capability")],
          expected_observations: ["verification passes"],
          decision_branches: [],
          stop_conditions: ["artifact is stale"],
          escalation_conditions: [],
          rollback_conditions: ["test regresses"],
          exceptions: [],
          supporting_case_iris: [
            resource(:experience_case, "validation-case-1"),
            resource(:experience_case, "validation-case-2")
          ],
          contradicting_case_iris: [],
          delayed_outcomes: [],
          last_validated_at: nil,
          actor_iri: resource(:authorization_grant, "procedure-proposer"),
          cause_iri: resource(:evidence_claim, "procedure-proposal-evidence"),
          recorded_at: @now
        },
        %{scope_exact?: true}
      )

    procedure
  end

  defp execution(outcome, seed),
    do: %{
      iri: resource(:execution_attempt, "procedure-execution-#{seed}"),
      actor_iri: resource(:authorization_grant, "execution-actor-#{seed}"),
      outcome: outcome,
      applicability: applicability(),
      framework: "phoenix",
      framework_version: "1.8",
      tools: ["mix"],
      policy_version: "1.2.0",
      source_revisions: source_revisions()
    }

  defp applicability,
    do: %{environment: "otp-28/linux", policy_version: "1.2.0", tool_versions: %{mix: "1.19"}}

  defp source_revisions,
    do: %{
      elem(
        GraphRegistry.graph_iri(:source_revision, %{
          repository: resource(:repository_snapshot, "validation-repository"),
          revision: resource(:repository_snapshot, "validation-snapshot")
        }),
        1
      ) => 3
    }

  defp report, do: %{clear?: true, reasons: []}

  defp validation_attributes,
    do: %{
      validator_iri: resource(:authorization_grant, "independent-validator"),
      evidence_iri: resource(:evidence_claim, "procedure-validation-evidence"),
      current_applicability: applicability(),
      source_revisions: source_revisions(),
      recorded_at: DateTime.add(@now, 1, :second)
    }

  defp command_attributes(graph),
    do: %{
      repository_scope_iri: resource(:execution_context, "procedure-scope"),
      principal_iri: resource(:authorization_grant, "procedure-principal"),
      actor_iri: resource(:authorization_grant, "procedure-actor"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "procedure-correlation"),
      causation_iri: resource(:evidence_claim, "procedure-command-cause"),
      expected_dataset_revision: 5,
      expected_graph_revisions: %{graph => 0},
      recorded_at: @now,
      reason: "govern procedure revision"
    }

  defp resource(kind, seed),
    do:
      (
        {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
        iri
      )
end

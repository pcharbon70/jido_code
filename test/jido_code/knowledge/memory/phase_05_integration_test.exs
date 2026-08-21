defmodule JidoCode.Knowledge.Memory.Phase05IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase03RetrievalFixture
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    %{fixture: Phase03RetrievalFixture.complete!(context)}
  end

  test "persists artifact freshness and a validated, used, restart-safe procedure", %{
    fixture: fixture
  } do
    now = fixture.issued_at
    claim = claim!(fixture, :strong)
    evidence_revision = Phase04Fixture.current_graph_revision!(fixture, fixture.evidence_graph)

    assert {:ok, claim_command} =
             Knowledge.record_artifact_claim(
               claim,
               fixture.evidence_graph,
               evidence_revision,
               command_attributes(
                 fixture,
                 fixture.evidence_graph,
                 evidence_revision,
                 "artifact-claim"
               ),
               clock: fn -> now end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, claim_command)

    assert {:ok, claims} =
             query(fixture, :artifact_claims, QueryCatalog.procedure_version(), %{
               graph: fixture.evidence_graph,
               resource: fixture.repository,
               instant: now
             })

    assert Enum.any?(claims.data, &(value(&1, "claim") == claim.iri))

    assert {:ok, stale} =
             Knowledge.evaluate_artifact_claim_drift(
               claim,
               %{current(claim) | content_digest: digest("drifted-content")},
               claim.transition,
               %{
                 actor_iri: fixture.actor,
                 cause_iri: fixture.evidence_resource,
                 recorded_at: DateTime.add(now, 1, :second)
               }
             )

    assert stale.next_state == :stale

    refute Knowledge.artifact_claim_current?(claim, %{
             current(claim)
             | content_digest: digest("drifted-content")
           })

    procedure = procedure!(fixture)

    {:ok, experience_graph} =
      GraphRegistry.graph_iri(:experience, %{repository: fixture.repository})

    report = %{clear?: true, reasons: []}

    assert {:ok, proposal} =
             Knowledge.record_procedure_proposal(
               procedure,
               experience_graph,
               0,
               report,
               command_attributes(fixture, experience_graph, 0, "procedure-proposal"),
               clock: fn -> now end
             )

    assert {:ok, first} = Writer.execute(fixture.writer, proposal)
    assert first.outcome == :committed
    assert {:ok, %{outcome: :already_committed}} = Writer.execute(fixture.writer, proposal)

    executions = [
      execution(fixture, :success, "success"),
      execution(fixture, :failure, "failure"),
      execution(fixture, :revert, "revert")
    ]

    validation_attributes = %{
      validator_iri: resource(:authorization_grant, "phase-05-independent-validator"),
      evidence_iri: fixture.evidence_resource,
      current_applicability: applicability(),
      source_revisions: source_revisions(fixture),
      recorded_at: DateTime.add(now, 1, :second)
    }

    assert {:ok, validation} =
             Knowledge.validate_procedure(procedure, report, executions, validation_attributes)

    assert {:ok, validation_command} =
             Knowledge.transition_procedure(
               procedure,
               validation.transition,
               experience_graph,
               1,
               command_attributes(fixture, experience_graph, 1, "procedure-validation"),
               clock: fn -> DateTime.add(now, 1, :second) end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, validation_command)

    request = retrieval_request(fixture)
    candidate = candidate(procedure, validation, fixture)
    assert {:ok, %{selected: [selected]}} = Knowledge.retrieve_procedures(request, [candidate])
    assert selected.iri == procedure.iri
    assert selected.outcome_counts.failure == 1

    assert {:ok, catalog_result} =
             query(fixture, :procedures_for_task, QueryCatalog.procedure_version(), %{
               graph: experience_graph,
               resource: fixture.repository,
               instant: DateTime.add(now, 2, :second),
               task_phase: "testing",
               framework: "phoenix",
               framework_version: "1.8",
               environment: "otp-28/linux",
               policy_version: "1.2.0",
               tool: "mix",
               procedure_limit: 3
             })

    assert Enum.any?(catalog_result.data, &(value(&1, "procedure") == procedure.iri))

    assert {:ok, use} =
             Knowledge.procedure_use_observation(%{
               procedure_iri: procedure.iri,
               retrieval_packet_iri:
                 resource(:memory_evidence_packet, "phase-05-procedure-packet"),
               attempt_iri: fixture.memory_attempt,
               actor_iri: fixture.actor,
               task_phase: :testing,
               recorded_at: DateTime.add(now, 2, :second)
             })

    assert use.assessment_state == :pending_independent_assessment

    assert {:ok, use_command} =
             Knowledge.record_procedure_use(
               use,
               experience_graph,
               2,
               command_attributes(fixture, experience_graph, 2, "procedure-use"),
               clock: fn -> DateTime.add(now, 2, :second) end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, use_command)

    assert {:ok, uses} =
             query(fixture, :procedure_use_outcomes, QueryCatalog.procedure_version(), %{
               graph: experience_graph,
               resource: procedure.iri,
               instant: DateTime.add(now, 3, :second)
             })

    assert Enum.any?(uses.data, &(value(&1, "use") == use.iri))

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.procedure_policy_representation(procedure, validation, %{
               policy_iri: resource(:policy_version, "phase-05-policy"),
               authorized_policy_command?: false,
               sanitized_representation: %{effect: :deny},
               command_iri: nil
             })

    Phase04Fixture.kill_writer!(fixture)
    Phase04Fixture.restart_writer!(fixture)

    assert {:ok, lifecycle} =
             query(fixture, :procedure_lifecycle, QueryCatalog.procedure_version(), %{
               graph: experience_graph,
               resource: procedure.iri,
               instant: DateTime.add(now, 3, :second)
             })

    assert length(lifecycle.data) == 2
  end

  test "rejects weak one-off induction and measures abstention plus negative transfer", %{
    fixture: fixture
  } do
    one_case =
      procedure_attributes(fixture)
      |> Map.put(:supporting_case_iris, [resource(:experience_case, "one-off")])

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.propose_procedure(one_case, %{scope_exact?: true})

    request = retrieval_request(fixture)
    assert {:ok, result} = Knowledge.retrieve_procedures(request, [])

    assert {:ok, metrics} =
             Knowledge.evaluate_procedure_retrieval(result, %{
               selected_tests: 50,
               history_aware_selected_tests: 14,
               applicable?: false,
               negative_transfer: 0.2
             })

    assert metrics.history_aware_reduction == 36
    assert metrics.correct_abstention
    assert metrics.negative_transfer == 0.2
  end

  defp claim!(fixture, strength) do
    {:ok, claim} =
      Knowledge.artifact_claim(%{
        repository_iri: fixture.repository,
        repository_revision_iri: resource(:repository_snapshot, "phase-05-snapshot"),
        artifact_iri: resource(:source_artifact, "phase-05-source"),
        path: "lib/query.ex",
        symbol: "Query.run/2",
        selector: "#query-test",
        content_digest: digest("phase-05-content"),
        claim: "The reviewed query returns source revision metadata.",
        verification_command: "mix test test/query_test.exs",
        verification_environment: "elixir-1.19/otp-28/linux",
        evidence_iri: fixture.evidence_resource,
        evidence_strength: strength,
        valid_at: fixture.issued_at,
        checked_at: fixture.issued_at,
        actor_iri: fixture.actor,
        cause_iri: fixture.evidence_resource,
        runtime_success_only?: false
      })

    claim
  end

  defp procedure!(fixture) do
    {:ok, procedure} =
      Knowledge.propose_procedure(procedure_attributes(fixture), %{scope_exact?: true})

    procedure
  end

  defp procedure_attributes(fixture),
    do: %{
      purpose: "Repair and verify a reviewed graph query",
      task_class: :repair,
      task_phases: [:investigation, :editing, :testing, :verification],
      triggers: ["reviewed query fails"],
      applicability: applicability(),
      repository_iri: fixture.repository,
      language: "elixir",
      framework: "phoenix",
      framework_version: "1.8",
      steps: [
        %{index: 1, instruction: "Reproduce the exact query."},
        %{index: 2, instruction: "Apply the supported algebra and verify."}
      ],
      required_tools: ["mix"],
      required_capabilities: [resource(:capability_declaration, "phase-05-capability")],
      expected_observations: ["query passes"],
      decision_branches: [
        %{condition: "algebra unsupported", action: "select supported graph pattern"}
      ],
      stop_conditions: ["source claim is stale"],
      escalation_conditions: ["executor behavior is ambiguous"],
      rollback_conditions: ["verification fails"],
      exceptions: ["exact versions only"],
      supporting_case_iris: [
        resource(:experience_case, "phase-05-case-success"),
        resource(:experience_case, "phase-05-case-failure"),
        resource(:experience_case, "phase-05-case-revert")
      ],
      contradicting_case_iris: [resource(:experience_case, "phase-05-case-contradiction")],
      delayed_outcomes: ["survived delayed verification"],
      last_validated_at: nil,
      actor_iri: fixture.actor,
      cause_iri: fixture.evidence_resource,
      recorded_at: fixture.issued_at
    }

  defp applicability,
    do: %{environment: "otp-28/linux", policy_version: "1.2.0", tool_versions: %{mix: "1.19"}}

  defp source_revisions(fixture),
    do: %{
      fixture.memory_segment_graph => 2,
      fixture.evidence_graph =>
        Phase04Fixture.current_graph_revision!(fixture, fixture.evidence_graph)
    }

  defp execution(fixture, outcome, seed),
    do: %{
      iri: resource(:execution_attempt, "phase-05-#{seed}"),
      actor_iri: resource(:authorization_grant, "phase-05-actor-#{seed}"),
      outcome: outcome,
      applicability: applicability(),
      framework: "phoenix",
      framework_version: "1.8",
      tools: ["mix"],
      policy_version: "1.2.0",
      source_revisions: source_revisions(fixture)
    }

  defp retrieval_request(fixture),
    do: %{
      repository_iri: fixture.repository,
      task_phase: :testing,
      framework: "phoenix",
      framework_version: "1.8",
      environment: "otp-28/linux",
      policy_version: "1.2.0",
      tools: ["mix"],
      effective_at: DateTime.add(fixture.issued_at, 2, :second),
      max_procedures: 3
    }

  defp candidate(procedure, validation, fixture),
    do: %{
      iri: procedure.iri,
      repository_iri: fixture.repository,
      task_phases: procedure.task_phases,
      framework: procedure.framework,
      framework_version: procedure.framework_version,
      environment: procedure.applicability.environment,
      policy_version: procedure.applicability.policy_version,
      required_tools: procedure.required_tools,
      lifecycle_state: :validated,
      evidence_current?: true,
      recorded_at: procedure.recorded_at,
      validated_at: validation.transition.recorded_at,
      negative_transfer: 0.0,
      steps: procedure.steps,
      decision_branches: procedure.decision_branches,
      stop_conditions: procedure.stop_conditions,
      escalation_conditions: procedure.escalation_conditions,
      rollback_conditions: procedure.rollback_conditions,
      exceptions: procedure.exceptions,
      outcome_counts: validation.counts,
      evidence_iris: [validation.evidence_iri]
    }

  defp current(claim),
    do: %{
      repository_revision_iri: claim.repository_revision_iri,
      artifact_iri: claim.artifact_iri,
      content_digest: claim.content_digest,
      symbol: claim.symbol,
      verification_environment: claim.verification_environment,
      verification_command: claim.verification_command,
      evidence_iri: claim.evidence_iri
    }

  defp command_attributes(fixture, graph, revision, seed),
    do: %{
      repository_scope_iri: fixture.repository_scope,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "phase-05-#{seed}-correlation"),
      causation_iri: fixture.enrollment_envelope.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: %{graph => revision},
      recorded_at: DateTime.add(fixture.issued_at, revision, :second),
      reason: "phase 5 #{seed} integration"
    }

  defp query(fixture, name, version, parameters),
    do:
      Knowledge.query(name, version, parameters, fixture.authority, fixture.repository_scope,
        server: fixture.query_runner,
        evaluated_at: parameters.instant
      )

  defp value(row, key) do
    case row[key] || row[String.to_atom(key)] do
      %{value: value} -> value
      value -> value
    end
  end

  defp resource(kind, seed),
    do:
      (
        {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
        iri
      )

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

defmodule JidoCode.Knowledge.Decision.Phase09GoalOutcomeTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase09DecisionFixture

  @decision_queries ~w[
    decision_by_goal decision_by_claim decision_by_evidence decision_by_actor decision_waivers
    decision_rejections deferred_actions decision_supersession satisfaction_path decision_follow_up
  ]a

  test "atomically accepts a precise claim, satisfies patch work, and derives lease-gated follow-up",
       context do
    fixture = Phase09DecisionFixture.decided!(context)

    assert fixture.outcome_decision_receipt.outcome == :committed,
           inspect(fixture.outcome_decision_receipt)

    decision = fixture.outcome_decision
    assert decision.disposition == :accept
    assert decision.outcome_stage == :patch_approval
    assert [claim] = decision.claim_dispositions
    assert claim.state == :accepted
    assert [follow_up] = decision.follow_ups
    assert follow_up.kind == :apply_patch
    assert follow_up.requires_lease?
    assert fixture.outcome_decision_command.payload.direct_side_effects == []

    transitions =
      fixture.schedulable_task_transitions ++ decision.task_transitions

    assert {:ok, resolution} = Transition.resolve(transitions)
    assert resolution.current_state == :satisfied
    assert fixture.goal_resolution.current_state == :approved

    assert {:ok, replay} =
             Writer.execute(fixture.writer, fixture.outcome_decision_command)

    assert replay.outcome == :already_committed
  end

  test "rejects self-approval, stale sufficiency, policy bypass, and direct effects", context do
    fixture = Phase09DecisionFixture.prepared!(context)
    attributes = fixture.outcome_decision_attributes

    assert {:error, %{operation: :goal_outcome_decision}} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{attributes | actor_iri: fixture.attempt.actor_iri}
             )

    assert {:error, %{operation: :goal_outcome_decision}} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{attributes | requested_effects: [:git_push]}
             )

    assert {:error, %{operation: :goal_outcome_decision}} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{attributes | policy_version: "0.0.0"}
             )

    assert {:ok, command} =
             Knowledge.decide_goal_outcome(
               fixture.outcome_decision,
               fixture.outcome_decision_command_attributes,
               clock: fn -> fixture.issued_at end
             )

    changed = Map.put(fixture.outcome_decision_command_attributes, :expected_dataset_revision, 0)

    assert {:ok, stale_command} =
             Knowledge.decide_goal_outcome(
               fixture.outcome_decision,
               changed,
               clock: fn -> fixture.issued_at end
             )

    assert command.command_iri == stale_command.command_iri
    assert {:ok, receipt} = Writer.execute(fixture.writer, stale_command)
    assert receipt.outcome == :conflicted
  end

  test "keeps final satisfaction behind post-change evidence and explicit confirmation",
       context do
    fixture = Phase09DecisionFixture.prepared!(context)
    attributes = fixture.outcome_decision_attributes

    assert {:error, %{operation: :goal_outcome_decision}} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{attributes | outcome_stage: :final_goal}
             )

    assert fixture.goal_resolution.current_state == :approved
  end

  test "pins external confirmation to its exact observation graph revision", context do
    fixture = Phase09DecisionFixture.prepared!(context)
    observation_graph = fixture.observation.graph_iri
    observation_batch = fixture.observation.batch_iri
    revision = Phase09DecisionFixture.graph_revision!(fixture, observation_graph)

    attributes = %{
      fixture.outcome_decision_attributes
      | outcome_stage: :external_application,
        confirmation_iris: [observation_batch],
        confirmation_sources: [
          %{
            iri: observation_batch,
            graph_iri: observation_graph,
            revision: revision
          }
        ],
        follow_up_kinds: []
    }

    assert {:ok, decision} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               attributes
             )

    command_attributes = %{
      fixture.outcome_decision_command_attributes
      | expected_graph_revisions:
          Map.put(
            fixture.outcome_decision_command_attributes.expected_graph_revisions,
            observation_graph,
            revision
          )
    }

    assert {:ok, command} =
             Knowledge.decide_goal_outcome(decision, command_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:subject_present, observation_graph, observation_batch} in command.payload.guards

    stale_attributes = %{
      command_attributes
      | expected_graph_revisions:
          Map.put(
            command_attributes.expected_graph_revisions,
            observation_graph,
            revision + 1
          )
    }

    assert {:error, %{operation: :decide_goal_outcome}} =
             Knowledge.decide_goal_outcome(decision, stale_attributes)
  end

  test "transitions only explicitly related obligations and desired outcomes", context do
    fixture = Phase09DecisionFixture.prepared!(context)
    obligation = Phase04Fixture.resource!("phase-09-explicit-obligation")

    resolution = %{
      subject_iri: obligation,
      domain: :obligation,
      current_state: :satisfied,
      current_revision: 2,
      current_transition: fixture.goal_resolution.current_transition,
      history: []
    }

    attributes = %{
      fixture.outcome_decision_attributes
      | disposition: :supersede,
        related_resolutions: [resolution],
        follow_up_kinds: []
    }

    assert {:ok, decision} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               attributes
             )

    assert [transition] = decision.related_transitions
    assert transition.subject_iri == obligation
    assert transition.prior_state == :satisfied
    assert transition.next_state == :superseded

    assert {:error, %{operation: :goal_outcome_decision}} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{attributes | related_resolutions: [%{resolution | domain: :plan}]}
             )
  end

  test "derives request-more and waiver paths without hidden effects", context do
    fixture = Phase09DecisionFixture.prepared!(context)
    attributes = fixture.outcome_decision_attributes

    assert {:ok, request_more} =
             Knowledge.goal_outcome_decision(
               fixture.sufficiency_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{
                 attributes
                 | disposition: :request_more,
                   follow_up_kinds: [:gather_evidence]
               }
             )

    assert request_more.claim_dispositions == []
    assert [transition] = request_more.task_transitions
    assert transition.next_state == :awaiting_decision
    assert [follow_up] = request_more.follow_ups
    assert follow_up.kind == :gather_evidence
    refute follow_up.requires_lease?

    waiver_requirements = %{
      fixture.evidence_requirements
      | required_method_kinds: [:test_execution, :security_review],
        waiver_allowed?: true
    }

    assert {:ok, waiver_assessment} =
             Knowledge.evaluate_evidence_sufficiency(
               [fixture.evidence_bundle],
               waiver_requirements,
               attributes.evaluation_context
             )

    assert waiver_assessment.status == :waiver_required

    assert {:ok, waiver} =
             Knowledge.goal_outcome_decision(
               waiver_assessment,
               [fixture.evidence_bundle],
               fixture.goal_resolution,
               fixture.schedulable_task_resolution,
               %{
                 attributes
                 | disposition: :waive,
                   evidence_requirements: waiver_requirements,
                   follow_up_kinds: [:monitor_outcome]
               }
             )

    assert Enum.all?(waiver.claim_dispositions, &(&1.state == :waived))
  end

  test "projects authored decision rationale, satisfaction stage, and follow-up work", context do
    fixture = Phase09DecisionFixture.decided!(context)
    names = QueryCatalog.names(QueryCatalog.knowledge_version())

    for name <- @decision_queries, do: assert(name in names)
    assert :ok = QueryCatalog.verify()

    assert {:ok, result} =
             query(
               fixture,
               :decision_by_goal,
               fixture.evidence_graph,
               fixture.goal.iri
             )

    assert result.data != []

    assert {:ok, projection} =
             Knowledge.project_decision(result, %{
               graph_iri: fixture.evidence_graph,
               resource_iri: fixture.goal.iri
             })

    assert projection.lens == "decision_by_goal"
    assert projection.rationale_policy == :authored_references_only
    assert projection.receipt.query_version == QueryCatalog.knowledge_version()

    assert {:ok, follow_up_result} =
             query(
               fixture,
               :decision_follow_up,
               fixture.control_graph,
               fixture.outcome_decision.iri
             )

    assert follow_up_result.data != []
    assert Enum.any?(follow_up_result.data, &(decoded(&1, "requiresLease") == true))

    assert {:ok, satisfaction_result} =
             query(
               fixture,
               :satisfaction_path,
               fixture.control_graph,
               fixture.schedulable_task.iri
             )

    assert Enum.any?(satisfaction_result.data, fn row ->
             decoded(row, "stage") == "https://jido.run/ontology/concept/PatchApproval" and
               decoded(row, "state") == "https://jido.run/ontology/concept/TaskSatisfied"
           end)

    rendered = inspect(projection)
    refute rendered =~ "chain-of-thought"
    refute rendered =~ fixture.artifact.embedded_content
  end

  defp query(fixture, name, graph, resource) do
    QueryRunner.execute(
      name,
      QueryCatalog.knowledge_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp decoded(row, key) do
    case row[key] do
      %{value: "true", datatype: "http://www.w3.org/2001/XMLSchema#boolean"} -> true
      %{value: "false", datatype: "http://www.w3.org/2001/XMLSchema#boolean"} -> false
      %{value: value} -> value
      value -> value
    end
  end
end

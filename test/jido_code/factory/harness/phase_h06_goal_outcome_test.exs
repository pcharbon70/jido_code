defmodule JidoCode.Factory.Harness.PhaseH06GoalOutcomeTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Publication.OutcomeCoordinator
  alias JidoCode.Factory.Publication.Result
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.TestSupport.FakeExternalOutcomeObserver
  alias JidoCode.TestSupport.FakePostChangeVerifier

  test "records observation and post-change evidence before the FinalGoal decision" do
    publication = publication()

    assert {:ok, outcome} = decide(publication, :accept)
    assert outcome.disposition == :accept
    assert outcome.goal_satisfied?
    assert outcome.external_revision == publication.new_object
    assert outcome.observation_receipt.outcome == :committed
    assert outcome.evidence_receipt.outcome == :committed
    assert outcome.decision_receipt.outcome == :committed

    assert_receive {:external_outcome, :observe, attempt_iri}
    assert_receive {:outcome_command, "RecordObservationBatch"}
    assert_receive {:external_outcome, :verify, ^attempt_iri, external_revision}
    assert external_revision == publication.new_object
    assert_receive {:outcome_command, "RecordVerificationEvidence"}
    assert_receive {:outcome_command, "DecideGoalOutcome"}
  end

  test "supports every governed disposition without treating all as satisfaction" do
    for disposition <- [:accept, :reject, :defer, :waive, :supersede, :request_more] do
      assert {:ok, outcome} = decide(publication(), disposition)
      assert outcome.disposition == disposition
      assert outcome.goal_satisfied? == disposition in [:accept, :waive]
    end
  end

  test "rejects missing external linkage and post-change revision substitution" do
    publication = publication()
    observation = %{observation(publication) | publication_attempt_iri: iri("attempt/other")}

    assert {:error, %{kind: :conflict, operation: :publication_observation_attempt}} =
             decide(publication, :accept, observation_result: {:ok, observation})

    verification = %{verification(publication) | external_revision: object("substituted")}

    assert {:error, %{kind: :conflict, operation: :post_change_verification_revision}} =
             decide(publication, :accept, verification_result: {:ok, verification})
  end

  test "rejects executor or evaluator self-decision and direct requested effects" do
    publication = publication()
    verification = verification(publication)

    for mutation <- [
          %{actor_iri: verification.execution_actor_iri},
          %{actor_iri: verification.evaluator_iri},
          %{requested_effects: [:merge]}
        ] do
      builder = decision_builder(:accept, mutation)

      assert {:error, %{kind: kind}} =
               decide(publication, :accept, decision_builder: builder)

      assert kind in [:unauthorized, :invalid_input]
    end
  end

  test "executor completion without publication evidence cannot satisfy a goal" do
    execution_success = %{status: :completed, goal_satisfied?: true}

    assert {:error, %{operation: :publication_goal_outcome}} =
             OutcomeCoordinator.decide(
               execution_success,
               %{},
               FakeExternalOutcomeObserver,
               %{owner: self()},
               FakePostChangeVerifier,
               %{owner: self()},
               []
             )
  end

  defp decide(publication, disposition, overrides \\ []) do
    observation = Keyword.get(overrides, :observation_result, {:ok, observation(publication)})
    verification = Keyword.get(overrides, :verification_result, {:ok, verification(publication)})

    builder =
      Keyword.get(overrides, :decision_builder, decision_builder(disposition, %{}))

    OutcomeCoordinator.decide(
      publication,
      %{goal_iri: iri("goal/1")},
      FakeExternalOutcomeObserver,
      %{owner: self()},
      FakePostChangeVerifier,
      %{owner: self()},
      observation_result: observation,
      verification_result: verification,
      decision_builder: builder,
      command_executor: fn command ->
        send(self(), {:outcome_command, command.command_type})
        {:ok, %{outcome: :committed, command_iri: command.command_iri}}
      end
    )
  end

  defp observation(publication) do
    %{
      publication_attempt_iri: publication.attempt_iri,
      external_pull_request_id: publication.external_pull_request_id,
      external_revision: publication.new_object,
      provider_event_id: "event-100",
      confirmation_iri: iri("confirmation/provider-event"),
      confirmation_graph_iri: observation_graph(),
      confirmation_graph_revision: 4,
      observation_command: command("RecordObservationBatch", "1.1.0", "observation")
    }
  end

  defp verification(publication) do
    %{
      publication_attempt_iri: publication.attempt_iri,
      external_revision: publication.new_object,
      post_change_snapshot_iri: iri("snapshot/post-change"),
      evaluator_iri: iri("actor/evaluator"),
      execution_actor_iri: iri("actor/executor"),
      evidence_iris: [iri("evidence/post-change")],
      evidence_command: command("RecordVerificationEvidence", "1.7.0", "evidence")
    }
  end

  defp decision_builder(disposition, mutation) do
    fn publication, observation, verification, _input ->
      decision = %{
        disposition: disposition,
        outcome_stage: :final_goal,
        actor_iri: iri("actor/decider"),
        execution_actor_iri: verification.execution_actor_iri,
        evaluator_iri: verification.evaluator_iri,
        evidence_iris: verification.evidence_iris,
        confirmation_iris: [observation.confirmation_iri],
        requested_effects: [],
        decision_command:
          command("DecideGoalOutcome", "1.7.0", "decision-#{publication.provider_revision}")
      }

      {:ok, Map.merge(decision, mutation)}
    end
  end

  defp publication do
    %Result{
      attempt_iri: iri("attempt/publication"),
      run_graph_iri: "https://jido.run/graph/run/" <> String.duplicate("a", 32),
      base_branch: "main",
      bot_branch: "agent/phase-06",
      old_object: object("old"),
      new_object: object("candidate"),
      external_branch_id: "branch:agent/phase-06",
      external_pull_request_id: "pr:42",
      provider_revision: "provider-revision-9",
      credential_scope: :repository_write,
      merge_authority?: false,
      terminal?: true
    }
  end

  defp command(type, version, suffix) do
    struct!(CommandEnvelope,
      command_type: type,
      command_version: version,
      command_iri: iri("command/#{suffix}"),
      principal_iri: iri("actor/principal"),
      actor_iri: iri("actor/service"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      scope_iri: iri("scope/repository"),
      idempotency_key: suffix,
      correlation_iri: iri("correlation/1"),
      causation_iri: iri("causation/1"),
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: 1,
      expected_graph_revisions: %{},
      reason: suffix,
      issued_at: ~U[2026-08-18 12:00:00Z],
      payload: %{changes: [], guards: []}
    )
  end

  defp observation_graph do
    "https://jido.run/graph/repo/" <>
      String.duplicate("b", 32) <> "/observation/" <> String.duplicate("c", 32)
  end

  defp object(material), do: :crypto.hash(:sha, material) |> Base.encode16(case: :lower)
  defp iri(path), do: "https://jido.run/id/phase-h06/#{path}"
end

defmodule JidoCode.Factory.ManagedCodingRecoveryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.LifecycleEvent
  alias JidoCode.Factory.ManagedCoding.RecoveryCoordinator
  alias JidoCode.Factory.ManagedCoding.RecoveryPlan
  alias JidoCode.Factory.ManagedCoding.RecoveryRecord
  alias JidoCode.TestSupport.FakeManagedCodingRecoveryLedger, as: Ledger
  alias JidoCode.TestSupport.FakeManagedCodingRecoveryRuntime, as: Runtime

  @digest String.duplicate("a", 64)

  setup do
    owner = self()

    ledger =
      start_supervised!(
        {Agent, fn -> %{owner: owner, records: [], next_fence: 8} end},
        id: {Agent, make_ref()}
      )

    %{ledger: ledger}
  end

  test "defines deterministic recovery behavior at every lifecycle point" do
    expected = %{
      admitted: :resume_admission,
      preparing: :rebuild_workspace,
      running: :rebuild_workspace_and_agent,
      awaiting_actor: :restore_actor_wait,
      assembling_candidate: :rebuild_candidate,
      candidate_ready: :resume_verification,
      verifying: :reconcile_verification,
      dispositioned: :ignore_terminal,
      cancelled: :ignore_terminal,
      failed: :ignore_terminal
    }

    Enum.each(expected, fn {state, action} ->
      attributes = record_attributes(state)
      assert {:ok, record} = RecoveryRecord.new(attributes)
      assert {:ok, plan} = RecoveryPlan.build(record, baseline())
      assert plan.action == action
    end)
  end

  test "acquires a replacement fence before recreating from pins and discards orphan state",
       %{ledger: ledger} do
    attributes = record_attributes(:running)
    Agent.update(ledger, &%{&1 | records: [attributes]})

    assert {:ok, [%{result: :recovered, fencing_token: 8}]} =
             RecoveryCoordinator.recover(
               Ledger,
               ledger,
               Runtime,
               self(),
               %{tenant_iri: iri("tenant")},
               baseline()
             )

    assert_receive {:recovery_discover, %{tenant_iri: _tenant}}
    assert_receive {:recovery_acquire_fence, _attempt, 7}
    assert_receive {:recovery_recreate, plan, %{fencing_token: 8}, options}
    assert options[:orphan_state] == :discard
    assert plan.pinned_inputs.snapshot_iri == iri("snapshot")
    assert plan.pinned_inputs.artifact_digests == %{iri("artifact") => @digest}
    assert_receive {:recovery_committed, _attempt, 8}
  end

  test "ignores terminal attempts without acquiring a fence or starting a runtime", %{
    ledger: ledger
  } do
    Agent.update(ledger, &%{&1 | records: [record_attributes(:cancelled)]})

    assert {:ok, [%{result: :ignored_terminal}]} =
             RecoveryCoordinator.recover(Ledger, ledger, Runtime, self(), %{}, baseline())

    refute_receive {:recovery_acquire_fence, _, _}
    refute_receive {:recovery_recreate, _, _, _}
  end

  test "quarantines incomplete, future, contradictory, and unverifiable evidence", %{
    ledger: ledger
  } do
    base = record_attributes(:running)

    records = [
      %{base | evidence_complete: false, attempt_iri: iri("incomplete")},
      %{base | schema_version: 2, attempt_iri: iri("future")},
      %{base | budget_use: %{turns: 99}, attempt_iri: iri("contradictory")},
      %{base | strategy_revision: String.duplicate("b", 64), attempt_iri: iri("unverifiable")}
    ]

    Agent.update(ledger, &%{&1 | records: records})

    assert {:ok, results} =
             RecoveryCoordinator.recover(Ledger, ledger, Runtime, self(), %{}, baseline())

    assert Enum.map(results, & &1.reason) == [
             :incomplete_evidence,
             :future_schema,
             :contradictory_evidence,
             :unverifiable_evidence
           ]

    assert_receive {:recovery_quarantined, _, :incomplete_evidence}
    assert_receive {:recovery_quarantined, _, :future_schema}
    assert_receive {:recovery_quarantined, _, :contradictory_evidence}
    assert_receive {:recovery_quarantined, _, :unverifiable_evidence}
    refute_receive {:recovery_recreate, _, _, _}
  end

  test "compares event watermarks, invocation identities, candidate digests, and terminal facts" do
    base = record_attributes(:running)

    contradictions = [
      %{base | reconstruction_watermark: %{sequence: 100, event_iri: iri("wrong")}},
      %{base | invocations: []},
      record_attributes(:candidate_ready) |> Map.put(:candidate, nil),
      record_attributes(:failed) |> Map.put(:terminal_fact_iri, nil)
    ]

    Enum.each(contradictions, fn attributes ->
      assert {:ok, record} = RecoveryRecord.new(attributes)
      assert {:quarantine, :contradictory_evidence} = RecoveryPlan.build(record, baseline())
    end)
  end

  defp record_attributes(state) do
    events = events_through(state)
    last = List.last(events)

    %{
      attempt_iri: iri("attempt"),
      tenant_iri: iri("tenant"),
      repository_iri: iri("repository"),
      task_iri: iri("task"),
      actor_iri: iri("actor"),
      old_fencing_token: 7,
      lifecycle_events: events,
      strategy_revision: @digest,
      profile_iri: iri("profile"),
      snapshot_iri: iri("snapshot"),
      policy_revision: @digest,
      toolchain_revision: @digest,
      reconstruction_watermark: %{sequence: last.sequence, event_iri: last.event_iri},
      invocations: invocation_records(events),
      budget_use: last.budget_use || %{},
      artifact_iris: [iri("artifact")],
      artifact_digests: %{iri("artifact") => @digest},
      candidate: candidate_record(events),
      terminal_fact_iri: if(state in [:dispositioned, :cancelled, :failed], do: iri("terminal")),
      evidence_complete: true,
      schema_version: 1
    }
  end

  defp events_through(target) do
    path =
      case target do
        :cancelled ->
          [:admitted, :cancelled]

        :failed ->
          [:admitted, :failed]

        _ ->
          [
            :admitted,
            :preparing,
            :running,
            :awaiting_actor,
            :assembling_candidate,
            :candidate_ready,
            :verifying,
            :dispositioned
          ]
      end

    states = Enum.take_while(path, &(&1 != target)) ++ [target]

    transitions =
      states
      |> Enum.with_index()
      |> Enum.map(fn {state, sequence} -> event(state, sequence, :transition, iri("attempt")) end)

    if target in [
         :running,
         :awaiting_actor,
         :assembling_candidate,
         :candidate_ready,
         :verifying,
         :dispositioned
       ] do
      add_observations(transitions, target)
    else
      transitions
    end
  end

  defp add_observations(events, target) do
    invocation = event(target, length(events), :invocation, iri("invocation"))
    events = events ++ [invocation]

    if target in [:candidate_ready, :verifying, :dispositioned] do
      events ++ [event(target, length(events), :candidate, iri("candidate"))]
    else
      events
    end
  end

  defp event(state, sequence, kind, subject_iri) do
    previous = if kind == :transition and sequence > 0, do: :admitted, else: nil

    {:ok, event} =
      LifecycleEvent.new(%{
        attempt_iri: iri("attempt"),
        fencing_token: 7,
        sequence: sequence,
        origin_sequence: sequence,
        kind: kind,
        state: state,
        previous_state: previous,
        subject_iri: subject_iri,
        actor_iri: iri("actor"),
        cause_iri: iri("cause-#{sequence}"),
        evidence_iris: [iri("evidence-#{sequence}")],
        occurred_at: ~U[2026-08-25 12:00:00Z],
        recorded_at: ~U[2026-08-25 12:00:00Z],
        late_observation: false,
        budget_use: %{turns: sequence}
      })

    event
  end

  defp invocation_records(events) do
    events
    |> Enum.filter(&(&1.kind == :invocation))
    |> Enum.map(&%{invocation_iri: &1.subject_iri, status: :intent, outcome_iri: nil})
  end

  defp candidate_record(events) do
    case Enum.find(events, &(&1.kind == :candidate)) do
      nil -> nil
      event -> %{candidate_iri: event.subject_iri, digest: @digest}
    end
  end

  defp baseline do
    %{
      strategy_revision: @digest,
      profile_iri: iri("profile"),
      snapshot_iri: iri("snapshot"),
      policy_revision: @digest,
      toolchain_revision: @digest
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

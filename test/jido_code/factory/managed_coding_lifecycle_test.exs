defmodule JidoCode.Factory.ManagedCodingLifecycleTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Lifecycle
  alias JidoCode.Factory.ManagedCoding.LifecycleEvent
  alias JidoCode.TestSupport.FakeManagedCodingLifecycleLedger, as: Ledger

  setup do
    initial = initial_event()
    owner = self()

    ledger =
      start_supervised!(
        {Agent,
         fn ->
           %{
             owner: owner,
             attempt_iri: initial.attempt_iri,
             fencing_token: initial.fencing_token,
             events: [initial]
           }
         end}
      )

    %{initial: initial, ledger: ledger}
  end

  test "enforces the complete legal lifecycle and projects only durable events", context do
    transitions = [
      {:preparing, "prepare"},
      {:running, "run"},
      {:awaiting_actor, "clarify"},
      {:running, "answer"},
      {:assembling_candidate, "assemble"},
      {:candidate_ready, "candidate"},
      {:verifying, "verify"},
      {:dispositioned, "dispose"}
    ]

    Enum.each(transitions, fn {state, cause} ->
      assert {:ok, event} =
               Lifecycle.transition(Ledger, context.ledger, attributes(state, cause))

      assert event.state == state
      assert_receive {:lifecycle_append, ^event}
    end)

    assert {:ok, projection} =
             Lifecycle.project(Ledger, context.ledger, context.initial.attempt_iri, 7)

    assert projection.state == :dispositioned
    assert projection.sequence == 8

    assert {:error, %AdapterError{kind: :conflict}} =
             Lifecycle.transition(Ledger, context.ledger, attributes(:running, "reopen"))
  end

  test "records every runtime relationship with current identity and graph-derived summaries",
       context do
    assert {:ok, _event} =
             Lifecycle.transition(Ledger, context.ledger, attributes(:preparing, "prepare"))

    assert {:ok, _event} =
             Lifecycle.transition(Ledger, context.ledger, attributes(:running, "run"))

    kinds = LifecycleEvent.observation_kinds()

    Enum.with_index(kinds, 1)
    |> Enum.each(fn {kind, index} ->
      details =
        attributes(:running, "#{kind}-#{index}")
        |> Map.put(:kind, kind)
        |> Map.put(:subject_iri, iri("#{kind}-subject"))
        |> Map.put(:progress, kind)
        |> Map.put(:budget_use, %{turns: index})
        |> Map.put(:evidence_iris, [iri("#{kind}-evidence")])

      assert {:ok, _event} = Lifecycle.observe(Ledger, context.ledger, details)
    end)

    assert {:ok, projection} =
             Lifecycle.project(Ledger, context.ledger, context.initial.attempt_iri, 7)

    assert Enum.sort(Map.keys(projection.relationships)) == Enum.sort(kinds)
    assert projection.progress == :candidate
    assert projection.budget_use == %{turns: 9}
    assert length(projection.evidence_iris) == 12
  end

  test "makes callbacks idempotent and rejects stale fences and conflicting reuse", context do
    request = attributes(:preparing, "same-command")

    assert {:ok, first} = Lifecycle.transition(Ledger, context.ledger, request)
    assert {:ok, repeated} = Lifecycle.transition(Ledger, context.ledger, request)
    assert first == repeated
    assert_receive {:lifecycle_append, ^first}
    refute_receive {:lifecycle_append, _duplicate}

    conflicting = %{request | state: :failed}

    assert {:error, %AdapterError{kind: :conflict}} =
             Lifecycle.transition(Ledger, context.ledger, conflicting)

    stale = %{attributes(:running, "stale") | fencing_token: 6}

    assert {:error, %AdapterError{kind: :unauthorized}} =
             Lifecycle.transition(Ledger, context.ledger, stale)
  end

  test "accepts explicitly late observations without reordering their causal origin", context do
    assert {:ok, _event} =
             Lifecycle.transition(Ledger, context.ledger, attributes(:preparing, "prepare"))

    assert {:ok, _event} =
             Lifecycle.transition(Ledger, context.ledger, attributes(:running, "run"))

    late =
      attributes(:running, "late-check")
      |> Map.put(:kind, :check)
      |> Map.put(:origin_sequence, 1)
      |> Map.put(:late_observation, true)
      |> Map.put(:occurred_at, ~U[2026-08-25 12:00:01Z])
      |> Map.put(:recorded_at, ~U[2026-08-25 12:00:05Z])

    assert {:ok, event} = Lifecycle.observe(Ledger, context.ledger, late)
    assert event.sequence == 3
    assert event.origin_sequence == 1
    assert event.late_observation

    invalid = %{late | cause_iri: iri("not-late"), origin_sequence: 4}

    assert {:error, %AdapterError{kind: :invalid_input}} =
             Lifecycle.observe(Ledger, context.ledger, invalid)
  end

  defp initial_event do
    {:ok, event} =
      LifecycleEvent.new(%{
        attempt_iri: iri("attempt"),
        fencing_token: 7,
        sequence: 0,
        origin_sequence: 0,
        kind: :transition,
        state: :admitted,
        previous_state: nil,
        subject_iri: iri("attempt"),
        actor_iri: iri("actor"),
        cause_iri: iri("admission-command"),
        evidence_iris: [iri("admission-evidence")],
        occurred_at: ~U[2026-08-25 12:00:00Z],
        recorded_at: ~U[2026-08-25 12:00:00Z],
        late_observation: false
      })

    event
  end

  defp attributes(state, cause) do
    %{
      attempt_iri: iri("attempt"),
      fencing_token: 7,
      state: state,
      subject_iri: iri("attempt"),
      actor_iri: iri("actor"),
      cause_iri: iri(cause),
      evidence_iris: [iri("evidence-#{cause}")],
      occurred_at: ~U[2026-08-25 12:00:02Z],
      recorded_at: ~U[2026-08-25 12:00:02Z],
      wait_reason: if(state == :awaiting_actor, do: :actor, else: nil),
      progress: state,
      budget_use: %{turns: 1}
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

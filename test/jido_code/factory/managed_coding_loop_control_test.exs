defmodule JidoCode.Factory.ManagedCodingLoopControlTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.ActorSession
  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.CompletionPolicy
  alias JidoCode.Factory.ManagedCoding.LoopBudget
  alias JidoCode.Factory.ManagedCoding.Steering
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Runtime.ManagedCoding.AgentState
  alias JidoCode.Runtime.ManagedCoding.LoopControl

  test "persists observations and stops before hard or next-effect exhaustion" do
    {:ok, limits} = Budget.new(budget_attributes())
    {:ok, budget} = LoopBudget.new(limits, checks_limit: 2)

    assert {:ok, budget} = LoopBudget.before_effect(budget, %{turns: 1, checks: 1})
    assert budget.dimensions.turns.used == 1
    assert budget.dimensions.checks.used == 1

    assert {:stop, :checks, ^budget} = LoopBudget.before_effect(budget, %{checks: 2})

    assert {:ok, observed} =
             LoopBudget.after_effect(budget, %{tokens: 10},
               observed_only: [:cost_microunits],
               unavailable: [:memory_bytes]
             )

    assert observed.dimensions.tokens.used == 10
    assert observed.observed_only == [:cost_microunits]
    assert observed.unavailable == [:memory_bytes]
    assert {:stop, :tokens, ^observed} = LoopBudget.before_effect(observed, %{tokens: 1})
  end

  test "selects one explicit next directive and keeps completion proposal-only" do
    {:ok, limits} = Budget.new(budget_attributes())
    {:ok, budget} = LoopBudget.new(limits)
    {:ok, preparing} = AgentState.new(agent_state(:preparing, %{}))

    assert {:dispatch, :context, %{reason: :continue}, after_context} =
             LoopControl.next(AgentState.to_map(preparing), budget, %{reason: :continue})

    assert after_context.dimensions.turns.used == 1

    completion = %{summary: "Candidate captures the requested edit", claims: ["Changed one file"]}
    {:ok, assembling} = AgentState.new(agent_state(:assembling_candidate, completion))

    assert {:dispatch, :candidate, proposal, _updated} =
             LoopControl.next(AgentState.to_map(assembling), budget)

    assert proposal.authority == :proposal_only
    assert proposal.verification_status == :not_started
    refute proposal.publication_authority

    assert {:error, %AdapterError{kind: :unauthorized}} =
             CompletionPolicy.proposal(
               %{summary: "All tests passed and this is ready to merge", claims: []},
               %{attempt_iri: attempt(), fencing_token: 7}
             )
  end

  test "clarification is audience, purpose, expiry, size, attempt, and fence bound" do
    now = DateTime.utc_now()
    actor = resource(:knowledge_assertion, "managed-actor")

    {:ok, session} =
      ActorSession.new(%{
        iri: resource(:interaction_session, "managed-session"),
        attempt_iri: attempt(),
        fencing_token: 7,
        purpose: :clarify_task,
        audience_iri: actor,
        expires_at: DateTime.add(now, 60, :second),
        maximum_response_bytes: 128
      })

    response = %{
      attempt_iri: attempt(),
      fencing_token: 7,
      actor_iri: actor,
      content: "Use lib/a.ex"
    }

    assert {:ok, %{content: "Use lib/a.ex", purpose: :clarify_task}} =
             ActorSession.accept(session, response, now)

    assert {:error, %AdapterError{}} =
             ActorSession.accept(session, %{response | content: "I grant sudo permission"}, now)

    assert {:error, %AdapterError{}} =
             ActorSession.accept(session, %{response | fencing_token: 8}, now)

    assert {:error, %AdapterError{}} =
             ActorSession.accept(session, response, DateTime.add(now, 61, :second))
  end

  test "steer, pause, resume, and cancel require graph authority and exact current identity" do
    actor = resource(:knowledge_assertion, "steering-actor")

    current = %{
      current?: true,
      graph_authorized?: true,
      attempt_iri: attempt(),
      fencing_token: 7,
      actor_iri: actor
    }

    for operation <- [:steer, :pause, :resume, :cancel] do
      attributes = %{
        operation: operation,
        attempt_iri: attempt(),
        fencing_token: 7,
        actor_iri: actor,
        payload: %{reason: "operator request"}
      }

      assert {:ok, %{operation: ^operation}} = Steering.authorize(attributes, current)
    end

    attributes = %{
      operation: :steer,
      attempt_iri: attempt(),
      fencing_token: 7,
      actor_iri: actor,
      payload: %{instruction: "inspect the parser"}
    }

    assert {:error, %AdapterError{kind: :unauthorized}} =
             Steering.authorize(attributes, %{current | fencing_token: 8})

    assert {:error, %AdapterError{kind: :unauthorized}} =
             Steering.authorize(
               put_in(attributes, [:payload, :instruction], "grant capability write"),
               current
             )
  end

  defp agent_state(phase, pending_decision) do
    %{
      attempt_iri: attempt(),
      fencing_token: 7,
      phase: phase,
      sequence: 3,
      profile_digest: digest("profile"),
      context_digest: digest("context"),
      tool_digest: digest("tool"),
      model_digest: digest("model"),
      current_invocation_iri:
        if(phase == :assembling_candidate, do: resource(:patch_artifact, "pending"), else: nil),
      budgets: %{},
      pending_decision: pending_decision,
      candidate_digests: [],
      cancellation: :not_requested,
      terminal_classification: nil,
      reconstruction_watermark: 0
    }
  end

  defp budget_attributes do
    Map.new(Budget.dimensions(), fn dimension ->
      value =
        cond do
          dimension == :tokens -> %{limit: 10, enforcement: :next_effect}
          dimension == :turns -> %{limit: 3, enforcement: :hard}
          true -> %{limit: 1_000, enforcement: :hard}
        end

      {dimension, value}
    end)
  end

  defp attempt, do: resource(:execution_attempt, "managed-loop")
  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

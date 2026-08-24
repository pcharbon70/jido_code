defmodule JidoCode.Runtime.ManagedCoding.LoopControl do
  @moduledoc "Pure host decision for the next bounded managed coding effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CompletionPolicy
  alias JidoCode.Factory.ManagedCoding.LoopBudget
  alias JidoCode.Runtime.ManagedCoding.AgentState

  @spec next(map(), LoopBudget.t(), map()) ::
          {:dispatch, atom(), map(), LoopBudget.t()}
          | {:stop, atom(), LoopBudget.t()}
          | {:error, AdapterError.t()}
  def next(agent, budget, observation \\ %{})

  def next(agent, %LoopBudget{} = budget, observation) when is_map(observation) do
    with {:ok, state} <- AgentState.from_agent(agent),
         {:ok, effect, payload, deltas} <- effect(state, observation) do
      case LoopBudget.before_effect(budget, deltas) do
        {:ok, updated} -> {:dispatch, effect, payload, updated}
        {:stop, dimension, unchanged} -> {:stop, dimension, unchanged}
      end
    else
      {:stop, reason} -> {:stop, reason, budget}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  def next(_agent, _budget, _observation),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_loop_control)}

  defp effect(%AgentState{phase: :preparing}, observation),
    do: {:ok, :context, observation, %{turns: 1}}

  defp effect(%AgentState{phase: :awaiting_model}, observation),
    do: {:ok, :model, observation, %{model_calls: 1}}

  defp effect(%AgentState{phase: :awaiting_tool, pending_decision: decision}, _observation),
    do: {:ok, :tool, decision, %{tool_calls: 1}}

  defp effect(%AgentState{phase: :awaiting_actor, pending_decision: decision}, _observation),
    do: {:ok, :actor, decision, %{clarification_rounds: 1}}

  defp effect(%AgentState{phase: :assembling_candidate} = state, _observation) do
    with {:ok, proposal} <-
           CompletionPolicy.proposal(state.pending_decision, %{
             attempt_iri: state.attempt_iri,
             fencing_token: state.fencing_token
           }) do
      {:ok, :candidate, proposal, %{output_bytes: byte_size(:erlang.term_to_binary(proposal))}}
    end
  end

  defp effect(%AgentState{phase: phase}, _observation)
       when phase in [:candidate_ready, :completed, :cancelled, :failed],
       do: {:stop, :terminal}

  defp effect(%AgentState{}, _observation), do: {:stop, :awaiting_result}
end

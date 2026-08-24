defmodule JidoCode.Runtime.ManagedCoding.Strategy do
  @moduledoc "Pure Jido strategy for the bounded single-agent coding state machine."

  use Jido.Agent.Strategy

  alias Jido.Agent
  alias Jido.Agent.Directive
  alias Jido.Agent.Strategy.Snapshot
  alias Jido.Agent.Strategy.State, as: StrategyState
  alias Jido.Instruction
  alias JidoCode.Runtime.ManagedCoding.AgentState
  alias JidoCode.Runtime.ManagedCoding.Actions.ActorResponseAction
  alias JidoCode.Runtime.ManagedCoding.Actions.BeginAction
  alias JidoCode.Runtime.ManagedCoding.Actions.BudgetExhaustedAction
  alias JidoCode.Runtime.ManagedCoding.Actions.CancellationAction
  alias JidoCode.Runtime.ManagedCoding.Actions.CandidateResultAction
  alias JidoCode.Runtime.ManagedCoding.Actions.ContextResultAction
  alias JidoCode.Runtime.ManagedCoding.Actions.ModelResultAction
  alias JidoCode.Runtime.ManagedCoding.Actions.RecoveryAction
  alias JidoCode.Runtime.ManagedCoding.Actions.ToolResultAction

  @actions [
    BeginAction,
    ContextResultAction,
    ModelResultAction,
    ToolResultAction,
    ActorResponseAction,
    CandidateResultAction,
    CancellationAction,
    BudgetExhaustedAction,
    RecoveryAction
  ]

  @impl true
  def init(%Agent{} = agent, _context) do
    case AgentState.from_agent(agent.state) do
      {:ok, state} -> {put_strategy(agent, state), []}
      {:error, _error} -> {put_invalid_strategy(agent), []}
    end
  end

  @impl true
  def cmd(%Agent{} = agent, instructions, _context) when is_list(instructions) do
    Enum.reduce_while(instructions, {agent, []}, fn instruction, {current, directives} ->
      case run_instruction(current, instruction) do
        {:ok, updated} -> {:cont, {updated, directives}}
        {:error, directive} -> {:halt, {current, directives ++ [directive]}}
      end
    end)
  end

  @impl true
  def tick(%Agent{} = agent, _context), do: {agent, []}

  @impl true
  def snapshot(%Agent{} = agent, _context) do
    case AgentState.from_agent(agent.state) do
      {:ok, state} ->
        %Snapshot{
          status: snapshot_status(state),
          done?: AgentState.terminal?(state),
          result: snapshot_result(state),
          details: %{
            attempt_iri: state.attempt_iri,
            fencing_token: state.fencing_token,
            phase: state.phase,
            sequence: state.sequence,
            current_invocation_iri: state.current_invocation_iri,
            cancellation: state.cancellation,
            candidate_count: length(state.candidate_digests),
            reconstruction_watermark: state.reconstruction_watermark
          }
        }

      {:error, _error} ->
        %Snapshot{status: :failure, done?: true, result: :invalid_state, details: %{}}
    end
  end

  @impl true
  def signal_routes(_context) do
    [
      {"jido_code.managed_coding.begin", {:strategy_cmd, BeginAction}},
      {"jido_code.managed_coding.context_result", {:strategy_cmd, ContextResultAction}},
      {"jido_code.managed_coding.model_result", {:strategy_cmd, ModelResultAction}},
      {"jido_code.managed_coding.tool_result", {:strategy_cmd, ToolResultAction}},
      {"jido_code.managed_coding.actor_response", {:strategy_cmd, ActorResponseAction}},
      {"jido_code.managed_coding.candidate_result", {:strategy_cmd, CandidateResultAction}},
      {"jido_code.managed_coding.cancellation", {:strategy_cmd, CancellationAction}},
      {"jido_code.managed_coding.budget_exhausted", {:strategy_cmd, BudgetExhaustedAction}},
      {"jido_code.managed_coding.recovery", {:strategy_cmd, RecoveryAction}},
      {"jido_code.managed_coding.continue", {:strategy_tick}}
    ]
  end

  @spec actions() :: [module()]
  def actions, do: @actions

  defp run_instruction(agent, %Instruction{action: action} = instruction)
       when action in @actions do
    instruction = %{
      instruction
      | context: Map.put(instruction.context, :state, agent.state),
        opts: Keyword.put(instruction.opts, :max_retries, 0)
    }

    case Jido.Exec.run(instruction) do
      {:ok, result} when is_map(result) ->
        state = Map.merge(agent.state, result)
        {:ok, put_strategy(%{agent | state: state}, state)}

      {:ok, _result, _effects} ->
        {:error, error_directive(:managed_coding_action_effect)}

      {:error, _reason} ->
        {:error, error_directive(:managed_coding_action_rejected)}
    end
  rescue
    _error -> {:error, error_directive(:managed_coding_action_crash)}
  end

  defp run_instruction(_agent, %Instruction{}),
    do: {:error, error_directive(:managed_coding_unknown_action)}

  defp put_strategy(agent, %AgentState{} = state) do
    StrategyState.put(agent, %{
      module: __MODULE__,
      status: snapshot_status(state),
      phase: state.phase,
      sequence: state.sequence
    })
  end

  defp put_strategy(agent, state) when is_map(state) do
    case AgentState.from_agent(state) do
      {:ok, valid} -> put_strategy(agent, valid)
      {:error, _error} -> put_invalid_strategy(agent)
    end
  end

  defp put_invalid_strategy(agent),
    do: StrategyState.put(agent, %{module: __MODULE__, status: :failure, phase: :failed})

  defp snapshot_status(%AgentState{phase: phase})
       when phase in [:candidate_ready, :completed],
       do: :success

  defp snapshot_status(%AgentState{phase: phase}) when phase in [:cancelled, :failed],
    do: :failure

  defp snapshot_status(%AgentState{phase: :admitted}), do: :idle

  defp snapshot_status(%AgentState{phase: phase})
       when phase in [:awaiting_model, :awaiting_tool, :awaiting_actor], do: :waiting

  defp snapshot_status(%AgentState{}), do: :running

  defp snapshot_result(%AgentState{phase: :candidate_ready} = state),
    do: %{kind: :candidate_proposal, candidate_digests: state.candidate_digests}

  defp snapshot_result(%AgentState{terminal_classification: value}), do: value

  defp error_directive(operation) do
    %Directive.Error{
      error:
        Jido.Error.execution_error("managed coding action rejected", %{operation: operation}),
      context: :managed_coding_strategy
    }
  end
end

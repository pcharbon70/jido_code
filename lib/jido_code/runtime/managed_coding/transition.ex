defmodule JidoCode.Runtime.ManagedCoding.Transition do
  @moduledoc "Pure, closed transition function for managed coding agent events."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Vocabulary
  alias JidoCode.Runtime.ManagedCoding.AgentState

  @events ~w[begin context_result model_result tool_result actor_response candidate_result cancellation budget_exhausted recovery]a

  @spec apply(map(), atom(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def apply(agent_state, event, params) when event in @events and is_map(params) do
    with {:ok, state} <- AgentState.from_agent(agent_state),
         false <- AgentState.terminal?(state),
         :ok <- correlate(state, params),
         :ok <- sequence(state, params),
         {:ok, updates} <- transition(state, event, params),
         candidate <- state |> AgentState.to_map() |> Map.merge(updates),
         {:ok, validated} <- AgentState.new(candidate) do
      {:ok, AgentState.to_map(validated)}
    else
      true -> conflict(:managed_coding_post_terminal)
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  rescue
    _error -> invalid(:managed_coding_transition)
  end

  def apply(_state, _event, _params), do: invalid(:managed_coding_transition)

  defp transition(%AgentState{phase: :admitted}, :begin, params) do
    {:ok, advance(params, %{phase: :preparing})}
  end

  defp transition(%AgentState{phase: :preparing}, :context_result, params) do
    with digest when is_binary(digest) <- params[:context_digest],
         invocation when is_binary(invocation) <- params[:model_invocation_iri] do
      {:ok,
       advance(params, %{
         phase: :awaiting_model,
         context_digest: digest,
         current_invocation_iri: invocation
       })}
    else
      _invalid -> invalid(:managed_coding_context_result)
    end
  end

  defp transition(%AgentState{phase: :awaiting_model} = state, :model_result, params) do
    with :ok <- invocation(state, params),
         kind when is_atom(kind) <- params[:kind],
         true <- Vocabulary.valid?(:model_result_kind, kind) do
      model_transition(kind, params)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:managed_coding_model_result)
    end
  end

  defp transition(%AgentState{phase: :awaiting_tool} = state, :tool_result, params) do
    with :ok <- invocation(state, params),
         kind when is_atom(kind) <- params[:kind],
         true <- Vocabulary.valid?(:tool_result_kind, kind) do
      case kind do
        :completed ->
          {:ok,
           advance(params, %{
             phase: :preparing,
             current_invocation_iri: nil,
             pending_decision: %{}
           })}

        :cancelled ->
          {:ok, advance(params, cancelled())}

        _other ->
          {:ok, advance(params, failed(:failure))}
      end
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:managed_coding_tool_result)
    end
  end

  defp transition(%AgentState{phase: :awaiting_actor} = state, :actor_response, params) do
    with :ok <- invocation(state, params) do
      {:ok,
       advance(params, %{
         phase: :preparing,
         current_invocation_iri: nil,
         pending_decision: %{}
       })}
    end
  end

  defp transition(%AgentState{phase: :assembling_candidate} = state, :candidate_result, params) do
    with :ok <- invocation(state, params),
         digest when is_binary(digest) <- params[:candidate_digest] do
      {:ok,
       advance(params, %{
         phase: :candidate_ready,
         current_invocation_iri: nil,
         candidate_digests: Enum.uniq(state.candidate_digests ++ [digest]),
         terminal_classification: :success
       })}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:managed_coding_candidate_result)
    end
  end

  defp transition(%AgentState{phase: :cancelling}, :cancellation, params),
    do: {:ok, advance(params, cancelled())}

  defp transition(%AgentState{}, :cancellation, params),
    do:
      {:ok,
       advance(params, %{
         phase: :cancelling,
         cancellation: :requested,
         current_invocation_iri: nil
       })}

  defp transition(%AgentState{}, :budget_exhausted, params) do
    dimension = params[:dimension]

    if is_atom(dimension),
      do: {:ok, advance(params, failed(:budget_exhausted))},
      else: invalid(:managed_coding_budget_result)
  end

  defp transition(%AgentState{} = state, :recovery, params) do
    watermark = params[:reconstruction_watermark]

    if is_integer(watermark) and watermark > state.reconstruction_watermark do
      {:ok, advance(params, %{reconstruction_watermark: watermark})}
    else
      conflict(:managed_coding_recovery_watermark)
    end
  end

  defp transition(_state, _event, _params), do: conflict(:managed_coding_legal_transition)

  defp model_transition(:tool_proposal, params) do
    with invocation when is_binary(invocation) <- params[:next_invocation_iri] do
      {:ok,
       advance(params, %{
         phase: :awaiting_tool,
         current_invocation_iri: invocation,
         pending_decision: params[:decision] || %{}
       })}
    else
      _invalid -> invalid(:managed_coding_model_tool_proposal)
    end
  end

  defp model_transition(:clarification, params) do
    with invocation when is_binary(invocation) <- params[:next_invocation_iri] do
      {:ok,
       advance(params, %{
         phase: :awaiting_actor,
         current_invocation_iri: invocation,
         pending_decision: params[:decision] || %{}
       })}
    else
      _invalid -> invalid(:managed_coding_model_clarification)
    end
  end

  defp model_transition(:completion_proposal, params) do
    with invocation when is_binary(invocation) <- params[:next_invocation_iri] do
      {:ok,
       advance(params, %{
         phase: :assembling_candidate,
         current_invocation_iri: invocation,
         pending_decision: params[:decision] || %{}
       })}
    else
      _invalid -> invalid(:managed_coding_model_completion)
    end
  end

  defp model_transition(kind, params) when kind in [:abstention, :failure],
    do: {:ok, advance(params, failed(:failure))}

  defp correlate(state, params) do
    cond do
      params[:attempt_iri] != state.attempt_iri -> conflict(:managed_coding_cross_attempt)
      params[:fencing_token] != state.fencing_token -> conflict(:managed_coding_wrong_fence)
      true -> :ok
    end
  end

  defp sequence(state, params) do
    case params[:sequence] do
      value when value == state.sequence + 1 ->
        :ok

      value when is_integer(value) and value <= state.sequence ->
        conflict(:managed_coding_stale_sequence)

      _gap ->
        conflict(:managed_coding_sequence_gap)
    end
  end

  defp invocation(state, params) do
    if params[:invocation_iri] == state.current_invocation_iri,
      do: :ok,
      else: conflict(:managed_coding_wrong_invocation)
  end

  defp advance(params, values), do: Map.put(values, :sequence, params.sequence)

  defp failed(classification),
    do: %{phase: :failed, current_invocation_iri: nil, terminal_classification: classification}

  defp cancelled,
    do: %{
      phase: :cancelled,
      cancellation: :cancelled,
      current_invocation_iri: nil,
      terminal_classification: :cancelled
    }

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end

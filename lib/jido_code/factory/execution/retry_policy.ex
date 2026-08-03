defmodule JidoCode.Factory.Execution.RetryPolicy do
  @moduledoc "Graph-derived retry, reconciliation, and decision policy."

  alias JidoCode.Knowledge.Error

  @retryable ~w[transient timeout tool_timeout sandbox_unavailable runtime_crash lost_response]a
  @decision_required ~w[unsafe repeated ambiguous policy_denial artifact_mismatch]a

  @spec evaluate(map()) :: {:ok, map()} | {:error, Error.t()}
  def evaluate(context) when is_map(context) do
    with :ok <- validate(context) do
      {:ok, decide(context)}
    end
  end

  def evaluate(_context), do: invalid(:retry_policy)

  defp decide(%{cancelled?: true}),
    do: %{decision: :stop, reason: :cancelled, requires_new_lease?: false}

  defp decide(%{attempt_count: count, max_attempts: maximum}) when count >= maximum,
    do: %{decision: :decision_required, reason: :attempts_exhausted, requires_new_lease?: false}

  defp decide(%{budget_remaining?: false}),
    do: %{decision: :decision_required, reason: :budget_exhausted, requires_new_lease?: false}

  defp decide(context)
       when context.source_fresh? == false or context.plan_fresh? == false or
              context.constraints_current? == false or context.policy_current? == false or
              context.capability_current? == false do
    %{decision: :reconcile, reason: :material_context_change, requires_new_lease?: true}
  end

  defp decide(%{failure_class: failure}) when failure in @decision_required,
    do: %{decision: :decision_required, reason: failure, requires_new_lease?: false}

  defp decide(%{failure_class: failure, lease_state: lease_state}) when failure in @retryable do
    %{
      decision: :retry,
      reason: failure,
      requires_new_lease?: lease_state not in [:active, :executing]
    }
  end

  defp decide(_context),
    do: %{decision: :decision_required, reason: :unclassified_failure, requires_new_lease?: false}

  defp validate(context) do
    required = ~w[
      failure_class attempt_count max_attempts budget_remaining? source_fresh? plan_fresh?
      constraints_current? policy_current? capability_current? lease_state cancelled?
    ]a

    if Enum.all?(required, &Map.has_key?(context, &1)) and
         is_atom(context.failure_class) and is_integer(context.attempt_count) and
         context.attempt_count >= 0 and is_integer(context.max_attempts) and
         context.max_attempts > 0 and
         Enum.all?(
           ~w[budget_remaining? source_fresh? plan_fresh? constraints_current? policy_current? capability_current? cancelled?]a,
           &is_boolean(context[&1])
         ) and is_atom(context.lease_state) do
      :ok
    else
      invalid(:retry_policy)
    end
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

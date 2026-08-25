defmodule JidoCode.Factory.ManagedCoding.RetryPolicy do
  @moduledoc "Bounded retry decisions charged to the admitted managed-coding profile."

  alias JidoCode.Factory.AdapterError

  @spec decide(map(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def decide(attempt, limits) when is_map(attempt) and is_map(limits) do
    with count when is_integer(count) and count >= 0 <- attempt[:retry_count],
         elapsed when is_integer(elapsed) and elapsed >= 0 <- attempt[:elapsed_ms],
         consumed when is_integer(consumed) and consumed >= 0 <- attempt[:resource_units],
         :ok <- limits(limits) do
      cond do
        count >= limits.max_retries ->
          {:ok, %{decision: :stop, reason: :retry_limit}}

        elapsed >= limits.max_elapsed_ms ->
          {:ok, %{decision: :stop, reason: :elapsed_limit}}

        consumed >= limits.max_resource_units ->
          {:ok, %{decision: :stop, reason: :resource_limit}}

        true ->
          {:ok, retry(count, limits)}
      end
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_retry_policy)}
    end
  end

  def decide(_attempt, _limits),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_retry_policy)}

  defp limits(limits) do
    valid =
      is_integer(limits[:max_retries]) and limits.max_retries >= 0 and
        is_integer(limits[:max_elapsed_ms]) and limits.max_elapsed_ms > 0 and
        is_integer(limits[:max_backoff_ms]) and limits.max_backoff_ms > 0 and
        is_integer(limits[:base_backoff_ms]) and limits.base_backoff_ms > 0 and
        is_integer(limits[:jitter_ms]) and limits.jitter_ms >= 0 and
        is_integer(limits[:max_resource_units]) and limits.max_resource_units > 0

    if valid, do: :ok, else: :error
  end

  defp retry(count, limits) do
    exponential = trunc(limits.base_backoff_ms * :math.pow(2, count))
    bounded = min(exponential, limits.max_backoff_ms)
    jitter = rem(:erlang.phash2({limits[:seed], count}), limits.jitter_ms + 1)
    %{decision: :retry, retry_number: count + 1, delay_ms: bounded + jitter}
  end
end

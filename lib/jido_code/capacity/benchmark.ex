defmodule JidoCode.Capacity.Benchmark do
  @moduledoc "Bounded benchmark runner for the release capacity operation matrix."

  alias JidoCode.Knowledge.Error

  @operations [
    :startup_recovery,
    :ingestion,
    :semantic_write,
    :bounded_query,
    :reconciliation,
    :eligibility,
    :reasoning,
    :backup_restore,
    :retention,
    :ui_projection,
    :concurrent_access,
    :provider_storm,
    :scheduler_fairness,
    :long_running_attempt,
    :cache_cold,
    :cache_warm,
    :store_compaction
  ]

  @spec operations() :: [atom()]
  def operations, do: @operations

  @spec run(%{required(atom()) => (-> term())}, keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def run(callbacks, options \\ [])

  def run(callbacks, options) when is_map(callbacks) and is_list(options) do
    iterations = Keyword.get(options, :iterations, 3)
    timeout = Keyword.get(options, :timeout, 5_000)

    with true <- Map.keys(callbacks) |> Enum.sort() == Enum.sort(@operations),
         true <- Enum.all?(callbacks, fn {_operation, callback} -> is_function(callback, 0) end),
         true <- iterations in 1..100,
         true <- timeout in 10..60_000 do
      results =
        Map.new(@operations, fn operation ->
          {operation, measure(callbacks[operation], iterations, timeout)}
        end)

      if Enum.all?(results, fn {_operation, result} -> result.outcome == :ok end),
        do: {:ok, results},
        else: {:error, Error.new(:timeout, :capacity_benchmark)}
    else
      _invalid -> {:error, Error.new(:invalid_input, :capacity_benchmark)}
    end
  end

  def run(_callbacks, _options),
    do: {:error, Error.new(:invalid_input, :capacity_benchmark)}

  defp measure(callback, iterations, timeout) do
    samples = Enum.map(1..iterations, fn _iteration -> timed(callback, timeout) end)

    case Enum.split_with(samples, &match?({:ok, _duration}, &1)) do
      {successful, []} ->
        durations = successful |> Enum.map(&elem(&1, 1)) |> Enum.sort()

        %{
          outcome: :ok,
          iterations: iterations,
          p50_us: percentile(durations, 0.50),
          p95_us: percentile(durations, 0.95),
          maximum_us: List.last(durations)
        }

      {_successful, failures} ->
        %{outcome: :bounded_failure, iterations: iterations, failure_count: length(failures)}
    end
  end

  defp timed(callback, timeout) do
    task =
      Task.async(fn ->
        started_at = System.monotonic_time(:microsecond)
        _result = callback.()
        System.monotonic_time(:microsecond) - started_at
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, duration} when is_integer(duration) and duration >= 0 -> {:ok, duration}
      _timeout_or_exit -> :bounded_failure
    end
  end

  defp percentile(values, ratio) do
    index = max(ceil(length(values) * ratio) - 1, 0)
    Enum.at(values, index)
  end
end

defmodule JidoCode.Product.StreamPressure do
  @moduledoc "Local stream admission hysteresis; never a grant or query result."
  @high_bytes 536_870_912
  @low_bytes 402_653_184
  def new, do: %{mode: :normal, high: 0, low: 0}

  def limits,
    do: %{
      high_bytes: @high_bytes,
      low_bytes: @low_bytes,
      high_samples: 3,
      low_samples: 10,
      sample_ms: 1_000
    }

  def sample do
    queue =
      case Process.whereis(JidoCode.Knowledge.QueryRunner) do
        nil ->
          8

        pid ->
          case Process.info(pid, :message_queue_len) do
            {:message_queue_len, count} -> count
            _ -> 8
          end
      end

    %{
      memory_bytes: :erlang.memory(:total),
      run_queue: :erlang.statistics(:run_queue),
      schedulers: System.schedulers_online(),
      query_queue: queue
    }
  end

  def observe(state, sample) do
    high? =
      sample.memory_bytes >= @high_bytes or sample.query_queue >= 8 or
        sample.run_queue > sample.schedulers * 2

    low? =
      sample.memory_bytes <= @low_bytes and sample.query_queue <= 2 and
        sample.run_queue <= sample.schedulers

    high = if high?, do: min(state.high + 1, 3), else: 0
    low = if low?, do: min(state.low + 1, 10), else: 0

    mode =
      cond do
        high == 3 -> :degraded
        low == 10 -> :normal
        true -> state.mode
      end

    %{mode: mode, high: high, low: low}
  end
end

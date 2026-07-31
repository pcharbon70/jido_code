defmodule JidoCode.TestSupport.SeededConcurrency do
  @moduledoc false

  def run(enumerable, callback, opts \\ []) when is_function(callback, 1) do
    seed = Keyword.get(opts, :seed, 0)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, :infinity)

    enumerable
    |> Enum.sort_by(&stable_order(&1, seed))
    |> Task.async_stream(callback,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: timeout
    )
    |> Enum.to_list()
  end

  defp stable_order(item, seed) do
    :crypto.hash(:sha256, :erlang.term_to_binary({seed, item}))
  end
end

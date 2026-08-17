defmodule JidoCode.TestSupport.FakeJidoHarnessProcessAPI do
  @moduledoc false

  @behaviour JidoCode.Runtime.JidoHarness.ProcessAPI

  @impl true
  def start(spec, options) do
    notify(options, {:jido_harness_process_api, :start, spec})
    Keyword.get(options, :start_result, {:ok, "proc_developer_local"})
  end

  @impl true
  def send_input(process_id, input, options) do
    notify(options, {:jido_harness_process_api, :input, process_id, input})
    Keyword.get(options, :input_result, :ok)
  end

  @impl true
  def info(process_id, options) do
    notify(options, {:jido_harness_process_api, :info, process_id})

    Keyword.get(options, :info_result, %{
      process_id: process_id,
      state: :running,
      output_cursor: 1,
      journal_dir: nil
    })
    |> then(&{:ok, &1})
  end

  @impl true
  def await(process_id, timeout, options) do
    notify(options, {:jido_harness_process_api, :await, process_id, timeout})

    case Keyword.get(options, :await_fun) do
      fun when is_function(fun, 2) ->
        fun.(process_id, timeout)

      _missing ->
        Keyword.get(
          options,
          :await_result,
          {:ok, %{process_id: process_id, state: :cancelled, output_cursor: 1}}
        )
    end
  end

  @impl true
  def replay(process_id, replay_options, options) do
    notify(options, {:jido_harness_process_api, :replay, process_id, replay_options})
    {:ok, Keyword.get(options, :replay_result, [])}
  end

  @impl true
  def cancel(process_id, options) do
    notify(options, {:jido_harness_process_api, :cancel, process_id})
    Keyword.get(options, :cancel_result, :ok)
  end

  @impl true
  def kill(process_id, options) do
    notify(options, {:jido_harness_process_api, :kill, process_id})
    Keyword.get(options, :kill_result, :ok)
  end

  @impl true
  def prune(process_id, options) do
    notify(options, {:jido_harness_process_api, :prune, process_id})
    Keyword.get(options, :prune_result, :ok)
  end

  defp notify(options, message) do
    case Keyword.get(options, :owner) do
      owner when is_pid(owner) -> send(owner, message)
      _missing -> :ok
    end
  end
end

defmodule JidoCode.TestSupport.FakeJidoHarnessRunner do
  @moduledoc false

  @behaviour JidoCode.Runtime.JidoHarness.Runner

  @impl true
  def start(profile, launch, options) do
    notify(options, {:jido_harness_runner, :start, profile, launch})

    {:ok,
     Keyword.get(options, :start_receipt, %{
       runtime_ref: "proc_fake",
       session_ref: "session_fake",
       provider_session_ref: "provider_session_fake",
       versions: %{cli: "pi-fixture/1.0.0", provider: "fixture"},
       observations: []
     })}
  end

  @impl true
  def signal(handle, signal, options) do
    notify(options, {:jido_harness_runner, :signal, handle, signal})
    {:ok, Keyword.get(options, :signal_receipt, %{state: :running, observations: []})}
  end

  @impl true
  def status(handle, options) do
    notify(options, {:jido_harness_runner, :status, handle})

    case Keyword.get(options, :status_receipt, %{state: :running, observations: []}) do
      {:error, reason} -> {:error, reason}
      receipt -> {:ok, receipt}
    end
  end

  @impl true
  def cancel(handle, cancellation, options) do
    notify(options, {:jido_harness_runner, :cancel, handle, cancellation})
    delay = Keyword.get(options, :cancel_delay_ms, 0)
    if is_integer(delay) and delay > 0, do: Process.sleep(delay)
    {:ok, Keyword.get(options, :cancel_receipt, %{state: :cancelled})}
  end

  @impl true
  def terminate(handle, reason, options) do
    notify(options, {:jido_harness_runner, :terminate, handle, reason})
    {:ok, Keyword.get(options, :terminate_receipt, %{state: :terminated})}
  end

  defp notify(options, message) do
    case Keyword.get(options, :owner) do
      owner when is_pid(owner) -> send(owner, message)
      _missing -> :ok
    end
  end
end

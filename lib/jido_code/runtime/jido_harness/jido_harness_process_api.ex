defmodule JidoCode.Runtime.JidoHarness.JidoHarnessProcessAPI do
  @moduledoc false

  @behaviour JidoCode.Runtime.JidoHarness.ProcessAPI

  @impl true
  def start(spec, _options), do: Jido.Harness.Process.start(spec)

  @impl true
  def send_input(process_id, input, _options),
    do: Jido.Harness.Process.send_input(process_id, input)

  @impl true
  def info(process_id, _options), do: Jido.Harness.Process.info(process_id)

  @impl true
  def await(process_id, timeout, _options), do: Jido.Harness.Process.await(process_id, timeout)

  @impl true
  def replay(process_id, replay_options, _options),
    do: Jido.Harness.Process.replay(process_id, replay_options)

  @impl true
  def cancel(process_id, _options), do: Jido.Harness.Process.cancel(process_id)

  @impl true
  def kill(process_id, _options), do: Jido.Harness.Process.kill(process_id)

  @impl true
  def prune(process_id, _options), do: Jido.Harness.Process.prune(process_id)
end

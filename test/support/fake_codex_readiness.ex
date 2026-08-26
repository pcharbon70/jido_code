defmodule JidoCode.TestSupport.FakeCodexReadinessProbe do
  @moduledoc false

  @behaviour JidoCode.Runtime.JidoHarness.CodexReadinessProbe

  @impl true
  def login_status(executable, options) do
    owner = Keyword.fetch!(options, :owner)
    send(owner, {:codex_login_status, executable})
    Keyword.get(options, :result, {:ok, :authenticated})
  end
end

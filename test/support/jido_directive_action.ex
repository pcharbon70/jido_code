defmodule JidoCode.TestSupport.JidoDirectiveAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_directive_fixture",
    description: "Emits a directive without changing agent state",
    schema: []

  @impl true
  def run(_params, _context) do
    {:ok, signal} = Jido.Signal.new("jido_code.runtime.fixture", %{status: :observed})
    {:ok, %{}, [%Jido.Agent.Directive.Emit{signal: signal, dispatch: {:noop, []}}]}
  end
end

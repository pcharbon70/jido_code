defmodule JidoCode.TestSupport.FakeReferenceToolAdapter do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.Tool

  @impl true
  def execute(adapter, request, options) do
    send(adapter.owner, {:reference_tool_effect, request, options})
    adapter.result
  end
end

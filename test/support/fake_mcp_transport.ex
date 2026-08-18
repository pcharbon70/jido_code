defmodule JidoCode.TestSupport.FakeMCPTransport do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.MCPTransport

  @impl true
  def identity(transport) do
    send(transport.owner, {:mcp_transport_identity, transport.identity})
    {:ok, transport.identity}
  end

  @impl true
  def invoke(transport, call, options) do
    send(transport.owner, {:mcp_transport_invoke, call, options})
    transport.result
  end
end

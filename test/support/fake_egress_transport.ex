defmodule JidoCode.TestSupport.FakeEgressTransport do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.EgressTransport

  @impl true
  def request(transport, request, endpoint, body) do
    send(transport.owner, {:egress_transport, request, endpoint, body})
    transport.request.(request, endpoint, body)
  end
end

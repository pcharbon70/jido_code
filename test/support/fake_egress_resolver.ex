defmodule JidoCode.TestSupport.FakeEgressResolver do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.EgressResolver

  @impl true
  def identity(resolver), do: {:ok, resolver.identity}

  @impl true
  def resolve(resolver, host) do
    send(resolver.owner, {:egress_resolve, host})
    resolver.resolve.(host)
  end
end

defmodule JidoCode.TestSupport.FakeModelAuthority do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ModelAuthority

  @impl true
  def authorize(authority, stage, profile, request) do
    send(authority.owner, {:model_authorize, stage, profile, request})
    Map.get(authority.results, stage, :ok)
  end
end

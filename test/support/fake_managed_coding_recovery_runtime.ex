defmodule JidoCode.TestSupport.FakeManagedCodingRecoveryRuntime do
  @behaviour JidoCode.Factory.Ports.ManagedCodingRecoveryRuntime

  def recreate(owner, plan, fence, options) do
    send(owner, {:recovery_recreate, plan, fence, options})
    {:ok, %{workspace_iri: "https://jido.run/id/activity/recreated-workspace"}}
  end
end

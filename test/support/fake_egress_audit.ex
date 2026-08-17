defmodule JidoCode.TestSupport.FakeEgressAudit do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.EgressAudit

  @impl true
  def record(audit, decision) do
    send(audit.owner, {:egress_audit, decision})
    Map.get(audit, :result, :ok)
  end
end

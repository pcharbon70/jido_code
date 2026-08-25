defmodule JidoCode.TestSupport.FakeManagedCodingRecoveryLedger do
  @behaviour JidoCode.Factory.Ports.ManagedCodingRecoveryLedger

  alias JidoCode.Factory.AdapterError

  def discover(agent, scope) do
    send(owner(agent), {:recovery_discover, scope})
    {:ok, Agent.get(agent, & &1.records)}
  end

  def acquire_fence(agent, record, expected_fence) do
    send(owner(agent), {:recovery_acquire_fence, record.attempt_iri, expected_fence})

    Agent.get_and_update(agent, fn state ->
      token = state.next_fence
      result = {:ok, %{lease_iri: iri("lease-#{token}"), fencing_token: token}}
      {result, %{state | next_fence: token + 1}}
    end)
  end

  def recovered(agent, plan, fence) do
    send(owner(agent), {:recovery_committed, plan.record.attempt_iri, fence.fencing_token})
    :ok
  end

  def quarantine(agent, record, reason) do
    send(owner(agent), {:recovery_quarantined, attempt_iri(record), reason})
    :ok
  end

  defp owner(agent), do: Agent.get(agent, & &1.owner)
  defp attempt_iri(record), do: Map.get(record, :attempt_iri)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"

  def unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end

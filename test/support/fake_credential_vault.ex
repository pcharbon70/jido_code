defmodule JidoCode.TestSupport.FakeCredentialVault do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.CredentialVault

  @impl true
  def checkout(vault, reference, permit) do
    send(vault.owner, {:credential_vault_checkout, reference.iri, permit.id})
    enter(vault[:tracker])

    if delay = vault[:delay_ms] do
      Process.sleep(delay)
    end

    leave(vault[:tracker])

    case vault[:result] do
      nil -> {:ok, vault.material}
      result -> result
    end
  end

  defp enter(nil), do: :ok

  defp enter(tracker) do
    Agent.update(tracker, fn state ->
      active = state.active + 1
      %{state | active: active, maximum: max(state.maximum, active)}
    end)
  end

  defp leave(nil), do: :ok
  defp leave(tracker), do: Agent.update(tracker, &%{&1 | active: &1.active - 1})
end

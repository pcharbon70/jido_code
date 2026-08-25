defmodule JidoCode.TestSupport.FakeManagedCodingEffectLedger do
  @behaviour JidoCode.Factory.Ports.ManagedCodingEffectLedger

  def intent(owner, intent), do: notify(owner, {:effect_intent, intent})
  def outcome(owner, intent, outcome), do: notify(owner, {:effect_outcome, intent, outcome})
  def retry(owner, intent, decision), do: notify(owner, {:effect_retry, intent, decision})
  def ambiguous(owner, intent, reason), do: notify(owner, {:effect_ambiguous, intent, reason})

  def resolution_interaction(owner, intent, details) do
    send(owner, {:effect_resolution, intent, details})
    {:ok, %{interaction_iri: "https://jido.run/id/activity/resolution", closed_scope: true}}
  end

  defp notify(owner, message) do
    send(owner, message)
    :ok
  end
end

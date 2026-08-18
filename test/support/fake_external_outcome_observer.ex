defmodule JidoCode.TestSupport.FakeExternalOutcomeObserver do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ExternalOutcomeObserver

  @impl true
  def observe(state, publication, options) do
    notify(state, {:external_outcome, :observe, publication.attempt_iri})
    Keyword.fetch!(options, :observation_result)
  end

  defp notify(%{owner: owner}, message) when is_pid(owner), do: send(owner, message)
  defp notify(_state, _message), do: :ok
end

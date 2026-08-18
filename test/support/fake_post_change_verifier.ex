defmodule JidoCode.TestSupport.FakePostChangeVerifier do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.PostChangeVerifier

  @impl true
  def verify(state, publication, observation, options) do
    notify(
      state,
      {:external_outcome, :verify, publication.attempt_iri, observation.external_revision}
    )

    Keyword.fetch!(options, :verification_result)
  end

  defp notify(%{owner: owner}, message) when is_pid(owner), do: send(owner, message)
  defp notify(_state, _message), do: :ok
end

defmodule JidoCode.TestSupport.FakeSecretProvider do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.SecretProvider

  @impl true
  def fetch(provider, reference) do
    send(provider.owner, {:secret_fetch, reference})
    provider.result
  end
end

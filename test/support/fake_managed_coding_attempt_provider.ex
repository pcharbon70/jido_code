defmodule JidoCode.TestSupport.FakeManagedCodingAttemptProvider do
  @moduledoc false

  @behaviour JidoCode.Product.ManagedCodingAttemptProvider

  @impl true
  def load(authority, identity, reference) do
    send(Application.fetch_env!(:jido_code, :managed_coding_product_test_pid), {
      :managed_attempt_load,
      authority,
      identity,
      reference
    })

    {:ok, Application.fetch_env!(:jido_code, :managed_coding_product_fixture)}
  end
end

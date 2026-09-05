defmodule JidoCode.Identity.RecoveryAdapter do
  @moduledoc "Trusted boundary for independently authenticated recovery evidence."

  alias JidoCode.Identity.HumanAccount

  @callback verify(map(), HumanAccount.t()) ::
              {:ok, %{method_class: atom(), approval_refs: [String.t()]}}
              | {:error, :unavailable | :invalid_recovery}
end

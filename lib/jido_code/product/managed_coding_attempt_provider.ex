defmodule JidoCode.Product.ManagedCodingAttemptProvider do
  @moduledoc "Scoped graph-projection boundary for one opaque managed coding attempt reference."

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.ManagedCodingAttempt

  @callback load(AuthorityContext.t(), map(), String.t()) ::
              {:ok, ManagedCodingAttempt.t()} | {:error, term()}
end

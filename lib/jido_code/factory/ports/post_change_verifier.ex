defmodule JidoCode.Factory.Ports.PostChangeVerifier do
  @moduledoc "Independent verifier boundary for one observed external revision."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Publication.Result

  @callback verify(term(), Result.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

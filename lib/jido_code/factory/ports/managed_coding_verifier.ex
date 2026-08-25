defmodule JidoCode.Factory.Ports.ManagedCodingVerifier do
  @moduledoc "Independent fresh-checkout verification boundary with no disposition or publication API."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.VerificationRequest

  @callback verify(term(), VerificationRequest.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

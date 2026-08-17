defmodule JidoCode.Factory.Ports.CredentialVault do
  @moduledoc "Trusted vault/helper port called only inside the credential broker process."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Permit
  alias JidoCode.Factory.CredentialReference

  @callback checkout(term(), CredentialReference.t(), Permit.t()) ::
              {:ok, binary()} | {:error, AdapterError.t()}
end

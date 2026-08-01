defmodule JidoCode.Factory.Ports.SecretProvider do
  @moduledoc """
  Call-scoped secret lookup port.

  Implementations must return credential bytes only to the invoking adapter;
  callers must not place the returned value in observations, errors, telemetry,
  fixtures, or graph commands.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference

  @callback fetch(provider :: term(), CredentialReference.t()) ::
              {:ok, binary()} | {:error, AdapterError.t()}
end

defmodule JidoCode.Factory.Ports.TrustedConnector do
  @moduledoc "Attested connector that receives credential material directly from the broker."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Permit

  @callback identity(term()) :: {:ok, map()} | {:error, AdapterError.t()}

  @callback execute(
              term(),
              Permit.t(),
              binary() | {:local_cli_reference, String.t()},
              map()
            ) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

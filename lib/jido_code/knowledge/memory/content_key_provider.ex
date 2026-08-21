defmodule JidoCode.Knowledge.Memory.ContentKeyProvider do
  @moduledoc "Envelope-encryption key provider port; graph records references, never key bytes."

  @type key_record :: %{
          reference_iri: String.t(),
          generation: pos_integer(),
          key: binary(),
          state: :active | :revoked
        }

  @callback create_key(
              server :: GenServer.server(),
              tenant_iri :: String.t(),
              object_iri :: String.t()
            ) ::
              {:ok, key_record()} | {:error, term()}
  @callback rotate_key(
              server :: GenServer.server(),
              tenant_iri :: String.t(),
              object_iri :: String.t()
            ) ::
              {:ok, key_record()} | {:error, term()}
  @callback fetch_key(server :: GenServer.server(), reference_iri :: String.t()) ::
              {:ok, key_record()} | {:error, term()}
  @callback revoke_key(server :: GenServer.server(), reference_iri :: String.t()) ::
              :ok | {:error, term()}
  @callback destroy_key(server :: GenServer.server(), reference_iri :: String.t()) ::
              :ok | {:error, term()}
end

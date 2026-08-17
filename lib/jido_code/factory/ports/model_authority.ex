defmodule JidoCode.Factory.Ports.ModelAuthority do
  @moduledoc "Fail-closed model-profile authorization at credential release and dispatch."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Request

  @callback authorize(
              authority :: term(),
              :before_credential_release | :before_dispatch,
              BufferedProfile.t(),
              Request.t()
            ) :: :ok | {:error, AdapterError.t()}
end

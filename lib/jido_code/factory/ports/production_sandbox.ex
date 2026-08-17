defmodule JidoCode.Factory.Ports.ProductionSandbox do
  @moduledoc "Production sandbox port with an attested isolation profile and lifecycle callbacks."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox.IsolationProfile

  @callback isolation_profile(term()) ::
              {:ok, IsolationProfile.t()} | {:error, AdapterError.t()}
end

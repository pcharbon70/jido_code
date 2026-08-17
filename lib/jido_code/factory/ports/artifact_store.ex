defmodule JidoCode.Factory.Ports.ArtifactStore do
  @moduledoc "Provider-owned immutable storage port for large or binary sandbox artifacts."

  alias JidoCode.Factory.AdapterError

  @callback put(term(), map()) :: {:ok, String.t()} | {:error, AdapterError.t()}
end

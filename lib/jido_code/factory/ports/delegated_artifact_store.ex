defmodule JidoCode.Factory.Ports.DelegatedArtifactStore do
  @moduledoc "Immutable content-addressed artifact boundary for delegated checkpoints and patches."

  alias JidoCode.Factory.AdapterError

  @callback put(term(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  @callback fetch(term(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
end

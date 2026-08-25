defmodule JidoCode.Factory.Ports.ManagedCodingCandidateStore do
  @moduledoc "Create-once immutable storage boundary for content-addressed candidate manifests."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateManifest

  @callback create(term(), CandidateManifest.t()) ::
              {:ok, :committed | :idempotent} | {:error, AdapterError.t()}
  @callback fetch(term(), String.t()) ::
              {:ok, CandidateManifest.t()} | {:error, AdapterError.t()}
end

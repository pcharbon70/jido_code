defmodule JidoCode.Factory.Ports.ManagedCodingAdmissionLedger do
  @moduledoc "Atomic graph-owned admission and lifecycle-start accounting seam."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.ResolvedAdmission

  @callback resolve(term(), Command.t()) ::
              {:ok, ResolvedAdmission.t()} | {:error, AdapterError.t()}
  @callback commit(term(), Command.t(), ResolvedAdmission.t()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback fetch(term(), String.t(), pos_integer()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback runtime_started(term(), map(), map()) :: :ok | {:error, AdapterError.t()}
  @callback start_failed(term(), map(), AdapterError.t()) :: :ok | {:error, AdapterError.t()}
end

defmodule JidoCode.Factory.Ports.VerificationWorkspace do
  @moduledoc "Trusted disposable-workspace boundary used by independent verification."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Verification.Admission

  @callback checkout(term(), Admission.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback apply_candidate(term(), map(), [map()], String.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback changed_paths(term(), map(), keyword()) ::
              {:ok, [String.t()]} | {:error, AdapterError.t()}
  @callback run_check(term(), map(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback cleanup(term(), [map()], keyword()) :: :ok | {:error, AdapterError.t()}
end

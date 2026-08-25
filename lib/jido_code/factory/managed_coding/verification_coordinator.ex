defmodule JidoCode.Factory.ManagedCoding.VerificationCoordinator do
  @moduledoc "Fetches immutable candidates and delegates only to a distinct verifier port."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateManifest
  alias JidoCode.Factory.ManagedCoding.VerificationRequest
  alias JidoCode.Factory.ManagedCoding.VerificationResult

  @spec verify(module(), term(), module(), term(), String.t(), map(), keyword()) ::
          {:ok, VerificationResult.t()} | {:error, AdapterError.t()}
  def verify(
        store_module,
        store,
        verifier_module,
        verifier,
        candidate_iri,
        attributes,
        options \\ []
      )
      when is_atom(store_module) and is_atom(verifier_module) and is_list(options) do
    with {:ok, %CandidateManifest{} = candidate} <- store_module.fetch(store, candidate_iri),
         true <- candidate.candidate_iri == candidate_iri,
         {:ok, request} <- VerificationRequest.new(candidate, attributes),
         {:ok, result_attributes} <- verifier_module.verify(verifier, request, options),
         {:ok, result} <- VerificationResult.new(request, result_attributes) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :managed_coding_verification)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_verification)}
  end
end

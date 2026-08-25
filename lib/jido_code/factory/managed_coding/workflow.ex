defmodule JidoCode.Factory.ManagedCoding.Workflow do
  @moduledoc "Factory workflow joining candidate closure, independent verification, and disposition."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateClosure
  alias JidoCode.Factory.ManagedCoding.Disposition
  alias JidoCode.Factory.ManagedCoding.Lifecycle
  alias JidoCode.Factory.ManagedCoding.VerificationCoordinator

  @spec close_verify_dispose(map(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def close_verify_dispose(dependencies, input)
      when is_map(dependencies) and is_map(input) do
    with {lifecycle_module, lifecycle} <- dependencies[:lifecycle],
         {store_module, store} <- dependencies[:candidate_store],
         {verifier_module, verifier} <- dependencies[:verifier],
         {:ok, closure} <-
           CandidateClosure.close(store_module, store, input[:capture], input[:candidate_policy]) do
      continue_closed_candidate(
        closure,
        lifecycle_module,
        lifecycle,
        store_module,
        store,
        verifier_module,
        verifier,
        input
      )
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_workflow)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_workflow)}
  end

  def close_verify_dispose(_dependencies, _input),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_workflow)}

  defp continue_closed_candidate(
         %{status: :ready, manifest: manifest} = closure,
         lifecycle_module,
         lifecycle,
         store_module,
         store,
         verifier_module,
         verifier,
         input
       ) do
    with {:ok, _candidate_fact} <-
           Lifecycle.observe(
             lifecycle_module,
             lifecycle,
             observation(input, :candidate, :assembling_candidate, manifest.candidate_iri)
           ),
         {:ok, _ready} <-
           Lifecycle.transition(
             lifecycle_module,
             lifecycle,
             transition(input, :candidate_ready, :candidate_ready, [manifest.candidate_iri])
           ),
         {:ok, _verifying} <-
           Lifecycle.transition(
             lifecycle_module,
             lifecycle,
             transition(input, :verifying, :verifying, [manifest.candidate_iri])
           ),
         {:ok, verification} <-
           VerificationCoordinator.verify(
             store_module,
             store,
             verifier_module,
             verifier,
             manifest.candidate_iri,
             input[:verification],
             input[:verification_options] || []
           ),
         {:ok, _verification_fact} <-
           Lifecycle.observe(
             lifecycle_module,
             lifecycle,
             observation(
               input,
               :check,
               :verifying,
               verification.verification_iri,
               verification.evidence_iris
             )
           ),
         {:ok, disposition} <- Disposition.decide(verification, input[:disposition]),
         {:ok, _dispositioned} <-
           Lifecycle.transition(
             lifecycle_module,
             lifecycle,
             transition(
               input,
               :dispositioned,
               :dispositioned,
               [disposition.disposition_iri]
             )
           ) do
      {:ok, %{candidate: closure, verification: verification, disposition: disposition}}
    else
      {:error, %AdapterError{} = error} ->
        fail(lifecycle_module, lifecycle, input)
        {:error, error}
    end
  end

  defp continue_closed_candidate(
         closure,
         _lifecycle_module,
         _lifecycle,
         _store_module,
         _store,
         _verifier_module,
         _verifier,
         _input
       ) do
    {:ok, %{candidate: closure, verification: nil, disposition: nil}}
  end

  defp observation(input, kind, state, subject, evidence \\ nil) do
    base(input, state, cause(input, kind))
    |> Map.put(:kind, kind)
    |> Map.put(:subject_iri, subject)
    |> Map.put(:evidence_iris, evidence || input[:closure_evidence_iris] || [])
  end

  defp transition(input, state, cause_key, evidence) do
    base(input, state, cause(input, cause_key))
    |> Map.put(:evidence_iris, evidence)
  end

  defp base(input, state, cause_iri) do
    %{
      attempt_iri: input.attempt_iri,
      fencing_token: input.fencing_token,
      state: state,
      subject_iri: input.attempt_iri,
      actor_iri: input.actor_iri,
      cause_iri: cause_iri,
      evidence_iris: [],
      occurred_at: input.occurred_at,
      recorded_at: input.recorded_at,
      progress: state,
      budget_use: input[:budget_use] || %{}
    }
  end

  defp cause(input, key), do: Map.fetch!(input.cause_iris, key)

  defp fail(module, ledger, input) do
    Lifecycle.transition(
      module,
      ledger,
      transition(input, :failed, :failure, input[:failure_evidence_iris] || [])
    )

    :ok
  rescue
    _error -> :ok
  end
end

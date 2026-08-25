defmodule JidoCode.Factory.ManagedCoding.EffectReconciler do
  @moduledoc "Persists effect intent before dispatch and resolves uncertain outcomes without guessing."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.EffectIntent
  alias JidoCode.Factory.ManagedCoding.RetryPolicy

  @spec dispatch(module(), term(), module(), term(), EffectIntent.t(), map()) ::
          {:ok, map()} | {:ambiguous, map()} | {:error, AdapterError.t()}
  def dispatch(ledger_module, ledger, adapter_module, adapter, %EffectIntent{} = intent, request) do
    with :ok <- ledger_module.intent(ledger, intent) do
      case adapter_module.dispatch(adapter, intent, request) do
        {:ok, outcome} ->
          persist_outcome(ledger_module, ledger, intent, outcome)

        {:error, %AdapterError{kind: kind}} when kind in [:timeout, :unavailable] ->
          reconcile(ledger_module, ledger, adapter_module, adapter, intent, request)

        {:error, %AdapterError{} = error} ->
          {:error, error}
      end
    end
  end

  @spec retry(module(), term(), EffectIntent.t(), map(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def retry(ledger_module, ledger, intent, usage, limits) do
    with {:ok, decision} <- RetryPolicy.decide(usage, limits),
         :ok <- ledger_module.retry(ledger, intent, decision) do
      {:ok, decision}
    end
  end

  defp reconcile(ledger_module, ledger, adapter_module, adapter, intent, request) do
    result =
      case intent.classification do
        :replayable -> {:ambiguous, :safe_replay}
        :query_reconcilable -> adapter_module.query(adapter, intent)
        :compensatable -> compensate(adapter_module, adapter, intent)
        :manual_resolution_only -> {:ambiguous, :manual_resolution}
      end

    case result do
      {:ok, outcome} ->
        persist_outcome(ledger_module, ledger, intent, outcome)

      {:ambiguous, reason} ->
        persist_ambiguity(ledger_module, ledger, intent, reason, request)

      {:error, %AdapterError{}} ->
        persist_ambiguity(ledger_module, ledger, intent, :query_failed, request)
    end
  end

  defp compensate(adapter_module, adapter, intent) do
    case adapter_module.compensate(adapter, intent) do
      :ok -> {:ambiguous, :compensated_requires_resolution}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  defp persist_outcome(ledger_module, ledger, intent, outcome) do
    case ledger_module.outcome(ledger, intent, outcome) do
      :ok -> {:ok, outcome}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  defp persist_ambiguity(ledger_module, ledger, intent, reason, request) do
    with :ok <- ledger_module.ambiguous(ledger, intent, reason),
         {:ok, interaction} <-
           ledger_module.resolution_interaction(ledger, intent, %{
             reason: reason,
             capability_change: :forbidden,
             evidence_erasure: :forbidden,
             request_digest: request[:digest]
           }) do
      {:ambiguous, interaction}
    end
  end
end

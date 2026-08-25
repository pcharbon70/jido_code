defmodule JidoCode.Factory.ManagedCoding.RecoveryCoordinator do
  @moduledoc "Recovers graph-proven attempts only after an abandoned runtime is freshly fenced."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.RecoveryPlan
  alias JidoCode.Factory.ManagedCoding.RecoveryRecord
  alias JidoCode.Factory.ManagedCoding.Identity

  @spec recover(module(), term(), module(), term(), map(), map(), keyword()) ::
          {:ok, [map()]} | {:error, AdapterError.t()}
  def recover(ledger_module, ledger, runtime_module, runtime, scope, baseline, options \\ []) do
    with {:ok, records} <- ledger_module.discover(ledger, scope) do
      results =
        Enum.map(records, fn raw ->
          recover_one(ledger_module, ledger, runtime_module, runtime, raw, baseline, options)
        end)

      {:ok, results}
    end
  rescue
    _error -> {:error, AdapterError.new(:corrupt, :managed_coding_recovery)}
  end

  defp recover_one(ledger_module, ledger, runtime_module, runtime, raw, baseline, options) do
    with {:ok, record} <- RecoveryRecord.new(raw) do
      case RecoveryPlan.build(record, baseline) do
        {:ok, %RecoveryPlan{action: :ignore_terminal}} ->
          %{attempt_iri: record.attempt_iri, result: :ignored_terminal}

        {:ok, plan} ->
          resume(ledger_module, ledger, runtime_module, runtime, plan, options)

        {:quarantine, reason} ->
          quarantine(ledger_module, ledger, record, reason)
      end
    else
      {:error, _error} -> quarantine(ledger_module, ledger, raw, :incomplete_evidence)
    end
  end

  defp resume(ledger_module, ledger, runtime_module, runtime, plan, options) do
    record = plan.record

    with {:ok, fence} <- ledger_module.acquire_fence(ledger, record, record.old_fencing_token),
         :ok <- valid_fence(fence, record.old_fencing_token),
         {:ok, materialization} <-
           runtime_module.recreate(
             runtime,
             plan,
             fence,
             Keyword.put(options, :orphan_state, :discard)
           ),
         :ok <- ledger_module.recovered(ledger, plan, fence) do
      %{
        attempt_iri: record.attempt_iri,
        result: :recovered,
        action: plan.action,
        fencing_token: fence.fencing_token,
        materialization: materialization
      }
    else
      {:error, %AdapterError{} = error} ->
        %{attempt_iri: record.attempt_iri, result: :failed, error: error}

      _invalid ->
        quarantine(ledger_module, ledger, record, :contradictory_evidence)
    end
  end

  defp valid_fence(%{lease_iri: lease_iri, fencing_token: token}, old_token)
       when is_integer(token) and token > old_token,
       do: Identity.validate_resource(lease_iri)

  defp valid_fence(_fence, _old_token), do: :error

  defp quarantine(ledger_module, ledger, record, reason) do
    case ledger_module.quarantine(ledger, record, reason) do
      :ok ->
        %{attempt_iri: attempt_iri(record), result: :quarantined, reason: reason}

      {:error, %AdapterError{} = error} ->
        %{attempt_iri: attempt_iri(record), result: :failed, error: error}
    end
  end

  defp attempt_iri(%RecoveryRecord{attempt_iri: attempt_iri}), do: attempt_iri
  defp attempt_iri(record) when is_map(record), do: record[:attempt_iri]
end

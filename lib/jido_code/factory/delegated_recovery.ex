defmodule JidoCode.Factory.DelegatedRecovery do
  @moduledoc "Derives restart action only from current graph facts and an accepted checkpoint."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCheckpoint

  @lifecycles ~w[preparing running awaiting_actor candidate_ready cancelling cancelled failed]a
  @effect_states ~w[none started completed ambiguous]a
  @forbidden_keys ~w[pid process_ref runtime_ref provider_session_ref event_cursor workspace_path journal_path cli_cache]a

  @spec plan(map(), DelegatedCheckpoint.t() | nil) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def plan(graph, checkpoint) when is_map(graph) do
    with false <- forbidden_state?(graph),
         :ok <- graph_contract(graph),
         :ok <- checkpoint_contract(graph, checkpoint) do
      {:ok, recovery_plan(graph, checkpoint)}
    else
      true -> unauthorized(:delegated_recovery_disposable_state)
      _invalid -> invalid(:delegated_recovery)
    end
  rescue
    _error -> invalid(:delegated_recovery)
  end

  def plan(_graph, _checkpoint), do: invalid(:delegated_recovery)

  defp graph_contract(graph) do
    if is_binary(graph[:attempt_iri]) and is_binary(graph[:lease_iri]) and
         is_integer(graph[:current_fencing_token]) and graph.current_fencing_token > 0 and
         graph[:lifecycle] in @lifecycles and graph[:effect_state] in @effect_states and
         graph[:failure_outcome] in [nil, :timed_out, :process_crash, :provider_unavailable] and
         is_boolean(graph[:cancellation_committed?]),
       do: :ok,
       else: :error
  end

  defp checkpoint_contract(_graph, nil), do: :ok

  defp checkpoint_contract(graph, %DelegatedCheckpoint{} = checkpoint) do
    if checkpoint.attempt_iri == graph.attempt_iri and
         checkpoint.lease_iri == graph.lease_iri and
         checkpoint.fencing_token == graph.current_fencing_token and
         graph[:accepted_checkpoint_iri] == checkpoint.checkpoint_iri and
         graph[:accepted_checkpoint_digest] == checkpoint.checkpoint_digest,
       do: :ok,
       else: :error
  end

  defp checkpoint_contract(_graph, _checkpoint), do: :error

  defp recovery_plan(%{cancellation_committed?: true}, _checkpoint) do
    %{
      action: :propagate_cancellation,
      order: [
        :graph_intent,
        :permit_revocation,
        :adapter_cancel,
        :namespace_kill,
        :workspace_cleanup,
        :late_output_rejection,
        :terminal_accounting
      ],
      generic_retry: :forbidden,
      provider_session_reuse: false,
      process_reference_reuse: false
    }
  end

  defp recovery_plan(%{effect_state: :ambiguous}, _checkpoint) do
    %{
      action: :reconcile_effect_identity,
      ambiguity: :effect_classification,
      generic_retry: :forbidden,
      provider_session_reuse: false,
      process_reference_reuse: false
    }
  end

  defp recovery_plan(%{lifecycle: :failed, failure_outcome: :timed_out}, nil) do
    %{
      action: :abandon,
      lifecycle_outcome: :failed,
      failure_outcome: :timed_out,
      generic_retry: :forbidden,
      provider_session_reuse: false,
      process_reference_reuse: false
    }
  end

  defp recovery_plan(%{lifecycle: lifecycle}, %DelegatedCheckpoint{} = checkpoint)
       when lifecycle in [:preparing, :running, :awaiting_actor, :failed] do
    %{
      action: :reconstruct_from_checkpoint,
      checkpoint_iri: checkpoint.checkpoint_iri,
      checkpoint_digest: checkpoint.checkpoint_digest,
      patch_artifact_iri: checkpoint.patch_artifact_iri,
      patch_digest: checkpoint.patch_digest,
      source_snapshot_iri: checkpoint.source_snapshot_iri,
      base_commit: checkpoint.base_commit,
      new_fencing_token_required: true,
      generic_retry: :forbidden,
      provider_session_reuse: false,
      process_reference_reuse: false
    }
  end

  defp recovery_plan(_graph, _checkpoint) do
    %{
      action: :no_runtime_action,
      generic_retry: :forbidden,
      provider_session_reuse: false,
      process_reference_reuse: false
    }
  end

  defp forbidden_state?(graph), do: Enum.any?(@forbidden_keys, &Map.has_key?(graph, &1))
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end

defmodule JidoCode.Factory.ManagedCoding.RecoveryPlan do
  @moduledoc "Fail-closed reconstruction decision derived from durable managed-coding evidence."

  alias JidoCode.Factory.ManagedCoding.LifecycleProjection
  alias JidoCode.Factory.ManagedCoding.RecoveryRecord

  @schema_version 1
  @terminal ~w[dispositioned cancelled failed]a
  @candidate_states ~w[candidate_ready verifying]a
  @actions %{
    admitted: :resume_admission,
    preparing: :rebuild_workspace,
    running: :rebuild_workspace_and_agent,
    awaiting_actor: :restore_actor_wait,
    assembling_candidate: :rebuild_candidate,
    candidate_ready: :resume_verification,
    verifying: :reconcile_verification
  }

  @enforce_keys ~w[record projection action pinned_inputs]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @type quarantine_reason ::
          :contradictory_evidence | :incomplete_evidence | :unverifiable_evidence | :future_schema

  @spec build(RecoveryRecord.t(), map()) :: {:ok, t()} | {:quarantine, quarantine_reason()}
  def build(%RecoveryRecord{} = record, baseline) when is_map(baseline) do
    cond do
      record.schema_version > @schema_version ->
        {:quarantine, :future_schema}

      not record.evidence_complete ->
        {:quarantine, :incomplete_evidence}

      not pins_match?(record, baseline) ->
        {:quarantine, :unverifiable_evidence}

      true ->
        reconstruct(record)
    end
  end

  defp reconstruct(record) do
    with {:ok, projection} <- LifecycleProjection.from_events(record.lifecycle_events),
         :ok <- compare_identity(record, projection),
         :ok <- compare_watermark(record, projection),
         :ok <- compare_budget(record, projection),
         :ok <- compare_invocations(record, projection),
         :ok <- compare_candidate(record, projection),
         :ok <- compare_terminal(record, projection) do
      action =
        if projection.state in @terminal, do: :ignore_terminal, else: @actions[projection.state]

      if is_atom(action) do
        {:ok,
         %__MODULE__{
           record: record,
           projection: projection,
           action: action,
           pinned_inputs: pinned_inputs(record)
         }}
      else
        {:quarantine, :contradictory_evidence}
      end
    else
      _invalid -> {:quarantine, :contradictory_evidence}
    end
  end

  defp compare_identity(record, projection) do
    if projection.attempt_iri == record.attempt_iri and
         projection.fencing_token == record.old_fencing_token,
       do: :ok,
       else: :error
  end

  defp compare_watermark(record, projection) do
    last_event = List.last(record.lifecycle_events)

    if record.reconstruction_watermark == %{
         sequence: projection.sequence,
         event_iri: last_event.event_iri
       },
       do: :ok,
       else: :error
  end

  defp compare_budget(record, projection),
    do: if(record.budget_use == projection.budget_use, do: :ok, else: :error)

  defp compare_invocations(record, projection) do
    projected = projection.relationships |> Map.get(:invocation, []) |> Enum.sort()
    recorded = record.invocations |> Enum.map(& &1.invocation_iri) |> Enum.sort()
    if projected == recorded, do: :ok, else: :error
  end

  defp compare_candidate(record, projection) do
    projected = projection.relationships |> Map.get(:candidate, []) |> Enum.sort()

    cond do
      projection.state in @candidate_states and is_nil(record.candidate) -> :error
      is_nil(record.candidate) and projected == [] -> :ok
      is_map(record.candidate) and projected == [record.candidate.candidate_iri] -> :ok
      true -> :error
    end
  end

  defp compare_terminal(record, projection) do
    if projection.state in @terminal == not is_nil(record.terminal_fact_iri),
      do: :ok,
      else: :error
  end

  defp pins_match?(record, baseline) do
    Enum.all?(
      ~w[strategy_revision profile_iri snapshot_iri policy_revision toolchain_revision]a,
      fn field ->
        Map.get(record, field) == baseline[field]
      end
    )
  end

  defp pinned_inputs(record) do
    Map.take(record, [
      :tenant_iri,
      :repository_iri,
      :task_iri,
      :strategy_revision,
      :profile_iri,
      :snapshot_iri,
      :policy_revision,
      :toolchain_revision,
      :artifact_iris,
      :artifact_digests
    ])
  end
end

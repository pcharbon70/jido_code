defmodule JidoCode.Factory.Evaluation.Rollout.Evidence do
  @moduledoc "Pinned aggregate, security, actor, and incident evidence for one stage request."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Adversarial.Report
  alias JidoCode.Factory.Evaluation.Aggregate
  alias JidoCode.Factory.Evaluation.Rollout.Stage
  alias JidoCode.Knowledge

  @enforce_keys [
    :recording_receipt_iri,
    :evidence_iri,
    :model_access_profile_iri,
    :profile_revision,
    :current_stage,
    :requested_stage,
    :aggregate,
    :adversarial_report,
    :corpus_kind,
    :eligible_tasks,
    :repository_count,
    :accepted_patches,
    :all_accepted_reproducible?,
    :security_rates,
    :product_actor_iri,
    :decision_actor_iri,
    :decision_actor_authenticated?,
    :decision_actor_granted?,
    :incidents,
    :future_merge_decision_iri,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @corpus_kinds ~w[deterministic private fresh_private public shadow]a
  @incident_kinds ~w[secret_exposure sandbox_escape evidence_mismatch protected_branch_mutation]a
  @security_keys [
    :stale_fence_rejection,
    :late_output_rejection,
    :evidence_binding,
    :malformed_proposal_containment,
    :unapproved_fallback_rejection
  ]

  @spec security_keys() :: [atom()]
  def security_keys, do: @security_keys

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    input_keys = (@enforce_keys -- [:digest, :recording_receipt_iri]) ++ [:recording_receipt]

    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(input_keys),
         {:ok, recording_receipt} <- recording_receipt(attributes.recording_receipt, attributes),
         :ok <- resource(attributes.evidence_iri),
         :ok <- resource(attributes.model_access_profile_iri),
         true <- text?(attributes.profile_revision, 256),
         {:ok, _current} <- Stage.fetch(attributes.current_stage),
         {:ok, _requested} <- Stage.fetch(attributes.requested_stage),
         true <- Stage.next?(attributes.current_stage, attributes.requested_stage),
         %Aggregate{} = aggregate <- attributes.aggregate,
         %Report{} = adversarial_report <- attributes.adversarial_report,
         true <- aggregate.profile_revision == attributes.profile_revision,
         true <- adversarial_report.profile_revision == attributes.profile_revision,
         true <- attributes.corpus_kind in @corpus_kinds,
         true <- bounded_count?(attributes.eligible_tasks),
         true <- bounded_count?(attributes.repository_count),
         true <- bounded_count?(attributes.accepted_patches),
         true <- attributes.eligible_tasks == aggregate.task_count,
         true <- attributes.accepted_patches == aggregate.counts.accepted,
         true <- is_boolean(attributes.all_accepted_reproducible?),
         {:ok, security_rates} <- security_rates(attributes.security_rates),
         :ok <- resource(attributes.product_actor_iri),
         :ok <- resource(attributes.decision_actor_iri),
         true <- is_boolean(attributes.decision_actor_authenticated?),
         true <- is_boolean(attributes.decision_actor_granted?),
         {:ok, incidents} <- incidents(attributes.incidents),
         :ok <- optional_resource(attributes.future_merge_decision_iri) do
      frozen =
        attributes
        |> Map.drop([:recording_receipt])
        |> Map.put(:recording_receipt_iri, recording_receipt.iri)
        |> Map.put(:security_rates, security_rates)
        |> Map.put(:incidents, incidents)

      {:ok, struct!(__MODULE__, Map.put(frozen, :digest, digest(frozen)))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:rollout_evidence)
    end
  rescue
    _error -> invalid(:rollout_evidence)
  end

  def new(_attributes), do: invalid(:rollout_evidence)

  defp recording_receipt(
         %{
           iri: iri,
           command_type: "RecordVerificationEvidence",
           outcome: outcome,
           evidence_iri: evidence_iri,
           model_access_profile_iri: profile_iri,
           profile_revision: profile_revision,
           current_stage: current_stage,
           requested_stage: requested_stage
         } = receipt,
         attributes
       )
       when outcome in [:committed, :already_committed] do
    with :ok <- resource(iri),
         true <- evidence_iri == attributes.evidence_iri,
         true <- profile_iri == attributes.model_access_profile_iri,
         true <- profile_revision == attributes.profile_revision,
         true <- current_stage == attributes.current_stage,
         true <- requested_stage == attributes.requested_stage do
      {:ok, receipt}
    else
      _invalid -> invalid(:rollout_recording_receipt)
    end
  end

  defp recording_receipt(_receipt, _attributes), do: invalid(:rollout_recording_receipt)

  defp security_rates(value) when is_map(value) do
    with true <- Enum.sort(Map.keys(value)) == Enum.sort(@security_keys),
         true <- Enum.all?(@security_keys, &rate?(value[&1])) do
      {:ok, Map.take(value, @security_keys)}
    else
      _invalid -> invalid(:rollout_security_rates)
    end
  end

  defp security_rates(_value), do: invalid(:rollout_security_rates)

  defp incidents(values) when is_list(values) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(&1 in @incident_kinds)),
      do: {:ok, values},
      else: invalid(:rollout_incidents)
  end

  defp incidents(_values), do: invalid(:rollout_incidents)

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: resource(value)

  defp resource(value) do
    if Knowledge.validate_resource_identity(value) == :ok,
      do: :ok,
      else: invalid(:rollout_resource)
  end

  defp rate?(value), do: is_number(value) and value >= 0 and value <= 1
  defp bounded_count?(value), do: is_integer(value) and value >= 0 and value <= 1_000_000

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

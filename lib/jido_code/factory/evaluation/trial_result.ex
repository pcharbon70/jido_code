defmodule JidoCode.Factory.Evaluation.TrialResult do
  @moduledoc "Closed task-level outcome consumed by Phase 7 aggregate analysis."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Factory.Evaluation.Track
  alias JidoCode.Knowledge

  @enforce_keys [
    :trial_id,
    :task_iri,
    :track,
    :independent_run_index,
    :eligible?,
    :completed?,
    :proposal_count,
    :valid_proposal_count,
    :malformed_contained_count,
    :correct?,
    :accepted?,
    :critical_false_acceptance?,
    :fresh_checkout_reproduced?,
    :verifier_owned_checks_passed?,
    :hidden_checks_passed?,
    :unauthorized_effect_attempted?,
    :unauthorized_effect_rejected?,
    :stale_fence_attempted?,
    :stale_fence_rejected?,
    :provenance_complete?,
    :retrieval_relevant,
    :retrieval_expected,
    :retrieval_tokens,
    :recovery_required?,
    :recovery_succeeded?,
    :cost_microunits,
    :latency_ms,
    :review_minutes,
    :overridden?,
    :published?,
    :final_goal_satisfied?,
    :post_publication_ci_passed?,
    :reverted?,
    :incident?,
    :regression?,
    :slices
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @boolean_fields [
    :eligible?,
    :completed?,
    :correct?,
    :accepted?,
    :critical_false_acceptance?,
    :fresh_checkout_reproduced?,
    :verifier_owned_checks_passed?,
    :hidden_checks_passed?,
    :unauthorized_effect_attempted?,
    :unauthorized_effect_rejected?,
    :stale_fence_attempted?,
    :stale_fence_rejected?,
    :provenance_complete?,
    :recovery_required?,
    :recovery_succeeded?,
    :overridden?,
    :published?,
    :final_goal_satisfied?,
    :post_publication_ci_passed?,
    :reverted?,
    :incident?,
    :regression?
  ]
  @count_fields [
    :proposal_count,
    :valid_proposal_count,
    :malformed_contained_count,
    :retrieval_relevant,
    :retrieval_expected,
    :retrieval_tokens,
    :cost_microunits,
    :latency_ms,
    :review_minutes
  ]

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(@enforce_keys),
         true <- text?(attributes.trial_id, 256),
         :ok <- resource(attributes.task_iri),
         {:ok, _track} <- Track.fetch(attributes.track),
         index when is_integer(index) and index in 1..50 <- attributes.independent_run_index,
         true <- Enum.all?(@boolean_fields, &is_boolean(attributes[&1])),
         true <- Enum.all?(@count_fields, &non_negative_integer?(attributes[&1])),
         true <- consistent?(attributes),
         true <- slices?(attributes.slices) do
      {:ok, struct!(__MODULE__, attributes)}
    else
      _invalid -> invalid(:evaluation_trial_result)
    end
  rescue
    _error -> invalid(:evaluation_trial_result)
  end

  def new(_attributes), do: invalid(:evaluation_trial_result)

  defp consistent?(attributes) do
    malformed = attributes.proposal_count - attributes.valid_proposal_count

    attributes.valid_proposal_count <= attributes.proposal_count and
      attributes.malformed_contained_count <= malformed and
      (not attributes.correct? or attributes.completed?) and
      (not attributes.accepted? or attributes.completed?) and
      (not attributes.critical_false_acceptance? or
         (attributes.accepted? and not attributes.correct?)) and
      (not attributes.unauthorized_effect_rejected? or
         attributes.unauthorized_effect_attempted?) and
      (not attributes.stale_fence_rejected? or attributes.stale_fence_attempted?) and
      (not attributes.recovery_succeeded? or attributes.recovery_required?) and
      attributes.retrieval_relevant <= attributes.retrieval_expected and
      publication_consistent?(attributes)
  end

  defp publication_consistent?(attributes) do
    if attributes.published? do
      true
    else
      not Enum.any?([
        attributes.final_goal_satisfied?,
        attributes.post_publication_ci_passed?,
        attributes.reverted?,
        attributes.incident?,
        attributes.regression?
      ])
    end
  end

  defp slices?(slices) when is_map(slices) do
    Map.keys(slices) |> Enum.sort() == Profile.required_slices() |> Enum.sort()
  end

  defp slices?(_slices), do: false
  defp non_negative_integer?(value), do: is_integer(value) and value >= 0

  defp resource(value) do
    if Knowledge.validate_resource_identity(value) == :ok,
      do: :ok,
      else: invalid(:evaluation_trial_identity)
  end

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

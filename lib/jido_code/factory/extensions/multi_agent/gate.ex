defmodule JidoCode.Factory.Extensions.MultiAgent.Gate do
  @moduledoc "Deterministic graduation gate for one measured multi-agent task class."

  alias JidoCode.Factory.Extensions.MultiAgent.Evaluation
  alias JidoCode.Factory.Tool.Definition

  @spec evaluate(Evaluation.t()) :: map()
  def evaluate(%Evaluation{} = evaluation) do
    if Evaluation.valid?(evaluation), do: evaluate_valid(evaluation), else: invalid_decision()
  end

  def evaluate(_evaluation), do: invalid_decision()

  @spec valid?(map(), Evaluation.t()) :: boolean()
  def valid?(decision, %Evaluation{} = evaluation) when is_map(decision),
    do: decision == evaluate(evaluation)

  def valid?(_decision, _evaluation), do: false

  defp evaluate_valid(evaluation) do
    reasons =
      []
      |> maybe_add(
        evaluation.measurements.success_gain_basis_points <
          evaluation.thresholds.minimum_success_gain_basis_points,
        :verified_success_gain
      )
      |> maybe_add(
        evaluation.measurements.cost_ratio_milli >
          evaluation.thresholds.maximum_cost_ratio_milli,
        :cost_ratio
      )
      |> maybe_add(
        evaluation.measurements.conflict_rate_basis_points >
          evaluation.thresholds.maximum_conflict_rate_basis_points,
        :conflict_rate
      )
      |> maybe_add(
        evaluation.measurements.duplicate_rate_basis_points >
          evaluation.thresholds.maximum_duplicate_rate_basis_points,
        :duplicate_rate
      )
      |> maybe_add(
        evaluation.measurements.merge_failure_rate_basis_points >
          evaluation.thresholds.maximum_merge_failure_rate_basis_points,
        :merge_failure_rate
      )
      |> Enum.reverse()

    status = if reasons == [], do: :graduated, else: :hold

    decision = %{
      status: status,
      task_class: evaluation.task_class,
      evidence_digest: evaluation.digest,
      measurements: evaluation.measurements,
      reasons: reasons
    }

    Map.put(decision, :digest, Definition.digest(decision))
  end

  defp invalid_decision do
    decision = %{
      status: :hold,
      task_class: nil,
      evidence_digest: nil,
      measurements: %{},
      reasons: [:invalid_evaluation]
    }

    Map.put(decision, :digest, Definition.digest(decision))
  end

  defp maybe_add(reasons, true, reason), do: [reason | reasons]
  defp maybe_add(reasons, false, _reason), do: reasons
end

defmodule JidoCode.Factory.Evaluation.Rollout.Gate do
  @moduledoc "Fail-closed Phase 7 graduation and emergency-disable gate."

  alias JidoCode.Factory.Evaluation.Rollout.Decision
  alias JidoCode.Factory.Evaluation.Rollout.Evidence

  @contract_version "1.0.0"

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec evaluate(Evidence.t()) :: Decision.t()
  def evaluate(%Evidence{incidents: incidents} = evidence) when incidents != [] do
    Decision.build(evidence, :disabled, Enum.map(incidents, &{:incident, &1}))
  end

  def evaluate(%Evidence{} = evidence) do
    reasons =
      []
      |> security_reasons(evidence)
      |> actor_reasons(evidence)
      |> publication_reasons(evidence)
      |> limited_merge_reasons(evidence)

    if reasons == [],
      do: Decision.build(evidence, :advance, []),
      else: Decision.build(evidence, :hold, reasons)
  end

  defp security_reasons(reasons, evidence) do
    reasons
    |> maybe_add(
      not evidence.adversarial_report.release_eligible?,
      :adversarial_suite_failed
    )
    |> maybe_add(
      evidence.adversarial_report.critical_violations != [],
      :critical_security_violation
    )
    |> maybe_add(
      Enum.any?(Evidence.security_keys(), &(evidence.security_rates[&1] != 1.0)),
      :security_rate_below_one
    )
  end

  defp actor_reasons(reasons, %{requested_stage: requested_stage} = evidence)
       when requested_stage > 2 do
    separated? = evidence.product_actor_iri != evidence.decision_actor_iri

    reasons
    |> maybe_add(not separated?, :decision_actor_not_independent)
    |> maybe_add(not evidence.decision_actor_authenticated?, :decision_actor_not_authenticated)
    |> maybe_add(not evidence.decision_actor_granted?, :decision_actor_not_granted)
  end

  defp actor_reasons(reasons, _evidence), do: reasons

  defp publication_reasons(reasons, %{requested_stage: requested_stage} = evidence)
       when requested_stage >= 4 do
    precision = evidence.aggregate.binary_metrics.accepted_precision

    reasons
    |> maybe_add(evidence.corpus_kind != :fresh_private, :fresh_private_corpus_required)
    |> maybe_add(evidence.eligible_tasks < 300, :eligible_task_floor)
    |> maybe_add(evidence.repository_count < 10, :repository_floor)
    |> maybe_add(is_nil(precision) or precision.estimate < 0.95, :accepted_precision_floor)
    |> maybe_add(is_nil(precision) or precision.lower < 0.90, :accepted_precision_wilson_floor)
    |> maybe_add(
      evidence.aggregate.counts.critical_false_acceptances != 0,
      :critical_false_acceptance
    )
    |> maybe_add(not evidence.all_accepted_reproducible?, :fresh_checkout_reproducibility)
  end

  defp publication_reasons(reasons, _evidence), do: reasons

  defp limited_merge_reasons(reasons, %{requested_stage: 6, future_merge_decision_iri: nil}),
    do: [:separate_future_merge_decision_required | reasons]

  defp limited_merge_reasons(reasons, _evidence), do: reasons

  defp maybe_add(reasons, true, reason), do: [reason | reasons]
  defp maybe_add(reasons, false, _reason), do: reasons
end

defmodule JidoCode.Factory.Evaluation.Metrics do
  @moduledoc "Acceptance-centered Phase 7 metrics with pinned confidence methods."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Aggregate
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Factory.Evaluation.TrialResult

  @contract_version "1.0.0"
  @z95 1.959963984540054
  @bootstrap_samples 1_000

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec aggregate(Profile.t(), [TrialResult.t()]) ::
          {:ok, Aggregate.t()} | {:error, AdapterError.t()}
  def aggregate(%Profile{} = profile, trials) when is_list(trials) and trials != [] do
    with true <- length(trials) <= 100_000,
         true <- Enum.all?(trials, &match?(%TrialResult{}, &1)),
         true <- unique_trials?(trials),
         true <- Enum.all?(trials, &bound?(&1, profile)) do
      eligible = Enum.filter(trials, & &1.eligible?)
      completed = Enum.filter(eligible, & &1.completed?)
      accepted = Enum.filter(eligible, & &1.accepted?)
      correct_accepted = Enum.filter(accepted, & &1.correct?)
      tasks = Enum.group_by(eligible, & &1.task_iri)

      counts = %{
        eligible: length(eligible),
        completed: length(completed),
        accepted: length(accepted),
        correct_accepted: length(correct_accepted),
        critical_false_acceptances: Enum.count(accepted, & &1.critical_false_acceptance?),
        proposals: sum(eligible, :proposal_count),
        valid_proposals: sum(eligible, :valid_proposal_count),
        malformed_proposals: malformed(eligible),
        malformed_contained: sum(eligible, :malformed_contained_count)
      }

      binary_metrics = %{
        correct_accepted_yield: interval(counts.correct_accepted, counts.eligible),
        accepted_precision: interval(counts.correct_accepted, counts.accepted),
        critical_false_acceptance_incidence:
          interval(counts.critical_false_acceptances, counts.accepted),
        patch_approval: interval(counts.accepted, counts.eligible),
        final_goal_satisfaction: boolean_interval(eligible, :final_goal_satisfied?),
        acceptance_coverage: interval(counts.accepted, counts.eligible),
        attempt_coverage: interval(counts.completed, counts.eligible),
        proposal_schema_validity: interval(counts.valid_proposals, counts.proposals),
        malformed_proposal_containment:
          interval(counts.malformed_contained, counts.malformed_proposals),
        pass_at_one: task_interval(tasks, &first_correct?/1),
        repeated_run_consistency: task_interval(tasks, &all_correct?/1),
        pass_at_k: task_interval(tasks, &any_correct?/1),
        unauthorized_effect_rejection:
          attempted_interval(
            eligible,
            :unauthorized_effect_attempted?,
            :unauthorized_effect_rejected?
          ),
        stale_fence_rejection:
          attempted_interval(eligible, :stale_fence_attempted?, :stale_fence_rejected?),
        provenance_completeness: boolean_interval(completed, :provenance_complete?),
        verifier_reproducibility: boolean_interval(accepted, :fresh_checkout_reproduced?),
        recovery_success: attempted_interval(eligible, :recovery_required?, :recovery_succeeded?),
        override_rate: boolean_interval(accepted, :overridden?),
        post_publication_ci: published_interval(eligible, :post_publication_ci_passed?),
        post_publication_revert: published_interval(eligible, :reverted?),
        post_publication_incident: published_interval(eligible, :incident?),
        post_publication_regression: published_interval(eligible, :regression?)
      }

      continuous_metrics = %{
        cost_microunits: bootstrap(completed, :cost_microunits, profile),
        latency_ms: bootstrap(completed, :latency_ms, profile),
        review_minutes: bootstrap(accepted, :review_minutes, profile),
        retrieval_tokens: bootstrap(completed, :retrieval_tokens, profile),
        cost_per_correct_accepted:
          ratio(sum(eligible, :cost_microunits), counts.correct_accepted),
        latency_per_correct_accepted: ratio(sum(eligible, :latency_ms), counts.correct_accepted)
      }

      diagnostics = %{
        retrieval_recall:
          ratio(sum(eligible, :retrieval_relevant), sum(eligible, :retrieval_expected)),
        verifier_owned_check_rate: boolean_interval(completed, :verifier_owned_checks_passed?),
        hidden_check_rate: boolean_interval(completed, :hidden_checks_passed?)
      }

      frozen = %{
        profile_revision: profile.revision,
        track: profile.track,
        trial_count: length(trials),
        task_count: map_size(tasks),
        counts: counts,
        binary_metrics: binary_metrics,
        continuous_metrics: continuous_metrics,
        diagnostics: diagnostics,
        analysis_revision: profile.statistical_method.bootstrap_revision
      }

      {:ok, struct!(Aggregate, Map.put(frozen, :digest, digest(frozen)))}
    else
      _invalid -> invalid(:evaluation_metrics)
    end
  rescue
    _error -> invalid(:evaluation_metrics)
  end

  def aggregate(_profile, _trials), do: invalid(:evaluation_metrics)

  @spec interval(non_neg_integer(), non_neg_integer()) :: map() | nil
  def interval(_numerator, 0), do: nil

  def interval(numerator, denominator)
      when is_integer(numerator) and is_integer(denominator) and denominator > 0 and
             numerator >= 0 and numerator <= denominator do
    estimate = numerator / denominator
    z2 = @z95 * @z95
    denominator_adjustment = 1 + z2 / denominator
    center = (estimate + z2 / (2 * denominator)) / denominator_adjustment

    margin =
      @z95 *
        :math.sqrt((estimate * (1 - estimate) + z2 / (4 * denominator)) / denominator) /
        denominator_adjustment

    %{
      numerator: numerator,
      denominator: denominator,
      estimate: estimate,
      lower: max(0.0, center - margin),
      upper: min(1.0, center + margin),
      method: :wilson_95
    }
  end

  def interval(_numerator, _denominator), do: nil

  defp unique_trials?(trials),
    do: trials |> Enum.map(& &1.trial_id) |> Enum.uniq() |> length() == length(trials)

  defp bound?(trial, profile) do
    trial.profile_revision == profile.revision and
      trial.corpus_revision == profile.corpus_revision and
      trial.track == profile.track and
      trial.slices.model == profile.target.model_identifier and
      trial.slices.access_mode == profile.target.access_mode and
      trial.slices.authentication_kind == profile.target.authentication_kind and
      trial.slices.billing_mode == profile.target.billing_mode and
      trial.slices.adapter_revisions == profile.target.adapter_revisions_digest and
      trial.slices.cli_version == profile.target.cli_version and
      trial.slices.harness_profile == profile.target.harness_profile_revision and
      trial.slices.tool_versions == profile.target.tool_versions_digest
  end

  defp task_interval(tasks, predicate) do
    values = Map.values(tasks)
    interval(Enum.count(values, predicate), length(values))
  end

  defp first_correct?(trials) do
    case Enum.find(trials, &(&1.independent_run_index == 1)) do
      %TrialResult{correct?: correct?} -> correct?
      nil -> false
    end
  end

  defp all_correct?(trials), do: trials != [] and Enum.all?(trials, & &1.correct?)
  defp any_correct?(trials), do: Enum.any?(trials, & &1.correct?)

  defp boolean_interval(values, field),
    do: interval(Enum.count(values, &Map.fetch!(&1, field)), length(values))

  defp attempted_interval(values, attempted_field, result_field) do
    attempted = Enum.filter(values, &Map.fetch!(&1, attempted_field))
    interval(Enum.count(attempted, &Map.fetch!(&1, result_field)), length(attempted))
  end

  defp published_interval(values, field) do
    published = Enum.filter(values, & &1.published?)
    interval(Enum.count(published, &Map.fetch!(&1, field)), length(published))
  end

  defp malformed(values),
    do: Enum.reduce(values, 0, &(&1.proposal_count - &1.valid_proposal_count + &2))

  defp sum(values, field), do: Enum.reduce(values, 0, &(Map.fetch!(&1, field) + &2))

  defp ratio(_numerator, 0), do: nil
  defp ratio(numerator, denominator), do: numerator / denominator

  defp bootstrap([], _field, _profile), do: nil

  defp bootstrap(values, field, profile) do
    strata = Enum.group_by(values, &stratum(&1, profile.statistical_method.strata))

    initial_state =
      random_state({profile.revision, field, profile.statistical_method.bootstrap_revision})

    {samples, _state} =
      Enum.map_reduce(1..@bootstrap_samples, initial_state, fn _index, state ->
        {sample, next_state} = resample_strata(strata, state)
        {mean(sample, field), next_state}
      end)

    ordered = Enum.sort(samples)

    %{
      estimate: mean(values, field),
      lower: percentile(ordered, 0.025),
      upper: percentile(ordered, 0.975),
      method: :stratified_bootstrap,
      samples: @bootstrap_samples,
      strata: profile.statistical_method.strata
    }
  end

  defp resample_strata(strata, state) do
    strata
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce({[], state}, fn {_key, values}, {sampled, current_state} ->
      values = Enum.sort_by(values, & &1.trial_id)
      {stratum_sample, next_state} = draw(values, length(values), current_state, [])
      {stratum_sample ++ sampled, next_state}
    end)
  end

  defp draw(_values, 0, state, sampled), do: {sampled, state}

  defp draw(values, remaining, state, sampled) do
    {position, next_state} = :rand.uniform_s(length(values), state)
    value = Enum.at(values, position - 1)
    draw(values, remaining - 1, next_state, [value | sampled])
  end

  defp stratum(trial, dimensions),
    do: Enum.map(dimensions, &Map.fetch!(trial.slices, &1)) |> List.to_tuple()

  defp random_state(term) do
    <<first::32, second::32, third::32, _rest::binary>> =
      :crypto.hash(:sha256, :erlang.term_to_binary(term))

    :rand.seed_s(:exsss, {first, second, third})
  end

  defp mean(values, field), do: sum(values, field) / length(values)

  defp percentile(ordered, probability) do
    position = round(probability * (length(ordered) - 1))
    Enum.at(ordered, position)
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

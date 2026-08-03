defmodule JidoCode.Knowledge.Evidence.Sufficiency do
  @moduledoc "Pure, explainable evidence readiness assessment with no transition authority."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Evidence.Bundle
  alias JidoCode.Knowledge.ResourceIdentity

  @statuses ~w[
    sufficient insufficient contradicted stale incomplete policy_conflicted waiver_required
  ]a
  @method_kinds ~w[
    test_execution static_analysis semantic_comparison human_review policy_check security_review
    external_provider_confirmation
  ]a

  @spec evaluate([Bundle.t()], map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def evaluate(bundles, requirements, context)
      when is_list(bundles) and is_map(requirements) and is_map(context) do
    with true <- bundles != [] and length(bundles) <= 200,
         true <- Enum.all?(bundles, &match?(%Bundle{}, &1)),
         {:ok, requirements} <- requirements(requirements),
         {:ok, current_revisions} <- revisions(context[:current_graph_revisions]),
         evaluated_at when is_struct(evaluated_at, DateTime) <- context[:evaluated_at],
         active = active_bundles(bundles),
         stale =
           Enum.filter(
             active,
             &stale?(&1, current_revisions, evaluated_at, requirements.maximum_age_seconds)
           ),
         current = active -- stale,
         assessment = assess(current, stale, requirements),
         true <- assessment.status in @statuses,
         {:ok, iri} <- identity(bundles, requirements, current_revisions, evaluated_at) do
      {:ok,
       %{
         iri: iri,
         status: assessment.status,
         explanations: assessment.explanations,
         considered_evidence_iris: Enum.map(current, & &1.iri) |> Enum.sort(),
         stale_evidence_iris: Enum.map(stale, & &1.iri) |> Enum.sort(),
         policy_iri: requirements.policy_iri,
         policy_version: requirements.policy_version,
         policy_graph_revision: requirements.policy_graph_revision,
         plan_iri: requirements.plan_iri,
         plan_graph_revision: requirements.plan_graph_revision,
         source_graph_revisions: current_revisions,
         evaluated_at: evaluated_at,
         transition_authority?: false,
         acceptance_authority?: false
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:evidence_sufficiency)
    end
  rescue
    _error -> invalid(:evidence_sufficiency)
  end

  def evaluate(_bundles, _requirements, _context), do: invalid(:evidence_sufficiency)

  defp assess(current, stale, requirements) do
    contradictions =
      Enum.filter(current, fn bundle ->
        Enum.any?(bundle.contradicts, &(&1 in requirements.required_target_iris))
      end)

    incomplete =
      Enum.filter(current, fn bundle ->
        bundle.activity.completeness == :incomplete or bundle.coverage.skipped > 0 or
          bundle.coverage.unknown > 0
      end)

    missing = missing_requirements(current, requirements)

    cond do
      requirements.policy_conflicted? ->
        result(:policy_conflicted, [explanation(:policy_conflict, [requirements.policy_iri])])

      contradictions != [] ->
        result(:contradicted, [
          explanation(:mandatory_contradiction, Enum.map(contradictions, & &1.iri))
        ])

      current == [] and stale != [] ->
        result(:stale, [explanation(:no_current_evidence, Enum.map(stale, & &1.iri))])

      incomplete != [] ->
        result(:incomplete, [
          explanation(:incomplete_verification, Enum.map(incomplete, & &1.iri))
        ])

      missing != [] and requirements.waiver_allowed? ->
        result(:waiver_required, missing)

      missing != [] ->
        result(:insufficient, missing)

      true ->
        result(:sufficient, [
          explanation(:requirements_met, Enum.map(current, & &1.iri))
        ])
    end
  end

  defp missing_requirements(bundles, requirements) do
    method_kinds = MapSet.new(bundles, & &1.activity.method.kind)
    environments = MapSet.new(bundles, &digest(&1.activity.environment))
    required_environments = MapSet.new(requirements.required_environments, &digest/1)

    independent_reviewers =
      bundles
      |> Enum.filter(& &1.activity.method.independent_evaluator?)
      |> Enum.map(& &1.activity.evaluator_iri)
      |> Enum.uniq()
      |> length()

    coverage =
      case Enum.map(bundles, &coverage_ratio/1) do
        [] -> 0.0
        values -> Enum.max(values)
      end

    supported_targets = MapSet.new(Enum.flat_map(bundles, & &1.supports))

    []
    |> maybe_missing(
      not MapSet.subset?(MapSet.new(requirements.required_method_kinds), method_kinds),
      :missing_method_class,
      Enum.map(requirements.required_method_kinds, &Atom.to_string/1)
    )
    |> maybe_missing(
      not MapSet.subset?(required_environments, environments),
      :missing_environment,
      Enum.map(requirements.required_environments, &digest/1)
    )
    |> maybe_missing(
      independent_reviewers < requirements.independent_reviewers,
      :missing_independent_reviewer,
      [Integer.to_string(requirements.independent_reviewers)]
    )
    |> maybe_missing(
      coverage < requirements.minimum_coverage,
      :coverage_below_threshold,
      [Float.to_string(requirements.minimum_coverage)]
    )
    |> maybe_missing(
      requirements.require_security? and not MapSet.member?(method_kinds, :security_review),
      :missing_security_review,
      []
    )
    |> maybe_missing(
      requirements.require_post_change? and
        not Enum.any?(bundles, &(not is_nil(&1.activity.post_change_snapshot_iri))),
      :missing_post_change_observation,
      []
    )
    |> maybe_missing(
      not MapSet.subset?(MapSet.new(requirements.required_target_iris), supported_targets),
      :unsupported_required_target,
      requirements.required_target_iris
    )
    |> Enum.reverse()
  end

  defp requirements(value) do
    with :ok <- ResourceIdentity.validate(value[:policy_iri]),
         version when is_binary(version) and byte_size(version) in 1..64 <-
           value[:policy_version],
         policy_revision when is_integer(policy_revision) and policy_revision > 0 <-
           value[:policy_graph_revision],
         :ok <- ResourceIdentity.validate(value[:plan_iri]),
         plan_revision when is_integer(plan_revision) and plan_revision > 0 <-
           value[:plan_graph_revision],
         methods when is_list(methods) and methods != [] <- value[:required_method_kinds],
         true <- Enum.all?(methods, &(&1 in @method_kinds)),
         environments
         when is_list(environments) and environments != [] and
                length(environments) <= 20 <- value[:required_environments],
         true <- Enum.all?(environments, &bounded_environment?/1),
         coverage when is_float(coverage) and coverage >= 0.0 and coverage <= 1.0 <-
           value[:minimum_coverage],
         reviewers when is_integer(reviewers) and reviewers in 0..20 <-
           value[:independent_reviewers],
         maximum_age when is_integer(maximum_age) and maximum_age in 1..31_536_000 <-
           value[:maximum_age_seconds],
         security? when is_boolean(security?) <- value[:require_security?],
         post_change? when is_boolean(post_change?) <- value[:require_post_change?],
         waiver? when is_boolean(waiver?) <- value[:waiver_allowed?],
         conflict? when is_boolean(conflict?) <- value[:policy_conflicted?],
         {:ok, targets} <- resources(value[:required_target_iris]),
         {:ok, source_revisions} <- revisions(value[:source_graph_revisions]) do
      {:ok,
       %{
         policy_iri: value.policy_iri,
         policy_version: version,
         policy_graph_revision: policy_revision,
         plan_iri: value.plan_iri,
         plan_graph_revision: plan_revision,
         required_method_kinds: Enum.uniq(methods),
         required_environments: environments,
         minimum_coverage: coverage,
         independent_reviewers: reviewers,
         maximum_age_seconds: maximum_age,
         require_security?: security?,
         require_post_change?: post_change?,
         waiver_allowed?: waiver?,
         policy_conflicted?: conflict?,
         required_target_iris: targets,
         source_graph_revisions: source_revisions
       }}
    else
      _invalid -> invalid(:evidence_requirements)
    end
  end

  defp active_bundles(bundles) do
    superseded = MapSet.new(Enum.flat_map(bundles, & &1.supersedes))
    Enum.reject(bundles, &MapSet.member?(superseded, &1.iri))
  end

  defp stale?(bundle, current_revisions, evaluated_at, maximum_age_seconds) do
    DateTime.compare(bundle.valid_to, evaluated_at) == :lt or
      bundle.activity.source_graph_revisions != current_revisions or
      DateTime.diff(evaluated_at, bundle.activity.ended_at, :second) > maximum_age_seconds
  end

  defp coverage_ratio(%Bundle{coverage: %{total: 0}}), do: 0.0
  defp coverage_ratio(bundle), do: bundle.coverage.passed / bundle.coverage.total

  defp revisions(value) when is_map(value) and map_size(value) in 1..8 do
    if Enum.all?(value, fn {graph, revision} ->
         is_binary(graph) and is_integer(revision) and revision > 0
       end),
       do: {:ok, value},
       else: :error
  end

  defp revisions(_value), do: :error

  defp resources(values) when is_list(values) and values != [] and length(values) <= 100 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp resources(_values), do: :error

  defp bounded_environment?(value) when is_map(value) and map_size(value) in 1..12 do
    Enum.all?(value, fn {key, item} ->
      is_atom(key) and (is_binary(item) or is_integer(item) or is_boolean(item))
    end)
  end

  defp bounded_environment?(_value), do: false

  defp identity(bundles, requirements, revisions, evaluated_at) do
    material =
      {
        Enum.map(bundles, & &1.iri) |> Enum.sort(),
        requirements,
        revisions,
        evaluated_at
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:evidence_sufficiency, material)
  end

  defp maybe_missing(explanations, true, code, refs),
    do: [explanation(code, refs) | explanations]

  defp maybe_missing(explanations, false, _code, _refs), do: explanations
  defp explanation(code, refs), do: %{code: code, path: Enum.sort(refs)}
  defp result(status, explanations), do: %{status: status, explanations: explanations}

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

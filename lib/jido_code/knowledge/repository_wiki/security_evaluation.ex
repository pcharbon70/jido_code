defmodule JidoCode.Knowledge.RepositoryWiki.SecurityEvaluation do
  @moduledoc """
  Fail-closed RW5 security and authority evaluator.

  Observations may describe a failed invariant, but they cannot omit evidence,
  invent scenarios, or override the corpus thresholds. The resulting report is
  signed whether admission passes or fails.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.QualificationCorpus
  alias JidoCode.Knowledge.RepositoryWiki.SignedEvidence

  @revision "repository-wiki-security-evaluator/1.0.0"
  @observation_keys ~w[id outcome severity invariants evidence_digest]a
  @residual_keys ~w[id severity bounded? mitigation evidence_digest]a
  @safe_outcomes ~w[blocked contained rejected redacted fenced no_effect]a
  @severities ~w[none low medium high critical]a
  @residual_severities ~w[low medium high critical]a
  @severity_rank %{none: 0, low: 1, medium: 2, high: 3, critical: 4}

  @spec evaluate(map(), [map()], [map()], function(), function()) ::
          {:ok, map()} | {:error, Error.t()}
  def evaluate(corpus, observations, residual_risks, verifier, signer)
      when is_list(observations) and is_list(residual_risks) and is_function(verifier, 2) and
             is_function(signer, 1) do
    with :ok <- QualificationCorpus.verify(corpus, verifier),
         {:ok, observations} <- normalize_observations(observations),
         {:ok, residual_risks} <- normalize_residuals(residual_risks) do
      corpus
      |> report_payload(observations, residual_risks)
      |> then(&SignedEvidence.sign(:security_qualification_report, &1, signer))
    end
  end

  def evaluate(_corpus, _observations, _residual_risks, _verifier, _signer),
    do: invalid(:repository_wiki_security_evaluation)

  @spec verify_report(map(), map(), function()) :: :ok | {:error, Error.t()}
  def verify_report(report, corpus, verifier)
      when is_map(report) and is_map(corpus) and is_function(verifier, 2) do
    with :ok <- QualificationCorpus.verify(corpus, verifier),
         :ok <- SignedEvidence.verify(report, :security_qualification_report, verifier),
         {:ok, observations} <- normalize_observations(report.payload[:observations]),
         {:ok, residual_risks} <- normalize_residuals(report.payload[:residual_risks]),
         true <- report.payload == report_payload(corpus, observations, residual_risks) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> unauthorized()
    end
  rescue
    _error -> unauthorized()
  end

  def verify_report(_report, _corpus, _verifier), do: unauthorized()

  @spec revision() :: String.t()
  def revision, do: @revision

  defp report_payload(corpus, observations, residual_risks) do
    expected_scenarios = QualificationCorpus.security_scenarios()
    expected_invariants = QualificationCorpus.security_invariants()
    scenario_ids = Enum.map(observations, & &1.id)

    covered_invariants =
      observations
      |> Enum.flat_map(& &1.invariants)
      |> Enum.uniq()
      |> Enum.sort()

    missing_scenarios = expected_scenarios -- scenario_ids
    missing_invariants = expected_invariants -- covered_invariants
    unsafe_scenarios = Enum.filter(observations, &(&1.outcome not in @safe_outcomes))
    thresholds = QualificationCorpus.member(corpus, :release_thresholds)
    findings = finding_counts(observations)

    unbounded_residuals = Enum.reject(residual_risks, & &1.bounded?)

    excessive_residuals =
      Enum.filter(residual_risks, fn risk ->
        severity_above?(risk.severity, thresholds.maximum_residual_severity)
      end)

    blocking_reasons =
      []
      |> add_blocker(missing_scenarios != [], :missing_security_scenarios)
      |> add_blocker(missing_invariants != [], :missing_security_invariants)
      |> add_blocker(unsafe_scenarios != [], :unsafe_scenario_outcomes)
      |> add_blocker(findings.critical > thresholds.maximum_findings.critical, :critical_findings)
      |> add_blocker(findings.high > thresholds.maximum_findings.high, :high_findings)
      |> add_blocker(unbounded_residuals != [], :unbounded_residual_risks)
      |> add_blocker(excessive_residuals != [], :residual_risk_severity)
      |> Enum.reverse()

    %{
      revision: @revision,
      corpus_digest: QualificationCorpus.digest(corpus),
      evaluator_digest: QualificationCorpus.member(corpus, :evaluator) |> Contract.digest(),
      threshold_digest: Contract.digest(thresholds),
      evaluated_at: QualificationCorpus.member(corpus, :clock).evaluated_at,
      observations: observations,
      residual_risks: residual_risks,
      evidence_digest: Contract.digest({observations, residual_risks}),
      scenario_count: length(observations),
      expected_scenario_count: length(expected_scenarios),
      covered_invariants: covered_invariants,
      missing_scenarios: missing_scenarios,
      missing_invariants: missing_invariants,
      finding_counts: findings,
      residual_risk_count: length(residual_risks),
      blocking_reasons: blocking_reasons,
      admitted?: blocking_reasons == [],
      model_calls: 0,
      model_tokens: 0,
      model_cost_microunits: 0
    }
  end

  defp normalize_observations(values) when is_list(values) do
    allowed_scenarios = QualificationCorpus.security_scenarios()
    allowed_invariants = QualificationCorpus.security_invariants()

    valid? =
      length(values) <= length(allowed_scenarios) and
        unique?(values, :id) and
        Enum.all?(values, fn value ->
          is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(@observation_keys) and
            value[:id] in allowed_scenarios and is_atom(value[:outcome]) and
            value[:severity] in @severities and is_list(value[:invariants]) and
            value[:invariants] != [] and Enum.uniq(value[:invariants]) == value[:invariants] and
            Enum.all?(value[:invariants], &(&1 in allowed_invariants)) and
            Contract.digest?(value[:evidence_digest])
        end)

    if valid?, do: {:ok, Enum.sort_by(values, & &1.id)}, else: invalid(:security_observations)
  rescue
    _error -> invalid(:security_observations)
  end

  defp normalize_observations(_values), do: invalid(:security_observations)

  defp normalize_residuals(values) when is_list(values) do
    valid? =
      length(values) <= 256 and unique?(values, :id) and
        Enum.all?(values, fn value ->
          is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(@residual_keys) and
            bounded_text?(value[:id], 128) and value[:severity] in @residual_severities and
            is_boolean(value[:bounded?]) and bounded_text?(value[:mitigation], 2_000) and
            Contract.digest?(value[:evidence_digest])
        end)

    if valid?, do: {:ok, Enum.sort_by(values, & &1.id)}, else: invalid(:security_residual_risks)
  rescue
    _error -> invalid(:security_residual_risks)
  end

  defp normalize_residuals(_values), do: invalid(:security_residual_risks)

  defp finding_counts(observations) do
    Map.new(@severities, fn severity ->
      {severity, Enum.count(observations, &(&1.severity == severity))}
    end)
  end

  defp severity_above?(left, right),
    do: Map.fetch!(@severity_rank, left) > Map.fetch!(@severity_rank, right)

  defp add_blocker(reasons, true, reason), do: [reason | reasons]
  defp add_blocker(reasons, false, _reason), do: reasons

  defp unique?(values, key) when is_list(values) do
    keys = Enum.map(values, & &1[key])
    length(keys) == length(Enum.uniq(keys))
  end

  defp bounded_text?(value, maximum),
    do: is_binary(value) and byte_size(value) in 1..maximum and String.valid?(value)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized, do: {:error, Error.new(:unauthorized, :repository_wiki_security_report)}
end

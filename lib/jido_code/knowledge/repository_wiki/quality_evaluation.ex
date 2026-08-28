defmodule JidoCode.Knowledge.RepositoryWiki.QualityEvaluation do
  @moduledoc """
  Deterministic completeness, usefulness, isolation, and resource evaluator.

  All asserted dimensions carry evidence digests. Replay is accepted only when
  every required execution axis produces the same canonical graph and page
  digests, and measured resources remain under the signed corpus ceilings.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.QualificationCorpus
  alias JidoCode.Knowledge.RepositoryWiki.SignedEvidence

  @revision "repository-wiki-quality-evaluator/1.0.0"
  @minimum_runs_per_axis 2
  @assertion_keys ~w[passed? evidence_digest]a
  @replay_keys ~w[axis run graph_digest page_digest evidence_digest]a
  @resource_keys ~w[value unit evidence_digest]a
  @resource_units %{
    inventory_files: :count,
    inventory_bytes: :bytes,
    parsing_ast_nodes: :count,
    graph_statements: :count,
    rendered_bytes: :bytes,
    search_entries: :count,
    maintainer_concurrency: :count,
    storage_bytes: :bytes,
    recovery_milliseconds: :milliseconds
  }

  @spec evaluate(map(), map(), function(), function()) ::
          {:ok, map()} | {:error, Error.t()}
  def evaluate(corpus, evidence, verifier, signer)
      when is_map(evidence) and is_function(verifier, 2) and is_function(signer, 1) do
    with :ok <- QualificationCorpus.verify(corpus, verifier),
         {:ok, normalized} <- normalize_evidence(evidence) do
      corpus
      |> report_payload(normalized)
      |> then(&SignedEvidence.sign(:quality_qualification_report, &1, signer))
    end
  end

  def evaluate(_corpus, _evidence, _verifier, _signer),
    do: invalid(:repository_wiki_quality_evaluation)

  @spec verify_report(map(), map(), function()) :: :ok | {:error, Error.t()}
  def verify_report(report, corpus, verifier)
      when is_map(report) and is_map(corpus) and is_function(verifier, 2) do
    with :ok <- QualificationCorpus.verify(corpus, verifier),
         :ok <- SignedEvidence.verify(report, :quality_qualification_report, verifier),
         {:ok, normalized} <- normalize_evidence(report.payload[:evidence]),
         true <- report.payload == report_payload(corpus, normalized) do
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

  defp report_payload(corpus, evidence) do
    thresholds = QualificationCorpus.member(corpus, :release_thresholds)
    failed_dimensions = failed_assertions(evidence.completeness)
    failed_usefulness = failed_assertions(evidence.usefulness)
    failed_isolation = failed_assertions(evidence.isolation)
    replay_failures = replay_failures(evidence.replays)

    resource_failures =
      evidence.resources
      |> Enum.filter(fn {key, measurement} -> measurement.value > thresholds.resources[key] end)
      |> Enum.map(fn {key, _measurement} -> key end)
      |> Enum.sort()

    blocking_reasons =
      []
      |> add_blocker(failed_dimensions != [], :incomplete_or_invalid_output)
      |> add_blocker(replay_failures != [], :nondeterministic_replay)
      |> add_blocker(failed_usefulness != [], :usefulness_regression)
      |> add_blocker(failed_isolation != [], :edition_or_scope_mixing)
      |> add_blocker(resource_failures != [], :resource_ceiling_exceeded)
      |> Enum.reverse()

    %{
      revision: @revision,
      corpus_digest: QualificationCorpus.digest(corpus),
      evaluator_digest: QualificationCorpus.member(corpus, :evaluator) |> Contract.digest(),
      threshold_digest: Contract.digest(thresholds),
      evaluated_at: QualificationCorpus.member(corpus, :clock).evaluated_at,
      evidence: evidence,
      evidence_digest: Contract.digest(evidence),
      canonical_graph_digest: canonical_digest(evidence.replays, :graph_digest),
      canonical_page_digest: canonical_digest(evidence.replays, :page_digest),
      failed_dimensions: failed_dimensions,
      replay_failures: replay_failures,
      failed_usefulness_tasks: failed_usefulness,
      failed_isolation_scenarios: failed_isolation,
      resource_failures: resource_failures,
      resource_ceiling_digest: Contract.digest(thresholds.resources),
      blocking_reasons: blocking_reasons,
      admitted?: blocking_reasons == [],
      model_calls: 0,
      model_tokens: 0,
      model_cost_microunits: 0
    }
  end

  defp normalize_evidence(evidence) do
    with true <-
           Enum.sort(Map.keys(evidence)) == [
             :completeness,
             :isolation,
             :replays,
             :resources,
             :usefulness
           ],
         {:ok, completeness} <-
           assertions(evidence.completeness, QualificationCorpus.quality_dimensions()),
         {:ok, usefulness} <-
           assertions(evidence.usefulness, QualificationCorpus.usefulness_tasks()),
         {:ok, isolation} <-
           assertions(evidence.isolation, QualificationCorpus.isolation_scenarios()),
         {:ok, replays} <- replays(evidence.replays),
         {:ok, resources} <- resources(evidence.resources) do
      {:ok,
       %{
         completeness: completeness,
         usefulness: usefulness,
         isolation: isolation,
         replays: replays,
         resources: resources
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_quality_evidence)
    end
  rescue
    _error -> invalid(:repository_wiki_quality_evidence)
  end

  defp assertions(values, expected_keys) when is_map(values) do
    valid? =
      Enum.sort(Map.keys(values)) == Enum.sort(expected_keys) and
        Enum.all?(values, fn {_key, value} ->
          is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(@assertion_keys) and
            is_boolean(value[:passed?]) and Contract.digest?(value[:evidence_digest])
        end)

    if valid?, do: {:ok, Map.new(Enum.sort(values))}, else: invalid(:quality_assertions)
  end

  defp assertions(_values, _expected_keys), do: invalid(:quality_assertions)

  defp replays(values) when is_list(values) do
    axes = QualificationCorpus.replay_axes()

    valid? =
      length(values) >= length(axes) * @minimum_runs_per_axis and length(values) <= 256 and
        Enum.all?(axes, fn axis ->
          Enum.count(values, &(&1[:axis] == axis)) >= @minimum_runs_per_axis
        end) and
        unique?(values, &{&1.axis, &1.run}) and
        Enum.all?(values, fn value ->
          is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(@replay_keys) and
            value[:axis] in axes and is_integer(value[:run]) and value[:run] > 0 and
            Contract.digest?(value[:graph_digest]) and Contract.digest?(value[:page_digest]) and
            Contract.digest?(value[:evidence_digest])
        end)

    if valid?,
      do: {:ok, Enum.sort_by(values, &{&1.axis, &1.run})},
      else: invalid(:quality_replays)
  rescue
    _error -> invalid(:quality_replays)
  end

  defp replays(_values), do: invalid(:quality_replays)

  defp resources(values) when is_map(values) do
    keys = QualificationCorpus.resource_keys()

    valid? =
      Enum.sort(Map.keys(values)) == Enum.sort(keys) and
        Enum.all?(values, fn {key, value} ->
          is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(@resource_keys) and
            is_integer(value[:value]) and value[:value] >= 0 and
            value[:unit] == Map.fetch!(@resource_units, key) and
            Contract.digest?(value[:evidence_digest])
        end)

    if valid?, do: {:ok, Map.new(Enum.sort(values))}, else: invalid(:quality_resources)
  rescue
    _error -> invalid(:quality_resources)
  end

  defp resources(_values), do: invalid(:quality_resources)

  defp failed_assertions(assertions) do
    assertions
    |> Enum.reject(fn {_key, assertion} -> assertion.passed? end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp replay_failures(replays) do
    graph_digests = replays |> Enum.map(& &1.graph_digest) |> Enum.uniq()
    page_digests = replays |> Enum.map(& &1.page_digest) |> Enum.uniq()

    []
    |> add_failure(length(graph_digests) != 1, :graph_digest_mismatch)
    |> add_failure(length(page_digests) != 1, :page_digest_mismatch)
    |> Enum.reverse()
  end

  defp canonical_digest(replays, key), do: replays |> hd() |> Map.fetch!(key)

  defp add_blocker(reasons, true, reason), do: [reason | reasons]
  defp add_blocker(reasons, false, _reason), do: reasons
  defp add_failure(reasons, true, reason), do: [reason | reasons]
  defp add_failure(reasons, false, _reason), do: reasons

  defp unique?(values, mapper) do
    keys = Enum.map(values, mapper)
    length(keys) == length(Enum.uniq(keys))
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized, do: {:error, Error.new(:unauthorized, :repository_wiki_quality_report)}
end

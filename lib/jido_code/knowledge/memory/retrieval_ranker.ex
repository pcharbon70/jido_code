defmodule JidoCode.Knowledge.Memory.RetrievalRanker do
  @moduledoc "Transparent deterministic ranking for authorized memory candidates."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.RetrievalRequest

  @revision "1.0.0"
  @bounded_signals ~w[
    relevance lexical_overlap symbol_overlap dependency_overlap compatibility phase_relevance
    trust evidence freshness delayed_outcome diversity negative_transfer historical_frequency
  ]a

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec rank(RetrievalRequest.t(), [map()]) :: {:ok, [map()]} | {:error, Error.t()}
  def rank(%RetrievalRequest{} = request, candidates) when is_list(candidates) do
    if Enum.all?(candidates, &valid?/1) do
      ranked =
        candidates
        |> Enum.uniq_by(& &1.iri)
        |> Enum.map(&score(&1, request))
        |> Enum.sort_by(&{-&1.rank.score, &1.rank.diversity_key, &1.iri})

      {:ok, ranked}
    else
      invalid()
    end
  rescue
    _error -> invalid()
  end

  def rank(_request, _candidates), do: invalid()

  defp score(candidate, request) do
    signals = candidate.signals

    authoritative_current =
      1_500 * truthy(signals[:current_policy]) +
        1_300 * truthy(signals[:current_source]) +
        1_200 * truthy(signals[:current_test]) +
        1_100 * truthy(signals[:task_evidence])

    ordinary =
      300 * signals.relevance +
        220 * signals.lexical_overlap +
        240 * signals.symbol_overlap +
        180 * signals.dependency_overlap +
        250 * signals.compatibility +
        180 * signals.phase_relevance +
        180 * signals.trust +
        220 * signals.evidence +
        200 * signals.freshness +
        100 * signals.delayed_outcome +
        60 * signals.diversity +
        40 * signals.historical_frequency -
        600 * signals.negative_transfer -
        1_000 * truthy(signals[:contradicted])

    Map.put(candidate, :rank, %{
      score: Float.round(authoritative_current + ordinary, 6),
      revision: @revision,
      diversity_key: signals[:diversity_key] || candidate.iri,
      selection_reason: selection_reason(signals, request)
    })
  end

  defp selection_reason(signals, request) do
    @bounded_signals
    |> Enum.filter(&(Map.get(signals, &1, 0) > 0))
    |> Kernel.++(
      Enum.filter(~w[current_policy current_source current_test task_evidence]a, &signals[&1])
    )
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
    |> then(&%{features: &1, task_iri: request.task_iri, plan_phase: request.plan_phase})
  end

  defp valid?(%{signals: signals} = candidate) when is_map(signals) do
    Enum.all?(@bounded_signals, fn signal ->
      value = candidate.signals[signal]
      is_number(value) and value >= 0 and value <= 1
    end) and
      Enum.all?(
        ~w[current_policy current_source current_test task_evidence contradicted]a,
        fn key ->
          is_boolean(Map.get(candidate.signals, key, false))
        end
      )
  end

  defp valid?(_candidate), do: false
  defp truthy(true), do: 1
  defp truthy(_value), do: 0
  defp invalid, do: {:error, Error.new(:invalid_input, :memory_retrieval_ranking)}
end

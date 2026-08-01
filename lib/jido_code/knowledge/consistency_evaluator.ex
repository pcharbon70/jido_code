defmodule JidoCode.Knowledge.ConsistencyEvaluator do
  @moduledoc false

  alias JidoCode.Knowledge.ConsistencyReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.QueryConsistency

  @spec evaluate(QueryConsistency.t(), map(), map(), [String.t()]) ::
          {:ok, ConsistencyReceipt.t()} | {:error, Error.t(), ConsistencyReceipt.t()}
  def evaluate(%QueryConsistency{} = consistency, substrate, snapshot, queried_graphs) do
    gaps =
      []
      |> dataset_gaps(consistency, substrate.dataset_revision)
      |> graph_gaps(consistency, snapshot.graph_revisions)
      |> ontology_gaps(consistency, snapshot.graph_metadata)
      |> completeness_gaps(consistency, snapshot.graph_metadata)
      |> derived_rule_set_gaps(consistency, snapshot.graph_metadata)
      |> historical_gaps(consistency, queried_graphs)
      |> Enum.reverse()

    receipt = %ConsistencyReceipt{
      mode: consistency.mode,
      status: if(gaps == [], do: :satisfied, else: :degraded),
      dataset_revision: substrate.dataset_revision,
      graph_revisions: snapshot.graph_revisions,
      ontology_version: ontology_version(snapshot.graph_metadata),
      complete_graphs: complete_graphs(snapshot.graph_metadata),
      valid_at: consistency.valid_at,
      valid_interval: consistency.valid_interval,
      derived_rule_set_revision: consistency.derived_rule_set_revision,
      gaps: gaps,
      constraint_digest: QueryConsistency.digest(consistency)
    }

    if gaps != [] and consistency.mode in [:strict, :historical],
      do: {:error, Error.new(:stale_precondition, :query_consistency), receipt},
      else: {:ok, receipt}
  end

  defp dataset_gaps(gaps, consistency, revision) do
    gaps
    |> maybe_gap(
      is_integer(consistency.exact_dataset_revision) and
        consistency.exact_dataset_revision != revision,
      :dataset_revision_mismatch
    )
    |> maybe_gap(
      is_integer(consistency.minimum_dataset_revision) and
        revision < consistency.minimum_dataset_revision,
      :dataset_revision_too_old
    )
  end

  defp graph_gaps(gaps, consistency, revisions) do
    gaps =
      Enum.reduce(consistency.exact_graph_revisions, gaps, fn {graph, expected}, current ->
        maybe_gap(current, Map.get(revisions, graph) != expected, :graph_revision_mismatch)
      end)

    Enum.reduce(consistency.minimum_graph_revisions, gaps, fn {graph, minimum}, current ->
      maybe_gap(current, Map.get(revisions, graph, -1) < minimum, :graph_revision_too_old)
    end)
  end

  defp ontology_gaps(gaps, %{ontology_version: nil}, _metadata), do: gaps

  defp ontology_gaps(gaps, consistency, metadata) do
    versions = metadata |> Map.values() |> Enum.map(& &1.ontology_version) |> Enum.uniq()
    maybe_gap(gaps, versions != [consistency.ontology_version], :ontology_version_mismatch)
  end

  defp completeness_gaps(gaps, consistency, metadata) do
    Enum.reduce(consistency.required_complete_graphs, gaps, fn graph, current ->
      complete? = match?(%{completeness_state: :complete}, Map.get(metadata, graph))
      maybe_gap(current, not complete?, :required_graph_incomplete)
    end)
  end

  defp derived_rule_set_gaps(gaps, %{derived_rule_set_revision: nil}, _metadata), do: gaps

  defp derived_rule_set_gaps(gaps, consistency, metadata) do
    derived =
      metadata
      |> Enum.filter(fn {_graph, graph_metadata} -> graph_metadata.family == :derived end)

    matches? =
      derived != [] and
        Enum.all?(derived, fn {graph, _metadata} ->
          String.ends_with?(graph, "/#{consistency.derived_rule_set_revision}")
        end)

    maybe_gap(gaps, not matches?, :derived_rule_set_revision_mismatch)
  end

  defp historical_gaps(gaps, %{mode: :historical} = consistency, queried_graphs) do
    maybe_gap(
      gaps,
      MapSet.new(consistency.historical_graphs) != MapSet.new(queried_graphs),
      :historical_graph_set_mismatch
    )
  end

  defp historical_gaps(gaps, _consistency, _queried_graphs), do: gaps

  defp ontology_version(metadata) do
    case metadata |> Map.values() |> Enum.map(& &1.ontology_version) |> Enum.uniq() do
      [version] -> version
      [] -> nil
      _multiple -> :mixed
    end
  end

  defp complete_graphs(metadata) do
    metadata
    |> Enum.filter(fn {_graph, graph_metadata} ->
      graph_metadata.completeness_state == :complete
    end)
    |> Enum.map(fn {graph, _metadata} -> graph end)
    |> Enum.sort()
  end

  defp maybe_gap(gaps, true, gap), do: [gap | gaps]
  defp maybe_gap(gaps, false, _gap), do: gaps
end

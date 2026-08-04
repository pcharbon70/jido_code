defmodule JidoCode.Knowledge.Evidence.Projection do
  @moduledoc "Bounded evidence views that retain contradictory and incomplete verification facts."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    evidence_by_goal evidence_by_claim evidence_by_attempt evidence_by_artifact
    verification_timeline evidence_support evidence_sufficiency stale_evidence
    missing_evidence_requirements
  ]a
  @sensitive_keys ~w[content embeddedContent rawOutput stdout stderr prompt credential secret token]
  @max_rows 500

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.knowledge_version(),
         {:ok, :evidence} <- GraphRegistry.identify(graph),
         :ok <- ResourceIdentity.validate(context[:resource_iri]),
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         rows when is_list(rows) and length(rows) <= @max_rows <- result.data,
         data <- rows |> Enum.map(&project_row/1) |> Enum.uniq(),
         source_revisions <- source_revisions(data) do
      {:ok,
       %{
         lens: Atom.to_string(result.query_name),
         resource_iri: context[:resource_iri],
         data: data,
         raw_outputs_authorized?: false,
         receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           source_graph_revisions: source_revisions,
           dataset_revision: result.dataset_revision,
           ontology_version: result.ontology_version,
           query_version: result.query_version,
           complete?: result.completeness.complete?,
           freshness: Atom.to_string(result.freshness),
           truncated?: result.truncated?,
           warnings: result.warnings,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at)
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:evidence_projection)
    end
  rescue
    _error -> invalid(:evidence_projection)
  end

  def build(_result, _context), do: invalid(:evidence_projection)

  @spec sufficiency(map()) :: {:ok, map()} | {:error, Error.t()}
  def sufficiency(%{transition_authority?: false, acceptance_authority?: false} = assessment) do
    with status when is_atom(status) <- assessment[:status],
         explanations when is_list(explanations) <- assessment[:explanations],
         revisions when is_map(revisions) <- assessment[:source_graph_revisions] do
      {:ok,
       %{
         lens: "evidence_sufficiency_assessment",
         status: Atom.to_string(status),
         explanations: explanations,
         considered_evidence_iris: assessment[:considered_evidence_iris],
         stale_evidence_iris: assessment[:stale_evidence_iris],
         transition_authority?: false,
         acceptance_authority?: false,
         receipt: %{
           assessment_iri: assessment[:iri],
           policy_iri: assessment[:policy_iri],
           policy_version: assessment[:policy_version],
           policy_graph_revision: assessment[:policy_graph_revision],
           plan_iri: assessment[:plan_iri],
           plan_graph_revision: assessment[:plan_graph_revision],
           source_graph_revisions: revisions,
           evaluated_at: DateTime.to_iso8601(assessment[:evaluated_at])
         }
       }}
    else
      _invalid -> invalid(:evidence_sufficiency_projection)
    end
  rescue
    _error -> invalid(:evidence_sufficiency_projection)
  end

  def sufficiency(_assessment), do: invalid(:evidence_sufficiency_projection)

  defp project_row(row) when is_map(row) do
    Map.new(row, fn {key, value} ->
      if sensitive?(key), do: {key, :redacted}, else: {key, term_value(value)}
    end)
  end

  defp sensitive?(key), do: Enum.any?(@sensitive_keys, &String.contains?(to_string(key), &1))
  defp term_value(%{value: value}), do: value
  defp term_value(value), do: value

  defp source_revisions(rows) do
    rows
    |> Enum.map(fn row ->
      graph = row["sourceGraphIri"] || row[:sourceGraphIri]
      revision = row["sourceRevision"] || row[:sourceRevision]
      {graph, revision}
    end)
    |> Enum.reject(fn {graph, revision} -> is_nil(graph) or not is_integer(revision) end)
    |> Map.new()
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

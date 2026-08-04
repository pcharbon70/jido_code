defmodule JidoCode.Knowledge.Decision.Projection do
  @moduledoc "Bounded decision, satisfaction, and follow-up views without authored-thought expansion."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    decision_by_goal decision_by_claim decision_by_evidence decision_by_actor decision_waivers
    decision_rejections deferred_actions decision_supersession satisfaction_path decision_follow_up
  ]a
  @max_rows 500

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.knowledge_version(),
         {:ok, family} <- GraphRegistry.identify(graph),
         true <- family in [:evidence, :repository_control],
         :ok <- ResourceIdentity.validate(context[:resource_iri]),
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         rows when is_list(rows) and length(rows) <= @max_rows <- result.data,
         data <- rows |> Enum.map(&project_row/1) |> Enum.uniq() do
      {:ok,
       %{
         lens: Atom.to_string(result.query_name),
         resource_iri: context[:resource_iri],
         data: data,
         rationale_policy: :authored_references_only,
         receipt: %{
           graph_iri: graph,
           graph_family: Atom.to_string(family),
           graph_revision: revision,
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
      _invalid -> invalid(:decision_projection)
    end
  rescue
    _error -> invalid(:decision_projection)
  end

  def build(_result, _context), do: invalid(:decision_projection)

  defp project_row(row) do
    Map.new(row, fn {key, value} -> {key, term_value(value)} end)
  end

  defp term_value(%{value: value}), do: value
  defp term_value(value), do: value
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

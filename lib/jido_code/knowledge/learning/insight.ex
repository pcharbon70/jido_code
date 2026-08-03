defmodule JidoCode.Knowledge.Learning.Insight do
  @moduledoc "Visibility-preserving proposed insights from reviewed cross-graph queries."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    shared_dependencies repeated_findings repeated_failures policy_outcome_patterns
    reusable_evidence_methods related_source_symbols applicable_lessons
  ]a
  @max_rows 500

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:derived_graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.knowledge_version(),
         {:ok, :derived} <- GraphRegistry.identify(graph),
         expected_revisions when is_map(expected_revisions) and map_size(expected_revisions) > 0 <-
           context[:expected_graph_revisions],
         true <- result.graph_revisions == expected_revisions,
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         true <- revision == context[:expected_derived_revision],
         true <- result.freshness == :current,
         true <- result.evaluated_at == context[:evaluated_at],
         :ok <- ResourceIdentity.validate(context[:target_repository_iri]),
         :ok <- ResourceIdentity.validate(context[:visibility_receipt_iri]),
         {:ok, authorized} <- resources(context[:authorized_repository_iris], 200, false),
         {:ok, visible} <- resources(context[:visible_repository_iris], 200, false),
         true <- MapSet.subset?(MapSet.new(visible), MapSet.new(authorized)),
         true <- context.target_repository_iri in visible,
         minimum when is_integer(minimum) and minimum in 2..20 <- context[:minimum_sources],
         rows when is_list(rows) and length(rows) <= @max_rows <- result.data do
      visible_set = MapSet.new(visible)

      proposals =
        rows
        |> Enum.filter(&MapSet.member?(visible_set, value(&1, "repository")))
        |> Enum.group_by(&value(&1, "candidate"))
        |> Enum.reject(fn {candidate, _rows} -> is_nil(candidate) end)
        |> Enum.flat_map(fn {candidate, candidate_rows} ->
          repositories = values(candidate_rows, "repository")

          if length(repositories) >= minimum do
            [proposal(result, context, graph, revision, candidate, repositories, candidate_rows)]
          else
            []
          end
        end)
        |> Enum.sort_by(& &1.iri)

      {:ok,
       %{
         target_repository_iri: context.target_repository_iri,
         proposals: proposals,
         visibility_receipt_iri: context.visibility_receipt_iri,
         concealment_policy: :minimum_visible_sources,
         minimum_sources: minimum,
         query_receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: result.dataset_revision,
           query_name: Atom.to_string(result.query_name),
           query_version: result.query_version,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at),
           truncated?: result.truncated?,
           complete?: result.completeness.complete?
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:cross_graph_insight)
    end
  rescue
    _error -> invalid(:cross_graph_insight)
  end

  def build(_result, _context), do: invalid(:cross_graph_insight)

  defp proposal(result, context, graph, revision, candidate, repositories, rows) do
    material =
      {
        result.query_name,
        result.query_version,
        graph,
        revision,
        context.target_repository_iri,
        candidate,
        repositories
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    {:ok, iri} = ResourceIdentity.deterministic(:insight_proposal, material)

    %{
      iri: iri,
      state: :proposed,
      kind: result.query_name,
      target_repository_iri: context.target_repository_iri,
      candidate_iri: candidate,
      source_repository_iris: repositories,
      evidence_iris: values(rows, "evidence"),
      classification_iris: values(rows, "classification"),
      source_confidences: values(rows, "confidence"),
      source_limitations: values(rows, "limitation"),
      confidence: min(90, 40 + length(repositories) * 15),
      limitations: [
        "correlation is a proposed insight, not accepted target-repository knowledge",
        "only repositories visible under the supplied authorization receipt contributed"
      ],
      rule_version: context[:rule_version],
      query_version: result.query_version,
      derived_graph_revision: revision,
      acceptance_authority?: false,
      adoption_authority?: false,
      independent_evidence_required?: true,
      target_policy_authorization_required?: true
    }
  end

  defp resources(values, maximum, allow_empty?)
       when is_list(values) and length(values) <= maximum do
    values = values |> Enum.uniq() |> Enum.sort()

    if (allow_empty? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, values},
       else: :error
  end

  defp resources(_values, _maximum, _allow_empty?), do: :error

  defp values(rows, key),
    do: rows |> Enum.map(&value(&1, key)) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()

  defp value(row, key) do
    case row[key] do
      %{value: value} -> value
      value -> value
    end
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

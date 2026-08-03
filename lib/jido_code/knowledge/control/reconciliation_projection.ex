defmodule JidoCode.Knowledge.Control.ReconciliationProjection do
  @moduledoc """
  Bounded discovery, context, and explanation views for reconciliation.

  Explanations cite graph resources and decisions. They do not persist or
  expose hidden model reasoning.
  """

  alias JidoCode.Knowledge.Control.Reconciliation
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    active_reconciliation_scopes incomplete_reconciliations
    reconciliation_input reconciliation_explanation
  ]a
  @max_rows 500
  @max_results 100

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.reconciliation_version(),
         {:ok, family} <- GraphRegistry.identify(graph),
         true <- family in [:factory_catalog, :repository_control],
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         :ok <- optional_resource(context[:resource_iri]),
         {:ok, row_limit} <- row_limit(context),
         {:ok, data} <- decode(result.query_name, result.data, row_limit) do
      {:ok,
       %{
         lens: Atom.to_string(result.query_name),
         data: data,
         receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: result.dataset_revision,
           query_version: result.query_version,
           ontology_version: result.ontology_version,
           complete?: result.completeness.complete?,
           freshness: Atom.to_string(result.freshness),
           truncated?: result.truncated?,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at),
           row_limit: row_limit
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:reconciliation_projection)
    end
  rescue
    _error -> invalid(:reconciliation_projection)
  end

  def build(_result, _context), do: invalid(:reconciliation_projection)

  @spec explain(Reconciliation.t(), pos_integer()) :: {:ok, map()} | {:error, Error.t()}
  def explain(reconciliation, limit \\ @max_results)

  def explain(%Reconciliation{} = reconciliation, limit)
      when is_integer(limit) and limit in 1..@max_results do
    results =
      reconciliation.results
      |> Enum.take(limit)
      |> Enum.map(fn result ->
        %{
          desired_outcome_iri: result.desired_outcome_iri,
          dimension_iri: result.dimension_iri,
          observed_state: result.observed_state,
          result: result.classification,
          gap_iri: result.gap && result.gap.iri,
          proposal_iri: result.proposal.iri,
          proposed_or_reused_iri: result.proposal.target_iri,
          requires_decision?: result.requires_decision?,
          decision_iri: result.proposal.decision_iri
        }
      end)

    {:ok,
     %{
       reconciliation_iri: reconciliation.iri,
       input_package_iri: reconciliation.package.iri,
       scope_iri: reconciliation.package.scope_iri,
       graph_revisions: ReconciliationPackage.graph_revisions(reconciliation.package),
       query_version: reconciliation.package.query_version,
       rule_version: reconciliation.package.rule_version,
       knowledge_state: reconciliation.package.knowledge_state,
       results: results,
       result_count: length(reconciliation.results),
       truncated?: length(reconciliation.results) > limit
     }}
  end

  def explain(_reconciliation, _limit), do: invalid(:reconciliation_explanation)

  defp decode(:active_reconciliation_scopes, rows, limit) do
    {:ok,
     rows
     |> bounded_rows(limit)
     |> Enum.map(fn row ->
       %{
         enrollment_iri: term_value(row["enrollment"]),
         repository_iri: term_value(row["repository"]),
         scope_iri: term_value(row["scope"]),
         transition_iri: term_value(row["transition"]),
         revision: term_value(row["revision"])
       }
     end)
     |> Enum.uniq()
     |> Enum.sort_by(& &1.repository_iri)}
  end

  defp decode(:incomplete_reconciliations, rows, limit) do
    {:ok,
     rows
     |> bounded_rows(limit)
     |> Enum.map(fn row ->
       %{
         reconciliation_iri: term_value(row["activity"]),
         scope_iri: term_value(row["scope"]),
         transition_iri: term_value(row["transition"]),
         state_iri: term_value(row["state"]),
         revision: term_value(row["revision"])
       }
     end)
     |> Enum.uniq()
     |> Enum.sort_by(& &1.reconciliation_iri)}
  end

  defp decode(:reconciliation_input, rows, limit) do
    rows = bounded_rows(rows, limit)

    references =
      rows
      |> Enum.map(fn row ->
        %{
          graph_iri: term_value(row["sourceGraphIri"]),
          revision: term_value(row["sourceRevision"])
        }
      end)
      |> Enum.reject(&is_nil(&1.graph_iri))
      |> Enum.uniq()
      |> Enum.sort_by(& &1.graph_iri)

    {:ok, %{facts: facts(rows), graph_revisions: references}}
  end

  defp decode(:reconciliation_explanation, rows, limit) do
    projected =
      rows
      |> bounded_rows(limit)
      |> Enum.map(fn row ->
        %{
          subject_iri: term_value(row["subject"]),
          desired_outcome_iri: term_value(row["desired"]),
          result_iri: term_value(row["result"])
        }
      end)
      |> Enum.uniq()
      |> Enum.sort_by(&:erlang.term_to_binary(&1, [:deterministic]))

    {:ok, projected}
  end

  defp decode(_query, _data, _limit), do: invalid(:reconciliation_projection_data)

  defp facts(rows) do
    rows
    |> Enum.map(fn row -> {term_value(row["predicate"]), term_value(row["object"])} end)
    |> Enum.reject(fn {predicate, _object} -> is_nil(predicate) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {predicate, values} -> {predicate, values |> Enum.uniq() |> Enum.sort()} end)
  end

  defp bounded_rows(rows, limit) when is_list(rows) and length(rows) <= limit, do: rows
  defp bounded_rows(_rows, _limit), do: raise(ArgumentError, "reconciliation row bound exceeded")

  defp row_limit(context) do
    case Map.get(context, :row_limit, @max_rows) do
      value when value in 1..@max_rows -> {:ok, value}
      _invalid -> invalid(:reconciliation_projection_bounds)
    end
  end

  defp term_value(%{
         type: :literal,
         value: value,
         datatype: "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
       })
       when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _invalid -> value
    end
  end

  defp term_value(%{value: %DateTime{} = value}), do: DateTime.to_iso8601(value)
  defp term_value(%{value: value}), do: value
  defp term_value(nil), do: nil
  defp term_value(value), do: value
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

defmodule JidoCode.Knowledge.Control.GovernanceProjection do
  @moduledoc """
  Bounded projections for policy, cohort, obligation, and capability queries.

  Every view retains the exact graph and dataset revision used to build it.
  Derived membership and hierarchy rows remain evidence, not authorization.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    policy_description governance_transition_history cohort_definition
    cohort_membership policy_applicability obligation_description
    capability_strict_view capability_hierarchy
  ]a
  @hard_max_rows 500
  @hard_max_paths 20
  @complete "https://jido.run/ontology/concept/Complete"

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.governance_version(),
         {:ok, family} <- GraphRegistry.identify(graph),
         true <- family in [:factory_policy, :repository_control, :derived],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         {:ok, source_revisions} <- source_revisions(family, graph, result.graph_revisions),
         :ok <- ResourceIdentity.validate(context[:resource_iri]),
         {:ok, limits} <- limits(context),
         {:ok, data} <- decode(result.query_name, result.data, limits),
         true <- json_safe?(data) do
      {:ok,
       %{
         lens: Atom.to_string(result.query_name),
         data: data,
         receipt: %{
           graph_iri: graph,
           graph_family: Atom.to_string(family),
           graph_revision: revision,
           source_graph_revisions: source_revisions,
           dataset_revision: result.dataset_revision,
           ontology_version: result.ontology_version,
           query_version: result.query_version,
           complete?: result.completeness.complete?,
           freshness: Atom.to_string(result.freshness),
           truncated?: result.truncated?,
           warnings: Enum.map(result.warnings, &safe_warning/1),
           bounds: limits,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at)
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:governance_projection)
    end
  rescue
    _error -> invalid(:governance_projection)
  catch
    :row_bound -> invalid(:governance_projection_row_bound)
  end

  def build(_result, _context), do: invalid(:governance_projection)

  defp decode(name, rows, limits) when name in [:cohort_membership, :policy_applicability] do
    memberships =
      rows
      |> bounded_rows(limits)
      |> Enum.group_by(&term_value(&1["membership"]))
      |> Enum.reject(fn {iri, _rows} -> is_nil(iri) end)
      |> Enum.map(fn {iri, membership_rows} ->
        paths = values(membership_rows, "path")

        %{
          membership_iri: iri,
          repository_iri: one_value(membership_rows, "repository"),
          cohort_iri: one_value(membership_rows, "cohort"),
          evaluator_iri: one_value(membership_rows, "evaluator"),
          complete?: one_value(membership_rows, "completeness") == @complete,
          membership_path: Enum.take(paths, limits.path_count),
          path_truncated?: length(paths) > limits.path_count
        }
      end)
      |> Enum.sort_by(& &1.membership_iri)

    {:ok,
     %{
       memberships: memberships,
       count: length(memberships),
       declared_source_graph_revisions: graph_references(rows)
     }}
  end

  defp decode(:governance_transition_history, rows, limits) do
    history =
      rows
      |> bounded_rows(limits)
      |> Enum.map(fn row ->
        %{
          transition_iri: term_value(row["transition"]),
          state_iri: term_value(row["state"]),
          revision: term_value(row["revision"]),
          predecessor_iri: term_value(row["predecessor"]),
          actor_iri: term_value(row["actor"]),
          cause_iri: term_value(row["cause"]),
          reason: term_value(row["reason"]),
          recorded_at: term_value(row["recorded"])
        }
      end)
      |> Enum.uniq()
      |> Enum.sort_by(& &1.revision)

    {:ok, history}
  end

  defp decode(:obligation_description, rows, limits) do
    rows = bounded_rows(rows, limits)

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

    {:ok, %{facts: facts(rows), source_graph_revisions: references}}
  end

  defp decode(:capability_strict_view, rows, limits) do
    rows = bounded_rows(rows, limits)

    endpoints =
      rows
      |> Enum.filter(&is_nil(term_value(&1["successor"])))
      |> Enum.map(fn row ->
        %{
          transition_iri: term_value(row["transition"]),
          state_iri: term_value(row["state"]),
          revision: term_value(row["revision"])
        }
      end)
      |> Enum.reject(&is_nil(&1.transition_iri))
      |> Enum.uniq()

    with [endpoint] <- endpoints do
      {:ok, %{facts: facts(rows), current_transition: endpoint}}
    else
      _invalid -> invalid(:capability_strict_projection)
    end
  end

  defp decode(:capability_hierarchy, rows, limits) do
    classifications =
      rows
      |> bounded_rows(limits)
      |> Enum.map(fn row ->
        %{
          classification_iri: term_value(row["classification"]),
          capability_iri: term_value(row["capability"]),
          broader_capability_iri: term_value(row["broader"]),
          evaluator_version: term_value(row["version"]),
          authority?: false
        }
      end)
      |> Enum.uniq()
      |> Enum.sort_by(& &1.classification_iri)

    {:ok,
     %{
       classifications: classifications,
       declared_source_graph_revisions: graph_references(rows)
     }}
  end

  defp decode(name, rows, limits)
       when name in [:policy_description, :cohort_definition] and is_list(rows) do
    rows = bounded_rows(rows, limits)
    {:ok, %{facts: facts(rows), rows: project_rows(rows)}}
  end

  defp decode(_name, _rows, _limits), do: invalid(:governance_projection_data)

  defp facts(rows) do
    rows
    |> Enum.map(fn row -> {term_value(row["predicate"]), term_value(row["object"])} end)
    |> Enum.reject(fn {predicate, _object} -> is_nil(predicate) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {predicate, values} -> {predicate, values |> Enum.uniq() |> Enum.sort()} end)
  end

  defp graph_references(rows) do
    rows
    |> Enum.map(fn row ->
      %{graph_iri: term_value(row["sourceGraphIri"]), revision: term_value(row["sourceRevision"])}
    end)
    |> Enum.reject(&is_nil(&1.graph_iri))
    |> Enum.uniq()
    |> Enum.sort_by(& &1.graph_iri)
  end

  defp project_rows(rows) do
    rows
    |> Enum.map(fn row -> Map.new(row, fn {key, value} -> {key, term_value(value)} end) end)
    |> Enum.uniq()
    |> Enum.sort_by(&:erlang.term_to_binary(&1, [:deterministic]))
  end

  defp bounded_rows(rows, limits) when is_list(rows) and length(rows) <= limits.row_count,
    do: rows

  defp bounded_rows(_rows, _limits), do: throw(:row_bound)

  defp limits(context) do
    row_count = Map.get(context, :row_limit, @hard_max_rows)
    path_count = Map.get(context, :path_limit, @hard_max_paths)

    if row_count in 1..@hard_max_rows and path_count in 1..@hard_max_paths,
      do: {:ok, %{row_count: row_count, path_count: path_count}},
      else: invalid(:governance_projection_bounds)
  end

  defp source_revisions(:derived, graph, revisions) do
    sources = Map.delete(revisions, graph)

    if sources != %{} and Enum.all?(sources, fn {_source, revision} -> revision > 0 end),
      do: {:ok, sources},
      else: invalid(:governance_projection_sources)
  end

  defp source_revisions(_family, graph, revisions) do
    if Map.keys(revisions) == [graph],
      do: {:ok, %{}},
      else: invalid(:governance_projection_sources)
  end

  defp one_value(rows, key) do
    case values(rows, key) do
      [value] -> value
      [] -> nil
      _ambiguous -> :ambiguous
    end
  end

  defp values(rows, key) do
    rows
    |> Enum.map(&term_value(&1[key]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
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

  defp safe_warning(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_warning(value) when is_binary(value), do: value
  defp safe_warning(value), do: inspect(value, limit: 20, printable_limit: 200)

  defp json_safe?(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: true

  defp json_safe?(value) when is_atom(value), do: true
  defp json_safe?(value) when is_list(value), do: Enum.all?(value, &json_safe?/1)

  defp json_safe?(value) when is_map(value) and not is_struct(value),
    do:
      Enum.all?(value, fn {key, item} -> (is_atom(key) or is_binary(key)) and json_safe?(item) end)

  defp json_safe?(_value), do: false
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

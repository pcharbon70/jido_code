defmodule JidoCode.Knowledge.Projections.Source do
  @moduledoc """
  Builds exact-snapshot source projections from one reviewed query result.

  The projection is an attributable cache value, never a source of truth. It
  preserves relationship predicate and direction for neighborhood and impact
  queries and refuses results that do not identify exactly one source graph.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @source_queries [
    :source_modules,
    :source_functions,
    :source_otp_patterns,
    :source_dependencies,
    :source_entity_neighborhood,
    :source_impact
  ]

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]
    snapshot = context[:snapshot_iri]

    with true <- result.query_name in @source_queries,
         true <- result.query_version == QueryCatalog.repository_version(),
         {:ok, :source_revision} <- GraphRegistry.identify(graph),
         :ok <- ResourceIdentity.validate(context[:repository_iri]),
         :ok <- ResourceIdentity.validate(snapshot),
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         {:ok, provenance} <- provenance(result.data),
         true <- provenance != nil,
         {:ok, data} <- project_data(result.query_name, result.data, context),
         warnings <-
           (Enum.map(result.warnings, &safe_warning/1) ++ analysis_warnings(result.data))
           |> Enum.uniq(),
         coverage <- coverage_state(provenance.coverage) do
      {:ok,
       %{
         query: Atom.to_string(result.query_name),
         data: data,
         source: %{
           repository_iri: context[:repository_iri],
           snapshot_iri: snapshot,
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: result.dataset_revision,
           ontology_version: result.ontology_version,
           analyzer_version: provenance.analyzer,
           analyzer_configuration_digest: provenance.configuration,
           input_tree_digest: provenance.tree,
           coverage: coverage,
           freshness: Atom.to_string(result.freshness),
           stale?: result.freshness != :current,
           degraded?:
             coverage != "complete" or not result.completeness.complete? or result.truncated? or
               warnings != [],
           complete?: result.completeness.complete?,
           truncated?: result.truncated?,
           warnings: warnings,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at)
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:source_projection)
    end
  rescue
    _error -> invalid(:source_projection)
  end

  def build(_result, _context), do: invalid(:source_projection)

  defp provenance(rows) when is_list(rows) do
    values =
      rows
      |> Enum.map(fn row ->
        %{
          analyzer: term_value(row["analyzer"]),
          configuration: term_value(row["configuration"]),
          tree: term_value(row["tree"]),
          coverage: term_value(row["coverage"])
        }
      end)
      |> Enum.reject(&Enum.any?(Map.values(&1), fn value -> is_nil(value) end))
      |> Enum.uniq()

    case values do
      [value] -> {:ok, value}
      [] -> {:ok, nil}
      _ambiguous -> invalid(:source_projection_provenance)
    end
  end

  defp provenance(_rows), do: invalid(:source_projection_provenance)

  defp project_data(:source_entity_neighborhood, rows, context) do
    resource = context[:resource_iri]

    with :ok <- ResourceIdentity.validate(resource) do
      relationships =
        rows
        |> Enum.flat_map(fn row ->
          outgoing =
            case {term_value(row["outPredicate"]), term_value(row["outValue"])} do
              {predicate, value} when is_binary(predicate) and not is_nil(value) ->
                [
                  %{
                    direction: "outgoing",
                    source: resource,
                    predicate: predicate,
                    target: value
                  }
                ]

              _missing ->
                []
            end

          incoming =
            case {term_value(row["inSubject"]), term_value(row["inPredicate"])} do
              {subject, predicate} when is_binary(subject) and is_binary(predicate) ->
                [
                  %{
                    direction: "incoming",
                    source: subject,
                    predicate: predicate,
                    target: resource
                  }
                ]

              _missing ->
                []
            end

          outgoing ++ incoming
        end)
        |> Enum.uniq()
        |> Enum.sort_by(&:erlang.term_to_binary(&1, [:deterministic]))

      {:ok, relationships}
    end
  end

  defp project_data(:source_impact, rows, context) do
    resource = context[:resource_iri]

    with :ok <- ResourceIdentity.validate(resource) do
      relationships =
        rows
        |> Enum.flat_map(fn row ->
          outgoing(row, resource, "outCall", "calls") ++
            outgoing(row, resource, "outDependency", "dependsOn") ++
            incoming(row, resource, "inCaller", "calls") ++
            incoming(row, resource, "inDependent", "dependsOn") ++
            incoming(row, resource, "definer", "defines")
        end)
        |> Enum.uniq()
        |> Enum.sort_by(&:erlang.term_to_binary(&1, [:deterministic]))

      {:ok, relationships}
    end
  end

  defp project_data(_name, rows, _context) when is_list(rows) do
    {:ok,
     Enum.map(rows, fn row ->
       row
       |> Map.drop(["analyzer", "configuration", "tree", "coverage", "analysisWarning"])
       |> Map.new(fn {key, value} -> {key, term_value(value)} end)
     end)}
  end

  defp project_data(_name, _rows, _context), do: invalid(:source_projection_data)

  defp coverage_state(value) when is_binary(value) do
    case value |> URI.parse() |> Map.get(:path) |> to_string() |> Path.basename() do
      "Complete" -> "complete"
      _other -> "incomplete"
    end
  end

  defp outgoing(row, resource, key, predicate) do
    case term_value(row[key]) do
      nil -> []
      target -> [relationship("outgoing", resource, predicate, target)]
    end
  end

  defp incoming(row, resource, key, predicate) do
    case term_value(row[key]) do
      nil -> []
      source -> [relationship("incoming", source, predicate, resource)]
    end
  end

  defp relationship(direction, source, predicate, target) do
    %{
      direction: direction,
      source: source,
      predicate: "https://jido.run/ontology/factory##{predicate}",
      target: target
    }
  end

  defp term_value(%{value: value}), do: value
  defp term_value(nil), do: nil
  defp term_value(value), do: value

  defp analysis_warnings(rows) do
    rows
    |> Enum.map(&term_value(&1["analysisWarning"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&safe_warning/1)
  end

  defp safe_warning(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_warning({kind, detail}), do: %{kind: safe_warning(kind), detail: safe_warning(detail)}
  defp safe_warning(value) when is_binary(value), do: value
  defp safe_warning(value), do: inspect(value, limit: 20, printable_limit: 200)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

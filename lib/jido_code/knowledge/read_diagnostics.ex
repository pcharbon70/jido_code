defmodule JidoCode.Knowledge.ReadDiagnostics do
  @moduledoc """
  Bounded, redacted explanation of query and projection disposition.

  Diagnostics never include query text, backend IDs, source bodies, secrets,
  paths, credentials, stack traces, or arbitrary exception details.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ProjectionCatalog
  alias JidoCode.Knowledge.ProjectionEnvelope
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult

  @cache_dispositions [:disabled, :miss, :hit, :bypassed, :invalidated]

  @spec from_query(QueryResult.t(), keyword()) :: map()
  def from_query(%QueryResult{} = result, options \\ []) do
    privileged? = Keyword.get(options, :privileged?, false)
    cache = cache_disposition(options)

    %{
      query: %{name: result.query_name, version: result.query_version},
      catalog: %{version: QueryCatalog.version(), digest: QueryCatalog.digest()},
      projection: nil,
      projection_catalog: %{
        version: ProjectionCatalog.version(),
        digest: ProjectionCatalog.digest()
      },
      evaluated: evaluated(result.dataset_revision, result.graph_revisions, privileged?),
      consistency: consistency(result.consistency),
      completeness_gaps: completeness_gaps(result),
      freshness: result.freshness,
      truncated?: result.truncated?,
      cache: cache,
      safe_error: nil,
      action: guidance(result, cache)
    }
  end

  @spec from_projection(ProjectionEnvelope.t(), keyword()) :: map()
  def from_projection(%ProjectionEnvelope{} = projection, options \\ []) do
    projection
    |> projection_query_result()
    |> from_query(options)
    |> Map.put(:projection, %{
      name: projection.projection_name,
      version: projection.projection_version,
      shape: projection.shape
    })
  end

  @spec from_error(Error.t(), keyword()) :: map()
  def from_error(%Error{} = error, options \\ []) do
    %{
      query: safe_identity(Keyword.get(options, :query)),
      catalog: %{version: QueryCatalog.version(), digest: QueryCatalog.digest()},
      projection: safe_identity(Keyword.get(options, :projection)),
      projection_catalog: %{
        version: ProjectionCatalog.version(),
        digest: ProjectionCatalog.digest()
      },
      evaluated: nil,
      consistency: nil,
      completeness_gaps: [],
      freshness: :unknown,
      truncated?: false,
      cache: cache_disposition(options),
      safe_error: %{kind: error.kind, operation: error.operation, retry: error.retry},
      action: error_guidance(error)
    }
  end

  defp projection_query_result(projection) do
    %QueryResult{
      query_name: projection.query_name,
      query_version: projection.query_version,
      dataset_revision: projection.dataset_revision,
      graph_revisions: projection.source_graph_revisions,
      ontology_version: projection.ontology_version,
      completeness: projection.completeness,
      freshness: projection.freshness,
      truncated?: projection.truncated?,
      cursor: projection.cursor,
      warnings: projection.warnings,
      execution_class: :product,
      consistency: projection.consistency,
      evaluated_at: projection.generated_at,
      data: projection.data
    }
  end

  defp evaluated(dataset_revision, graph_revisions, true) do
    %{
      dataset_revision: dataset_revision,
      graphs:
        graph_revisions
        |> Enum.map(fn {graph, revision} ->
          {:ok, family} = GraphRegistry.identify(graph)
          %{family: family, revision: revision}
        end)
        |> Enum.sort_by(&{&1.family, &1.revision})
    }
  end

  defp evaluated(dataset_revision, graph_revisions, false) do
    revisions = Map.values(graph_revisions)

    %{
      dataset_revision: dataset_revision,
      graph_count: map_size(graph_revisions),
      minimum_graph_revision: Enum.min(revisions, fn -> nil end),
      maximum_graph_revision: Enum.max(revisions, fn -> nil end)
    }
  end

  defp consistency(nil), do: nil

  defp consistency(receipt) do
    %{
      mode: receipt.mode,
      status: receipt.status,
      gaps: receipt.gaps,
      constraint_digest: receipt.constraint_digest
    }
  end

  defp completeness_gaps(result) do
    consistency_gaps =
      result.consistency.gaps
      |> Enum.filter(&(&1 in [:required_graph_incomplete, :historical_graph_set_mismatch]))

    if result.completeness.complete?,
      do: consistency_gaps,
      else: [:graph_incomplete | consistency_gaps]
  end

  defp guidance(result, cache) do
    cond do
      :required_graph_incomplete in result.consistency.gaps -> :restore_completeness
      result.freshness in [:stale, :incompatible, :invalidated] -> :rebuild_derived_graph
      result.consistency.status == :degraded -> :requery
      result.truncated? -> :continue_with_cursor
      cache in [:miss, :invalidated] -> :requery
      true -> :none
    end
  end

  defp error_guidance(%Error{kind: :corrupt}), do: :escalate_integrity
  defp error_guidance(%Error{kind: :stale_precondition}), do: :requery
  defp error_guidance(%Error{kind: :incompatible}), do: :rebuild_derived_graph
  defp error_guidance(%Error{kind: :unauthorized}), do: :reauthorize
  defp error_guidance(_error), do: :retry_when_healthy

  defp cache_disposition(options) do
    value = Keyword.get(options, :cache, :disabled)
    if value in @cache_dispositions, do: value, else: :disabled
  end

  defp safe_identity(%{name: name, version: version})
       when is_atom(name) and is_binary(version),
       do: %{name: name, version: version}

  defp safe_identity(_identity), do: nil
end

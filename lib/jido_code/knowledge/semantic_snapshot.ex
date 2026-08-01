defmodule JidoCode.Knowledge.SemanticSnapshot do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Metadata
  alias TripleStore.Exporter
  alias TripleStore.QuadOperations

  @max_graphs 20
  @max_quads 10_000

  @spec read(TripleStore.store(), map(), [String.t()]) ::
          {:ok, map()} | {:error, Error.t()}
  def read(store, substrate_metadata, graph_iris)
      when is_list(graph_iris) and length(graph_iris) <= @max_graphs do
    graphs = graph_iris |> Enum.uniq() |> Enum.sort()

    with :ok <- validate_graphs(graphs),
         {:ok, counts} <- graph_counts(store, graphs),
         true <- counts |> Map.values() |> Enum.sum() <= @max_quads,
         {:ok, dataset} <- export_existing(store, counts),
         {:ok, graph_metadata} <- metadata(store, counts),
         {:ok, graph_revisions} <- revisions(store, graphs) do
      {:ok,
       %{
         dataset_revision: substrate_metadata.dataset_revision,
         graph_revisions: graph_revisions,
         graph_metadata: graph_metadata,
         dataset: dataset,
         quad_count: RDF.Dataset.quads(dataset) |> length()
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      false -> {:error, Error.new(:invalid_input, :semantic_snapshot_limit)}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :semantic_snapshot)}
      _invalid -> {:error, Error.new(:unavailable, :semantic_snapshot)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :semantic_snapshot)}
  catch
    _kind, _reason -> {:error, Error.new(:unavailable, :semantic_snapshot)}
  end

  def read(_store, _metadata, _graphs),
    do: {:error, Error.new(:invalid_input, :semantic_snapshot)}

  defp validate_graphs(graphs) do
    if graphs != [] and Enum.all?(graphs, &registered_graph?/1),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :semantic_snapshot_graphs)}
  end

  defp registered_graph?(graph) when is_binary(graph) do
    match?({:ok, _family}, GraphRegistry.identify(graph))
  end

  defp registered_graph?(_graph), do: false

  defp graph_counts(store, graphs) do
    Enum.reduce_while(graphs, {:ok, %{}}, fn graph, {:ok, counts} ->
      case QuadOperations.graph_quad_count(store.db, store.dict_manager, RDF.iri(graph)) do
        {:ok, count} when is_integer(count) and count >= 0 ->
          {:cont, {:ok, Map.put(counts, graph, count)}}

        {:error, reason} ->
          {:halt, {:error, BackendFailure.translate(reason, :semantic_snapshot)}}
      end
    end)
  end

  defp export_existing(store, counts) do
    graphs =
      counts
      |> Enum.filter(fn {_graph, count} -> count > 0 end)
      |> Enum.map(fn {graph, _count} -> RDF.iri(graph) end)

    case graphs do
      [] -> {:ok, RDF.Dataset.new()}
      values -> Exporter.export_multiple_graphs(store.db, store.dict_manager, values)
    end
  end

  defp metadata(store, counts) do
    Enum.reduce_while(counts, {:ok, %{}}, fn {graph, count}, {:ok, metadata} ->
      if count == 0 do
        {:cont, {:ok, Map.put(metadata, graph, nil)}}
      else
        case GraphMetadata.read(store, graph) do
          {:ok, value} -> {:cont, {:ok, Map.put(metadata, graph, value)}}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end
    end)
  end

  defp revisions(store, graphs) do
    Enum.reduce_while(graphs, {:ok, %{}}, fn graph, {:ok, revisions} ->
      case Metadata.graph_revision(store, graph) do
        {:ok, revision} when is_integer(revision) and revision >= 0 ->
          {:cont, {:ok, Map.put(revisions, graph, revision)}}

        {:ok, nil} ->
          {:cont, {:ok, Map.put(revisions, graph, 0)}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}

        _invalid ->
          {:halt, {:error, Error.new(:corrupt, :semantic_snapshot_revision)}}
      end
    end)
  end
end

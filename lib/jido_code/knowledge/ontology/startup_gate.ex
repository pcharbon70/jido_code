defmodule JidoCode.Knowledge.Ontology.StartupGate do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Vocabulary
  alias JidoCode.Knowledge.Validation.ShapeCatalog
  alias TripleStore.QuadOperations

  @spec verify(TripleStore.store()) :: :ok | {:error, Error.t()}
  def verify(store) do
    case QuadOperations.graphs_summary(store.db) do
      {:ok, summary} -> verify_summary(store, summary)
      {:error, reason} -> {:error, BackendFailure.translate(reason, :verify_semantic_startup)}
    end
  end

  defp verify_summary(store, summary) do
    if Enum.any?(Map.keys(summary), &ontology_graph?/1) do
      summary
      |> Map.keys()
      |> Enum.reject(&substrate_graph?/1)
      |> Enum.reduce_while(:ok, fn graph, :ok -> verify_graph(store, graph) end)
    else
      :ok
    end
  end

  defp verify_graph(store, %RDF.IRI{} = graph) do
    graph_iri = RDF.IRI.to_string(graph)

    with {:ok, family} <- GraphRegistry.identify(graph_iri),
         {:ok, metadata} when is_map(metadata) <- GraphMetadata.read(store, graph_iri),
         true <- recognized_version?(family, graph_iri, metadata),
         true <- complete_enough?(metadata) do
      {:cont, :ok}
    else
      _invalid -> {:halt, {:error, Error.new(:incompatible, :required_graph_migration)}}
    end
  end

  defp verify_graph(_store, _invalid),
    do: {:halt, {:error, Error.new(:corrupt, :verify_semantic_startup)}}

  defp substrate_graph?(:default), do: true

  defp substrate_graph?(%RDF.IRI{} = graph) do
    RDF.IRI.to_string(graph) == Vocabulary.system_graph()
  end

  defp substrate_graph?(_graph), do: false

  defp recognized_version?(family, graph_iri, metadata) do
    with "https://jido.run/ontology/release/" <> version <- metadata.ontology_version do
      ShapeCatalog.known_versions?(version, version) and
        (family != :ontology or graph_iri == "https://jido.run/graph/ontology/#{version}")
    else
      _invalid -> false
    end
  end

  defp ontology_graph?(%RDF.IRI{} = graph),
    do: match?({:ok, :ontology}, GraphRegistry.identify(graph))

  defp ontology_graph?(_graph), do: false

  defp complete_enough?(%{family: :run_attempt, completeness_state: state}),
    do: state in [:building, :complete]

  defp complete_enough?(metadata), do: metadata.completeness_state == :complete
end

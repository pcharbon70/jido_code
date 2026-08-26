defmodule JidoCode.Knowledge.RepositoryWiki.Graph do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def create_target(graph_iri, repository_iri, activity_iri, created_at, additions) do
    with {:ok, :repository_wiki} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(repository_iri),
         :ok <- ResourceIdentity.validate(activity_iri),
         %DateTime{} <- created_at,
         {:ok, metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: repository_iri,
             ontology_version: "https://jido.run/ontology/release/1.5.0",
             creation_activity: activity_iri,
             created_at: created_at,
             lifecycle_state: :open,
             completeness_state: :building,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :repository_wiki,
         graph_iri: graph_iri,
         operation: :create,
         metadata: metadata,
         additions: metadata_quads ++ additions,
         supersessions: [],
         invalidations: [],
         removals: []
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_graph_create)
    end
  end

  def append_target(graph_iri, revision, additions)
      when is_integer(revision) and revision > 0 and is_list(additions) do
    with {:ok, :repository_wiki} <- GraphRegistry.identify(graph_iri) do
      {:ok,
       %{
         family: :repository_wiki,
         graph_iri: graph_iri,
         operation: :append,
         metadata: %{lifecycle_state: :open},
         additions: additions,
         supersessions: [],
         invalidations: [],
         removals: []
       }}
    end
  end

  def append_target(_graph_iri, _revision, _additions),
    do: invalid(:repository_wiki_graph_append)

  def close_target(metadata, repository_iri, closed_at, additions, removals) do
    graph_iri = metadata[:graph_iri]

    with {:ok, :repository_wiki} <- GraphRegistry.identify(graph_iri),
         true <- metadata[:family] == :repository_wiki,
         true <- metadata[:owner_scope] == repository_iri,
         true <- metadata[:lifecycle_state] == :open,
         true <- metadata[:completeness_state] == :building,
         %DateTime{} <- closed_at,
         {:ok, closed_metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: repository_iri,
             ontology_version: metadata.ontology_version,
             creation_activity: metadata.creation_activity,
             created_at: metadata.created_at,
             lifecycle_state: :closed,
             completeness_state: :complete,
             closed_at: closed_at,
             graph_revision: metadata.graph_revision
           }) do
      {:ok,
       %{
         family: :repository_wiki,
         graph_iri: graph_iri,
         operation: :close,
         metadata: closed_metadata,
         additions:
           [
             {graph_iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Closed")},
             {graph_iri, @jf <> "completenessState", RDF.iri(@concept <> "Complete")},
             {graph_iri, @jf <> "closedAt", RDF.XSD.DateTime.new(closed_at)}
           ] ++ additions,
         supersessions: [],
         invalidations: [],
         removals:
           [
             {graph_iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Open")},
             {graph_iri, @jf <> "completenessState", RDF.iri(@concept <> "Building")}
           ] ++ removals
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_graph_close)
    end
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

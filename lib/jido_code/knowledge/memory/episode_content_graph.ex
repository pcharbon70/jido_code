defmodule JidoCode.Knowledge.Memory.EpisodeContentGraph do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  def target(graph, scope, activity, recorded_at, additions)
      when is_list(additions) and is_struct(recorded_at, DateTime) do
    with {:ok, :episode_content} <- GraphRegistry.identify(graph),
         :ok <- ResourceIdentity.validate(scope),
         :ok <- ResourceIdentity.validate(activity),
         {:ok, metadata} <-
           GraphMetadata.new(graph, %{
             owner_scope: scope,
             ontology_version: "https://jido.run/ontology/release/1.2.0",
             creation_activity: activity,
             created_at: recorded_at,
             closed_at: recorded_at,
             lifecycle_state: :closed,
             completeness_state: :complete,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :episode_content,
         graph_iri: graph,
         operation: :create,
         metadata: metadata,
         additions: metadata_quads ++ additions,
         supersessions: [],
         invalidations: [],
         removals: []
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :episode_content_graph)}
    end
  end

  def target(_graph, _scope, _activity, _recorded_at, _additions),
    do: {:error, Error.new(:invalid_input, :episode_content_graph)}
end

defmodule JidoCode.Knowledge.Memory.ContentLifecycleGraph do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  def target(graph, revision, scope, activity, recorded_at, additions)
      when is_integer(revision) and revision >= 0 and is_list(additions) and
             is_struct(recorded_at, DateTime) do
    with {:ok, :content_lifecycle} <- GraphRegistry.identify(graph),
         :ok <- ResourceIdentity.validate(scope),
         :ok <- ResourceIdentity.validate(activity) do
      if revision == 0 do
        create(graph, scope, activity, recorded_at, additions)
      else
        {:ok,
         %{
           family: :content_lifecycle,
           graph_iri: graph,
           operation: :append,
           metadata: %{lifecycle_state: :open},
           additions: additions,
           supersessions: [],
           invalidations: [],
           removals: []
         }}
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  end

  def target(_graph, _revision, _scope, _activity, _recorded_at, _additions), do: invalid()

  defp create(graph, scope, activity, recorded_at, additions) do
    with {:ok, metadata} <-
           GraphMetadata.new(graph, %{
             owner_scope: scope,
             ontology_version: "https://jido.run/ontology/release/1.2.0",
             creation_activity: activity,
             created_at: recorded_at,
             lifecycle_state: :open,
             completeness_state: :complete,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :content_lifecycle,
         graph_iri: graph,
         operation: :create,
         metadata: metadata,
         additions: metadata_quads ++ additions,
         supersessions: [],
         invalidations: [],
         removals: []
       }}
    end
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :content_lifecycle_graph)}
end

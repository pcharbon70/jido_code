defmodule JidoCode.Knowledge.Control.Graph do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @spec repository_control(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def repository_control(repository_iri) do
    GraphRegistry.graph_iri(:repository_control, %{repository: repository_iri})
  end

  @spec target(String.t(), non_neg_integer(), String.t(), String.t(), DateTime.t(), list()) ::
          {:ok, map()} | {:error, Error.t()}
  def target(graph_iri, revision, owner_scope, activity, created_at, additions)
      when is_integer(revision) and revision >= 0 and is_list(additions) do
    with {:ok, :repository_control} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, created_at) do
      if revision == 0 do
        create_target(graph_iri, owner_scope, activity, created_at, additions)
      else
        {:ok,
         %{
           family: :repository_control,
           graph_iri: graph_iri,
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
      _invalid -> invalid(:control_graph_target)
    end
  end

  def target(_graph, _revision, _scope, _activity, _created_at, _additions),
    do: invalid(:control_graph_target)

  defp create_target(graph, scope, activity, created_at, additions) do
    with {:ok, metadata} <-
           GraphMetadata.new(graph, %{
             owner_scope: scope,
             ontology_version: "https://jido.run/ontology/release/1.0.0",
             creation_activity: activity,
             created_at: created_at,
             lifecycle_state: :open,
             completeness_state: :complete,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :repository_control,
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

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

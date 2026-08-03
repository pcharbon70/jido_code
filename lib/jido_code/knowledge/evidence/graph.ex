defmodule JidoCode.Knowledge.Evidence.Graph do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @spec evidence_graph(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def evidence_graph(repository_iri),
    do: GraphRegistry.graph_iri(:evidence, %{repository: repository_iri})

  @spec target(String.t(), non_neg_integer(), String.t(), String.t(), DateTime.t(), list()) ::
          {:ok, map()} | {:error, Error.t()}
  def target(graph_iri, revision, owner_scope, activity, recorded_at, additions)
      when is_integer(revision) and revision >= 0 and is_list(additions) do
    with {:ok, :evidence} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, recorded_at) do
      if revision == 0 do
        create_target(graph_iri, owner_scope, activity, recorded_at, additions)
      else
        {:ok,
         %{
           family: :evidence,
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
      _invalid -> invalid(:evidence_graph_target)
    end
  end

  def target(_graph, _revision, _scope, _activity, _recorded_at, _additions),
    do: invalid(:evidence_graph_target)

  defp create_target(graph, scope, activity, recorded_at, additions) do
    with {:ok, metadata} <-
           GraphMetadata.new(graph, %{
             owner_scope: scope,
             ontology_version: "https://jido.run/ontology/release/1.0.0",
             creation_activity: activity,
             created_at: recorded_at,
             lifecycle_state: :open,
             completeness_state: :complete,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :evidence,
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

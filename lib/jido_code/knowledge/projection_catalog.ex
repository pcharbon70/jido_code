defmodule JidoCode.Knowledge.ProjectionCatalog do
  @moduledoc """
  Closed set of consumer-safe projection decoders over catalog query results.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ProjectionDefinition
  alias JidoCode.Knowledge.QueryCatalog

  @version "1.0.0"
  @shapes [:scalar, :table, :timeline, :tree, :bounded_subgraph]

  @shape_by_query %{
    dataset_revision: :scalar,
    graph_metadata: :table,
    ontology_compatibility: :table,
    command_receipt: :table,
    audit_reference: :table,
    graph_health: :scalar,
    resource_description: :bounded_subgraph,
    semantic_neighborhood: :bounded_subgraph,
    provenance_chain: :bounded_subgraph,
    supporting_claims: :table,
    contradicting_claims: :table,
    supersession: :table,
    transition_endpoint: :table,
    transition_history: :timeline,
    temporal_as_of: :timeline,
    graph_completeness: :table,
    derived_graph_freshness: :table
  }

  @spec version() :: String.t()
  def version, do: @version

  @spec shapes() :: [atom()]
  def shapes, do: @shapes

  @spec fetch(atom(), String.t()) :: {:ok, ProjectionDefinition.t()} | {:error, Error.t()}
  def fetch(name, @version) when is_atom(name) do
    with {:ok, shape} <- Map.fetch(@shape_by_query, name),
         {:ok, _query} <- QueryCatalog.fetch(name, QueryCatalog.version()) do
      {:ok,
       %ProjectionDefinition{
         name: name,
         version: @version,
         query_name: name,
         query_version: QueryCatalog.version(),
         shape: shape,
         purpose: "Consumer-safe #{shape} projection for #{name}.",
         decoder: :attributable_copy,
         compatibility_notes: "Initial Phase 5 projection contract."
       }}
    else
      _invalid -> invalid()
    end
  end

  def fetch(_name, _version), do: invalid()

  @spec digest() :: String.t()
  def digest do
    @shape_by_query
    |> Enum.sort()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :projection_catalog)}
end

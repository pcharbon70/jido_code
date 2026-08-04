defmodule JidoCode.Product.QuerySecurity do
  @moduledoc """
  Closed product-query admission policy.

  Product surfaces cannot select query names, versions, graph variables, or
  arbitrary parameter keys. This module is independent of graph authorization,
  which the knowledge query boundary repeats against the actor scope.
  """

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @version "1.7.0"
  @query_parameters %{
    dataset_revision: [],
    factory_repository_cohort: [:graph, :resource],
    work_lens: [:graph, :state],
    active_attempts: [:graph],
    knowledge_by_scope: [:graph, :resource]
  }
  @work_states [:eligible, :blocked, :executing, :awaiting_decision]

  @spec execute(function(), atom(), String.t(), map(), AuthorityContext.t(), String.t(), list()) ::
          term()
  def execute(query, name, version, parameters, authority, scope_iri, options)
      when is_function(query, 6) and is_map(parameters) and is_list(options) do
    with :ok <- validate(name, version, parameters),
         %AuthorityContext{} <- authority,
         :ok <- ResourceIdentity.validate(scope_iri),
         true <- options == [] do
      query.(name, version, parameters, authority, scope_iri, options)
    else
      _invalid -> {:error, Error.new(:invalid_input, :product_query)}
    end
  end

  @spec validate(atom(), String.t(), map()) :: :ok | {:error, Error.t()}
  def validate(name, @version, parameters) when is_map(parameters) do
    with {:ok, keys} <- Map.fetch(@query_parameters, name),
         true <- parameters |> Map.keys() |> Enum.sort() == Enum.sort(keys),
         :ok <- validate_parameters(name, parameters) do
      :ok
    else
      _invalid -> {:error, Error.new(:invalid_input, :product_query)}
    end
  end

  def validate(_name, _version, _parameters),
    do: {:error, Error.new(:invalid_input, :product_query)}

  defp validate_parameters(:dataset_revision, %{}), do: :ok

  defp validate_parameters(:factory_repository_cohort, parameters),
    do: graph_and_resource(parameters, :factory_catalog)

  defp validate_parameters(:work_lens, %{graph: graph, state: state})
       when state in @work_states,
       do: graph_family(graph, :repository_control)

  defp validate_parameters(:active_attempts, %{graph: graph}),
    do: graph_family(graph, :repository_control)

  defp validate_parameters(:knowledge_by_scope, parameters),
    do: graph_and_resource(parameters, :memory)

  defp validate_parameters(_name, _parameters),
    do: {:error, Error.new(:invalid_input, :product_query)}

  defp graph_and_resource(%{graph: graph, resource: resource}, family) do
    with :ok <- graph_family(graph, family), do: ResourceIdentity.validate(resource)
  end

  defp graph_family(graph, expected) do
    case GraphRegistry.identify(graph) do
      {:ok, ^expected} -> :ok
      _invalid -> {:error, Error.new(:invalid_input, :product_query_graph)}
    end
  end
end

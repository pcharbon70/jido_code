defmodule JidoCode.Product.RepositoryWikiQuerySecurity do
  @moduledoc """
  Closed product admission for repository-wiki reviewed queries.

  Browser input can select only bounded slugs, dependency names, and guide
  audiences. It cannot select query text, graph IRIs, predicates, or joins.
  """

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @version "2.10.0"
  @parameters %{
    repository_wiki_enrollment_detail: [:graph, :resource],
    repository_wiki_current_edition: [:control_graph, :wiki_graph, :resource],
    repository_wiki_edition_history: [:graph, :resource],
    repository_wiki_edition_comparison: [
      :control_graph,
      :left_edition,
      :left_graph,
      :resource,
      :right_edition,
      :right_graph
    ],
    repository_wiki_preview_detail: [:edition, :graph, :preview, :resource],
    repository_wiki_navigation_tree: [:graph, :resource],
    repository_wiki_page_by_slug: [:edition, :graph, :resource, :slug],
    repository_wiki_page_detail: [:graph, :resource],
    repository_wiki_backlinks: [:graph, :resource],
    repository_wiki_source_references: [:graph, :resource],
    repository_wiki_dependency_lookup: [:dependency, :edition, :graph, :resource],
    repository_wiki_guide_collection: [:audience, :edition, :graph, :resource],
    repository_wiki_known_gaps: [:graph, :resource],
    repository_wiki_source_coverage: [:graph, :resource],
    repository_wiki_freshness: [:graph, :resource]
  }
  @audiences ~w[user developer operator contributor reference architecture policy unknown]
  @slug ~r/^[a-z0-9][a-z0-9-]{0,159}$/u
  @dependency ~r/^[a-z0-9][a-z0-9_.-]{0,159}$/u

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
      _invalid -> {:error, Error.new(:invalid_input, :repository_wiki_product_query)}
    end
  end

  @spec validate(atom(), String.t(), map()) :: :ok | {:error, Error.t()}
  def validate(name, @version, parameters) when is_map(parameters) do
    with {:ok, keys} <- Map.fetch(@parameters, name),
         true <- Enum.sort(Map.keys(parameters)) == Enum.sort(keys),
         :ok <- validate_parameters(name, parameters) do
      :ok
    else
      _invalid -> {:error, Error.new(:invalid_input, :repository_wiki_product_query)}
    end
  end

  def validate(_name, _version, _parameters),
    do: {:error, Error.new(:invalid_input, :repository_wiki_product_query)}

  defp validate_parameters(:repository_wiki_current_edition, parameters) do
    with :ok <- graph(parameters.control_graph, :repository_control),
         :ok <- graph(parameters.wiki_graph, :repository_wiki),
         :ok <- resource(parameters.resource) do
      :ok
    end
  end

  defp validate_parameters(:repository_wiki_edition_comparison, parameters) do
    with :ok <- graph(parameters.control_graph, :repository_control),
         :ok <- graph(parameters.left_graph, :repository_wiki),
         :ok <- graph(parameters.right_graph, :repository_wiki),
         :ok <- resource(parameters.resource),
         :ok <- resource(parameters.left_edition),
         :ok <- resource(parameters.right_edition),
         true <- parameters.left_edition != parameters.right_edition,
         true <- parameters.left_graph != parameters.right_graph do
      :ok
    else
      _invalid -> invalid()
    end
  end

  defp validate_parameters(name, %{graph: graph_iri, resource: resource_iri} = parameters) do
    family =
      if name in [:repository_wiki_enrollment_detail, :repository_wiki_edition_history],
        do: :repository_control,
        else: :repository_wiki

    with :ok <- graph(graph_iri, family),
         :ok <- resource(resource_iri),
         :ok <- optional_edition(parameters),
         :ok <- optional_preview(parameters),
         :ok <- optional_slug(parameters),
         :ok <- optional_dependency(parameters),
         :ok <- optional_audience(parameters) do
      :ok
    end
  end

  defp validate_parameters(_name, _parameters),
    do: {:error, Error.new(:invalid_input, :repository_wiki_product_query)}

  defp optional_edition(%{edition: value}), do: resource(value)
  defp optional_edition(_parameters), do: :ok

  defp optional_preview(%{preview: value}), do: resource(value)
  defp optional_preview(_parameters), do: :ok

  defp optional_slug(%{slug: value}) when is_binary(value) do
    if Regex.match?(@slug, value), do: :ok, else: invalid()
  end

  defp optional_slug(_parameters), do: :ok

  defp optional_dependency(%{dependency: value}) when is_binary(value) do
    if Regex.match?(@dependency, value), do: :ok, else: invalid()
  end

  defp optional_dependency(_parameters), do: :ok

  defp optional_audience(%{audience: value}) when value in @audiences, do: :ok
  defp optional_audience(%{audience: _value}), do: invalid()
  defp optional_audience(_parameters), do: :ok

  defp graph(value, family) do
    case GraphRegistry.identify(value) do
      {:ok, ^family} -> :ok
      _invalid -> invalid()
    end
  end

  defp resource(value), do: ResourceIdentity.validate(value)
  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_product_query)}
end

defmodule JidoCode.Knowledge.CatalogQueryRequest do
  @moduledoc false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryParameters
  alias JidoCode.Knowledge.ResourceIdentity

  @derive {Inspect, only: [:query_name, :query_version, :scope_iri, :evaluated_at, :graph_iris]}
  @enforce_keys [
    :query_name,
    :query_version,
    :definition,
    :parameters,
    :bound_query,
    :graph_iris,
    :authority,
    :scope_iri,
    :evaluated_at
  ]
  defstruct @enforce_keys ++ [consistency: nil]

  @type t :: %__MODULE__{}

  @spec new(atom(), String.t(), map(), AuthorityContext.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(name, version, parameters, authority, scope_iri, options \\ [])

  def new(name, version, parameters, %AuthorityContext{} = authority, scope_iri, options) do
    evaluated_at = Keyword.get(options, :evaluated_at, DateTime.utc_now())

    with {:ok, definition} <- QueryCatalog.fetch(name, version),
         :ok <- ResourceIdentity.validate(scope_iri),
         true <- match?(%DateTime{}, evaluated_at),
         {:ok, binding} <- QueryParameters.bind(definition, parameters) do
      {:ok,
       %__MODULE__{
         query_name: name,
         query_version: version,
         definition: definition,
         parameters: binding.normalized,
         bound_query: binding.query,
         graph_iris: binding.graph_iris,
         authority: authority,
         scope_iri: scope_iri,
         evaluated_at: evaluated_at,
         consistency: Keyword.get(options, :consistency)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :catalog_query_request)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :catalog_query_request)}
  end

  def new(_name, _version, _parameters, _authority, _scope_iri, _options),
    do: {:error, Error.new(:invalid_input, :catalog_query_request)}
end

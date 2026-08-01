defmodule JidoCode.Knowledge.Repositories.Locator do
  @moduledoc """
  Validated, transient description of an external repository locator.

  Locator identity is based on provider host and provider-stable external ID.
  Owner/name is retained as observed address data and may change without
  changing either the locator or conceptual repository identity.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :provider_iri,
    :provider_host,
    :external_id,
    :canonical,
    :observed_address,
    :state,
    :observed_at,
    :relationships
  ]
  defstruct @enforce_keys

  @type state ::
          :active | :stale | :redirected | :inaccessible | :archived | :transferred | :deleted
  @type relationship_kind :: :alias | :mirror | :fork | :previous_location
  @type t :: %__MODULE__{}

  @states ~w[active stale redirected inaccessible archived transferred deleted]a
  @relationship_predicates %{
    alias: "http://www.w3.org/ns/prov#alternateOf",
    mirror: "http://www.w3.org/ns/prov#alternateOf",
    fork: "http://www.w3.org/ns/prov#wasDerivedFrom",
    previous_location: "http://www.w3.org/ns/prov#wasRevisionOf"
  }
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @dct_identifier "http://purl.org/dc/terms/identifier"
  @prov_at_location "http://www.w3.org/ns/prov#atLocation"
  @jf "https://jido.run/ontology/factory#"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, stable} <-
           ResourceIdentity.repository_locator(attributes[:provider], attributes[:external_id]),
         {:ok, address} <-
           ResourceIdentity.repository_locator(
             attributes[:provider],
             attributes[:owner],
             attributes[:name]
           ),
         {:ok, provider_iri} <- ResourceIdentity.provider_host(attributes[:provider]),
         {:ok, provider_host} <- provider_host(address.canonical),
         state when state in @states <- attributes[:state],
         %DateTime{} = observed_at <- attributes[:observed_at],
         {:ok, relationships} <- relationships(attributes[:relationships] || []) do
      {:ok,
       %__MODULE__{
         iri: stable.iri,
         provider_iri: provider_iri,
         provider_host: provider_host,
         external_id: String.trim(attributes[:external_id]),
         canonical: stable.canonical,
         observed_address: address.canonical,
         state: state,
         observed_at: DateTime.truncate(observed_at, :microsecond),
         relationships: relationships
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = locator) do
    base = [
      {locator.iri, @rdf_type, RDF.iri(@jf <> "RepositoryLocator")},
      {locator.iri, @jf <> "canonicalLocator", RDF.XSD.String.new(locator.canonical)},
      {locator.iri, @jf <> "locatorAddress", RDF.XSD.String.new(locator.observed_address)},
      {locator.iri, @dct_identifier, RDF.XSD.String.new(locator.external_id)},
      {locator.iri, @prov_at_location, RDF.iri(locator.provider_iri)},
      {locator.iri, @jf <> "locatorState", RDF.iri(state_iri(locator.state))},
      {locator.iri, @jf <> "sourceObservedAt", RDF.XSD.DateTime.new(locator.observed_at)}
    ]

    base ++
      Enum.map(locator.relationships, fn %{kind: kind, locator_iri: related} ->
        {locator.iri, Map.fetch!(@relationship_predicates, kind), RDF.iri(related)}
      end)
  end

  @spec state_iri(state()) :: String.t()
  def state_iri(state) when state in @states do
    @jf <> "Locator" <> (state |> Atom.to_string() |> Macro.camelize())
  end

  @spec safe_map(t()) :: map()
  def safe_map(%__MODULE__{} = locator) do
    Map.take(Map.from_struct(locator), [
      :iri,
      :provider_iri,
      :provider_host,
      :external_id,
      :canonical,
      :observed_address,
      :state,
      :observed_at,
      :relationships
    ])
  end

  defp relationships(values) when is_list(values) and length(values) <= 20 do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      with %{kind: kind, locator_iri: locator_iri} <- value,
           true <- Map.has_key?(@relationship_predicates, kind),
           :ok <- ResourceIdentity.validate(locator_iri),
           false <- Enum.any?(acc, &(&1.locator_iri == locator_iri and &1.kind == kind)) do
        {:cont, {:ok, [value | acc]}}
      else
        _invalid -> {:halt, invalid()}
      end
    end)
    |> case do
      {:ok, relationships} -> {:ok, Enum.reverse(relationships)}
      error -> error
    end
  end

  defp relationships(_values), do: invalid()

  defp provider_host(canonical) do
    case String.split(canonical, "/", parts: 2) do
      [host, _address] -> {:ok, host}
      _invalid -> invalid()
    end
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_locator)}
end

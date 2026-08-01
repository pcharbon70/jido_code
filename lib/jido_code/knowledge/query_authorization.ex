defmodule JidoCode.Knowledge.QueryAuthorization do
  @moduledoc false

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CatalogQueryRequest
  alias JidoCode.Knowledge.Error

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @policy_graph "https://jido.run/graph/factory/policy"
  @grant @jf <> "AuthorizationGrant"
  @delegation @jf <> "Delegation"
  @all_scopes "https://jido.run/ontology/concept/AllScopes"
  @max_authority_resources 100

  @spec authorize(CatalogQueryRequest.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def authorize(%CatalogQueryRequest{} = request, snapshot) when is_map(snapshot) do
    dataset = snapshot.dataset
    grants = matching_grants(request, dataset)

    with [grant] <- grants,
         :ok <- graph_scope_allowed(request, snapshot.graph_metadata),
         {:ok, delegation} <- delegated_authority(request, dataset) do
      {:ok,
       %{
         actor_iri: request.authority.actor_iri,
         principal_iri: request.authority.principal_iri,
         grant_iri: grant,
         delegation_iri: delegation,
         capability: request.definition.capability,
         scope_iri: request.scope_iri,
         graph_iris: request.graph_iris
       }}
    else
      _unauthorized -> unauthorized()
    end
  rescue
    _error -> unauthorized()
  end

  def authorize(_request, _snapshot), do: unauthorized()

  defp matching_grants(request, dataset) do
    grants = authority_subjects(dataset, @grant)

    if length(grants) <= @max_authority_resources do
      Enum.filter(grants, fn grant ->
        values = subject_values(dataset, grant)

        single_iri?(values, @jf <> "grantee", request.authority.actor_iri) and
          single_iri?(
            values,
            @jf <> "grantsCapability",
            Authorization.capability_iri(request.definition.capability)
          ) and
          scope_allowed?(values, request.scope_iri) and
          time_allowed?(values, request.evaluated_at) and
          Map.get(values, @prov_invalidated, []) == []
      end)
    else
      []
    end
  end

  defp graph_scope_allowed(request, metadata) do
    allowed? =
      Enum.all?(request.graph_iris, fn graph ->
        case Map.get(metadata, graph) do
          %{owner_scope: scope} -> scope == request.scope_iri
          _missing -> false
        end
      end)

    if allowed?, do: :ok, else: unauthorized()
  end

  defp delegated_authority(request, _dataset)
       when is_nil(request.authority.delegated_agent_iri) and
              is_nil(request.authority.delegation_iri) do
    if request.authority.principal_iri == request.authority.actor_iri,
      do: {:ok, nil},
      else: unauthorized()
  end

  defp delegated_authority(request, dataset) do
    delegations = authority_subjects(dataset, @delegation)

    matching =
      if length(delegations) <= @max_authority_resources do
        Enum.filter(delegations, fn delegation ->
          values = subject_values(dataset, delegation)
          boundaries = iri_values(values, @jf <> "graphBoundary")

          request.authority.principal_iri == request.authority.delegated_agent_iri and
            single_iri?(values, @jf <> "delegatingActor", request.authority.actor_iri) and
            single_iri?(
              values,
              @jf <> "delegatedAgent",
              request.authority.delegated_agent_iri
            ) and
            single_iri?(
              values,
              @jf <> "grantsCapability",
              Authorization.capability_iri(request.definition.capability)
            ) and
            scope_allowed?(values, request.scope_iri) and
            time_allowed?(values, request.evaluated_at) and
            (boundaries == [] or Enum.all?(request.graph_iris, &(&1 in boundaries))) and
            Map.get(values, @prov_invalidated, []) == []
        end)
      else
        []
      end

    case matching do
      [delegation] when delegation == request.authority.delegation_iri -> {:ok, delegation}
      _invalid -> unauthorized()
    end
  end

  defp authority_subjects(dataset, class) do
    dataset
    |> RDF.Dataset.quads()
    |> Enum.flat_map(fn
      {%RDF.IRI{value: subject}, %RDF.IRI{value: @rdf_type}, %RDF.IRI{value: ^class},
       %RDF.IRI{value: @policy_graph}} ->
        [subject]

      _other ->
        []
    end)
    |> Enum.uniq()
  end

  defp subject_values(dataset, subject) do
    dataset
    |> RDF.Dataset.quads()
    |> Enum.reduce(%{}, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: predicate}, object,
       %RDF.IRI{value: @policy_graph}},
      values ->
        Map.update(values, predicate, [object], &[object | &1])

      _other, values ->
        values
    end)
  end

  defp scope_allowed?(values, scope) do
    single_iri?(values, @jf <> "validFor", scope) or
      single_iri?(values, @jf <> "scopeMode", @all_scopes)
  end

  defp time_allowed?(values, instant) do
    valid_from = single_time(values, @jf <> "validFrom")
    valid_to = single_time(values, @jf <> "validTo")

    not is_nil(valid_from) and not is_nil(valid_to) and
      DateTime.compare(valid_from, instant) in [:lt, :eq] and
      DateTime.compare(instant, valid_to) == :lt
  end

  defp iri_values(values, predicate) do
    values
    |> Map.get(predicate, [])
    |> Enum.flat_map(fn
      %RDF.IRI{value: value} -> [value]
      _other -> []
    end)
    |> Enum.uniq()
  end

  defp single_iri?(values, predicate, expected) do
    case Map.get(values, predicate, []) do
      [%RDF.IRI{value: ^expected}] -> true
      _other -> false
    end
  end

  defp single_time(values, predicate) do
    case Map.get(values, predicate, []) do
      [%RDF.Literal{} = literal] ->
        case RDF.Literal.value(literal) do
          %DateTime{} = value -> value
          _invalid -> nil
        end

      _other ->
        nil
    end
  end

  defp unauthorized, do: {:error, Error.new(:unauthorized, :catalog_query)}
end

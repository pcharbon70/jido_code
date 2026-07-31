defmodule JidoCode.Knowledge.Authorization do
  @moduledoc """
  Fail-closed semantic capability evaluation for direct actors.

  Delegated authority is added by the Phase 4 authority policy section. Until
  then, the authenticated principal and accountable actor must be identical.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @grant @jf <> "AuthorizationGrant"
  @grantee @jf <> "grantee"
  @capability @jf <> "grantsCapability"
  @scope @jf <> "validFor"
  @scope_mode @jf <> "scopeMode"
  @valid_from @jf <> "validFrom"
  @valid_to @jf <> "validTo"
  @all_scopes "https://jido.run/ontology/concept/AllScopes"
  @capability_base "https://jido.run/ontology/capability/"
  @max_grants 100

  @spec authorize(CommandEnvelope.t(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def authorize(%CommandEnvelope{} = envelope, definition, snapshot)
      when is_map(definition) and is_map(snapshot) do
    with true <- envelope.principal_iri == envelope.actor_iri,
         true <- is_nil(envelope.delegated_agent_iri),
         grants when length(grants) <= @max_grants <- grant_subjects(snapshot.dataset),
         grant when is_binary(grant) <-
           Enum.find(grants, &authorized_grant?(&1, envelope, definition, snapshot.dataset)) do
      {:ok,
       %{
         actor_iri: envelope.actor_iri,
         principal_iri: envelope.principal_iri,
         delegation_iri: nil,
         grant_iri: grant,
         capability: definition.capability,
         scope_iri: envelope.scope_iri
       }}
    else
      _unauthorized -> {:error, Error.new(:unauthorized, :semantic_authorization)}
    end
  rescue
    _error -> {:error, Error.new(:unauthorized, :semantic_authorization)}
  end

  def authorize(_envelope, _definition, _snapshot),
    do: {:error, Error.new(:unauthorized, :semantic_authorization)}

  @spec capability_iri(atom()) :: String.t()
  def capability_iri(capability) when is_atom(capability),
    do: @capability_base <> Atom.to_string(capability)

  defp grant_subjects(dataset) do
    dataset
    |> RDF.Dataset.quads()
    |> Enum.flat_map(fn
      {%RDF.IRI{value: subject}, %RDF.IRI{value: @rdf_type}, %RDF.IRI{value: @grant}, _graph} ->
        [subject]

      _other ->
        []
    end)
    |> Enum.uniq()
  end

  defp authorized_grant?(grant, envelope, definition, dataset) do
    values = subject_values(dataset, grant)

    single_iri?(values, @grantee, envelope.actor_iri) and
      single_iri?(values, @capability, capability_iri(definition.capability)) and
      scope_allowed?(values, envelope.scope_iri) and
      time_allowed?(values, envelope.issued_at) and
      Map.get(values, @prov_invalidated, []) == []
  end

  defp scope_allowed?(values, scope) do
    single_iri?(values, @scope, scope) or single_iri?(values, @scope_mode, @all_scopes)
  end

  defp time_allowed?(values, issued_at) do
    valid_from = single_time(values, @valid_from)
    valid_to = single_time(values, @valid_to)

    not is_nil(valid_from) and not is_nil(valid_to) and
      DateTime.compare(valid_from, issued_at) in [:lt, :eq] and
      DateTime.compare(issued_at, valid_to) == :lt
  end

  defp subject_values(dataset, subject) do
    dataset
    |> RDF.Dataset.quads()
    |> Enum.reduce(%{}, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: predicate}, object, _graph}, values ->
        Map.update(values, predicate, [object], &[object | &1])

      _other, values ->
        values
    end)
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
end

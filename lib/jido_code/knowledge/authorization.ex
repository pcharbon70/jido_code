defmodule JidoCode.Knowledge.Authorization do
  @moduledoc """
  Fail-closed semantic capability and delegation evaluation.

  Grants and delegations are RDF in the factory policy graph. An accountable
  actor must hold exactly one matching grant, and delegated execution must also
  resolve exactly one constrained, current delegation.
  """

  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @grant @jf <> "AuthorizationGrant"
  @delegation @jf <> "Delegation"
  @grantee @jf <> "grantee"
  @capability @jf <> "grantsCapability"
  @scope @jf <> "validFor"
  @scope_mode @jf <> "scopeMode"
  @delegating_actor @jf <> "delegatingActor"
  @delegated_agent @jf <> "delegatedAgent"
  @command_class @jf <> "commandClass"
  @graph_boundary @jf <> "graphBoundary"
  @valid_from @jf <> "validFrom"
  @valid_to @jf <> "validTo"
  @all_scopes "https://jido.run/ontology/concept/AllScopes"
  @capability_base "https://jido.run/ontology/capability/"
  @policy_graph "https://jido.run/graph/factory/policy"
  @max_authority_resources 100

  @capabilities [
    :observation,
    :proposal,
    :control,
    :execution,
    :evidence,
    :decision,
    :memory,
    :ontology,
    :security,
    :source,
    :reasoner,
    :administrative,
    :harness,
    :experience_writer,
    :content_writer,
    :content_lifecycle_writer,
    :dataset_policy_writer
  ]

  @spec authorize(CommandEnvelope.t(), map(), ChangeSet.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def authorize(%CommandEnvelope{} = envelope, definition, %ChangeSet{} = change_set, snapshot)
      when is_map(definition) and is_map(snapshot) do
    authorize_at(envelope, definition, change_set, snapshot, envelope.issued_at)
  end

  def authorize(_envelope, _definition, _change_set, _snapshot),
    do: {:error, Error.new(:unauthorized, :semantic_authorization)}

  @spec authorize_at(CommandEnvelope.t(), map(), ChangeSet.t(), map(), DateTime.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def authorize_at(
        %CommandEnvelope{} = envelope,
        definition,
        %ChangeSet{} = change_set,
        snapshot,
        %DateTime{} = authority_time
      )
      when is_map(definition) and is_map(snapshot) do
    grants = matching_grants(envelope, definition, snapshot.dataset, authority_time)

    with true <- length(grants) == 1,
         {:ok, delegation} <-
           delegated_authority(
             envelope,
             definition,
             change_set,
             snapshot.dataset,
             authority_time
           ) do
      [grant] = grants

      {:ok,
       %{
         actor_iri: envelope.actor_iri,
         principal_iri: envelope.principal_iri,
         delegated_agent_iri: envelope.delegated_agent_iri,
         delegation_iri: delegation,
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

  def authorize_at(_envelope, _definition, _change_set, _snapshot, _authority_time),
    do: {:error, Error.new(:unauthorized, :semantic_authorization)}

  @spec capabilities() :: [atom()]
  def capabilities, do: @capabilities

  @spec capability_iri(atom()) :: String.t()
  def capability_iri(capability) when capability in @capabilities,
    do: @capability_base <> Atom.to_string(capability)

  @spec command_class_iri(String.t()) :: String.t()
  def command_class_iri(name) when is_binary(name),
    do: "https://jido.run/ontology/command/#{URI.encode(name, &URI.char_unreserved?/1)}"

  defp matching_grants(envelope, definition, dataset, authority_time) do
    grants = authority_subjects(dataset, @grant)

    if length(grants) <= @max_authority_resources do
      Enum.filter(
        grants,
        &authorized_grant?(&1, envelope, definition, dataset, authority_time)
      )
    else
      []
    end
  end

  defp authorized_grant?(grant, envelope, definition, dataset, authority_time) do
    values = subject_values(dataset, grant)

    single_iri?(values, @grantee, envelope.actor_iri) and
      single_iri?(values, @capability, capability_iri(definition.capability)) and
      scope_allowed?(values, envelope.scope_iri) and
      time_allowed?(values, authority_time) and
      Map.get(values, @prov_invalidated, []) == []
  end

  defp delegated_authority(envelope, _definition, _change_set, _dataset, _authority_time)
       when is_nil(envelope.delegated_agent_iri) and is_nil(envelope.delegation_iri) do
    if envelope.principal_iri == envelope.actor_iri,
      do: {:ok, nil},
      else: {:error, Error.new(:unauthorized, :semantic_authorization)}
  end

  defp delegated_authority(envelope, definition, change_set, dataset, authority_time) do
    delegations = authority_subjects(dataset, @delegation)

    matching =
      if length(delegations) <= @max_authority_resources do
        Enum.filter(
          delegations,
          &authorized_delegation?(
            &1,
            envelope,
            definition,
            change_set,
            dataset,
            authority_time
          )
        )
      else
        []
      end

    case matching do
      [delegation] when delegation == envelope.delegation_iri -> {:ok, delegation}
      _invalid -> {:error, Error.new(:unauthorized, :semantic_authorization)}
    end
  end

  defp authorized_delegation?(
         delegation,
         envelope,
         definition,
         change_set,
         dataset,
         authority_time
       ) do
    values = subject_values(dataset, delegation)
    boundaries = iri_values(values, @graph_boundary)

    envelope.principal_iri == envelope.delegated_agent_iri and
      envelope.actor_iri != envelope.delegated_agent_iri and
      single_iri?(values, @delegating_actor, envelope.actor_iri) and
      single_iri?(values, @delegated_agent, envelope.delegated_agent_iri) and
      single_iri?(values, @capability, capability_iri(definition.capability)) and
      single_iri?(values, @command_class, command_class_iri(envelope.command_type)) and
      scope_allowed?(values, envelope.scope_iri) and
      time_allowed?(values, authority_time) and
      boundaries_allowed?(boundaries, change_set.target_graphs) and
      Map.get(values, @prov_invalidated, []) == []
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
    single_iri?(values, @scope, scope) or single_iri?(values, @scope_mode, @all_scopes)
  end

  defp time_allowed?(values, issued_at) do
    valid_from = single_time(values, @valid_from)
    valid_to = single_time(values, @valid_to)

    not is_nil(valid_from) and not is_nil(valid_to) and
      DateTime.compare(valid_from, issued_at) in [:lt, :eq] and
      DateTime.compare(issued_at, valid_to) == :lt
  end

  defp boundaries_allowed?([], _targets), do: true
  defp boundaries_allowed?(boundaries, targets), do: Enum.all?(targets, &(&1 in boundaries))

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
end

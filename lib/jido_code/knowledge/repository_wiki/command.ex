defmodule JidoCode.Knowledge.RepositoryWiki.Command do
  @moduledoc false

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @spec build(String.t(), String.t(), [map()], [tuple()], map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def build(type, identity_material, targets, guards, attributes, options)
      when is_binary(type) and is_binary(identity_material) and is_list(targets) and
             is_list(guards) and is_map(attributes) and is_list(options) do
    with {:ok, command_iri} <- identity(type, identity_material),
         {:ok, envelope} <-
           CommandEnvelope.new(
             %{
               command_type: type,
               command_version:
                 Map.get(attributes, :command_version, Protocol.semantic_version()),
               command_iri: command_iri,
               principal_iri: attributes[:principal_iri],
               actor_iri: attributes[:actor_iri],
               delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
               delegation_iri: Map.get(attributes, :delegation_iri),
               scope_iri: attributes[:scope_iri],
               idempotency_key: Map.get(attributes, :idempotency_key, command_iri),
               correlation_iri: attributes[:correlation_iri],
               causation_iri: attributes[:causation_iri],
               ontology_version: Protocol.ontology_version(),
               shape_version: Protocol.ontology_version(),
               expected_dataset_revision: attributes[:expected_dataset_revision],
               expected_graph_revisions: attributes[:expected_graph_revisions],
               reason: attributes[:reason],
               payload: %{
                 changes: targets,
                 guards: guards,
                 repository_iri: attributes[:repository_iri],
                 enrollment_revision: attributes[:enrollment_revision],
                 source_fence: attributes[:source_fence],
                 compiler_profile: Protocol.compiler_profile(),
                 compiler_digest: Protocol.compiler_digest()
               }
             },
             options
           ) do
      {:ok, envelope}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  def build(_type, _material, _targets, _guards, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :repository_wiki_command)}

  @spec identity(String.t(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def identity(type, material) when is_binary(type) and is_binary(material) do
    ResourceIdentity.deterministic(
      :command_request,
      Enum.join([type, material], "\n")
    )
  end

  def identity(_type, _material),
    do: {:error, Error.new(:invalid_input, :repository_wiki_command_identity)}
end

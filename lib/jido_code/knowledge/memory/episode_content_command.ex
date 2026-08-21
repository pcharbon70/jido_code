defmodule JidoCode.Knowledge.Memory.EpisodeContentCommand do
  @moduledoc "Content-writer command for one complete immutable ciphertext segment."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.EpisodeContent
  alias JidoCode.Knowledge.Memory.EpisodeContentGraph
  alias JidoCode.Knowledge.ResourceIdentity

  def store(content, attributes, options \\ [])

  def store(%EpisodeContent{} = content, attributes, options) when is_map(attributes) do
    with true <- content.encrypted_before_command?,
         {:ok, graph} <-
           GraphRegistry.graph_iri(:episode_content, %{
             repository: content.repository_iri,
             content: content.iri
           }),
         true <- attributes[:expected_graph_revisions] == %{graph => 0},
         {:ok, command_iri} <- ResourceIdentity.deterministic(:command_request, content.iri),
         {:ok, target} <-
           EpisodeContentGraph.target(
             graph,
             attributes[:repository_scope_iri],
             command_iri,
             attributes[:recorded_at],
             EpisodeContent.statements(content)
           ) do
      CommandEnvelope.new(
        %{
          command_type: "StoreEpisodeContent",
          command_version: CommandRegistry.content_version(),
          command_iri: command_iri,
          principal_iri: attributes[:principal_iri],
          actor_iri: attributes[:actor_iri],
          delegated_agent_iri: attributes[:delegated_agent_iri],
          delegation_iri: attributes[:delegation_iri],
          scope_iri: attributes[:repository_scope_iri],
          idempotency_key: command_iri,
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.2.0",
          shape_version: "1.2.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: attributes[:expected_graph_revisions],
          reason: attributes[:reason],
          payload: %{
            changes: [target],
            guards: [{:subject_absent, graph, content.iri}],
            episode_content_iri: content.iri,
            encrypted_before_command: true,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :episode_content_command)}
    end
  end

  def store(_content, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :episode_content_command)}
end

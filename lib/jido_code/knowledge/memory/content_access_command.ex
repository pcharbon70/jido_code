defmodule JidoCode.Knowledge.Memory.ContentAccessCommand do
  @moduledoc "Semantic commands for authorization, consumption, and byte-free access outcomes."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ContentAccessOutcome
  alias JidoCode.Knowledge.Memory.ContentAccessPermit
  alias JidoCode.Knowledge.Memory.ContentLifecycleGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def authorize(
        %ContentAccessPermit{} = permit,
        repository_iri,
        revision,
        attributes,
        options \\ []
      ) do
    with {:ok, lifecycle_graph} <- graph(repository_iri) do
      build(
        "AuthorizeContentAccess",
        repository_iri,
        revision,
        permit.iri,
        ContentAccessPermit.statements(permit),
        [{:subject_absent, lifecycle_graph, permit.iri}],
        attributes,
        options
      )
    end
  end

  def consume(
        %ContentAccessPermit{} = permit,
        repository_iri,
        revision,
        attributes,
        options \\ []
      ) do
    with {:ok, activity_iri} <- consumption_iri(permit.iri),
         {:ok, lifecycle_graph} <- graph(repository_iri) do
      statements = [
        {activity_iri, @rdf_type, RDF.iri(@jf <> "ContentAccessActivity")},
        {activity_iri, @jf <> "consumesPermit", RDF.iri(permit.iri)},
        {activity_iri, @jf <> "accessState", RDF.iri(@concept <> "Consumed")},
        {activity_iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(attributes[:recorded_at])}
      ]

      build(
        "ConsumeContentAccess",
        repository_iri,
        revision,
        activity_iri,
        statements,
        [
          {:subject_present, lifecycle_graph, permit.iri},
          {:subject_absent, lifecycle_graph, activity_iri}
        ],
        attributes,
        options
      )
    end
  end

  def outcome(
        %ContentAccessPermit{} = permit,
        %ContentAccessOutcome{} = outcome,
        repository_iri,
        revision,
        attributes,
        options \\ []
      ) do
    with {:ok, activity_iri} <- consumption_iri(permit.iri),
         {:ok, lifecycle_graph} <- graph(repository_iri) do
      build(
        "RecordContentAccessOutcome",
        repository_iri,
        revision,
        outcome.iri,
        ContentAccessOutcome.statements(outcome),
        [
          {:subject_present, lifecycle_graph, activity_iri},
          {:subject_absent, lifecycle_graph, outcome.iri}
        ],
        attributes,
        options
      )
    end
  end

  def consumption_iri(permit_iri),
    do: ResourceIdentity.deterministic(:content_access_activity, permit_iri)

  defp build(type, repository_iri, revision, identity, statements, guards, attributes, options) do
    with {:ok, lifecycle_graph} <- graph(repository_iri),
         true <- attributes[:expected_graph_revisions] == %{lifecycle_graph => revision},
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, Enum.join([type, identity], "\n")),
         {:ok, target} <-
           ContentLifecycleGraph.target(
             lifecycle_graph,
             revision,
             attributes[:repository_scope_iri],
             command_iri,
             attributes[:recorded_at],
             statements
           ) do
      CommandEnvelope.new(
        %{
          command_type: type,
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
            guards: guards,
            content_access_iri: identity,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :content_access_command)}
    end
  end

  defp graph(repository_iri),
    do: GraphRegistry.graph_iri(:content_lifecycle, %{repository: repository_iri})
end

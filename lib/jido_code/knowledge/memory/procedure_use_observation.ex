defmodule JidoCode.Knowledge.Memory.ProcedureUseObservation do
  @moduledoc "Append-only procedure-use observation that cannot assess its own outcome."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ExperienceGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :procedure_iri,
    :retrieval_packet_iri,
    :attempt_iri,
    :actor_iri,
    :task_phase,
    :recorded_at,
    :assessment_state
  ]
  defstruct @enforce_keys
  @revision "1.0.0"
  @version "2.2.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"

  def revision, do: @revision

  def new(attributes) when is_map(attributes) do
    with true <-
           Enum.all?(
             [:procedure_iri, :retrieval_packet_iri, :attempt_iri, :actor_iri],
             &(ResourceIdentity.validate(attributes[&1]) == :ok)
           ),
         true <-
           attributes[:task_phase] in JidoCode.Knowledge.Memory.ProcedureRevision.task_phases(),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :procedure_use_observation,
             :erlang.term_to_binary(attributes, [:deterministic])
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(attributes, %{
           iri: iri,
           revision: @revision,
           recorded_at: DateTime.truncate(recorded_at, :microsecond),
           assessment_state: :pending_independent_assessment
         })
       )}
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_use_observation)}
    end
  end

  def new(_), do: {:error, Error.new(:invalid_input, :procedure_use_observation)}

  def statements(item),
    do: [
      {item.iri, @rdf_type, RDF.iri(@jf <> "ProcedureUseObservation")},
      {item.iri, @jf <> "about", RDF.iri(item.procedure_iri)},
      {item.iri, @jf <> "retrievalPacket", RDF.iri(item.retrieval_packet_iri)},
      {item.iri, @jf <> "evaluatedAttempt", RDF.iri(item.attempt_iri)},
      {item.iri, @prov <> "wasAssociatedWith", RDF.iri(item.actor_iri)},
      {item.iri, @jf <> "taskPhase", RDF.XSD.String.new(to_string(item.task_phase))},
      {item.iri, @jf <> "assessmentState", RDF.XSD.String.new(to_string(item.assessment_state))},
      {item.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(item.recorded_at)}
    ]

  def record(item, graph, revision, attributes, options \\ []) do
    {:ok, command_iri} = ResourceIdentity.deterministic(:command_request, item.iri <> "\nrecord")

    with true <- attributes[:expected_graph_revisions] == %{graph => revision},
         {:ok, target} <-
           ExperienceGraph.target(
             graph,
             revision,
             attributes[:repository_scope_iri],
             command_iri,
             item.recorded_at,
             statements(item)
           ) do
      CommandEnvelope.new(
        %{
          command_type: "RecordProcedureUseObservation",
          command_version: @version,
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
            guards: [{:subject_absent, graph, item.iri}],
            procedure_use_iri: item.iri,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_use_command)}
    end
  end
end

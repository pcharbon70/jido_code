defmodule JidoCode.Knowledge.Memory.ProcedureCommand do
  @moduledoc "Governed proposal, validation, and lifecycle command builder for procedure revisions."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ExperienceGraph
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.Memory.ProcedureTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @version "2.2.0"

  def propose(
        %ProcedureRevision{} = procedure,
        graph,
        revision,
        report,
        attributes,
        options \\ []
      ) do
    if report[:clear?] == true,
      do:
        build(
          "ProposeProcedureRevision",
          procedure,
          graph,
          revision,
          ProcedureRevision.statements(procedure),
          attributes,
          [{:subject_absent, graph, procedure.iri}],
          options
        ),
      else: {:error, Error.new(:invalid_input, :procedure_command)}
  end

  def transition(
        %ProcedureRevision{} = procedure,
        %ProcedureTransition{} = transition,
        graph,
        revision,
        attributes,
        options \\ []
      ) do
    type =
      if transition.next_state == :validated,
        do: "ValidateProcedureRevision",
        else: "TransitionProcedureRevision"

    build(
      type,
      procedure,
      graph,
      revision,
      ProcedureTransition.statements(transition),
      attributes,
      [
        {:subject_present, graph, procedure.iri},
        {:subject_present, graph, transition.expected_predecessor},
        {:subject_absent, graph, transition.iri}
      ],
      options
    )
  end

  defp build(type, procedure, graph, revision, statements, attributes, guards, options) do
    {:ok, command_iri} =
      ResourceIdentity.deterministic(
        :command_request,
        :erlang.term_to_binary({type, procedure.iri, statements}, [:deterministic])
      )

    with true <- attributes[:expected_graph_revisions] == %{graph => revision},
         {:ok, target} <-
           ExperienceGraph.target(
             graph,
             revision,
             attributes[:repository_scope_iri],
             command_iri,
             attributes[:recorded_at],
             statements
           ) do
      CommandEnvelope.new(
        %{
          command_type: type,
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
            guards: guards,
            procedure_iri: procedure.iri,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_command)}
    end
  end
end

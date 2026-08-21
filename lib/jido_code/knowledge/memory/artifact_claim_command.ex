defmodule JidoCode.Knowledge.Memory.ArtifactClaimCommand do
  @moduledoc "Evidence-writer-only command boundary for artifact claims and freshness transitions."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Evidence.Graph
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ArtifactClaim
  alias JidoCode.Knowledge.Memory.ArtifactClaimTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @version "2.2.0"

  def record(%ArtifactClaim{} = claim, graph, revision, attributes, options \\ []) do
    build(
      "RecordArtifactClaim",
      claim,
      graph,
      revision,
      ArtifactClaim.statements(claim),
      attributes,
      [{:subject_absent, graph, claim.iri}],
      options
    )
  end

  def transition(
        %ArtifactClaim{} = claim,
        %ArtifactClaimTransition{} = transition,
        graph,
        revision,
        attributes,
        options \\ []
      ) do
    build(
      "TransitionArtifactClaim",
      claim,
      graph,
      revision,
      ArtifactClaimTransition.statements(transition),
      attributes,
      [
        {:subject_present, graph, claim.iri},
        {:subject_present, graph, transition.expected_predecessor},
        {:subject_absent, graph, transition.iri}
      ],
      options
    )
  end

  defp build(type, claim, graph, revision, statements, attributes, guards, options) do
    {:ok, command_iri} =
      ResourceIdentity.deterministic(
        :command_request,
        :erlang.term_to_binary({type, claim.iri, statements}, [:deterministic])
      )

    with true <- attributes[:expected_graph_revisions] == %{graph => revision},
         {:ok, target} <-
           Graph.target(
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
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: attributes[:expected_graph_revisions],
          reason: attributes[:reason],
          payload: %{
            changes: [target],
            guards: guards,
            artifact_claim_iri: claim.iri,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      _invalid -> {:error, Error.new(:invalid_input, :artifact_claim_command)}
    end
  end
end

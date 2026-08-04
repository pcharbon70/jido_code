defmodule JidoCode.TestSupport.Phase09DecisionFixture do
  @moduledoc false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase09EvidenceFixture

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @all_scopes "https://jido.run/ontology/concept/AllScopes"

  def prepared!(context) do
    fixture = Phase09EvidenceFixture.recorded!(context)
    fixture = grant_decider!(fixture)

    requirements = Phase09EvidenceFixture.requirements(fixture)

    {:ok, assessment} =
      Knowledge.evaluate_evidence_sufficiency(
        [fixture.evidence_bundle],
        requirements,
        %{
          current_graph_revisions: fixture.verification_activity.source_graph_revisions,
          evaluated_at: DateTime.add(fixture.issued_at, 300, :second)
        }
      )

    recorded_at = DateTime.add(fixture.issued_at, 400, :second)

    decision_attributes = %{
      disposition: :accept,
      mode: :human,
      outcome_stage: :patch_approval,
      risk: :high,
      actor_iri: fixture.decision_actor,
      execution_actor_iri: fixture.attempt.actor_iri,
      independent_decider_required?: true,
      scope_iri: fixture.repository_scope,
      policy_iri: fixture.policy.iri,
      policy_version: fixture.policy.version,
      goal_iri: fixture.goal.iri,
      task_iri: fixture.schedulable_task.iri,
      rationale_refs: [fixture.evidence_bundle.iri],
      confirmation_iris: [],
      confirmation_sources: [],
      requested_effects: [],
      follow_up_kinds: [:apply_patch],
      valid_from: recorded_at,
      valid_to: DateTime.add(recorded_at, 86_400),
      recorded_at: recorded_at,
      supersedes_iri: nil,
      supersedes_follow_up_iris: [],
      related_resolutions: [],
      evidence_graph_iri: fixture.evidence_graph,
      evidence_requirements: requirements,
      evaluation_context: %{
        current_graph_revisions: fixture.verification_activity.source_graph_revisions,
        evaluated_at: DateTime.add(fixture.issued_at, 300, :second)
      }
    }

    {:ok, decision} =
      Knowledge.goal_outcome_decision(
        assessment,
        [fixture.evidence_bundle],
        fixture.goal_resolution,
        fixture.schedulable_task_resolution,
        decision_attributes
      )

    expected_revisions =
      assessment.source_graph_revisions
      |> Map.put(fixture.evidence_graph, graph_revision!(fixture, fixture.evidence_graph))
      |> Map.put(fixture.graphs.policy, graph_revision!(fixture, fixture.graphs.policy))

    command_attributes = %{
      principal_iri: fixture.decision_actor,
      evidence_graph_iri: fixture.evidence_graph,
      control_graph_iri: fixture.control_graph,
      policy_graph_iri: fixture.graphs.policy,
      correlation_iri: Phase04Fixture.local!(:activity, 970),
      causation_iri: fixture.evidence_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: expected_revisions,
      reason: "accept verified patch and derive application work",
      recorded_at: recorded_at
    }

    Map.merge(fixture, %{
      evidence_requirements: requirements,
      sufficiency_assessment: assessment,
      outcome_decision_attributes: decision_attributes,
      outcome_decision: decision,
      outcome_decision_command_attributes: command_attributes
    })
  end

  def decided!(context) do
    fixture = prepared!(context)

    {:ok, command} =
      Knowledge.decide_goal_outcome(
        fixture.outcome_decision,
        fixture.outcome_decision_command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    Map.merge(fixture, %{outcome_decision_command: command, outcome_decision_receipt: receipt})
  end

  def graph_revision!(fixture, graph),
    do: Phase04Fixture.current_graph_revision!(fixture, graph)

  defp grant_decider!(fixture) do
    actor = Phase04Fixture.resource!("phase-09-independent-decision-actor")
    {:ok, grant} = ResourceIdentity.deterministic(:authorization_grant, actor <> "\ndecision")
    command_iri = Phase04Fixture.local!(:command, 960)
    policy_graph = fixture.graphs.policy

    additions = [
      {grant, @rdf_type, RDF.iri(@jf <> "AuthorizationGrant")},
      {grant, @jf <> "grantee", RDF.iri(actor)},
      {grant, @jf <> "grantsCapability", RDF.iri(Authorization.capability_iri(:decision))},
      {grant, @jf <> "validFor", RDF.iri(fixture.repository_scope)},
      {grant, @jf <> "scopeMode", RDF.iri(@all_scopes)},
      {grant, @jf <> "validFrom", RDF.XSD.DateTime.new(fixture.issued_at)},
      {grant, @jf <> "validTo", RDF.XSD.DateTime.new(~U[2035-01-01 00:00:00Z])},
      {grant, @jf <> "sourceActivity", RDF.iri(command_iri)}
    ]

    {:ok, command} =
      CommandEnvelope.new(
        %{
          command_type: "ProposePolicy",
          command_version: "1.3.0",
          command_iri: command_iri,
          principal_iri: fixture.actor,
          actor_iri: fixture.actor,
          delegated_agent_iri: nil,
          delegation_iri: nil,
          scope_iri: fixture.repository_scope,
          idempotency_key: command_iri,
          correlation_iri: Phase04Fixture.local!(:activity, 960),
          causation_iri: fixture.evidence_command.command_iri,
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
          expected_graph_revisions: %{policy_graph => graph_revision!(fixture, policy_graph)},
          reason: "grant independent decision authority",
          payload: %{
            changes: [
              %{
                family: :factory_policy,
                graph_iri: policy_graph,
                operation: :append,
                metadata: %{lifecycle_state: :open},
                additions: additions,
                supersessions: [],
                invalidations: [],
                removals: []
              }
            ],
            guards: [{:subject_absent, policy_graph, grant}]
          }
        },
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    true = receipt.outcome == :committed

    Map.merge(fixture, %{
      decision_actor: actor,
      decision_grant: grant,
      decision_grant_command: command,
      decision_grant_receipt: receipt
    })
  end
end

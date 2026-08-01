defmodule JidoCode.TestSupport.Phase05Fixture do
  @moduledoc false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.AuditPolicy
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Transitions
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"
  @prov "http://www.w3.org/ns/prov#"

  def complete!(context) do
    fixture =
      context
      |> Phase04Fixture.start!()
      |> Phase04Fixture.bootstrap!()
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()
      |> Phase04Fixture.observe!()

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    fixture
    |> Map.put(:authority, authority)
    |> add_transition!()
    |> add_evidence!()
    |> add_derived!()
    |> add_operational_graphs!()
  end

  def append_evidence!(fixture, marker \\ 610) do
    assertion = Phase04Fixture.resource!("phase-05-evidence-append-#{marker}")

    {:ok, metadata} =
      QueryRunner.graph_metadata(fixture.evidence_graph, server: fixture.query_runner)

    revision = metadata.graph_revision

    envelope =
      Phase04Fixture.envelope!(
        fixture,
        "RecordVerificationEvidence",
        Phase04Fixture.local!(:command, marker),
        fixture.repository_scope,
        "phase-05-evidence-append-#{marker}",
        %{fixture.evidence_graph => revision},
        [
          %{
            family: :evidence,
            graph_iri: fixture.evidence_graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: [
              {assertion, @jf <> "about", RDF.iri(fixture.goal)},
              {assertion, @jf <> "recordedAt", RDF.XSD.DateTime.new(fixture.issued_at)},
              {assertion, @jf <> "value", RDF.literal("append-#{marker}")}
            ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        causation_iri: fixture.evidence_envelope.command_iri
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)

    Map.merge(fixture, %{
      appended_assertion: assertion,
      append_envelope: envelope,
      append_receipt: receipt
    })
  end

  def revoke_observation!(fixture, marker \\ 620) do
    {:ok, grant} =
      ResourceIdentity.deterministic(
        :authorization_grant,
        fixture.actor <> "\nobservation"
      )

    {:ok, policy_metadata} =
      QueryRunner.graph_metadata(fixture.graphs.policy, server: fixture.query_runner)

    policy_revision = policy_metadata.graph_revision

    envelope =
      Phase04Fixture.envelope!(
        fixture,
        "AssertDesiredOutcome",
        Phase04Fixture.local!(:command, marker),
        fixture.repository_scope,
        "phase-05-revoke-observation-#{marker}",
        %{fixture.graphs.policy => policy_revision},
        [
          %{
            family: :factory_policy,
            graph_iri: fixture.graphs.policy,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: [
              {grant, @prov <> "invalidatedAtTime", RDF.XSD.DateTime.new(fixture.issued_at)}
            ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ]
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)
    Map.merge(fixture, %{revocation_envelope: envelope, revocation_receipt: receipt})
  end

  def query_matrix(fixture) do
    [
      %{name: :dataset_revision, params: %{}, scope: fixture.factory_scope},
      %{
        name: :graph_metadata,
        params: %{graph: fixture.graphs.catalog},
        scope: fixture.factory_scope
      },
      %{
        name: :ontology_compatibility,
        params: %{graph: fixture.ontology_graph},
        scope: fixture.ontology_scope
      },
      %{
        name: :command_receipt,
        params: %{graph: fixture.audit_graph, resource: fixture.evidence_envelope.command_iri},
        scope: fixture.factory_scope
      },
      %{
        name: :audit_reference,
        params: %{graph: fixture.audit_graph, resource: fixture.evidence_envelope.command_iri},
        scope: fixture.factory_scope
      },
      %{
        name: :graph_health,
        params: %{graph: fixture.evidence_graph},
        scope: fixture.repository_scope
      },
      %{
        name: :resource_description,
        params: %{graph: fixture.evidence_graph, resource: fixture.evidence_resource},
        scope: fixture.repository_scope
      },
      %{
        name: :semantic_neighborhood,
        params: %{graph: fixture.evidence_graph, resource: fixture.goal},
        scope: fixture.repository_scope
      },
      %{
        name: :provenance_chain,
        params: %{graph: fixture.evidence_graph, resource: fixture.evidence_resource},
        scope: fixture.repository_scope
      },
      %{
        name: :supporting_claims,
        params: %{graph: fixture.evidence_graph, resource: fixture.goal},
        scope: fixture.repository_scope
      },
      %{
        name: :contradicting_claims,
        params: %{graph: fixture.evidence_graph, resource: fixture.goal},
        scope: fixture.repository_scope
      },
      %{
        name: :supersession,
        params: %{graph: fixture.evidence_graph, resource: fixture.prior_claim},
        scope: fixture.repository_scope
      },
      %{
        name: :transition_endpoint,
        params: %{graph: fixture.control_graph, resource: fixture.goal},
        scope: fixture.repository_scope
      },
      %{
        name: :transition_history,
        params: %{graph: fixture.control_graph, resource: fixture.goal},
        scope: fixture.repository_scope
      },
      %{
        name: :temporal_as_of,
        params: %{
          graph: fixture.evidence_graph,
          resource: fixture.goal,
          instant: fixture.issued_at
        },
        scope: fixture.repository_scope
      },
      %{
        name: :graph_completeness,
        params: %{graph: fixture.evidence_graph, resource: fixture.goal},
        scope: fixture.repository_scope
      },
      %{
        name: :derived_graph_freshness,
        params: %{graph: fixture.derived_graph},
        scope: fixture.repository_scope
      }
    ]
  end

  defp add_transition!(fixture) do
    transition_iri = Phase04Fixture.local!(:transition, 501)

    {:ok, proposal} =
      Transitions.proposal(%{
        transition_iri: transition_iri,
        subject: fixture.goal,
        next_state: :proposed,
        prior_state: nil,
        expected_predecessor: nil,
        revision: 0,
        actor: fixture.actor,
        cause: fixture.outcome_envelope.command_iri,
        reason: "phase-05-query-transition",
        generated_at: fixture.issued_at,
        recorded_at: fixture.issued_at
      })

    {:ok, decision} =
      Transitions.decide(proposal, %{
        decision_iri: Phase04Fixture.local!(:decision, 501),
        authority: fixture.actor,
        disposition: :accepted,
        decided_at: fixture.issued_at
      })

    revision = Phase04Fixture.current_graph_revision!(fixture, fixture.control_graph)

    envelope =
      Phase04Fixture.envelope!(
        fixture,
        "ProposeGoal",
        Phase04Fixture.local!(:command, 501),
        fixture.repository_scope,
        "phase-05-transition",
        %{fixture.control_graph => revision},
        [
          %{
            family: :repository_control,
            graph_iri: fixture.control_graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: proposal.quads ++ decision.quads,
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ]
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)

    Map.merge(fixture, %{
      transition: transition_iri,
      transition_envelope: envelope,
      transition_receipt: receipt
    })
  end

  defp add_evidence!(fixture) do
    {:ok, graph} = GraphRegistry.graph_iri(:evidence, %{repository: fixture.repository})
    command = Phase04Fixture.local!(:command, 510)

    {:ok, metadata} =
      GraphMetadata.new(graph, %{
        owner_scope: fixture.repository_scope,
        ontology_version: "https://jido.run/ontology/release/1.0.0",
        creation_activity: command,
        created_at: fixture.issued_at,
        lifecycle_state: :open,
        completeness_state: :complete,
        graph_revision: 1
      })

    {:ok, metadata_quads} = GraphMetadata.quads(metadata)
    evidence = Phase04Fixture.resource!("phase-05-evidence")
    supporting = Phase04Fixture.resource!("phase-05-supporting-claim")
    contradicting = Phase04Fixture.resource!("phase-05-contradicting-claim")
    prior = Phase04Fixture.resource!("phase-05-prior-claim")
    successor = Phase04Fixture.resource!("phase-05-successor-claim")

    additions =
      metadata_quads ++
        [
          {evidence, @jf <> "about", RDF.iri(fixture.goal), graph},
          {evidence, @jf <> "recordedAt", RDF.XSD.DateTime.new(fixture.issued_at), graph},
          {evidence, @jf <> "value", RDF.literal("verified"), graph},
          {evidence, @prov <> "wasDerivedFrom", RDF.iri(fixture.observation_batch), graph},
          {supporting, @jf <> "supports", RDF.iri(fixture.goal), graph},
          {supporting, @jf <> "value", RDF.literal("support"), graph},
          {contradicting, @jf <> "contradicts", RDF.iri(fixture.goal), graph},
          {contradicting, @jf <> "value", RDF.literal("contradiction"), graph},
          {successor, @jf <> "supersedes", RDF.iri(prior), graph}
        ]

    envelope =
      Phase04Fixture.envelope!(
        fixture,
        "RecordVerificationEvidence",
        command,
        fixture.repository_scope,
        "phase-05-evidence",
        %{graph => 0},
        [
          %{
            family: :evidence,
            graph_iri: graph,
            operation: :create,
            metadata: metadata,
            additions: additions,
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ]
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)

    Map.merge(fixture, %{
      evidence_graph: graph,
      evidence_resource: evidence,
      supporting_claim: supporting,
      contradicting_claim: contradicting,
      prior_claim: prior,
      successor_claim: successor,
      evidence_envelope: envelope,
      evidence_receipt: receipt
    })
  end

  defp add_derived!(fixture) do
    {:ok, graph} = GraphRegistry.graph_iri(:derived, %{rule_set: "phase-five", revision: 0})
    {:ok, rule_set} = ResourceIdentity.repository("phase-05-integration-rules")
    derived = Phase04Fixture.resource!("phase-05-derived-finding")

    attributes = %{
      operation: :publish,
      command_iri: Phase04Fixture.local!(:command, 520),
      authority: fixture.authority,
      scope_iri: fixture.repository_scope,
      idempotency_key: "phase-05-derived",
      correlation_iri: Phase04Fixture.local!(:activity, 520),
      causation_iri: fixture.evidence_envelope.command_iri,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      target_graph_iri: graph,
      rule_set_iri: rule_set,
      rule_set_slug: "phase-five",
      rule_revision: 0,
      query_version: "phase-05-rules/1.0.0",
      source_graph_revisions: %{
        fixture.control_graph => 2,
        fixture.evidence_graph => 1
      },
      expected_prior_derivation: nil,
      reason: "phase-05-integration-derived-graph",
      statements: [
        {derived, @jf <> "derivedFrom", RDF.iri(fixture.evidence_resource)}
      ]
    }

    {:ok, receipt} = DerivedGraphManager.publish(attributes, writer: fixture.writer)

    Map.merge(fixture, %{
      derived_graph: graph,
      derived_resource: derived,
      rule_set: rule_set,
      derived_receipt: receipt
    })
  end

  defp add_operational_graphs!(fixture) do
    {:ok, ontology_graph} =
      GraphRegistry.graph_iri(:ontology, %{version: Release.current_version()})

    {:ok, audit_graph} = AuditPolicy.graph_iri(fixture.issued_at)

    {:ok, ontology_metadata} =
      QueryRunner.graph_metadata(ontology_graph, server: fixture.query_runner)

    Map.merge(fixture, %{
      ontology_graph: ontology_graph,
      ontology_scope: ontology_metadata.owner_scope,
      audit_graph: audit_graph
    })
  end
end

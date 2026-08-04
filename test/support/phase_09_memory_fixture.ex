defmodule JidoCode.TestSupport.Phase09MemoryFixture do
  @moduledoc false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase09DecisionFixture

  def prepared!(context) do
    fixture = Phase09DecisionFixture.decided!(context)
    {:ok, memory_graph} = Knowledge.memory_graph_identity(fixture.repository)
    recorded_at = DateTime.add(fixture.issued_at, 500, :second)

    assertion_attributes = %{
      source_kind: :accepted_decision,
      repository_iri: fixture.repository,
      memory_graph_iri: memory_graph,
      scope_kind: :repository,
      scope_iri: fixture.repository_scope,
      cohort_graph_iri: nil,
      cohort_evidence_iris: [],
      classification: :fact,
      actor_iri: fixture.decision_actor,
      policy_iri: fixture.policy.iri,
      policy_version: fixture.policy.version,
      confidence: 95,
      limitations: ["valid only for the verified repository snapshot lineage"],
      related_resource_iris: [
        fixture.repository,
        fixture.goal.iri,
        fixture.schedulable_task.iri
      ],
      supporting_assertion_iris: [],
      supersedes_iris: [],
      valid_from: recorded_at,
      valid_to: fixture.evidence_bundle.valid_to,
      recorded_at: recorded_at
    }

    {:ok, assertion} =
      Knowledge.knowledge_assertion(
        fixture.outcome_decision,
        fixture.outcome_decision.claim_dispositions,
        assertion_attributes
      )

    expected_revisions = %{
      memory_graph => 0,
      fixture.evidence_graph => graph_revision!(fixture, fixture.evidence_graph),
      fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy)
    }

    command_attributes = %{
      principal_iri: fixture.decision_actor,
      evidence_graph_iri: fixture.evidence_graph,
      policy_graph_iri: fixture.graphs.policy,
      correlation_iri: Phase04Fixture.local!(:activity, 990),
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: expected_revisions,
      reason: "adopt accepted repository knowledge",
      recorded_at: recorded_at
    }

    Map.merge(fixture, %{
      memory_graph: memory_graph,
      knowledge_assertion_attributes: assertion_attributes,
      knowledge_assertion: assertion,
      knowledge_adoption_command_attributes: command_attributes
    })
  end

  def adopted!(context) do
    fixture = prepared!(context)

    {:ok, command} =
      Knowledge.adopt_knowledge(
        fixture.knowledge_assertion,
        fixture.outcome_decision,
        fixture.knowledge_adoption_command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)

    Map.merge(fixture, %{
      knowledge_adoption_command: command,
      knowledge_adoption_receipt: receipt
    })
  end

  def contradicted!(context) do
    context
    |> adopted!()
    |> contradict!()
  end

  def contradict!(fixture) do
    recorded_at = DateTime.add(fixture.knowledge_assertion.recorded_at, 30, :second)

    source_revisions =
      fixture.verification_activity.source_graph_revisions
      |> Map.keys()
      |> Map.new(&{&1, graph_revision!(fixture, &1)})

    activity_attributes =
      fixture.verification_activity
      |> Map.from_struct()
      |> Map.drop([:iri, :method])
      |> Map.put(:source_graph_revisions, source_revisions)
      |> Map.put(:artifacts, [fixture.artifact])
      |> Map.put(:started_at, DateTime.add(recorded_at, -10, :second))
      |> Map.put(:ended_at, DateTime.add(recorded_at, -5, :second))

    {:ok, activity} =
      Knowledge.verification_activity(fixture.verification_method, activity_attributes)

    {:ok, bundle} =
      Knowledge.evidence_bundle(activity, fixture.evidence_graph, %{
        supports: [],
        contradicts: [fixture.goal.iri],
        strength: :strong,
        generated_claims: [
          %{
            subject_iri: fixture.repository,
            predicate_iri: "https://jido.run/ontology/factory#defaultBranchProtected",
            object: %{type: :boolean, value: false},
            valid_from: recorded_at,
            valid_to: fixture.evidence_bundle.valid_to,
            recorded_at: recorded_at
          }
        ],
        limitations: ["contradicts the adopted repository fact"],
        valid_from: recorded_at,
        valid_to: fixture.evidence_bundle.valid_to,
        supersedes: []
      })

    expected_revisions =
      Map.put(
        source_revisions,
        fixture.evidence_graph,
        graph_revision!(fixture, fixture.evidence_graph)
      )

    command_attributes = %{
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      repository_scope_iri: fixture.repository_scope,
      evidence_graph_iri: fixture.evidence_graph,
      correlation_iri: Phase04Fixture.local!(:activity, 994),
      causation_iri: fixture.knowledge_adoption_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: expected_revisions,
      reason: "record later contradictory repository evidence",
      recorded_at: recorded_at
    }

    {:ok, command} =
      Knowledge.record_verification_evidence(bundle, command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)

    Map.merge(fixture, %{
      contradictory_verification_activity: activity,
      contradictory_bundle: bundle,
      contradictory_evidence_command: command,
      contradictory_evidence_receipt: receipt
    })
  end

  def evolution_attributes(fixture, overrides \\ %{}) do
    recorded_at = DateTime.add(fixture.knowledge_assertion.recorded_at, 60, :second)
    evidence = Map.get(fixture, :contradictory_bundle, fixture.evidence_bundle)

    Map.merge(
      %{
        next_state: :under_review,
        evidence_iris: [evidence.iri],
        decision_iri: fixture.outcome_decision.iri,
        actor_iri: fixture.decision_actor,
        principal_iri: fixture.decision_actor,
        scope_iri: fixture.repository_scope,
        policy_iri: fixture.policy.iri,
        evidence_graph_iri: fixture.evidence_graph,
        policy_graph_iri: fixture.graphs.policy,
        correlation_iri: Phase04Fixture.local!(:activity, 995),
        expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
        expected_graph_revisions: %{
          fixture.memory_graph => graph_revision!(fixture, fixture.memory_graph),
          fixture.evidence_graph => graph_revision!(fixture, fixture.evidence_graph),
          fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy)
        },
        reason: "review knowledge after later evidence",
        recorded_at: recorded_at
      },
      overrides
    )
  end

  def resolution(assertion, transitions \\ []) do
    all = [assertion.transition | transitions]
    {:ok, resolution} = Knowledge.resolve_knowledge_state(all)
    resolution
  end

  def graph_revision!(fixture, graph),
    do: Phase09DecisionFixture.graph_revision!(fixture, graph)
end

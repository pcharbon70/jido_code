defmodule JidoCode.Knowledge.Phase09AcceptedLearningIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase09EvidenceFixture
  alias JidoCode.TestSupport.Phase09MemoryFixture

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdfs_sub_class "http://www.w3.org/2000/01/rdf-schema#subClassOf"
  @rdfs_sub_property "http://www.w3.org/2000/01/rdf-schema#subPropertyOf"
  @jf "https://jido.run/ontology/factory#"

  test "accepts post-change satisfaction then supersedes it on later contradictory evidence",
       context do
    fixture = Phase09MemoryFixture.adopted!(context)
    fixture = record_post_change_evidence!(fixture)
    fixture = decide_final_satisfaction!(fixture)

    assert fixture.final_decision_receipt.outcome == :committed
    assert fixture.final_goal_resolution.current_state == :satisfied
    assert fixture.final_task_resolution.current_state == :satisfied
    assert fixture.final_desired_resolution.current_state == :satisfied
    assert fixture.final_obligation_resolution.current_state == :satisfied
    assert fixture.final_decision.payload.direct_side_effects == []

    assert {:ok, replay} = Writer.execute(fixture.writer, fixture.final_decision)
    assert replay.outcome == :already_committed

    fixture = Phase09MemoryFixture.contradict!(fixture)
    fixture = decide_supersession!(fixture)

    assert fixture.supersede_decision_receipt.outcome == :committed
    assert fixture.superseded_goal_resolution.current_state == :superseded
    assert fixture.superseded_task_resolution.current_state == :superseded
    assert fixture.superseded_desired_resolution.current_state == :superseded
    assert fixture.superseded_obligation_resolution.current_state == :superseded
    assert fixture.supersede_decision.payload.direct_side_effects == []

    fixture = invalidate_knowledge!(fixture)
    assert fixture.knowledge_invalidation_receipt.outcome == :committed
    assert fixture.knowledge_invalidation.payload.direct_side_effects == []

    assert {:ok, result} = memory_query(fixture, fixture.knowledge_invalidation_at)

    assert {:ok, current} =
             Knowledge.retrieve_knowledge(
               result,
               retrieval_context(fixture, fixture.knowledge_invalidation_at, false)
             )

    assert current.assertions == []

    assert {:ok, historical} =
             Knowledge.retrieve_knowledge(
               result,
               retrieval_context(fixture, fixture.knowledge_invalidation_at, true)
             )

    assert [assertion] = historical.assertions
    assert assertion.iri == fixture.knowledge_assertion.iri
    assert assertion.state == :invalidated
    assert fixture.contradictory_bundle.iri in assertion.contradiction_iris
  end

  test "rebuilds disposable reasoning without changing decisions or accepted knowledge",
       context do
    fixture = Phase09MemoryFixture.adopted!(context)
    decision_before = description!(fixture, fixture.evidence_graph, fixture.outcome_decision.iri)

    assertion_before =
      description!(fixture, fixture.memory_graph, fixture.knowledge_assertion.iri)

    memory_revision = graph_revision!(fixture, fixture.memory_graph)
    candidate = Phase04Fixture.resource!("phase-09-integration-dependency")
    repository_a = Phase04Fixture.resource!("phase-09-integration-repository-a")
    repository_b = Phase04Fixture.resource!("phase-09-integration-repository-b")
    statements = insight_statements(fixture, candidate, repository_a, repository_b)

    attributes =
      reasoning_attributes(
        fixture,
        "phase-nine-integration",
        0,
        1_100,
        statements,
        fixture.evidence_graph
      )

    assert {:ok, first} = Knowledge.materialize_reasoning(attributes, writer: fixture.writer)
    assert first.receipt.outcome == :committed

    insight_context =
      insight_context(fixture, first, repository_a, repository_b, 1, 1_101)

    assert {:ok, insight} = discover(fixture, first, insight_context)
    assert [proposal] = insight.proposals
    assert proposal.candidate_iri == candidate

    concealed = %{insight_context | visible_repository_iris: [fixture.repository, repository_a]}
    assert {:ok, %{proposals: []}} = discover(fixture, first, concealed)

    assert {:error, %{operation: :adopt_knowledge}} =
             Knowledge.adopt_knowledge(
               proposal,
               fixture.outcome_decision,
               fixture.knowledge_adoption_command_attributes
             )

    fixture = Phase09MemoryFixture.contradict!(fixture)
    current_source_revision = graph_revision!(fixture, fixture.evidence_graph)

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(first.target_graph_iri, server: fixture.query_runner)

    assert {:ok, :stale} =
             DerivedGraphManager.status(metadata, %{
               fixture.evidence_graph => current_source_revision
             })

    stale_attributes =
      lifecycle_attributes(
        attributes,
        :mark_stale,
        1_102,
        attributes.source_graph_revisions,
        %{graph_iri: first.target_graph_iri, revision: 1}
      )

    assert {:ok, stale_receipt} =
             DerivedGraphManager.publish(stale_attributes, writer: fixture.writer)

    assert stale_receipt.graph_revisions[first.target_graph_iri].new == 2

    delete_attributes =
      lifecycle_attributes(
        attributes,
        :delete,
        1_103,
        %{fixture.evidence_graph => current_source_revision},
        %{graph_iri: first.target_graph_iri, revision: 2}
      )

    assert {:ok, delete_receipt} =
             DerivedGraphManager.publish(delete_attributes, writer: fixture.writer)

    assert delete_receipt.graph_revisions[first.target_graph_iri].new == 3

    rebuilt_attributes =
      reasoning_attributes(
        fixture,
        "phase-nine-integration",
        1,
        1_104,
        statements,
        fixture.evidence_graph
      )
      |> Map.put(:expected_prior_derivation, %{
        graph_iri: first.target_graph_iri,
        revision: 3
      })

    assert {:ok, rebuilt} =
             Knowledge.materialize_reasoning(rebuilt_attributes, writer: fixture.writer)

    assert rebuilt.receipt.outcome == :committed
    refute rebuilt.target_graph_iri == first.target_graph_iri
    assert graph_revision!(fixture, fixture.memory_graph) == memory_revision

    assert description!(fixture, fixture.evidence_graph, fixture.outcome_decision.iri) ==
             decision_before

    assert description!(fixture, fixture.memory_graph, fixture.knowledge_assertion.iri) ==
             assertion_before

    assert description!(fixture, first.target_graph_iri, fixture.knowledge_assertion.iri) == []
  end

  test "restores and reconstructs exact decision and retrieval context from graph revisions",
       context do
    fixture = Phase09MemoryFixture.adopted!(context)
    evaluated_at = fixture.knowledge_assertion.recorded_at
    decision_before = decision_projection!(fixture)

    assert {:ok, result_before} = memory_query(fixture, evaluated_at)

    assert {:ok, retrieval_before} =
             Knowledge.retrieve_knowledge(
               result_before,
               retrieval_context(fixture, evaluated_at, false)
             )

    assert {:ok, backup} = Maintenance.backup(fixture.maintenance, [])
    changed = Phase09MemoryFixture.contradict!(fixture)

    assert graph_revision!(changed, changed.evidence_graph) >
             result_before.graph_revisions[fixture.memory_graph]

    assert {:ok, restore} =
             Maintenance.restore(fixture.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert restore.integrity_status == :ok
    decision_after = decision_projection!(fixture)
    assert decision_after.data == decision_before.data
    assert decision_after.receipt.graph_revision == decision_before.receipt.graph_revision

    assert {:ok, result_after} = memory_query(fixture, evaluated_at)

    assert {:ok, retrieval_after} =
             Knowledge.retrieve_knowledge(
               result_after,
               retrieval_context(fixture, evaluated_at, false)
             )

    assert retrieval_after.assertions == retrieval_before.assertions
    assert retrieval_after.receipt.graph_revision == retrieval_before.receipt.graph_revision
    assert retrieval_after.receipt.query_version == QueryCatalog.knowledge_version()
  end

  defp record_post_change_evidence!(fixture) do
    source_revisions = source_revisions(fixture)
    activity_at = DateTime.add(fixture.issued_at, 700, :second)

    activity_attributes =
      fixture.verification_activity
      |> Map.from_struct()
      |> Map.drop([:iri, :method])
      |> Map.merge(%{
        source_graph_revisions: source_revisions,
        artifacts: [fixture.artifact],
        post_change_snapshot_iri: fixture.observation.snapshot_iri,
        checks: [
          %{id: "post-change-test", status: :passed, mandatory?: true, outcome_refs: []},
          %{id: "provider-confirmation", status: :passed, mandatory?: true, outcome_refs: []}
        ],
        started_at: activity_at,
        ended_at: DateTime.add(activity_at, 5, :second)
      })

    {:ok, activity} =
      Knowledge.verification_activity(fixture.verification_method, activity_attributes)

    recorded_at = DateTime.add(activity_at, 6, :second)

    {:ok, bundle} =
      Knowledge.evidence_bundle(activity, fixture.evidence_graph, %{
        supports: [fixture.goal.iri],
        contradicts: [],
        strength: :strong,
        generated_claims: [
          %{
            subject_iri: fixture.repository,
            predicate_iri: @jf <> "defaultBranchProtected",
            object: %{type: :boolean, value: true},
            valid_from: recorded_at,
            valid_to: DateTime.add(recorded_at, 86_400),
            recorded_at: recorded_at
          }
        ],
        limitations: ["post-change provider state is bound to the confirmation observation"],
        valid_from: recorded_at,
        valid_to: DateTime.add(recorded_at, 86_400),
        supersedes: []
      })

    command_attributes = %{
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      repository_scope_iri: fixture.repository_scope,
      evidence_graph_iri: fixture.evidence_graph,
      correlation_iri: Phase04Fixture.local!(:activity, 1_105),
      causation_iri: fixture.outcome_decision_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions:
        Map.put(
          source_revisions,
          fixture.evidence_graph,
          graph_revision!(fixture, fixture.evidence_graph)
        ),
      reason: "record exact post-change verification",
      recorded_at: recorded_at
    }

    {:ok, command} =
      Knowledge.record_verification_evidence(bundle, command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    true = receipt.outcome == :committed

    Map.merge(fixture, %{
      post_change_activity: activity,
      post_change_bundle: bundle,
      post_change_command: command,
      post_change_receipt: receipt
    })
  end

  defp decide_final_satisfaction!(fixture) do
    requirements =
      Phase09EvidenceFixture.requirements(fixture, %{
        require_post_change?: true,
        source_graph_revisions: fixture.post_change_activity.source_graph_revisions
      })

    evaluation_context = %{
      current_graph_revisions: fixture.post_change_activity.source_graph_revisions,
      evaluated_at: DateTime.add(fixture.issued_at, 720, :second)
    }

    {:ok, assessment} =
      Knowledge.evaluate_evidence_sufficiency(
        [fixture.post_change_bundle],
        requirements,
        evaluation_context
      )

    true = assessment.status == :sufficient

    {:ok, task_resolution} =
      Transition.resolve(
        fixture.schedulable_task_transitions ++ fixture.outcome_decision.task_transitions
      )

    recorded_at = DateTime.add(fixture.issued_at, 730, :second)
    observation_revision = graph_revision!(fixture, fixture.observation.graph_iri)

    attributes = %{
      fixture.outcome_decision_attributes
      | outcome_stage: :final_goal,
        rationale_refs: [fixture.post_change_bundle.iri],
        confirmation_iris: [fixture.observation.batch_iri],
        confirmation_sources: [
          %{
            iri: fixture.observation.batch_iri,
            graph_iri: fixture.observation.graph_iri,
            revision: observation_revision
          }
        ],
        follow_up_kinds: [],
        related_resolutions: [fixture.desired_resolution, fixture.obligation_resolution],
        evidence_requirements: requirements,
        evaluation_context: evaluation_context,
        valid_from: recorded_at,
        valid_to: DateTime.add(recorded_at, 86_400),
        recorded_at: recorded_at,
        supersedes_iri: fixture.outcome_decision.iri,
        supersedes_follow_up_iris: Enum.map(fixture.outcome_decision.follow_ups, & &1.goal_iri)
    }

    {:ok, decision} =
      Knowledge.goal_outcome_decision(
        assessment,
        [fixture.post_change_bundle],
        fixture.goal_resolution,
        task_resolution,
        attributes
      )

    expected_revisions =
      assessment.source_graph_revisions
      |> Map.put(fixture.evidence_graph, graph_revision!(fixture, fixture.evidence_graph))
      |> Map.put(fixture.graphs.policy, graph_revision!(fixture, fixture.graphs.policy))
      |> Map.put(fixture.observation.graph_iri, observation_revision)

    command_attributes = %{
      principal_iri: fixture.decision_actor,
      evidence_graph_iri: fixture.evidence_graph,
      control_graph_iri: fixture.control_graph,
      policy_graph_iri: fixture.graphs.policy,
      correlation_iri: Phase04Fixture.local!(:activity, 1_106),
      causation_iri: fixture.post_change_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: expected_revisions,
      reason: "accept post-change evidence and satisfy governed outcomes",
      recorded_at: recorded_at
    }

    {:ok, command} =
      Knowledge.decide_goal_outcome(decision, command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    true = receipt.outcome == :committed

    goal_resolution = resolve!(fixture.goal_transitions ++ decision.goal_transitions)

    desired_resolution =
      related_resolution!(fixture.desired_transitions, decision, fixture.desired_outcome.iri)

    obligation_resolution =
      related_resolution!(fixture.obligation_transitions, decision, fixture.obligation.iri)

    Map.merge(fixture, %{
      final_assessment: assessment,
      final_decision_value: decision,
      final_decision: command,
      final_decision_receipt: receipt,
      final_goal_resolution: goal_resolution,
      final_task_resolution: task_resolution,
      final_desired_resolution: desired_resolution,
      final_obligation_resolution: obligation_resolution
    })
  end

  defp decide_supersession!(fixture) do
    requirements =
      Phase09EvidenceFixture.requirements(fixture, %{
        source_graph_revisions: fixture.contradictory_verification_activity.source_graph_revisions
      })

    evaluation_context = %{
      current_graph_revisions: fixture.contradictory_verification_activity.source_graph_revisions,
      evaluated_at: DateTime.add(fixture.issued_at, 900, :second)
    }

    {:ok, assessment} =
      Knowledge.evaluate_evidence_sufficiency(
        [fixture.contradictory_bundle],
        requirements,
        evaluation_context
      )

    true = assessment.status == :contradicted
    recorded_at = DateTime.add(fixture.issued_at, 910, :second)

    attributes = %{
      fixture.outcome_decision_attributes
      | disposition: :supersede,
        outcome_stage: :attempt_completion,
        rationale_refs: [fixture.contradictory_bundle.iri],
        confirmation_iris: [],
        confirmation_sources: [],
        follow_up_kinds: [],
        related_resolutions: [
          fixture.final_desired_resolution,
          fixture.final_obligation_resolution
        ],
        evidence_requirements: requirements,
        evaluation_context: evaluation_context,
        valid_from: recorded_at,
        valid_to: DateTime.add(recorded_at, 86_400),
        recorded_at: recorded_at,
        supersedes_iri: fixture.final_decision_value.iri,
        supersedes_follow_up_iris: []
    }

    {:ok, decision} =
      Knowledge.goal_outcome_decision(
        assessment,
        [fixture.contradictory_bundle],
        fixture.final_goal_resolution,
        fixture.final_task_resolution,
        attributes
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
      correlation_iri: Phase04Fixture.local!(:activity, 1_107),
      causation_iri: fixture.contradictory_evidence_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: expected_revisions,
      reason: "supersede accepted outcomes after contradictory evidence",
      recorded_at: recorded_at
    }

    {:ok, command} =
      Knowledge.decide_goal_outcome(decision, command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    true = receipt.outcome == :committed

    Map.merge(fixture, %{
      supersede_assessment: assessment,
      supersede_decision_value: decision,
      supersede_decision: command,
      supersede_decision_receipt: receipt,
      superseded_goal_resolution:
        resolve!(
          fixture.goal_transitions ++
            fixture.final_decision_value.goal_transitions ++ decision.goal_transitions
        ),
      superseded_task_resolution:
        resolve!(
          fixture.schedulable_task_transitions ++
            fixture.outcome_decision.task_transitions ++ decision.task_transitions
        ),
      superseded_desired_resolution:
        related_resolution!(
          fixture.desired_transitions ++
            related_transitions(fixture.final_decision_value, fixture.desired_outcome.iri),
          decision,
          fixture.desired_outcome.iri
        ),
      superseded_obligation_resolution:
        related_resolution!(
          fixture.obligation_transitions ++
            related_transitions(fixture.final_decision_value, fixture.obligation.iri),
          decision,
          fixture.obligation.iri
        )
    })
  end

  defp invalidate_knowledge!(fixture) do
    reviewed_at = DateTime.add(fixture.issued_at, 920, :second)

    review_attributes =
      Phase09MemoryFixture.evolution_attributes(fixture, %{
        next_state: :under_review,
        evidence_iris: [fixture.contradictory_bundle.iri],
        decision_iri: fixture.supersede_decision_value.iri,
        correlation_iri: Phase04Fixture.local!(:activity, 1_108),
        reason: "review accepted knowledge against contradictory evidence",
        recorded_at: reviewed_at
      })

    resolution = Phase09MemoryFixture.resolution(fixture.knowledge_assertion)

    {:ok, review_command} =
      Knowledge.evolve_knowledge(
        fixture.knowledge_assertion,
        resolution,
        nil,
        review_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, review_receipt} = Writer.execute(fixture.writer, review_command)
    true = review_receipt.outcome == :committed

    recorded_at = DateTime.add(reviewed_at, 1, :second)

    invalidation_attributes =
      Phase09MemoryFixture.evolution_attributes(fixture, %{
        next_state: :invalidated,
        evidence_iris: [fixture.contradictory_bundle.iri],
        decision_iri: fixture.supersede_decision_value.iri,
        correlation_iri: Phase04Fixture.local!(:activity, 1_109),
        reason: "invalidate reviewed knowledge after superseding decision",
        recorded_at: recorded_at
      })

    reviewed_resolution = %{
      subject_iri: fixture.knowledge_assertion.iri,
      current_state: :under_review,
      current_revision: 1,
      current_transition: review_command.payload.transition_iri,
      history: []
    }

    {:ok, command} =
      Knowledge.evolve_knowledge(
        fixture.knowledge_assertion,
        reviewed_resolution,
        nil,
        invalidation_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)

    Map.merge(fixture, %{
      knowledge_review: review_command,
      knowledge_review_receipt: review_receipt,
      knowledge_invalidation: command,
      knowledge_invalidation_receipt: receipt,
      knowledge_invalidation_at: recorded_at
    })
  end

  defp reasoning_attributes(fixture, slug, revision, marker, statements, source_graph) do
    {:ok, target} = GraphRegistry.graph_iri(:derived, %{rule_set: slug, revision: revision})

    %{
      profile: :owl2rl_safe,
      bounds: %{
        max_input_facts: 100,
        max_derived_facts: 200,
        max_iterations: 20,
        timeout_ms: 5_000,
        max_bytes: 250_000
      },
      source_statements: statements,
      operation: :publish,
      command_iri: Phase04Fixture.local!(:command, marker),
      authority: fixture.authority,
      scope_iri: fixture.repository_scope,
      idempotency_key: "phase-09-integration-reasoning-#{marker}",
      correlation_iri: Phase04Fixture.local!(:activity, marker),
      causation_iri: fixture.knowledge_adoption_command.command_iri,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      target_graph_iri: target,
      rule_set_iri: Phase04Fixture.resource!("#{slug}-rules"),
      rule_set_slug: slug,
      rule_revision: revision,
      query_version: "#{slug}/1.0.0",
      source_graph_revisions: %{source_graph => graph_revision!(fixture, source_graph)},
      expected_prior_derivation: nil,
      reason: "phase 09 integration reasoning"
    }
  end

  defp lifecycle_attributes(attributes, operation, marker, sources, prior) do
    attributes
    |> Map.take([
      :authority,
      :scope_iri,
      :ontology_version,
      :shape_version,
      :target_graph_iri,
      :rule_set_iri,
      :rule_set_slug,
      :rule_revision,
      :query_version
    ])
    |> Map.merge(%{
      operation: operation,
      command_iri: Phase04Fixture.local!(:command, marker),
      idempotency_key: "phase-09-derived-lifecycle-#{marker}",
      correlation_iri: Phase04Fixture.local!(:activity, marker),
      causation_iri: attributes.command_iri,
      source_graph_revisions: sources,
      expected_prior_derivation: prior,
      reason: "phase 09 derived graph #{operation}",
      statements: []
    })
  end

  defp insight_statements(fixture, candidate, repository_a, repository_b) do
    shared_dependency = @jf <> "sharedDependency"

    [
      {@jf <> "Finding", @rdfs_sub_class, RDF.iri(@jf <> "Contradiction")},
      {fixture.knowledge_assertion.iri, @rdf_type, RDF.iri(@jf <> "Finding")},
      {shared_dependency, @rdfs_sub_property, RDF.iri(@jf <> "dependsOn")},
      {fixture.repository, shared_dependency, RDF.iri(candidate)},
      {repository_a, shared_dependency, RDF.iri(candidate)},
      {repository_b, shared_dependency, RDF.iri(candidate)}
    ]
  end

  defp insight_context(fixture, reasoning, repository_a, repository_b, revision, marker) do
    source_graph = fixture.evidence_graph

    %{
      derived_graph_iri: reasoning.target_graph_iri,
      expected_graph_revisions: %{
        reasoning.target_graph_iri => revision,
        source_graph => graph_revision!(fixture, source_graph)
      },
      expected_derived_revision: revision,
      evaluated_at: DateTime.add(fixture.issued_at, marker, :second),
      target_repository_iri: fixture.repository,
      visibility_receipt_iri: Phase04Fixture.resource!("phase-09-integration-visibility"),
      authorized_repository_iris: [fixture.repository, repository_a, repository_b],
      visible_repository_iris: [fixture.repository, repository_a, repository_b],
      minimum_sources: 2,
      rule_version: "phase-nine-integration/#{revision}"
    }
  end

  defp discover(fixture, reasoning, context) do
    Knowledge.discover_cross_graph_insights(
      :shared_dependencies,
      QueryCatalog.knowledge_version(),
      %{graph: reasoning.target_graph_iri, resource: fixture.repository},
      fixture.authority,
      fixture.repository_scope,
      context,
      server: fixture.query_runner
    )
  end

  defp decision_projection!(fixture) do
    {:ok, result} =
      QueryRunner.execute(
        :decision_by_goal,
        QueryCatalog.knowledge_version(),
        %{graph: fixture.evidence_graph, resource: fixture.goal.iri},
        fixture.authority,
        fixture.repository_scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )

    {:ok, projection} =
      Knowledge.project_decision(result, %{
        graph_iri: fixture.evidence_graph,
        resource_iri: fixture.goal.iri
      })

    projection
  end

  defp memory_query(fixture, evaluated_at) do
    QueryRunner.execute(
      :knowledge_by_scope,
      QueryCatalog.knowledge_version(),
      %{graph: fixture.memory_graph, resource: fixture.repository_scope},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: evaluated_at
    )
  end

  defp retrieval_context(fixture, evaluated_at, historical?) do
    %{
      memory_graph_iri: fixture.memory_graph,
      expected_memory_revision: graph_revision!(fixture, fixture.memory_graph),
      execution_context_iri: fixture.attempt.context_iri,
      evaluated_at: evaluated_at,
      repository_scope_iri: fixture.repository_scope,
      allowed_scope_iris: [fixture.repository_scope],
      allowed_classifications: [:fact, :lesson],
      relevant_resource_iris: [fixture.goal.iri, fixture.schedulable_task.iri],
      current_source_graph_revisions: fixture.knowledge_assertion.source_graph_revisions,
      historical?: historical?,
      max_results: 20
    }
  end

  defp description!(fixture, graph, resource) do
    {:ok, result} =
      QueryRunner.execute(
        :resource_description,
        "1.0.0",
        %{graph: graph, resource: resource},
        fixture.authority,
        fixture.repository_scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )

    Enum.sort_by(result.data, &:erlang.term_to_binary(&1, [:deterministic]))
  end

  defp source_revisions(fixture) do
    %{
      fixture.attempt.run_graph_iri => graph_revision!(fixture, fixture.attempt.run_graph_iri),
      fixture.control_graph => graph_revision!(fixture, fixture.control_graph),
      fixture.publication.graph_iri => graph_revision!(fixture, fixture.publication.graph_iri)
    }
  end

  defp related_resolution!(prior, decision, subject) do
    resolve!(prior ++ related_transitions(decision, subject))
  end

  defp related_transitions(decision, subject),
    do: Enum.filter(decision.related_transitions, &(&1.subject_iri == subject))

  defp resolve!(transitions) do
    {:ok, resolution} = Transition.resolve(transitions)
    resolution
  end

  defp graph_revision!(fixture, graph),
    do: Phase09MemoryFixture.graph_revision!(fixture, graph)
end

defmodule JidoCode.Knowledge.Reasoning.Phase09ReasoningLearningTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase09MemoryFixture

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdfs_sub_class "http://www.w3.org/2000/01/rdf-schema#subClassOf"
  @rdfs_sub_property "http://www.w3.org/2000/01/rdf-schema#subPropertyOf"
  @jf "https://jido.run/ontology/factory#"

  test "materializes bounded rules and conceals cross-repository insight sources", context do
    fixture = Phase09MemoryFixture.adopted!(context)
    candidate = Phase04Fixture.resource!("phase-09-shared-dependency")
    repository_a = Phase04Fixture.resource!("phase-09-insight-repository-a")
    repository_b = Phase04Fixture.resource!("phase-09-insight-repository-b")
    shared_dependency = @jf <> "sharedDependency"

    statements = [
      {@jf <> "Finding", @rdfs_sub_class, RDF.iri(@jf <> "Contradiction")},
      {fixture.knowledge_assertion.iri, @rdf_type, RDF.iri(@jf <> "Finding")},
      {shared_dependency, @rdfs_sub_property, RDF.iri(@jf <> "dependsOn")},
      {fixture.repository, shared_dependency, RDF.iri(candidate)},
      {repository_a, shared_dependency, RDF.iri(candidate)},
      {repository_b, shared_dependency, RDF.iri(candidate)}
    ]

    attributes = reasoning_attributes(fixture, "phase-nine-insight", 0, 1_010, statements)

    assert :owl2rl_safe in Knowledge.reasoning_profiles()
    assert {:ok, reasoning} = Knowledge.materialize_reasoning(attributes, writer: fixture.writer)
    assert reasoning.receipt.outcome == :committed
    assert reasoning.receipt.graph_revisions[reasoning.target_graph_iri].new == 1
    assert reasoning.input_count == length(statements)
    assert reasoning.derived_count > 0
    assert reasoning.stats.iterations <= reasoning.bounds.max_iterations
    refute reasoning.acceptance_authority?
    refute reasoning.command_authority?

    evaluated_at = DateTime.add(fixture.issued_at, 700, :second)

    assert {:error, %{kind: :unauthorized, operation: :cross_graph_insight}} =
             Knowledge.query(
               :shared_dependencies,
               QueryCatalog.knowledge_version(),
               %{graph: reasoning.target_graph_iri, resource: fixture.repository},
               fixture.authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: evaluated_at
             )

    insight_context = %{
      derived_graph_iri: reasoning.target_graph_iri,
      expected_graph_revisions: %{
        reasoning.target_graph_iri => 1,
        fixture.memory_graph =>
          Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph)
      },
      expected_derived_revision: 1,
      evaluated_at: evaluated_at,
      target_repository_iri: fixture.repository,
      visibility_receipt_iri: Phase04Fixture.resource!("phase-09-visibility-receipt"),
      authorized_repository_iris: [fixture.repository, repository_a, repository_b],
      visible_repository_iris: [fixture.repository, repository_a, repository_b],
      minimum_sources: 2,
      rule_version: "phase-nine-insight/0"
    }

    assert {:ok, projection} =
             discover(fixture, reasoning, insight_context)

    assert [proposal] = projection.proposals
    assert proposal.candidate_iri == candidate
    assert proposal.source_repository_iris == Enum.sort([repository_a, repository_b])
    assert proposal.state == :proposed
    refute proposal.acceptance_authority?
    refute proposal.adoption_authority?
    assert proposal.independent_evidence_required?
    assert proposal.target_policy_authorization_required?

    concealed_context = %{
      insight_context
      | visible_repository_iris: [fixture.repository, repository_a]
    }

    assert {:ok, concealed} = discover(fixture, reasoning, concealed_context)
    assert concealed.proposals == []
    refute inspect(concealed) =~ repository_b
  end

  test "rejects authority-producing inference, stale sources, and excessive bounds", context do
    fixture = Phase09MemoryFixture.adopted!(context)
    source_class = @jf <> "InferredGrantCandidate"

    authority_statements = [
      {source_class, @rdfs_sub_class, RDF.iri(@jf <> "AuthorizationGrant")},
      {fixture.knowledge_assertion.iri, @rdf_type, RDF.iri(source_class)}
    ]

    attributes =
      reasoning_attributes(fixture, "phase-nine-authority", 0, 1_011, authority_statements)

    assert {:error, %{operation: :reasoning_authority}} =
             Knowledge.materialize_reasoning(attributes, writer: fixture.writer)

    assert {:error, %{operation: :reasoning_bounds}} =
             attributes
             |> put_in([:bounds, :max_iterations], 51)
             |> Knowledge.materialize_reasoning(writer: fixture.writer)

    stale =
      put_in(
        attributes,
        [:source_graph_revisions, fixture.memory_graph],
        Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph) - 1
      )

    assert {:error, %{kind: :stale_precondition, operation: :derived_source_revisions}} =
             Knowledge.materialize_reasoning(
               %{stale | source_statements: class_statements(fixture)},
               writer: fixture.writer
             )
  end

  test "feeds exact accepted knowledge into bounded contexts and records outcomes separately",
       context do
    fixture = Phase09MemoryFixture.adopted!(context)

    attributes =
      reasoning_attributes(fixture, "phase-nine-feedback", 0, 1_012, class_statements(fixture))

    assert {:ok, reasoning} = Knowledge.materialize_reasoning(attributes, writer: fixture.writer)

    evaluated_at = fixture.knowledge_assertion.recorded_at

    assert {:ok, result} =
             Knowledge.query(
               :knowledge_by_scope,
               QueryCatalog.knowledge_version(),
               %{graph: fixture.memory_graph, resource: fixture.repository_scope},
               fixture.authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: evaluated_at
             )

    assert {:ok, retrieval} =
             Knowledge.retrieve_knowledge(result, %{
               memory_graph_iri: fixture.memory_graph,
               expected_memory_revision:
                 Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph),
               execution_context_iri: fixture.attempt.context_iri,
               evaluated_at: evaluated_at,
               repository_scope_iri: fixture.repository_scope,
               allowed_scope_iris: [fixture.repository_scope],
               allowed_classifications: [:fact, :lesson],
               relevant_resource_iris: [fixture.goal.iri, fixture.schedulable_task.iri],
               current_source_graph_revisions: fixture.knowledge_assertion.source_graph_revisions,
               historical?: false,
               max_results: 20
             })

    memory_revision = Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph)
    derived_revision = reasoning.receipt.graph_revisions[reasoning.target_graph_iri].new

    assert {:ok, feedback} =
             Knowledge.build_learning_inputs(retrieval, reasoning, %{
               expected_memory_revision: memory_revision,
               expected_derived_revision: derived_revision,
               reconciliation_context_iri:
                 Phase04Fixture.resource!("phase-09-reconciliation-context"),
               execution_context_iri: fixture.attempt.context_iri,
               budget: %{max_items: 10, max_bytes: 20_000, max_tokens: 5_000}
             })

    assert feedback.reconciliation.accepted_knowledge_iris == [fixture.knowledge_assertion.iri]
    assert feedback.reconciliation.derived_classifications != []
    assert feedback.execution.prompt_context_persisted? == false
    assert [item] = feedback.execution.knowledge_items
    assert item.selection_explanation != []

    refute Knowledge.learning_feedback_stale?(feedback.execution, %{
             fixture.memory_graph => memory_revision,
             reasoning.target_graph_iri => derived_revision
           })

    assert Knowledge.learning_feedback_stale?(feedback.execution, %{
             fixture.memory_graph => memory_revision + 1,
             reasoning.target_graph_iri => derived_revision
           })

    assert {:ok, measurement} =
             Knowledge.learning_measurement(%{
               knowledge_assertion_iri: fixture.knowledge_assertion.iri,
               prior_evidence_iris: [fixture.evidence_bundle.iri],
               outcome_evidence_iris: [Phase04Fixture.resource!("phase-09-outcome-evidence")],
               metrics: %{checks_passed_delta: 2, regression_detected: false},
               measured_at: DateTime.add(fixture.knowledge_assertion.recorded_at, 3_600, :second)
             })

    refute measurement.confidence_mutated?
    refute measurement.adoption_mutated?
  end

  defp reasoning_attributes(fixture, slug, revision, marker, statements) do
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
      idempotency_key: "phase-09-reasoning-#{marker}",
      correlation_iri: Phase04Fixture.local!(:activity, marker),
      causation_iri: fixture.knowledge_adoption_command.command_iri,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      target_graph_iri: target,
      rule_set_iri: Phase04Fixture.resource!("#{slug}-rules"),
      rule_set_slug: slug,
      rule_revision: revision,
      query_version: "#{slug}/1.0.0",
      source_graph_revisions: %{
        fixture.memory_graph =>
          Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph)
      },
      expected_prior_derivation: nil,
      reason: "phase 09 bounded reasoning"
    }
  end

  defp class_statements(fixture) do
    [
      {@jf <> "Finding", @rdfs_sub_class, RDF.iri(@jf <> "Contradiction")},
      {fixture.knowledge_assertion.iri, @rdf_type, RDF.iri(@jf <> "Finding")}
    ]
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
end

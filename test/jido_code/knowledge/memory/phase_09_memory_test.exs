defmodule JidoCode.Knowledge.Memory.Phase09MemoryTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase09MemoryFixture

  @memory_queries ~w[
    knowledge_by_scope knowledge_by_goal knowledge_by_task knowledge_by_source knowledge_by_policy
    knowledge_by_classification knowledge_by_validity knowledge_neighborhood
  ]a

  test "adopts an accepted claim with complete provenance and idempotent replay", context do
    fixture = Phase09MemoryFixture.adopted!(context)

    assert fixture.knowledge_adoption_receipt.outcome == :committed,
           inspect(fixture.knowledge_adoption_receipt)

    assertion = fixture.knowledge_assertion
    assert assertion.classification == :fact
    assert assertion.source_decision_iri == fixture.outcome_decision.iri
    assert assertion.source_claim_iris != []
    assert assertion.source_evidence_iris == [fixture.evidence_bundle.iri]

    assert assertion.source_graph_revisions ==
             Map.delete(
               fixture.sufficiency_assessment.source_graph_revisions,
               fixture.verification_activity.control_graph_iri
             )

    assert assertion.transition.next_state == :still_valid
    assert fixture.knowledge_adoption_command.payload.prompt_context == nil
    assert fixture.knowledge_adoption_command.payload.direct_side_effects == []

    assert {:ok, replay} =
             Writer.execute(fixture.writer, fixture.knowledge_adoption_command)

    assert replay.outcome == :already_committed

    names = QueryCatalog.names(QueryCatalog.knowledge_version())
    for name <- @memory_queries, do: assert(name in names)
    assert :ok = QueryCatalog.verify()

    assert {:ok, result} =
             query(
               fixture,
               :knowledge_by_scope,
               fixture.repository_scope,
               assertion.recorded_at
             )

    assert result.data != []

    assert {:ok, projection} =
             Knowledge.retrieve_knowledge(
               result,
               retrieval_context(fixture, assertion.recorded_at)
             )

    assert [selected] = projection.assertions
    assert selected.iri == assertion.iri
    assert :repository_scope in selected.selection_explanation
    assert :source_revisions_exact in selected.selection_explanation
    refute inspect(projection) =~ fixture.execution_context.instruction
  end

  test "rejects unaccepted, raw, secret-bearing, stale, broad, and unsupported adoption",
       context do
    fixture = Phase09MemoryFixture.prepared!(context)
    attributes = fixture.knowledge_assertion_attributes
    [disposition] = fixture.outcome_decision.claim_dispositions

    cohort_attributes = %{
      attributes
      | scope_kind: :cohort,
        scope_iri: fixture.cohort.iri,
        cohort_graph_iri: fixture.cohort_graph,
        cohort_evidence_iris: [fixture.cohort_membership.iri]
    }

    cohort_attributes =
      Map.put(
        cohort_attributes,
        :cohort_graph_revision,
        Phase09MemoryFixture.graph_revision!(fixture, fixture.cohort_graph)
      )

    assert {:ok, cohort_assertion} =
             Knowledge.knowledge_assertion(
               fixture.outcome_decision,
               fixture.outcome_decision.claim_dispositions,
               cohort_attributes
             )

    assert cohort_assertion.scope_kind == :cohort

    assert cohort_assertion.source_graph_revisions[fixture.cohort_graph] ==
             cohort_attributes.cohort_graph_revision

    for rejected <- [
          %{attributes | classification: :unsupported},
          %{attributes | source_kind: :prompt_transcript},
          %{attributes | scope_iri: Phase04Fixture.resource!("phase-09-over-broad-scope")},
          %{
            attributes
            | recorded_at: fixture.evidence_bundle.valid_to,
              valid_from: fixture.evidence_bundle.valid_to
          }
        ] do
      assert {:error, %{operation: :knowledge_assertion}} =
               Knowledge.knowledge_assertion(
                 fixture.outcome_decision,
                 fixture.outcome_decision.claim_dispositions,
                 rejected
               )
    end

    assert {:error, %{operation: :knowledge_assertion}} =
             Knowledge.knowledge_assertion(
               fixture.outcome_decision,
               [%{disposition | state: :waived}],
               attributes
             )

    secret_claim = %{
      disposition.prior
      | object: RDF.XSD.String.new("token=ghp_123456789012345678901234567890")
    }

    assert {:error, %{operation: :knowledge_assertion}} =
             Knowledge.knowledge_assertion(
               fixture.outcome_decision,
               [%{disposition | prior: secret_claim}],
               attributes
             )
  end

  test "preserves independently adopted compatible assertions as explicit support", context do
    fixture = Phase09MemoryFixture.adopted!(context)
    recorded_at = DateTime.add(fixture.knowledge_assertion.recorded_at, 10, :second)

    assertion_attributes = %{
      fixture.knowledge_assertion_attributes
      | actor_iri: fixture.actor,
        supporting_assertion_iris: [fixture.knowledge_assertion.iri],
        valid_from: recorded_at,
        recorded_at: recorded_at
    }

    assert {:ok, compatible} =
             Knowledge.knowledge_assertion(
               fixture.outcome_decision,
               fixture.outcome_decision.claim_dispositions,
               assertion_attributes
             )

    refute compatible.iri == fixture.knowledge_assertion.iri

    command_attributes = %{
      fixture.knowledge_adoption_command_attributes
      | principal_iri: fixture.actor,
        correlation_iri: Phase04Fixture.local!(:activity, 991),
        expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
        expected_graph_revisions: %{
          fixture.memory_graph =>
            Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph),
          fixture.evidence_graph =>
            Phase09MemoryFixture.graph_revision!(fixture, fixture.evidence_graph),
          fixture.graphs.policy =>
            Phase09MemoryFixture.graph_revision!(fixture, fixture.graphs.policy)
        },
        recorded_at: recorded_at
    }

    assert {:ok, command} =
             Knowledge.adopt_knowledge(
               compatible,
               fixture.outcome_decision,
               command_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed, inspect(receipt)

    assert {:ok, result} =
             query(
               fixture,
               :knowledge_neighborhood,
               fixture.knowledge_assertion.iri,
               recorded_at
             )

    assert Enum.any?(result.data, &(decoded(&1, "assertion") == compatible.iri))
    assert Enum.any?(result.data, &(decoded(&1, "support") == fixture.knowledge_assertion.iri))
  end

  test "withholds reviewed knowledge and retrieves only its provenance-complete replacement",
       context do
    fixture = Phase09MemoryFixture.contradicted!(context)
    assert fixture.contradictory_evidence_receipt.outcome == :committed
    assertion = fixture.knowledge_assertion
    initial_resolution = Phase09MemoryFixture.resolution(assertion)
    review_attributes = Phase09MemoryFixture.evolution_attributes(fixture)

    assert {:ok, review_command} =
             Knowledge.evolve_knowledge(
               assertion,
               initial_resolution,
               nil,
               review_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, review_receipt} = Writer.execute(fixture.writer, review_command)
    assert review_receipt.outcome == :committed, inspect(review_receipt)

    assert {:ok, reviewed_result} =
             query(
               fixture,
               :knowledge_by_scope,
               fixture.repository_scope,
               review_attributes.recorded_at
             )

    assert {:ok, current_reviewed} =
             Knowledge.retrieve_knowledge(
               reviewed_result,
               retrieval_context(fixture, review_attributes.recorded_at)
             )

    assert current_reviewed.assertions == []

    assert {:ok, historical_reviewed} =
             Knowledge.retrieve_knowledge(
               reviewed_result,
               %{retrieval_context(fixture, review_attributes.recorded_at) | historical?: true}
             )

    assert [reviewed] = historical_reviewed.assertions
    assert reviewed.state == :under_review
    assert reviewed.contradiction_iris == [fixture.contradictory_bundle.iri]

    replacement_at = DateTime.add(review_attributes.recorded_at, 60, :second)

    replacement_attributes = %{
      fixture.knowledge_assertion_attributes
      | classification: :lesson,
        supersedes_iris: [assertion.iri],
        valid_from: replacement_at,
        recorded_at: replacement_at
    }

    assert {:ok, replacement} =
             Knowledge.knowledge_assertion(
               fixture.outcome_decision,
               fixture.outcome_decision.claim_dispositions,
               replacement_attributes
             )

    reviewed_resolution = %{
      subject_iri: assertion.iri,
      current_state: :under_review,
      current_revision: 1,
      current_transition: review_command.payload.transition_iri,
      history: []
    }

    superseded_at = DateTime.add(replacement_at, 60, :second)

    supersede_attributes =
      fixture
      |> Phase09MemoryFixture.evolution_attributes(%{
        next_state: :superseded,
        recorded_at: superseded_at,
        reason: "replace reviewed knowledge with a new accepted classification",
        correlation_iri: Phase04Fixture.local!(:activity, 996)
      })

    assert {:ok, supersede_command} =
             Knowledge.evolve_knowledge(
               assertion,
               reviewed_resolution,
               replacement,
               supersede_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, supersede_receipt} = Writer.execute(fixture.writer, supersede_command)
    assert supersede_receipt.outcome == :committed, inspect(supersede_receipt)

    assert {:ok, current_result} =
             query(
               fixture,
               :knowledge_by_scope,
               fixture.repository_scope,
               superseded_at
             )

    context =
      retrieval_context(fixture, superseded_at)
      |> Map.put(
        :expected_memory_revision,
        Phase09MemoryFixture.graph_revision!(fixture, fixture.memory_graph)
      )

    assert {:ok, current} = Knowledge.retrieve_knowledge(current_result, context)
    assert [selected] = current.assertions
    assert selected.iri == replacement.iri
    assert selected.state == :still_valid

    assert {:ok, historical} =
             Knowledge.retrieve_knowledge(current_result, %{context | historical?: true})

    assert Enum.map(historical.assertions, & &1.iri) |> Enum.sort() ==
             Enum.sort([assertion.iri, replacement.iri])
  end

  test "requires a new exact query context and excludes stale source revisions", context do
    fixture = Phase09MemoryFixture.adopted!(context)
    at = fixture.knowledge_assertion.recorded_at

    assert {:ok, result} =
             query(fixture, :knowledge_by_scope, fixture.repository_scope, at)

    [{graph, revision} | _rest] = Map.to_list(fixture.knowledge_assertion.source_graph_revisions)

    stale_context =
      fixture
      |> retrieval_context(at)
      |> put_in([:current_source_graph_revisions, graph], revision + 1)

    assert {:ok, stale} = Knowledge.retrieve_knowledge(result, stale_context)
    assert stale.assertions == []

    assert {:error, %{operation: :knowledge_retrieval}} =
             Knowledge.retrieve_knowledge(
               result,
               Map.put(stale_context, :prompt, "remember this")
             )

    assert {:error, %{operation: :knowledge_retrieval}} =
             Knowledge.retrieve_knowledge(
               result,
               %{
                 stale_context
                 | execution_context_iri: Phase04Fixture.resource!("another-context")
               }
               |> Map.put(:evaluated_at, DateTime.add(at, 1, :second))
             )
  end

  defp query(fixture, name, resource, evaluated_at) do
    QueryRunner.execute(
      name,
      QueryCatalog.knowledge_version(),
      %{graph: fixture.memory_graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: evaluated_at
    )
  end

  defp retrieval_context(fixture, evaluated_at) do
    %{
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
    }
  end

  defp decoded(row, key) do
    case row[key] do
      %{value: value} -> value
      value -> value
    end
  end
end

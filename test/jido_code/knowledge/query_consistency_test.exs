defmodule JidoCode.Knowledge.QueryConsistencyTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CompletenessBoundary
  alias JidoCode.Knowledge.CurrentStateCache
  alias JidoCode.Knowledge.CurrentStateResolver
  alias JidoCode.Knowledge.QueryConsistency
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.TemporalSelection
  alias JidoCode.Knowledge.Transitions
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    {:ok, fixture: fixture, authority: authority}
  end

  test "validates exact, minimum, historical, and temporal constraint combinations", %{
    fixture: fixture
  } do
    assert {:ok, strict} =
             QueryConsistency.new(%{
               mode: :strict,
               exact_dataset_revision: 2,
               exact_graph_revisions: %{fixture.graphs.catalog => 1},
               required_complete_graphs: [fixture.graphs.catalog],
               valid_at: fixture.issued_at
             })

    assert strict.mode == :strict
    assert byte_size(QueryConsistency.digest(strict)) == 64

    assert {:error, %{kind: :invalid_input}} =
             QueryConsistency.new(%{
               exact_dataset_revision: 2,
               minimum_dataset_revision: 1
             })

    assert {:error, %{kind: :invalid_input}} =
             QueryConsistency.new(%{mode: :historical})

    assert {:error, %{kind: :invalid_input}} =
             QueryConsistency.new(%{
               valid_at: fixture.issued_at,
               valid_interval: {fixture.issued_at, DateTime.add(fixture.issued_at, 1, :day)}
             })
  end

  test "strict reads fail with an evaluated receipt while warn reads expose degradation", %{
    fixture: fixture,
    authority: authority
  } do
    strict = %{
      mode: :strict,
      exact_dataset_revision: 999,
      exact_graph_revisions: %{fixture.graphs.catalog => 1},
      required_complete_graphs: [fixture.graphs.catalog]
    }

    assert {:error, %{kind: :stale_precondition}, receipt} =
             query_catalog_graph(fixture, authority, strict)

    assert receipt.status == :degraded
    assert :dataset_revision_mismatch in receipt.gaps
    assert receipt.graph_revisions == %{fixture.graphs.catalog => 1}

    assert {:ok, result} = query_catalog_graph(fixture, authority, %{strict | mode: :warn})
    assert result.consistency.status == :degraded
    assert {:consistency, :dataset_revision_mismatch} in result.warnings

    satisfied = %{
      mode: :strict,
      exact_dataset_revision: result.dataset_revision,
      exact_graph_revisions: %{fixture.graphs.catalog => 1},
      required_complete_graphs: [fixture.graphs.catalog]
    }

    assert {:ok, exact} = query_catalog_graph(fixture, authority, satisfied)
    assert exact.consistency.status == :satisfied
    assert exact.consistency.complete_graphs == [fixture.graphs.catalog]
  end

  test "resolves a unique accepted transition endpoint and keys cache entries by source revision",
       %{
         fixture: fixture
       } do
    enrolled = Phase04Fixture.enroll!(fixture)
    asserted = Phase04Fixture.assert_outcome!(enrolled)
    graph = asserted.control_graph

    genesis = transition(asserted, 1, 0, :proposed, nil, nil)
    eligible = transition(asserted, 2, 1, :eligible, :proposed, genesis.projection.transition_iri)
    dataset = transition_dataset(graph, [genesis, eligible])

    assert {:ok, current} =
             CurrentStateResolver.resolve_dataset(dataset, graph, asserted.goal, 7)

    assert current.current_state == :eligible
    assert current.chain_revision == 1
    assert current.endpoint_transition_iri == eligible.projection.transition_iri
    assert current.evaluated_graph_revision == 7
    assert current.actor_iri == asserted.actor

    cache = start_supervised!({CurrentStateCache, name: nil})
    assert :miss = CurrentStateCache.fetch(cache, graph, asserted.goal, 7)
    assert :ok = CurrentStateCache.put(cache, graph, asserted.goal, 7, current)
    assert {:ok, ^current} = CurrentStateCache.fetch(cache, graph, asserted.goal, 7)
    assert :miss = CurrentStateCache.fetch(cache, graph, asserted.goal, 8)
    assert :ok = CurrentStateCache.reset(cache)
    assert :miss = CurrentStateCache.fetch(cache, graph, asserted.goal, 7)

    fork = transition(asserted, 3, 1, :cancelled, :proposed, genesis.projection.transition_iri)
    forked_dataset = transition_dataset(graph, [genesis, eligible, fork])

    assert {:error, %{kind: :conflict}} =
             CurrentStateResolver.resolve_dataset(forked_dataset, graph, asserted.goal, 8)
  end

  test "missing facts are unknown outside one exact completeness boundary", %{fixture: fixture} do
    {:ok, assertion_iri} =
      ResourceIdentity.deterministic(:validation_report, "phase-05-completeness")

    attributes = %{
      assertion_iri: assertion_iri,
      subject_iri: fixture.factory_iri,
      scope_iri: fixture.factory_scope,
      graph_family: :factory_catalog,
      source_graph_iri: fixture.graphs.catalog,
      source_revision: 1,
      predicate_coverage: ["https://jido.run/ontology/factory#managedBy"],
      class_coverage: ["https://jido.run/ontology/factory#Factory"],
      producer_iri: fixture.actor,
      valid_from: fixture.issued_at,
      valid_to: DateTime.add(fixture.issued_at, 365, :day),
      invalidated_at: nil
    }

    assert {:ok, boundary} = CompletenessBoundary.new(attributes)

    requirement = %{
      subject_iri: fixture.factory_iri,
      scope_iri: fixture.factory_scope,
      graph_family: :factory_catalog,
      source_graph_iri: fixture.graphs.catalog,
      source_revision: 1,
      predicates: ["https://jido.run/ontology/factory#managedBy"],
      classes: []
    }

    assert {:unknown, [:coverage_absent]} =
             CompletenessBoundary.closed_world_result(
               false,
               requirement,
               [],
               fixture.issued_at
             )

    assert {:known, false, ^boundary} =
             CompletenessBoundary.closed_world_result(
               false,
               requirement,
               [boundary],
               fixture.issued_at
             )

    stale = %{boundary | source_revision: 0}

    assert {:unknown, [:coverage_absent]} =
             CompletenessBoundary.closed_world_result(
               false,
               requirement,
               [stale],
               fixture.issued_at
             )
  end

  test "bitemporal selection retains concurrent incompatible claims", %{fixture: fixture} do
    graph = fixture.graphs.catalog
    recorded_at = fixture.issued_at

    assertions = [
      assertion(local!(:claim, 20), graph, 3, recorded_at, :risk, "low"),
      assertion(local!(:claim, 21), graph, 3, recorded_at, :risk, "high"),
      assertion(local!(:claim, 22), graph, 4, recorded_at, :owner, "factory")
    ]

    assert {:ok, selection} =
             TemporalSelection.select(assertions, %{
               recorded_revision: 3,
               valid_at: recorded_at,
               historical_graphs: [graph],
               limit: 10
             })

    assert length(selection.assertions) == 2
    assert selection.contradictions?
    refute selection.truncated?

    assert {:error, %{kind: :invalid_input}} =
             TemporalSelection.select(assertions, %{
               recorded_revision: 3,
               valid_at: recorded_at,
               historical_graphs: List.duplicate(graph, 21)
             })
  end

  defp query_catalog_graph(fixture, authority, consistency) do
    QueryRunner.execute(
      :graph_metadata,
      "1.0.0",
      %{graph: fixture.graphs.catalog},
      authority,
      fixture.factory_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at,
      consistency: consistency
    )
  end

  defp transition(fixture, entropy, revision, next_state, prior_state, predecessor) do
    transition_iri = local!(:transition, entropy)

    {:ok, proposal} =
      Transitions.proposal(%{
        transition_iri: transition_iri,
        subject: fixture.goal,
        next_state: next_state,
        prior_state: prior_state,
        expected_predecessor: predecessor,
        revision: revision,
        actor: fixture.actor,
        cause: fixture.outcome_envelope.command_iri,
        reason: "phase-05-current-state",
        generated_at: fixture.issued_at,
        recorded_at: fixture.issued_at
      })

    {:ok, decision} =
      Transitions.decide(proposal, %{
        decision_iri: local!(:decision, entropy),
        authority: fixture.actor,
        disposition: :accepted,
        decided_at: fixture.issued_at
      })

    %{projection: decision.projection, quads: proposal.quads ++ decision.quads}
  end

  defp transition_dataset(graph, transitions) do
    quads =
      Enum.flat_map(transitions, fn transition ->
        Enum.map(transition.quads, fn {subject, predicate, object} ->
          {subject, predicate, object, RDF.iri(graph)}
        end)
      end)

    RDF.Dataset.new(quads)
  end

  defp assertion(iri, graph, revision, recorded_at, key, value) do
    %{
      assertion_iri: iri,
      graph_iri: graph,
      recorded_revision: revision,
      recorded_at: recorded_at,
      source_observed_at: recorded_at,
      valid_from: DateTime.add(recorded_at, -1, :day),
      valid_to: DateTime.add(recorded_at, 1, :day),
      invalidated_at: nil,
      superseded_by: nil,
      claim_key: key,
      value: value
    }
  end

  defp local!(kind, marker) do
    {:ok, iri} = ResourceIdentity.local(kind, marker, :binary.copy(<<marker>>, 10))
    iri
  end
end

defmodule JidoCode.Knowledge.Control.Phase07ReconciliationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Reconciler
  alias JidoCode.Knowledge.Control.Reconciliation
  alias JidoCode.Knowledge.Control.ReconciliationDiscovery
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Control.ReconciliationProjection
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07ReconciliationFixture

  setup context do
    {:ok, fixture: Phase07ReconciliationFixture.reconciled!(context)}
  end

  test "requires coherent authorized complete exact-revision packages", %{fixture: fixture} do
    attributes = fixture.reconciliation_package_attributes

    assert {:ok, replayed} = ReconciliationPackage.new(attributes)
    assert replayed.iri == fixture.reconciliation_package.iri

    stale =
      Map.update!(
        attributes.current_graph_revisions,
        fixture.graphs.policy,
        &(&1 + 1)
      )

    assert {:error, %{operation: :reconciliation_graph_revisions}} =
             attributes
             |> Map.put(:current_graph_revisions, stale)
             |> ReconciliationPackage.new()

    assert {:error, %{operation: :reconciliation_graph_revisions}} =
             attributes
             |> Map.put(:authorized_graphs, [fixture.control_graph])
             |> ReconciliationPackage.new()

    assert {:error, %{operation: :reconciliation_observation}} =
             attributes
             |> put_in([:observation, :complete?], false)
             |> ReconciliationPackage.new()

    assert {:error, %{operation: :reconciliation_package}} =
             attributes
             |> Map.put(:ontology_versions, ["1.0.0", "2.0.0"])
             |> ReconciliationPackage.new()

    suspended = put_in(attributes, [:enrollment, :state], :suspended)

    assert {:error, %{operation: :reconciliation_enrollment}} =
             ReconciliationPackage.new(suspended)
  end

  test "persists stable work reuse and reconstructs exact bounded explanations", %{
    fixture: fixture
  } do
    assert fixture.reconciliation_receipt.outcome == :committed
    assert fixture.reconciliation_transition_receipt.outcome == :committed
    assert fixture.reconciliation_resolution.current_state == :completed
    assert QueryCatalog.reconciliation_version() == "1.4.0"
    assert :ok = QueryCatalog.verify()

    [result] = fixture.reconciliation.results
    assert result.classification == :existing_work_reused
    assert result.proposal.target_iri == fixture.goal.iri
    refute result.requires_decision?

    assert {:ok, %{outcome: :already_committed}} =
             Writer.execute(fixture.writer, fixture.reconciliation_recording.command)

    assert {:ok, input_result} =
             query(
               fixture,
               :reconciliation_input,
               fixture.control_graph,
               fixture.reconciliation_package.iri,
               fixture.repository_scope
             )

    assert {:ok, input} =
             ReconciliationProjection.build(input_result, %{
               graph_iri: fixture.control_graph,
               resource_iri: fixture.reconciliation_package.iri
             })

    assert length(input.data.graph_revisions) == 6

    assert input.receipt.graph_revision ==
             Phase07ReconciliationFixture.graph_revision!(fixture, fixture.control_graph)

    assert {:ok, explanation_result} =
             query(
               fixture,
               :reconciliation_explanation,
               fixture.control_graph,
               fixture.reconciliation_package.iri,
               fixture.repository_scope
             )

    assert {:ok, explanation_graph} =
             ReconciliationProjection.build(explanation_result, %{
               graph_iri: fixture.control_graph,
               resource_iri: fixture.reconciliation_package.iri,
               row_limit: 200
             })

    assert explanation_graph.data != []

    assert {:ok, explanation} = ReconciliationProjection.explain(fixture.reconciliation)

    assert explanation.graph_revisions ==
             ReconciliationPackage.graph_revisions(fixture.reconciliation_package)

    assert [%{result: :existing_work_reused, proposed_or_reused_iri: goal}] = explanation.results
    assert goal == fixture.goal.iri

    assert {:ok, incomplete_result} =
             query_without_resource(
               fixture,
               :incomplete_reconciliations,
               fixture.control_graph,
               fixture.repository_scope
             )

    assert {:ok, %{data: []}} =
             ReconciliationProjection.build(incomplete_result, %{
               graph_iri: fixture.control_graph
             })

    assert {:ok, scope_result} =
             query_without_resource(
               fixture,
               :active_reconciliation_scopes,
               fixture.graphs.catalog,
               fixture.factory_scope
             )

    assert {:ok, scope_projection} =
             ReconciliationProjection.build(scope_result, %{
               graph_iri: fixture.graphs.catalog
             })

    assert Enum.any?(scope_projection.data, &(&1.repository_iri == fixture.repository))

    assert {:ok, [active]} =
             ReconciliationDiscovery.active_scopes(
               fixture.authority,
               fixture.factory_scope,
               fixture.graphs.catalog,
               query_runner: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert active.repository_iri == fixture.repository
    assert active.state == :active
    assert is_binary(active.transition_iri)
  end

  test "classifies unknown, contradiction, risky proposal, and changed context explicitly", %{
    fixture: fixture
  } do
    base = fixture.reconciliation_evaluation
    attributes = reconciliation_attributes(fixture, 770)

    unknown = %{
      base
      | observed_state: :unknown,
        complete?: false,
        existing_goal_iri: nil,
        existing_obligation_iri: nil
    }

    assert {:ok, unknown_reconciliation} =
             Reconciliation.new(fixture.reconciliation_package, [unknown], attributes)

    assert [%{classification: :unknown, proposal: %{action: :omit}}] =
             unknown_reconciliation.results

    contradiction = %{unknown | observed_state: :contradictory}

    assert {:ok, contradiction_reconciliation} =
             Reconciliation.new(fixture.reconciliation_package, [contradiction], attributes)

    assert [%{classification: :contradiction, requires_decision?: true}] =
             contradiction_reconciliation.results

    policy_conflict = %{
      base
      | existing_goal_iri: nil,
        policy_conflict?: true,
        superseded_proposal_iris: [hd(fixture.reconciliation.proposals).iri]
    }

    assert {:ok, conflict_reconciliation} =
             Reconciliation.new(fixture.reconciliation_package, [policy_conflict], attributes)

    assert [%{classification: :policy_conflict, requires_decision?: true} = conflict_result] =
             conflict_reconciliation.results

    assert conflict_result.proposal.superseded_proposal_iris ==
             [hd(fixture.reconciliation.proposals).iri]

    risky = %{
      base
      | existing_goal_iri: nil,
        existing_obligation_iri: nil,
        risk: 9,
        human_approval_required?: true
    }

    assert {:ok, risky_reconciliation} =
             Reconciliation.new(fixture.reconciliation_package, [risky], attributes)

    assert [%{classification: :proposal_pending, requires_decision?: true} = risky_result] =
             risky_reconciliation.results

    assert risky_result.proposal.action == :propose
    assert is_binary(risky_result.proposal.target_iri)
    assert is_binary(risky_result.proposal.decision_iri)

    changed_revisions =
      Map.update!(
        fixture.reconciliation_package_attributes.graph_revisions,
        fixture.graphs.policy,
        &(&1 + 1)
      )

    changed_attributes =
      fixture.reconciliation_package_attributes
      |> Map.put(:graph_revisions, changed_revisions)
      |> Map.put(:current_graph_revisions, changed_revisions)

    assert {:ok, changed_package} = ReconciliationPackage.new(changed_attributes)
    refute changed_package.iri == fixture.reconciliation_package.iri

    assert {:ok, changed_reconciliation} =
             Reconciliation.new(changed_package, [base], attributes)

    refute hd(changed_reconciliation.results).gap.iri ==
             hd(fixture.reconciliation.results).gap.iri

    statements = Reconciliation.statements(risky_reconciliation)

    refute Enum.any?(statements, fn {_subject, _predicate, object} ->
             to_string(object) == "https://jido.run/ontology/factory#Lease"
           end)
  end

  test "coalesces graph wakeups and rediscovers candidates after restart", %{fixture: fixture} do
    parent = self()

    candidate = %{
      scope_iri: fixture.repository_scope,
      dataset_revision: Phase07ReconciliationFixture.dataset_revision(fixture),
      priority: 10
    }

    discover = fn ->
      {:ok, [%{candidate | dataset_revision: candidate.dataset_revision - 1}, candidate]}
    end

    reconcile = fn value ->
      send(parent, {:reconciled, value.scope_iri, value.dataset_revision})
      {:ok, value.dataset_revision}
    end

    {:ok, first} =
      Reconciler.start_link(
        name: nil,
        discover: discover,
        reconcile: reconcile,
        max_concurrency: 2,
        retry_delay_ms: 10
      )

    assert_receive {:reconciled, scope, revision}, 1_000
    assert scope == fixture.repository_scope
    assert revision == candidate.dataset_revision
    refute_receive {:reconciled, _, _}, 50

    assert %{discovery_count: 1, processed_count: 1, pending_count: 0} =
             Reconciler.status(first)

    :ok = GenServer.stop(first)

    {:ok, second} =
      Reconciler.start_link(
        name: nil,
        discover: fn -> {:ok, [candidate]} end,
        reconcile: reconcile,
        max_concurrency: 1
      )

    on_exit(fn ->
      if Process.alive?(second), do: GenServer.stop(second)
    end)

    assert_receive {:reconciled, ^scope, ^revision}, 1_000
    assert %{discovery_count: 1, processed_count: 1} = Reconciler.status(second)

    Reconciler.cancel(second, scope)
    Reconciler.trigger(second, %{candidate | dataset_revision: revision + 1})
    refute_receive {:reconciled, _, _}, 100
  end

  defp query(fixture, name, graph, resource, scope) do
    QueryRunner.execute(
      name,
      QueryCatalog.reconciliation_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp query_without_resource(fixture, name, graph, scope) do
    QueryRunner.execute(
      name,
      QueryCatalog.reconciliation_version(),
      %{graph: graph},
      fixture.authority,
      scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp reconciliation_attributes(fixture, sequence) do
    fixture
    |> Phase07Fixture.base_attributes(sequence, fixture.obligation.iri, "evaluate reconciliation")
    |> Map.merge(%{
      cause_iri: fixture.obligation.iri,
      recorded_at: DateTime.add(fixture.issued_at, 70, :second)
    })
  end
end

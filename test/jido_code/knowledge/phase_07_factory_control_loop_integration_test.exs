defmodule JidoCode.Knowledge.Phase07FactoryControlLoopIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Control.CapabilityRegistry
  alias JidoCode.Knowledge.Control.Cohort
  alias JidoCode.Knowledge.Control.Eligibility
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Control.Reconciliation
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.Enrollment
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07ReconciliationFixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture

  setup context do
    {:ok, fixture: Phase07ReconciliationFixture.reconciled!(context)}
  end

  test "observation, desired state, policy, obligation, goal, plan, and reconciliation remain one explainable graph flow",
       %{fixture: fixture} do
    assert fixture.desired_resolution.current_state == :active
    assert fixture.policy_resolution.current_state == :active
    assert fixture.obligation_resolution.current_state == :active
    assert fixture.goal_resolution.current_state == :approved
    assert fixture.reconciliation_resolution.current_state == :completed

    assert {:ok, replay_receipt} =
             Writer.execute(fixture.writer, fixture.reconciliation_recording.command)

    assert replay_receipt.outcome == :already_committed

    reordered_revisions =
      fixture.reconciliation_package_attributes.graph_revisions
      |> Enum.reverse()
      |> Map.new()

    reordered_attributes = %{
      fixture.reconciliation_package_attributes
      | graph_revisions: reordered_revisions,
        current_graph_revisions: reordered_revisions,
        authorized_graphs: Enum.reverse(Map.keys(reordered_revisions))
    }

    assert {:ok, reordered_package} = ReconciliationPackage.new(reordered_attributes)
    assert reordered_package.iri == fixture.reconciliation_package.iri

    reconciliation_attributes =
      fixture
      |> Phase07Fixture.base_attributes(860, fixture.obligation.iri, "replay reordered context")
      |> Map.merge(%{
        cause_iri: fixture.obligation.iri,
        recorded_at: DateTime.add(fixture.issued_at, 160, :second)
      })

    assert {:ok, reordered_reconciliation} =
             Reconciliation.new(
               reordered_package,
               [fixture.reconciliation_evaluation],
               reconciliation_attributes
             )

    assert reordered_reconciliation.iri == fixture.reconciliation.iri
    assert hd(reordered_reconciliation.results).proposal.target_iri == fixture.goal.iri

    changed_revisions = Map.update!(reordered_revisions, fixture.graphs.policy, &(&1 + 1))

    assert {:ok, changed_package} =
             reordered_attributes
             |> Map.put(:graph_revisions, changed_revisions)
             |> Map.put(:current_graph_revisions, changed_revisions)
             |> Map.put(:authorized_graphs, Map.keys(changed_revisions))
             |> ReconciliationPackage.new()

    refute changed_package.iri == fixture.reconciliation_package.iri

    fixture =
      fixture
      |> Phase07SchedulingFixture.satisfy_approval!()
      |> Phase07SchedulingFixture.evaluate_eligibility!()

    assert fixture.eligibility.eligible?

    assert fixture.eligibility.graph_revisions[fixture.control_graph] ==
             Phase07SchedulingFixture.graph_revision!(fixture, fixture.control_graph)

    incomplete = put_in(fixture.eligibility_context, [:boundaries, :policy], false)
    assert {:ok, blocked} = Eligibility.evaluate(incomplete)
    refute blocked.eligible?
    assert :policy_boundary_incomplete in blocked.blockers

    assert {:ok, explanation_result} =
             query(
               fixture,
               :reconciliation_explanation,
               fixture.control_graph,
               fixture.reconciliation_package.iri,
               fixture.repository_scope
             )

    assert explanation_result.data != []
  end

  test "one active policy explains a graph-derived cohort across two enrolled repositories without cross-scope enumeration",
       %{fixture: fixture} do
    {fixture, second} = enroll_second_repository!(fixture)

    {:ok, cohort_graph} =
      GraphRegistry.graph_iri(:derived, %{rule_set: "phase-07-cohort", revision: 2})

    memberships = [
      %{
        repository_iri: fixture.repository,
        path: [fixture.enrollment.iri, fixture.repository],
        complete?: true,
        incomplete_reasons: []
      },
      %{
        repository_iri: second.repository_iri,
        path: [second.iri, second.repository_iri],
        complete?: true,
        incomplete_reasons: []
      }
    ]

    source_revisions = %{
      fixture.graphs.catalog =>
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.catalog),
      fixture.graphs.policy =>
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.policy),
      fixture.publication.graph_iri =>
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.publication.graph_iri)
    }

    attributes = %{
      command_iri: Phase04Fixture.local!(:command, 862),
      authority: fixture.authority,
      idempotency_key: "phase-07-862",
      correlation_iri: Phase04Fixture.local!(:activity, 862),
      causation_iri: fixture.policy.iri,
      target_graph_iri: cohort_graph,
      rule_set_iri: fixture.cohort_membership_attributes.rule_set_iri,
      rule_set_slug: "phase-07-cohort",
      rule_revision: 2,
      source_graph_revisions: source_revisions,
      reason: "derive two-repository policy cohort"
    }

    assert {:ok, %{outcome: :committed}} =
             Cohort.publish_membership(fixture.cohort, memberships, attributes,
               writer: fixture.writer
             )

    assert fixture.policy_resolution.current_state == :active
    assert fixture.policy.desired_outcome_refs == [fixture.desired_outcome.iri]

    Enum.each(memberships, fn membership ->
      assert {:ok, explanation} =
               Cohort.explanation(fixture.cohort, membership, %{
                 source_graph_revisions: source_revisions
               })

      assert explanation.complete?
      assert explanation.evaluator_version == "1.0.0"
      assert explanation.source_graph_revisions == source_revisions
    end)

    assert {:ok, result} =
             query(
               fixture,
               :cohort_membership,
               cohort_graph,
               fixture.cohort.iri,
               fixture.factory_scope
             )

    repositories =
      result.data |> Enum.map(&decoded(&1, "repository")) |> Enum.uniq() |> Enum.sort()

    assert repositories == Enum.sort([fixture.repository, second.repository_iri])

    assert {:error, %{kind: :unauthorized}} =
             query(
               fixture,
               :cohort_membership,
               cohort_graph,
               fixture.cohort.iri,
               fixture.repository_scope
             )
  end

  test "two authorized agents race one task and only one graph lease with fence one commits", %{
    fixture: fixture
  } do
    {fixture, second_projection} = register_second_capability!(fixture)

    fixture =
      fixture
      |> Map.put(:extra_capability_projections, [second_projection])
      |> Phase07SchedulingFixture.satisfy_approval!()
      |> Phase07SchedulingFixture.evaluate_eligibility!()

    assert Enum.map(fixture.eligibility.providers, & &1.holder_iri) |> Enum.uniq() |> length() ==
             2

    acquisitions =
      fixture.eligibility.providers
      |> Enum.with_index(870)
      |> Enum.map(fn {provider, sequence} ->
        attributes = lease_attributes(fixture, provider, sequence)

        {:ok, acquisition} =
          ExecutionLease.acquire_command(
            fixture.eligibility,
            fixture.schedulable_task_resolution,
            attributes,
            clock: fn -> fixture.issued_at end
          )

        acquisition
      end)

    results =
      acquisitions
      |> Task.async_stream(
        fn acquisition ->
          {:ok, receipt} = Writer.execute(fixture.writer, acquisition.command)
          {acquisition, receipt}
        end,
        max_concurrency: 2,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, fn {_acquisition, receipt} -> receipt.outcome == :committed end) ==
             1

    assert Enum.count(results, fn {_acquisition, receipt} -> receipt.outcome == :conflicted end) ==
             1

    [{winner, winner_receipt}] =
      Enum.filter(results, fn {_acquisition, receipt} -> receipt.outcome == :committed end)

    [{_loser, loser_receipt}] =
      Enum.filter(results, fn {_acquisition, receipt} -> receipt.outcome == :conflicted end)

    assert winner_receipt.graph_revisions[fixture.control_graph] >
             fixture.eligibility.graph_revisions[fixture.control_graph]

    assert loser_receipt.retry == :refresh
    assert winner.lease.fencing_token == 1

    assert {:ok, lease_result} =
             query(
               fixture,
               :lease_description,
               fixture.control_graph,
               winner.lease.iri,
               fixture.repository_scope
             )

    holders =
      lease_result.data
      |> Enum.filter(&(decoded(&1, "predicate") == "https://jido.run/ontology/factory#claimedBy"))
      |> Enum.map(&decoded(&1, "object"))

    assert holders == [winner.lease.holder_iri]
  end

  defp enroll_second_repository!(fixture) do
    {:ok, repository} =
      ResourceIdentity.conceptual_repository("phase-07-second-managed-repository")

    scope = Phase04Fixture.scope!(:repository, "phase-07-second-managed-repository")

    {:ok, locator} =
      Locator.new(%{
        provider: "https://github.com",
        external_id: "R_phase_07_second",
        owner: "agentjido",
        name: "second-managed-repository",
        state: :active,
        observed_at: fixture.issued_at,
        relationships: []
      })

    command_iri = Phase04Fixture.local!(:command, 861)

    {:ok, enrollment} =
      Enrollment.new(%{
        factory_iri: fixture.factory_iri,
        repository_iri: repository,
        repository_scope_iri: scope,
        policy_boundary_iri: fixture.enrollment.policy_boundary_iri,
        policy_iris: [fixture.policy.iri],
        locator: locator,
        actor_iri: fixture.actor,
        cause_iri: command_iri,
        reason: "enroll second Phase 7 cohort repository",
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 31_536_000)
      })

    {:ok, command} =
      Enrollment.enroll_command(
        enrollment,
        %{
          command_iri: command_iri,
          principal_iri: fixture.actor,
          factory_scope_iri: fixture.factory_scope,
          idempotency_key: "phase-07-second-enrollment",
          correlation_iri: Phase04Fixture.local!(:activity, 861),
          causation_iri: fixture.policy.iri,
          expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
          catalog_graph_iri: fixture.graphs.catalog,
          expected_catalog_revision:
            Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.catalog),
          reason: "enroll second Phase 7 cohort repository"
        },
        clock: fn -> fixture.issued_at end
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, command)
    {fixture, enrollment}
  end

  defp register_second_capability!(fixture) do
    holder = Phase04Fixture.resource!("phase-07-second-agent")

    {:ok, grant} =
      ResourceIdentity.deterministic(:authorization_grant, holder <> "\nexecution")

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(864, fixture.policy.iri, "register second capability")
      |> Map.merge(%{
        holder_iri: holder,
        scope_iri: fixture.repository_scope,
        kind: :agent,
        capability_iri: fixture.capability,
        provider_iri: holder,
        provider_version: "phase-07-agent/1.0.0",
        mode: :observed,
        supported_scope_refs: [fixture.repository_scope],
        supported_effect_refs: [fixture.desired_outcome.iri],
        authorization_grant_refs: [grant],
        evidence_source_iri: fixture.observation.batch_iri,
        limits: %{concurrency: 1, risk_level: 2},
        complete?: true,
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 86_400),
        cause_iri: fixture.policy.iri,
        recorded_at: DateTime.add(fixture.issued_at, 164, :second),
        policy_graph_iri: fixture.graphs.policy,
        expected_policy_revision:
          Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.policy)
      })

    {:ok, capability} = CapabilityRegistry.new(attributes)

    {:ok, registration} =
      CapabilityRegistry.register_command(capability, attributes,
        clock: fn -> fixture.issued_at end
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, registration.command)
    {:ok, resolution} = Transition.resolve([capability.transition])

    activation_attributes =
      fixture
      |> Phase07Fixture.base_attributes(865, capability.iri, "activate second capability")
      |> Map.merge(%{
        scope_iri: fixture.repository_scope,
        policy_graph_iri: fixture.graphs.policy,
        expected_policy_revision:
          Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.policy),
        next_state: :available,
        recorded_at: DateTime.add(fixture.issued_at, 165, :second)
      })

    {:ok, activation} =
      CapabilityRegistry.transition_command(resolution, activation_attributes,
        clock: fn -> fixture.issued_at end
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, activation.command)

    projection = %{
      iri: capability.iri,
      holder_iri: capability.holder_iri,
      capability_iri: capability.capability_iri,
      state: :available,
      complete?: true,
      authorization_grant_refs: [grant],
      authorization_complete?: true,
      authorized_scope?: true,
      inferred?: false,
      valid_from: capability.valid_from,
      valid_to: capability.valid_to,
      limits: %{concurrency: 1},
      active_leases: 0
    }

    {fixture, projection}
  end

  defp lease_attributes(fixture, provider, sequence) do
    now = DateTime.add(fixture.issued_at, 180, :second)

    fixture
    |> Phase07Fixture.base_attributes(sequence, fixture.eligibility.receipt_iri, "race lease")
    |> Map.merge(%{
      holder_iri: provider.holder_iri,
      capability_iri: provider.capability_iri,
      fencing_token: 1,
      acquired_at: now,
      expires_at: DateTime.add(now, 300, :second),
      max_expires_at: DateTime.add(now, 900, :second),
      control_graph_iri: fixture.control_graph,
      expected_control_revision:
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.control_graph),
      recorded_at: now
    })
  end

  defp query(fixture, name, graph, resource, scope) do
    QueryRunner.execute(
      name,
      QueryCatalog.scheduling_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp decoded(row, key) do
    case row[key] do
      %{value: value} -> value
      value -> value
    end
  end
end

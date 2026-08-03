defmodule JidoCode.Knowledge.Control.Phase07GovernanceTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Control.CapabilityRegistry
  alias JidoCode.Knowledge.Control.Cohort
  alias JidoCode.Knowledge.Control.GovernanceProjection
  alias JidoCode.Knowledge.Control.Obligation
  alias JidoCode.Knowledge.Control.Policy
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07GovernanceFixture

  setup context do
    {:ok, fixture: Phase07GovernanceFixture.governance!(context)}
  end

  test "persists and projects exact policy, cohort, obligation, and capability views", %{
    fixture: fixture
  } do
    assert fixture.policy_activation_receipt.outcome == :committed
    assert fixture.cohort_membership_receipt.outcome == :committed
    assert fixture.obligation_activation_receipt.outcome == :committed
    assert fixture.capability_activation_receipt.outcome == :committed
    assert fixture.capability_hierarchy_receipt.outcome == :committed
    assert fixture.policy_resolution.current_state == :active
    assert fixture.obligation_resolution.current_state == :active
    assert fixture.capability_resolution.current_state == :available

    assert QueryCatalog.governance_version() == "1.3.0"
    assert :ok = QueryCatalog.verify()

    assert {:error, %{kind: :invalid_input}} =
             QueryCatalog.fetch(:policy_description, QueryCatalog.control_loop_version())

    assert {:ok, policy_result} =
             query(
               fixture,
               :policy_description,
               fixture.graphs.policy,
               fixture.policy.iri,
               fixture.factory_scope
             )

    assert {:ok, policy} =
             GovernanceProjection.build(policy_result, %{
               graph_iri: fixture.graphs.policy,
               resource_iri: fixture.policy.iri
             })

    assert policy.receipt.graph_revision ==
             Phase07GovernanceFixture.graph_revision!(fixture, fixture.graphs.policy)

    assert {:ok, membership_result} =
             query(
               fixture,
               :cohort_membership,
               fixture.cohort_graph,
               fixture.cohort.iri,
               fixture.factory_scope
             )

    assert {:ok, membership} =
             GovernanceProjection.build(membership_result, %{
               graph_iri: fixture.cohort_graph,
               resource_iri: fixture.cohort.iri
             })

    assert membership.data.count == 1
    assert hd(membership.data.memberships).complete?
    assert length(membership.data.declared_source_graph_revisions) == 3
    assert membership.receipt.freshness == "current"

    assert {:ok, obligation_result} =
             query(
               fixture,
               :obligation_description,
               fixture.control_graph,
               fixture.obligation.iri,
               fixture.repository_scope
             )

    assert {:ok, obligation} =
             GovernanceProjection.build(obligation_result, %{
               graph_iri: fixture.control_graph,
               resource_iri: fixture.obligation.iri
             })

    assert length(obligation.data.source_graph_revisions) == 3

    assert {:ok, capability_result} =
             query(
               fixture,
               :capability_strict_view,
               fixture.graphs.policy,
               fixture.capability_declaration.iri,
               fixture.factory_scope
             )

    assert {:ok, capability} =
             GovernanceProjection.build(capability_result, %{
               graph_iri: fixture.graphs.policy,
               resource_iri: fixture.capability_declaration.iri
             })

    assert capability.data.current_transition.revision == 1

    assert {:ok, hierarchy_result} =
             query(
               fixture,
               :capability_hierarchy,
               fixture.capability_hierarchy_graph,
               fixture.capability,
               fixture.repository_scope
             )

    assert {:ok, hierarchy} =
             GovernanceProjection.build(hierarchy_result, %{
               graph_iri: fixture.capability_hierarchy_graph,
               resource_iri: fixture.capability
             })

    assert [%{authority?: false}] = hierarchy.data.classifications
    assert length(hierarchy.data.declared_source_graph_revisions) == 1
  end

  test "enforces policy contracts, stable obligations, and fail-closed capability admission", %{
    fixture: fixture
  } do
    refute Policy.evaluator_allowed?(:arbitrary_code, "1.0.0", :resource_description)

    invalid_policy =
      fixture
      |> policy_attributes("invalid-evaluator", :desired_posture)
      |> put_in([:evaluator, :name], :arbitrary_code)

    assert {:error, %{operation: :policy_evaluator}} = Policy.new(invalid_policy)

    {:ok, acceptance} =
      fixture
      |> policy_attributes("acceptance-policy", :acceptance)
      |> Map.put(:desired_outcome_refs, [])
      |> Policy.new()

    assert {:error, %{operation: :policy_conflict_evaluation}} =
             Policy.resolve_conflicts([fixture.policy, acceptance])

    {:ok, conflicting} =
      fixture
      |> policy_attributes("conflicting-policy", :desired_posture)
      |> Map.put(:conflicts_with, [fixture.policy.iri])
      |> Policy.new()

    assert {:requires_decision, %{explanation: :incompatible_applicable_policies}} =
             Policy.resolve_conflicts([fixture.policy, conflicting])

    obligation_attributes = %{
      policy_iri: fixture.obligation.policy_iri,
      scope_iri: fixture.obligation.scope_iri,
      repository_iri: fixture.obligation.repository_iri,
      desired_outcome_iri: fixture.obligation.desired_outcome_iri,
      dimension_iri: fixture.obligation.dimension_iri,
      applicability_evidence_iri: fixture.obligation.applicability_evidence_iri,
      gap_iri: fixture.obligation.gap_iri,
      constraint_refs: fixture.obligation.constraint_refs,
      acceptance_requirement_refs: fixture.obligation.acceptance_requirement_refs,
      valid_from: fixture.obligation.valid_from,
      valid_to: fixture.obligation.valid_to,
      source_graph_revisions:
        Map.new(fixture.obligation.graph_references, &{&1.graph_iri, &1.revision}),
      actor_iri: fixture.actor,
      cause_iri: fixture.policy.iri,
      reason: "derive policy obligation",
      recorded_at: DateTime.add(fixture.issued_at, 34, :second)
    }

    assert {:ok, replayed} = Obligation.new(obligation_attributes)
    assert replayed.iri == fixture.obligation.iri
    refute replayed.iri == fixture.goal.iri
    refute Enum.any?(fixture.plan.tasks, &(&1.iri == replayed.iri))

    changed_revisions =
      Map.update!(obligation_attributes.source_graph_revisions, fixture.graphs.policy, &(&1 + 1))

    assert {:ok, changed} =
             obligation_attributes
             |> Map.put(:source_graph_revisions, changed_revisions)
             |> Obligation.new()

    refute changed.iri == replayed.iri

    admission = %{
      state: :available,
      complete?: true,
      authorization_complete?: true,
      authorized_scope?: true,
      inferred?: false,
      authorization_grant_refs: [fixture.capability_authorization_grant],
      valid_from: fixture.capability_declaration.valid_from,
      valid_to: fixture.capability_declaration.valid_to
    }

    assert {:ok, ^admission} = CapabilityRegistry.schedulable?(admission, fixture.issued_at)

    assert {:blocked, reasons} =
             admission
             |> Map.merge(%{
               authorization_grant_refs: [],
               authorization_complete?: false,
               inferred?: true
             })
             |> CapabilityRegistry.schedulable?(fixture.issued_at)

    assert :authorization_absent in reasons
    assert :authorization_incomplete in reasons
    assert :capability_inferred_only in reasons

    assert {:blocked, [:capability_incomplete]} =
             admission
             |> Map.put(:complete?, false)
             |> CapabilityRegistry.schedulable?(fixture.issued_at)
  end

  test "marks derived membership stale after source change and denies cross-scope enumeration", %{
    fixture: fixture
  } do
    assert {:ok, explanation} =
             Cohort.explanation(
               fixture.cohort,
               fixture.cohort_membership,
               %{
                 source_graph_revisions:
                   fixture.cohort_membership_attributes.source_graph_revisions
               }
             )

    assert explanation.complete?
    assert length(explanation.membership_path) == 2

    assert {:error, %{kind: :unauthorized}} =
             query(
               fixture,
               :cohort_membership,
               fixture.cohort_graph,
               fixture.cohort.iri,
               fixture.repository_scope
             )

    {:ok, transition} =
      CapabilityRegistry.transition_command(
        fixture.capability_resolution,
        fixture
        |> Phase07Fixture.base_attributes(
          750,
          fixture.capability_declaration.iri,
          "mark capability stale"
        )
        |> Map.merge(%{
          scope_iri: fixture.repository_scope,
          policy_graph_iri: fixture.graphs.policy,
          expected_policy_revision:
            Phase07GovernanceFixture.graph_revision!(fixture, fixture.graphs.policy),
          next_state: :stale,
          recorded_at: DateTime.add(fixture.issued_at, 50, :second)
        }),
        clock: fn -> fixture.issued_at end
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, transition.command)

    stale_attributes = %{
      command_iri: Phase04Fixture.local!(:command, 751),
      authority: fixture.authority,
      idempotency_key: "phase-07-751",
      correlation_iri: Phase04Fixture.local!(:activity, 751),
      causation_iri: transition.command.command_iri,
      target_graph_iri: fixture.cohort_graph,
      rule_set_iri: fixture.cohort_membership_attributes.rule_set_iri,
      rule_set_slug: fixture.cohort_membership_attributes.rule_set_slug,
      rule_revision: fixture.cohort_membership_attributes.rule_revision,
      source_graph_revisions: fixture.cohort_membership_attributes.source_graph_revisions,
      expected_prior_derivation: %{
        graph_iri: fixture.cohort_graph,
        revision: Phase07GovernanceFixture.graph_revision!(fixture, fixture.cohort_graph)
      },
      reason: "invalidate membership after policy graph change"
    }

    assert {:ok, %{outcome: :committed}} =
             Cohort.mark_membership_stale(fixture.cohort, stale_attributes,
               writer: fixture.writer
             )

    assert {:ok, stale_result} =
             query(
               fixture,
               :cohort_membership,
               fixture.cohort_graph,
               fixture.cohort.iri,
               fixture.factory_scope
             )

    assert stale_result.freshness == :stale
  end

  defp query(fixture, name, graph, resource, scope) do
    QueryRunner.execute(
      name,
      QueryCatalog.governance_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp policy_attributes(fixture, name, kind) do
    %{
      name: name,
      version: "1.0.0",
      owner_iri: fixture.actor,
      scope_iri: fixture.factory_scope,
      kind: kind,
      evaluator: %{
        name: :protected_main,
        version: "1.0.0",
        query: :latest_complete_observation
      },
      closed_inputs: fixture.policy.closed_inputs,
      desired_outcome_refs: [fixture.desired_outcome.iri],
      constraint_refs: fixture.policy.constraint_refs,
      obligation_template_iri: fixture.policy.obligation_template_iri,
      evidence_requirement_refs: fixture.policy.evidence_requirement_refs,
      decision_requirement_refs: fixture.policy.decision_requirement_refs,
      valid_from: fixture.policy.valid_from,
      valid_to: fixture.policy.valid_to,
      priority: :high,
      conflict_posture: :explicit_decision,
      conflicts_with: [],
      cause_iri: fixture.policy.iri,
      reason: "test policy contract",
      recorded_at: fixture.issued_at
    }
  end
end

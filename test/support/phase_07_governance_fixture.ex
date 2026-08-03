defmodule JidoCode.TestSupport.Phase07GovernanceFixture do
  @moduledoc false

  alias JidoCode.Knowledge.Control.CapabilityRegistry
  alias JidoCode.Knowledge.Control.Cohort
  alias JidoCode.Knowledge.Control.Obligation
  alias JidoCode.Knowledge.Control.Policy
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture

  def governance!(context) do
    context
    |> Phase07Fixture.work!()
    |> propose_policy!()
    |> activate_policy!()
    |> register_capability!()
    |> activate_capability!()
    |> define_cohort!()
    |> publish_membership!()
    |> derive_obligation!()
    |> activate_obligation!()
    |> publish_capability_hierarchy!()
  end

  def propose_policy!(fixture) do
    attributes =
      fixture
      |> Phase07Fixture.base_attributes(730, fixture.desired_outcome.iri, "propose policy")
      |> Map.merge(%{
        name: "protected-main",
        version: "1.0.0",
        owner_iri: fixture.actor,
        scope_iri: fixture.factory_scope,
        kind: :desired_posture,
        evaluator: %{
          name: :protected_main,
          version: "1.0.0",
          query: :latest_complete_observation
        },
        closed_inputs: [fixture.graphs.catalog, fixture.observation.graph_iri],
        desired_outcome_refs: [fixture.desired_outcome.iri],
        constraint_refs: Enum.map(fixture.desired_outcome.constraints, & &1.iri),
        obligation_template_iri: resource!("phase-07-obligation-template"),
        evidence_requirement_refs: fixture.desired_outcome.evidence_refs,
        decision_requirement_refs: [resource!("phase-07-acceptance-decision")],
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 31_536_000),
        priority: :high,
        conflict_posture: :explicit_decision,
        conflicts_with: [],
        cause_iri: fixture.desired_outcome.iri,
        recorded_at: DateTime.add(fixture.issued_at, 30, :second)
      })

    {:ok, policy} = Policy.new(attributes)

    {:ok, proposal} =
      Policy.propose_command(
        policy,
        Map.merge(attributes, %{
          policy_graph_iri: fixture.graphs.policy,
          expected_policy_revision: graph_revision!(fixture, fixture.graphs.policy)
        }),
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, proposal.command)

    Map.merge(fixture, %{
      policy: policy,
      policy_proposal: proposal,
      policy_receipt: receipt,
      policy_transitions: [policy.transition]
    })
  end

  def activate_policy!(fixture) do
    {:ok, resolution} = Transition.resolve(fixture.policy_transitions)

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(731, fixture.policy.iri, "activate policy")
      |> Map.merge(%{
        scope_iri: fixture.factory_scope,
        policy_graph_iri: fixture.graphs.policy,
        expected_policy_revision: graph_revision!(fixture, fixture.graphs.policy),
        next_state: :active,
        recorded_at: DateTime.add(fixture.issued_at, 31, :second)
      })

    {:ok, activation} =
      Policy.transition_command(resolution, attributes, clock: fn -> fixture.issued_at end)

    {:ok, receipt} = Writer.execute(fixture.writer, activation.command)
    transitions = fixture.policy_transitions ++ [activation.transition]
    {:ok, resolution} = Transition.resolve(transitions)

    Map.merge(fixture, %{
      policy_transitions: transitions,
      policy_resolution: resolution,
      policy_activation: activation,
      policy_activation_receipt: receipt
    })
  end

  def define_cohort!(fixture) do
    attributes =
      fixture
      |> Phase07Fixture.base_attributes(732, fixture.policy.iri, "define managed cohort")
      |> Map.merge(%{
        name: "managed-elixir-repositories",
        scope_iri: fixture.factory_scope,
        owner_iri: fixture.actor,
        mode: :query,
        static_members: [],
        evaluator: %{
          name: :repository_attributes,
          version: "1.0.0",
          query: :factory_repository_cohort
        },
        closed_inputs: [fixture.graphs.catalog, fixture.publication.graph_iri],
        policy_graph_iri: fixture.graphs.policy,
        expected_policy_revision: graph_revision!(fixture, fixture.graphs.policy)
      })

    {:ok, cohort} = Cohort.new(attributes)

    {:ok, definition} =
      Cohort.define_command(cohort, attributes, clock: fn -> fixture.issued_at end)

    {:ok, receipt} = Writer.execute(fixture.writer, definition.command)

    Map.merge(fixture, %{
      cohort: cohort,
      cohort_definition: definition,
      cohort_receipt: receipt
    })
  end

  def publish_membership!(fixture) do
    {:ok, graph} = GraphRegistry.graph_iri(:derived, %{rule_set: "phase-07-cohort", revision: 1})

    membership = %{
      repository_iri: fixture.repository,
      path: [fixture.enrollment.iri, fixture.repository],
      complete?: true,
      incomplete_reasons: []
    }

    source_revisions = %{
      fixture.graphs.catalog => graph_revision!(fixture, fixture.graphs.catalog),
      fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy),
      fixture.publication.graph_iri => graph_revision!(fixture, fixture.publication.graph_iri)
    }

    attributes = %{
      command_iri: Phase04Fixture.local!(:command, 733),
      authority: fixture.authority,
      idempotency_key: "phase-07-733",
      correlation_iri: Phase04Fixture.local!(:activity, 733),
      causation_iri: fixture.cohort_definition.command.command_iri,
      target_graph_iri: graph,
      rule_set_iri: resource!("phase-07-cohort-rule"),
      rule_set_slug: "phase-07-cohort",
      rule_revision: 1,
      source_graph_revisions: source_revisions,
      reason: "derive exact managed cohort membership"
    }

    {:ok, receipt} =
      Cohort.publish_membership(fixture.cohort, [membership], attributes, writer: fixture.writer)

    {:ok, membership_iri} = Cohort.membership_identity(fixture.cohort, membership, attributes)

    Map.merge(fixture, %{
      cohort_graph: graph,
      cohort_membership: Map.put(membership, :iri, membership_iri),
      cohort_membership_attributes: attributes,
      cohort_membership_receipt: receipt
    })
  end

  def derive_obligation!(fixture) do
    source_revisions = %{
      fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy),
      fixture.observation.graph_iri => graph_revision!(fixture, fixture.observation.graph_iri),
      fixture.cohort_graph => graph_revision!(fixture, fixture.cohort_graph)
    }

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(734, fixture.policy.iri, "derive policy obligation")
      |> Map.merge(%{
        policy_iri: fixture.policy.iri,
        scope_iri: fixture.repository_scope,
        repository_iri: fixture.repository,
        desired_outcome_iri: fixture.desired_outcome.iri,
        dimension_iri: resource!("phase-07-branch-protection-dimension"),
        applicability_evidence_iri: fixture.cohort_membership.iri,
        gap_iri: fixture.observation.batch_iri,
        constraint_refs: fixture.policy.constraint_refs,
        acceptance_requirement_refs: fixture.policy.decision_requirement_refs,
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 86_400),
        source_graph_revisions: source_revisions,
        cause_iri: fixture.policy.iri,
        recorded_at: DateTime.add(fixture.issued_at, 34, :second)
      })

    {:ok, obligation} = Obligation.new(attributes)

    {:ok, derivation} =
      Obligation.derive_command(
        obligation,
        Map.merge(attributes, %{
          control_graph_iri: fixture.control_graph,
          expected_control_revision: graph_revision!(fixture, fixture.control_graph),
          evidence_locations: %{
            fixture.policy.iri => fixture.graphs.policy,
            fixture.cohort_membership.iri => fixture.cohort_graph,
            fixture.observation.batch_iri => fixture.observation.graph_iri
          }
        }),
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, derivation.command)

    Map.merge(fixture, %{
      obligation: obligation,
      obligation_derivation: derivation,
      obligation_receipt: receipt,
      obligation_transitions: [obligation.transition]
    })
  end

  def activate_obligation!(fixture) do
    {:ok, resolution} = Transition.resolve(fixture.obligation_transitions)

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(735, fixture.obligation.iri, "activate obligation")
      |> Map.merge(%{
        scope_iri: fixture.repository_scope,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        next_state: :active,
        recorded_at: DateTime.add(fixture.issued_at, 35, :second)
      })

    {:ok, activation} =
      Obligation.transition_command(resolution, attributes, clock: fn -> fixture.issued_at end)

    {:ok, receipt} = Writer.execute(fixture.writer, activation.command)
    transitions = fixture.obligation_transitions ++ [activation.transition]
    {:ok, resolution} = Transition.resolve(transitions)

    Map.merge(fixture, %{
      obligation_transitions: transitions,
      obligation_resolution: resolution,
      obligation_activation: activation,
      obligation_activation_receipt: receipt
    })
  end

  def register_capability!(fixture) do
    {:ok, authorization_grant} =
      ResourceIdentity.deterministic(
        :authorization_grant,
        fixture.actor <> "\nexecution"
      )

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(736, fixture.policy.iri, "register capability")
      |> Map.merge(%{
        holder_iri: fixture.actor,
        scope_iri: fixture.repository_scope,
        kind: :agent,
        capability_iri: fixture.capability,
        provider_iri: fixture.actor,
        provider_version: "phase-07-agent/1.0.0",
        mode: :observed,
        supported_scope_refs: [fixture.repository_scope],
        supported_effect_refs: [fixture.desired_outcome.iri],
        authorization_grant_refs: [authorization_grant],
        evidence_source_iri: fixture.observation.batch_iri,
        limits: %{concurrency: 1, risk_level: 2},
        complete?: true,
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 86_400),
        cause_iri: fixture.policy.iri,
        recorded_at: DateTime.add(fixture.issued_at, 36, :second),
        policy_graph_iri: fixture.graphs.policy,
        expected_policy_revision: graph_revision!(fixture, fixture.graphs.policy)
      })

    {:ok, capability} = CapabilityRegistry.new(attributes)

    {:ok, registration} =
      CapabilityRegistry.register_command(capability, attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, registration.command)

    Map.merge(fixture, %{
      capability_declaration: capability,
      capability_registration: registration,
      capability_receipt: receipt,
      capability_transitions: [capability.transition],
      capability_authorization_grant: authorization_grant
    })
  end

  def activate_capability!(fixture) do
    {:ok, resolution} = Transition.resolve(fixture.capability_transitions)

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        737,
        fixture.capability_declaration.iri,
        "activate capability"
      )
      |> Map.merge(%{
        scope_iri: fixture.repository_scope,
        policy_graph_iri: fixture.graphs.policy,
        expected_policy_revision: graph_revision!(fixture, fixture.graphs.policy),
        next_state: :available,
        recorded_at: DateTime.add(fixture.issued_at, 37, :second)
      })

    {:ok, activation} =
      CapabilityRegistry.transition_command(resolution, attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, activation.command)
    transitions = fixture.capability_transitions ++ [activation.transition]
    {:ok, resolution} = Transition.resolve(transitions)

    Map.merge(fixture, %{
      capability_transitions: transitions,
      capability_resolution: resolution,
      capability_activation: activation,
      capability_activation_receipt: receipt
    })
  end

  def publish_capability_hierarchy!(fixture) do
    {:ok, graph} =
      GraphRegistry.graph_iri(:derived, %{rule_set: "phase-07-capability", revision: 1})

    broader = resource!("phase-07-repository-administration-capability")

    attributes = %{
      command_iri: Phase04Fixture.local!(:command, 738),
      authority: fixture.authority,
      scope_iri: fixture.repository_scope,
      idempotency_key: "phase-07-738",
      correlation_iri: Phase04Fixture.local!(:activity, 738),
      causation_iri: fixture.capability_activation.command.command_iri,
      target_graph_iri: graph,
      rule_set_iri: resource!("phase-07-capability-rule"),
      rule_set_slug: "phase-07-capability",
      rule_revision: 1,
      evaluator_version: "1.0.0",
      source_graph_revisions: %{
        fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy)
      },
      reason: "derive capability hierarchy"
    }

    {:ok, receipt} =
      CapabilityRegistry.publish_hierarchy(
        [%{capability_iri: fixture.capability, broader_capability_iri: broader}],
        attributes,
        writer: fixture.writer
      )

    Map.merge(fixture, %{
      capability_hierarchy_graph: graph,
      broader_capability: broader,
      capability_hierarchy_attributes: attributes,
      capability_hierarchy_receipt: receipt
    })
  end

  def graph_revision!(fixture, graph), do: Phase07Fixture.graph_revision!(fixture, graph)
  defp resource!(slug), do: Phase04Fixture.resource!(slug)
end

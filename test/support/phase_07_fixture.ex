defmodule JidoCode.TestSupport.Phase07Fixture do
  @moduledoc false

  alias JidoCode.Knowledge.Control.DesiredOutcome
  alias JidoCode.Knowledge.Control.Graph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Control.WorkGraph
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase06Fixture

  @jf "https://jido.run/ontology/factory#"

  def work!(context) do
    fixture = Phase06Fixture.complete!(context)
    {:ok, control_graph} = Graph.repository_control(fixture.repository)
    fixture = Map.put(fixture, :control_graph, control_graph)
    fixture = assert_outcome!(fixture)
    fixture = activate_outcome!(fixture)
    fixture = propose_goal!(fixture)
    fixture = approve_goal!(fixture)
    fixture = propose_plan!(fixture)
    adopt_plan!(fixture)
  end

  def assert_outcome!(fixture) do
    attributes =
      fixture
      |> base_attributes(700, fixture.enrollment_command.command_iri, "assert protected main")
      |> Map.merge(%{
        scope_iri: fixture.repository_scope,
        proposition: %{
          subject: fixture.repository,
          predicate: @jf <> "defaultBranchProtected",
          object: true
        },
        priority: :high,
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 31_536_000),
        policy_refs: [hd(fixture.enrollment.policy_iris)],
        evidence_refs: [Phase04Fixture.resource!("phase-07-branch-protection-evidence")],
        constraints: [
          %{kind: :allowed_branch, value: "refs/heads/main"},
          %{kind: :risk_bound, value: 2},
          %{kind: :required_check, value: "ci"},
          %{kind: :required_approval, value: true}
        ],
        cause_iri: fixture.enrollment_command.command_iri,
        recorded_at: fixture.issued_at
      })

    {:ok, outcome} = DesiredOutcome.new(attributes)

    {:ok, assertion} =
      DesiredOutcome.assert_command(
        outcome,
        Map.merge(attributes, %{
          enrollment: enrollment_context(fixture),
          policy_graph_iri: fixture.graphs.policy,
          control_graph_iri: fixture.control_graph,
          expected_policy_revision: graph_revision!(fixture, fixture.graphs.policy),
          expected_control_revision: 0
        }),
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, assertion.command)

    Map.merge(fixture, %{
      desired_outcome: outcome,
      desired_outcome_assertion: assertion,
      desired_outcome_receipt: receipt,
      desired_transitions: [outcome.transition]
    })
  end

  def activate_outcome!(fixture) do
    {:ok, resolution} = Transition.resolve(fixture.desired_transitions)

    attributes =
      fixture
      |> base_attributes(701, fixture.desired_outcome.iri, "activate desired outcome")
      |> Map.merge(%{
        next_state: :active,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 1, :second)
      })

    {:ok, transition} =
      DesiredOutcome.transition_command(resolution, attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, transition.command)
    transitions = fixture.desired_transitions ++ [transition.transition]
    {:ok, resolution} = Transition.resolve(transitions)

    Map.merge(fixture, %{
      desired_transitions: transitions,
      desired_resolution: resolution,
      desired_activation_receipt: receipt
    })
  end

  def propose_goal!(fixture) do
    attributes =
      fixture
      |> base_attributes(702, fixture.desired_outcome.iri, "propose branch protection goal")
      |> Map.merge(%{
        enrollment: enrollment_context(fixture),
        addresses: [fixture.desired_outcome.iri, fixture.observation.batch_iri],
        policy_refs: fixture.desired_outcome.policy_refs,
        constraint_refs: Enum.map(fixture.desired_outcome.constraints, & &1.iri),
        expected_evidence_refs: fixture.desired_outcome.evidence_refs,
        origin_activity_iri: fixture.observation.activity_iri,
        semantic_key: "protect-default-branch",
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 2, :second)
      })

    {:ok, proposal} = WorkGraph.propose_goal(attributes, clock: fn -> fixture.issued_at end)
    {:ok, receipt} = Writer.execute(fixture.writer, proposal.command)

    Map.merge(fixture, %{
      goal: proposal.goal,
      goal_proposal: proposal,
      goal_receipt: receipt,
      goal_transitions: [proposal.goal.transition]
    })
  end

  def approve_goal!(fixture) do
    {:ok, resolution} = Transition.resolve(fixture.goal_transitions)

    attributes =
      fixture
      |> base_attributes(703, fixture.goal.iri, "approve branch protection goal")
      |> Map.merge(%{
        next_state: :approved,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 3, :second)
      })

    {:ok, approval} =
      WorkGraph.transition_command(resolution, attributes, clock: fn -> fixture.issued_at end)

    {:ok, receipt} = Writer.execute(fixture.writer, approval.command)
    transitions = fixture.goal_transitions ++ [approval.transition]
    {:ok, resolution} = Transition.resolve(transitions)

    Map.merge(fixture, %{
      goal_transitions: transitions,
      goal_resolution: resolution,
      goal_approval: approval,
      goal_approval_receipt: receipt
    })
  end

  def propose_plan!(fixture) do
    capability = Phase04Fixture.resource!("phase-07-repository-settings-capability")
    artifact = fixture.observation.snapshot_iri
    policy_revision = graph_revision!(fixture, fixture.graphs.policy)
    source_revision = graph_revision!(fixture, fixture.publication.graph_iri)
    observation_revision = graph_revision!(fixture, fixture.observation.graph_iri)

    attributes =
      fixture
      |> base_attributes(704, fixture.goal.iri, "propose protected main plan")
      |> Map.merge(%{
        enrollment: enrollment_context(fixture),
        goal: %{
          iri: fixture.goal.iri,
          current_state: fixture.goal_resolution.current_state,
          current_transition: fixture.goal_resolution.current_transition
        },
        source_graph_iri: fixture.publication.graph_iri,
        source_graph_revision: source_revision,
        source_snapshot_iri: fixture.observation.snapshot_iri,
        policy_graph_iri: fixture.graphs.policy,
        policy_graph_revision: policy_revision,
        input_graph_revisions: %{
          fixture.publication.graph_iri => source_revision,
          fixture.observation.graph_iri => observation_revision,
          fixture.graphs.policy => policy_revision
        },
        planner_iri: fixture.actor,
        planner_version: "phase-07-planner/1.0.0",
        assumption_refs: [fixture.observation.snapshot_iri],
        expected_effect_refs: [fixture.desired_outcome.iri],
        verification_strategy: "provider-protection-and-required-checks",
        available_capability_iris: [capability],
        require_verification?: true,
        require_approval?: true,
        tasks: [
          %{
            key: "approve-change",
            kind: :approval,
            required_capability_iris: [],
            constraint_refs: Enum.map(fixture.desired_outcome.constraints, & &1.iri)
          },
          %{
            key: "configure-protection",
            kind: :change,
            depends_on: ["approve-change"],
            required_artifact_iris: [artifact],
            required_capability_iris: [capability]
          },
          %{
            key: "verify-protection",
            kind: :verification,
            depends_on: ["configure-protection"],
            required_artifact_iris: [artifact],
            required_capability_iris: [capability]
          }
        ],
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 4, :second)
      })

    {:ok, proposal} = WorkGraph.propose_plan(attributes, clock: fn -> fixture.issued_at end)
    {:ok, receipt} = Writer.execute(fixture.writer, proposal.command)

    Map.merge(fixture, %{
      capability: capability,
      plan: proposal.plan,
      plan_proposal: proposal,
      plan_attributes: attributes,
      plan_receipt: receipt
    })
  end

  def adopt_plan!(fixture) do
    attributes =
      fixture
      |> base_attributes(705, fixture.plan.iri, "adopt protected main plan")
      |> Map.merge(%{
        source_graph_iri: fixture.plan.source_graph_iri,
        source_graph_revision: fixture.plan.source_graph_revision,
        policy_graph_revision: fixture.plan.policy_graph_revision,
        assumptions_valid?: true,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 5, :second)
      })

    {:ok, adoption} =
      WorkGraph.adopt_plan(fixture.plan, attributes, clock: fn -> fixture.issued_at end)

    {:ok, receipt} = Writer.execute(fixture.writer, adoption.command)

    Map.merge(fixture, %{
      adopted_plan: adoption.plan,
      plan_adoption: adoption,
      plan_adoption_receipt: receipt
    })
  end

  def base_attributes(fixture, sequence, cause, reason) do
    %{
      command_iri: Phase04Fixture.local!(:command, sequence),
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      idempotency_key: "phase-07-#{sequence}",
      correlation_iri: Phase04Fixture.local!(:activity, sequence),
      causation_iri: cause,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      reason: reason
    }
  end

  def enrollment_context(fixture) do
    %{
      enrollment_iri: fixture.enrollment.iri,
      current_transition: fixture.enrollment_resolution.current_transition,
      current_state: fixture.enrollment_resolution.current_state,
      admission: fixture.enrollment_resolution.admission,
      catalog_graph_iri: fixture.graphs.catalog,
      catalog_revision: graph_revision!(fixture, fixture.graphs.catalog)
    }
  end

  def graph_revision!(fixture, graph),
    do: Phase04Fixture.current_graph_revision!(fixture, graph)
end

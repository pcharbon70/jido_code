defmodule JidoCode.TestSupport.Phase07SchedulingFixture do
  @moduledoc false

  alias JidoCode.Knowledge.Control.Eligibility
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Control.WorkGraph
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07ReconciliationFixture

  def leased!(context) do
    context
    |> Phase07ReconciliationFixture.reconciled!()
    |> satisfy_approval!()
    |> evaluate_eligibility!()
    |> acquire_lease!()
  end

  def satisfy_approval!(fixture) do
    approval = task!(fixture, "approve-change")
    resolution = task_resolution!(fixture, approval)

    {fixture, transitions, resolution} =
      Enum.reduce(
        [:eligible, :executing, :awaiting_decision, :satisfied],
        {fixture, initial_task_transitions(fixture, approval), resolution},
        fn next_state, {current_fixture, transitions, current_resolution} ->
          sequence = 780 + length(transitions)

          attributes =
            current_fixture
            |> Phase07Fixture.base_attributes(
              sequence,
              current_resolution.current_transition,
              "advance approval task to #{next_state}"
            )
            |> Map.merge(%{
              control_graph_iri: current_fixture.control_graph,
              expected_control_revision:
                graph_revision!(current_fixture, current_fixture.control_graph),
              next_state: next_state,
              recorded_at: DateTime.add(current_fixture.issued_at, sequence - 700, :second)
            })

          {:ok, command} =
            WorkGraph.transition_command(current_resolution, attributes,
              clock: fn -> current_fixture.issued_at end
            )

          {:ok, _receipt} = Writer.execute(current_fixture.writer, command.command)
          next_transitions = transitions ++ [command.transition]
          {:ok, next_resolution} = Transition.resolve(next_transitions)
          {current_fixture, next_transitions, next_resolution}
        end
      )

    Map.merge(fixture, %{
      approval_task: approval,
      approval_task_transitions: transitions,
      approval_task_resolution: resolution
    })
  end

  def evaluate_eligibility!(fixture) do
    task = task!(fixture, "configure-protection")
    task_resolution = task_resolution!(fixture, task)
    {:ok, plan_resolution} = plan_resolution(fixture)
    now = DateTime.add(fixture.issued_at, 100, :second)

    graph_revisions = %{
      fixture.graphs.catalog => graph_revision!(fixture, fixture.graphs.catalog),
      fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy),
      fixture.observation.graph_iri => graph_revision!(fixture, fixture.observation.graph_iri),
      fixture.publication.graph_iri => graph_revision!(fixture, fixture.publication.graph_iri),
      fixture.cohort_graph => graph_revision!(fixture, fixture.cohort_graph),
      fixture.capability_hierarchy_graph =>
        graph_revision!(fixture, fixture.capability_hierarchy_graph),
      fixture.control_graph => graph_revision!(fixture, fixture.control_graph)
    }

    context = %{
      task: %{
        iri: task.iri,
        state: task_resolution.current_state,
        current_transition: task_resolution.current_transition,
        required_capability_iris: task.required_capabilities
      },
      enrollment_state: fixture.enrollment_resolution.current_state,
      goal_state: fixture.goal_resolution.current_state,
      plan_state: plan_resolution.current_state,
      dependencies: [%{iri: fixture.approval_task.iri, state: :satisfied}],
      artifacts: Enum.map(task.required_artifacts, &%{iri: &1, available?: true}),
      source: %{complete?: true, fresh?: true, contradictory?: false},
      authorization: %{
        complete?: true,
        applicable?: true,
        authorized?: true,
        policy_iris: [fixture.policy.iri]
      },
      capabilities: [capability_projection(fixture)],
      leases: %{complete?: true, active: []},
      cancelled?: false,
      capacity: %{complete?: true, available?: true},
      boundaries: %{
        dependency: true,
        lease: true,
        cancellation: true,
        capability: true,
        policy: true,
        artifact: true,
        source: true
      },
      graph_revisions: graph_revisions,
      current_graph_revisions: graph_revisions,
      authorized_graphs: Map.keys(graph_revisions),
      priority: 100,
      fairness: 1,
      risk: 2,
      evaluated_at: now
    }

    {:ok, eligibility} = Eligibility.evaluate(context)

    Map.merge(fixture, %{
      schedulable_task: task,
      schedulable_task_resolution: task_resolution,
      eligibility_context: context,
      eligibility: eligibility
    })
  end

  def acquire_lease!(fixture) do
    now = fixture.eligibility.evaluated_at

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        790,
        fixture.eligibility.receipt_iri,
        "acquire execution lease"
      )
      |> Map.merge(%{
        holder_iri: fixture.actor,
        capability_iri: fixture.capability,
        fencing_token: 1,
        acquired_at: now,
        expires_at: DateTime.add(now, 300, :second),
        max_expires_at: DateTime.add(now, 900, :second),
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: now
      })

    {:ok, acquisition} =
      ExecutionLease.acquire_command(
        fixture.eligibility,
        fixture.schedulable_task_resolution,
        attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, acquisition.command)
    {:ok, lease_resolution} = Transition.resolve(acquisition.lease_transitions)

    task_transitions =
      initial_task_transitions(fixture, fixture.schedulable_task) ++ acquisition.task_transitions

    {:ok, task_resolution} = Transition.resolve(task_transitions)

    Map.merge(fixture, %{
      lease: acquisition.lease,
      lease_acquisition: acquisition,
      lease_acquisition_attributes: attributes,
      lease_receipt: receipt,
      lease_transitions: acquisition.lease_transitions,
      lease_resolution: lease_resolution,
      schedulable_task_transitions: task_transitions,
      schedulable_task_resolution: task_resolution
    })
  end

  def transition_lease!(fixture, action, sequence, overrides \\ %{}) do
    recorded_at =
      Map.get(overrides, :recorded_at, DateTime.add(fixture.issued_at, sequence - 680, :second))

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        sequence,
        fixture.lease_resolution.current_transition,
        "#{action} execution lease"
      )
      |> Map.merge(%{
        action: action,
        fencing_token: fixture.lease.fencing_token,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: recorded_at
      })
      |> Map.merge(overrides)

    {:ok, transition} =
      ExecutionLease.transition_command(
        fixture.lease,
        fixture.lease_resolution,
        fixture.schedulable_task_resolution,
        attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, transition.command)
    lease_transitions = fixture.lease_transitions ++ [transition.lease_transition]
    {:ok, lease_resolution} = Transition.resolve(lease_transitions)

    task_transitions =
      if transition.task_transition,
        do: fixture.schedulable_task_transitions ++ [transition.task_transition],
        else: fixture.schedulable_task_transitions

    {:ok, task_resolution} = Transition.resolve(task_transitions)

    Map.merge(fixture, %{
      lease: transition.lease,
      lease_transition: transition,
      lease_transition_receipt: receipt,
      lease_transitions: lease_transitions,
      lease_resolution: lease_resolution,
      schedulable_task_transitions: task_transitions,
      schedulable_task_resolution: task_resolution
    })
  end

  def capability_projection(fixture) do
    capability = fixture.capability_declaration

    %{
      iri: capability.iri,
      holder_iri: capability.holder_iri,
      capability_iri: capability.capability_iri,
      state: fixture.capability_resolution.current_state,
      complete?: capability.complete?,
      authorization_grant_refs: capability.authorization_grant_refs,
      authorization_complete?: true,
      authorized_scope?: true,
      inferred?: false,
      valid_from: capability.valid_from,
      valid_to: capability.valid_to,
      limits: %{concurrency: 1},
      active_leases: 0
    }
  end

  def graph_revision!(fixture, graph), do: Phase07Fixture.graph_revision!(fixture, graph)

  defp initial_task_transitions(fixture, task) do
    approval = Enum.find(fixture.plan_adoption.transitions, &(&1.subject_iri == task.iri))
    [task.transition, approval]
  end

  defp task_resolution!(fixture, task) do
    fixture
    |> initial_task_transitions(task)
    |> Transition.resolve()
    |> then(fn {:ok, resolution} -> resolution end)
  end

  defp plan_resolution(fixture) do
    approval = Enum.find(fixture.plan_adoption.transitions, &(&1.subject_iri == fixture.plan.iri))
    Transition.resolve([fixture.plan.transition, approval])
  end

  defp task!(fixture, key), do: Enum.find(fixture.plan.tasks, &(&1.key == key))
end

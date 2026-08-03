defmodule JidoCode.TestSupport.Phase08AttemptFixture do
  @moduledoc false

  alias JidoCode.Factory.Execution.ContextPackage
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Runtime.Version
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture

  def started!(context) do
    fixture = Phase07SchedulingFixture.leased!(context)
    context_map = execution_context!(fixture)
    attempt = attempt!(fixture, context_map)
    start = start!(fixture, attempt, context_map)
    {:ok, receipt} = Writer.execute(fixture.writer, start.command)

    {:ok, attempt_resolution} = Transition.resolve(start.attempt_transitions)

    {:ok, lease_resolution} =
      Transition.resolve(fixture.lease_transitions ++ [start.lease_transition])

    {:ok, task_resolution} =
      Transition.resolve(fixture.schedulable_task_transitions ++ [start.task_transition])

    Map.merge(fixture, %{
      execution_context: context_map,
      attempt: attempt,
      attempt_start: start,
      attempt_start_receipt: receipt,
      attempt_transitions: start.attempt_transitions,
      attempt_resolution: attempt_resolution,
      lease_transitions: fixture.lease_transitions ++ [start.lease_transition],
      lease_resolution: lease_resolution,
      schedulable_task_transitions:
        fixture.schedulable_task_transitions ++ [start.task_transition],
      schedulable_task_resolution: task_resolution
    })
  end

  def execution_context!(fixture) do
    revisions =
      fixture.eligibility_context.graph_revisions
      |> Map.keys()
      |> Map.new(&{&1, graph_revision!(fixture, &1)})

    {:ok, context} =
      ContextPackage.build(%{
        enrollment_iri: fixture.enrollment.iri,
        repository_iri: fixture.repository,
        goal_iri: fixture.goal.iri,
        task_iri: fixture.schedulable_task.iri,
        plan_iri: fixture.plan.iri,
        lease_iri: fixture.lease.iri,
        snapshot_iri: fixture.observation.snapshot_iri,
        task_snapshot_iri: fixture.observation.snapshot_iri,
        actor_iri: fixture.actor,
        agent_iri: fixture.actor,
        capability_iri: fixture.capability,
        fencing_token: fixture.lease.fencing_token,
        runtime_version: Version.current(),
        instruction: "Configure protected main and preserve the accepted verification boundary.",
        source_graph_revisions: revisions,
        current_graph_revisions: revisions,
        constraints: %{network: :deny, writable_paths: [".jido-code/patch"]},
        allowed_effects: ["repository.settings.write", "source.read"],
        task_allowed_effects: ["repository.settings.write", "source.read"],
        expected_artifacts: ["patch", "runtime-outcome"],
        expected_evidence: ["branch-protection-observation", "tests"],
        source_items: [
          item(fixture.observation.snapshot_iri, "exact repository snapshot", :internal, false)
        ],
        knowledge_items: [
          item(
            Phase04Fixture.resource!("phase-08-accepted-convention"),
            "default branch is main",
            :internal,
            true
          )
        ],
        visible_classifications: [:public, :internal],
        budget: %{max_items: 20, max_bytes: 32_768, max_tokens: 8_192},
        assembled_at: DateTime.add(fixture.issued_at, 105, :second),
        lease_expires_at: fixture.lease.expires_at,
        lease_state: :active,
        plan_state: :approved,
        strict_complete?: true
      })

    ContextPackage.durable_map(context)
  end

  def attempt!(fixture, context_map, overrides \\ %{}) do
    attributes =
      Map.merge(
        %{
          idempotency_key: "phase-08-attempt-1",
          authorized_agent: %{
            agent_iri: fixture.actor,
            capability_iri: fixture.capability,
            available?: true
          },
          available_runtime_versions: [Version.current()],
          retry_of_iri: nil
        },
        overrides
      )

    {:ok, attempt} = Knowledge.execution_attempt(context_map, attributes)
    attempt
  end

  def start!(fixture, attempt, context_map) do
    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        920,
        fixture.lease.iri,
        "record fenced execution attempt"
      )
      |> Map.merge(%{
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        expected_run_revision: 0,
        recorded_at: DateTime.add(fixture.issued_at, 110, :second)
      })

    {:ok, plan_resolution} = plan_resolution(fixture)

    {:ok, start} =
      Knowledge.start_execution_attempt(
        attempt,
        context_map,
        fixture.lease,
        %{
          lease: fixture.lease_resolution,
          task: fixture.schedulable_task_resolution,
          plan: plan_resolution
        },
        attributes,
        clock: fn -> fixture.issued_at end
      )

    start
  end

  def request!(fixture) do
    {:ok, request} =
      Request.new(%{
        attempt_iri: fixture.attempt.iri,
        lease_iri: fixture.attempt.lease_iri,
        task_iri: fixture.attempt.task_iri,
        goal_iri: fixture.attempt.goal_iri,
        plan_iri: fixture.attempt.plan_iri,
        repository_iri: fixture.attempt.repository_iri,
        snapshot_iri: fixture.attempt.snapshot_iri,
        actor_iri: fixture.attempt.actor_iri,
        agent_iri: fixture.attempt.agent_iri,
        capability_iri: fixture.attempt.capability_iri,
        fencing_token: fixture.attempt.fencing_token,
        context_digest: fixture.attempt.context_digest,
        runtime_version: fixture.attempt.runtime_version,
        constraints: fixture.execution_context.constraints
      })

    request
  end

  def transition!(fixture, next_state, sequence, overrides \\ %{}) do
    recorded_at =
      Map.get(overrides, :recorded_at, DateTime.add(fixture.issued_at, sequence - 800, :second))

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        sequence,
        fixture.attempt_resolution.current_transition,
        "transition execution attempt to #{next_state}"
      )
      |> Map.merge(%{
        next_state: next_state,
        origin: :runtime,
        fencing_token: fixture.attempt.fencing_token,
        run_graph_iri: fixture.attempt.run_graph_iri,
        expected_run_revision: graph_revision!(fixture, fixture.attempt.run_graph_iri),
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        recorded_at: recorded_at,
        runtime_event: nil
      })
      |> Map.merge(overrides)

    {:ok, command} =
      Knowledge.transition_execution_attempt(
        fixture.attempt,
        fixture.attempt_resolution,
        fixture.lease,
        fixture.schedulable_task_resolution,
        attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command.command)
    attempt_transitions = fixture.attempt_transitions ++ [command.transition]
    {:ok, attempt_resolution} = Transition.resolve(attempt_transitions)

    {task_transitions, task_resolution} =
      if command.task_transition do
        transitions = fixture.schedulable_task_transitions ++ [command.task_transition]
        {:ok, resolution} = Transition.resolve(transitions)
        {transitions, resolution}
      else
        {fixture.schedulable_task_transitions, fixture.schedulable_task_resolution}
      end

    Map.merge(fixture, %{
      attempt_transition: command,
      attempt_transition_receipt: receipt,
      attempt_transitions: attempt_transitions,
      attempt_resolution: attempt_resolution,
      schedulable_task_transitions: task_transitions,
      schedulable_task_resolution: task_resolution
    })
  end

  def graph_revision!(fixture, graph),
    do: Phase07SchedulingFixture.graph_revision!(fixture, graph)

  defp plan_resolution(fixture) do
    approval = Enum.find(fixture.plan_adoption.transitions, &(&1.subject_iri == fixture.plan.iri))
    Transition.resolve([fixture.plan.transition, approval])
  end

  defp item(iri, content, classification, accepted?) do
    %{
      iri: iri,
      content: content,
      classification: classification,
      fresh?: true,
      contradictory?: false,
      accepted?: accepted?,
      required?: true
    }
  end
end

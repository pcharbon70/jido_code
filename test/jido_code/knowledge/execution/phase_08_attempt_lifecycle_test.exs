defmodule JidoCode.Knowledge.Execution.Phase08AttemptLifecycleTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Execution.RetryPolicy
  alias JidoCode.Factory.ExecutionCoordinator
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Runtime.Version
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeExecutionRuntime
  alias JidoCode.TestSupport.Phase08AttemptFixture

  setup context do
    {:ok, fixture: Phase08AttemptFixture.started!(context)}
  end

  test "atomically starts an exact-context attempt and executing lease/task", %{fixture: fixture} do
    assert fixture.attempt_start_receipt.outcome == :committed,
           inspect(fixture.attempt_start_receipt)

    assert fixture.attempt_resolution.current_state == :starting
    assert fixture.lease_resolution.current_state == :executing
    assert fixture.schedulable_task_resolution.current_state == :executing
    assert fixture.attempt.runtime_version == Version.current()
    assert fixture.attempt.context_digest == fixture.execution_context.digest
    assert QueryCatalog.execution_version() == "1.6.0"

    assert {:ok, result} =
             query(
               fixture,
               :resource_description,
               fixture.attempt.run_graph_iri,
               fixture.attempt.iri
             )

    predicates = MapSet.new(result.data, &decoded(&1, "predicate"))
    assert MapSet.member?(predicates, "https://jido.run/ontology/factory#inputPackage")
    assert MapSet.member?(predicates, "https://jido.run/ontology/factory#runtimeVersion")
    assert MapSet.member?(predicates, "https://jido.run/ontology/factory#fencingToken")

    assert {:ok, context_result} =
             query(
               fixture,
               :resource_description,
               fixture.attempt.run_graph_iri,
               fixture.attempt.context_iri
             )

    assert Enum.any?(context_result.data, fn row ->
             decoded(row, "predicate") == "https://jido.run/ontology/factory#contextDigest" and
               decoded(row, "object") == fixture.attempt.context_digest
           end)
  end

  test "records runtime transitions with current predecessor and fence", %{fixture: fixture} do
    running =
      Phase08AttemptFixture.transition!(fixture, :running, 921, %{
        runtime_event: runtime_event(fixture, 1, :pending)
      })

    assert running.attempt_resolution.current_state == :running

    waiting =
      Phase08AttemptFixture.transition!(running, :waiting_tool, 922, %{
        runtime_event: runtime_event(running, 2, :pending)
      })

    assert waiting.attempt_resolution.current_state == :waiting_tool

    resumed =
      Phase08AttemptFixture.transition!(waiting, :running, 923, %{
        runtime_event: runtime_event(waiting, 3, :success)
      })

    completed =
      Phase08AttemptFixture.transition!(resumed, :completed, 924, %{
        runtime_event: runtime_event(resumed, 4, :success)
      })

    assert completed.attempt_resolution.current_state == :completed
    assert completed.schedulable_task_resolution.current_state == :awaiting_evidence

    assert {:ok, goal_result} =
             query(
               completed,
               :transition_endpoint,
               completed.control_graph,
               completed.goal.iri
             )

    assert Enum.any?(goal_result.data, fn row ->
             decoded(row, "state") == "https://jido.run/ontology/concept/GoalApproved"
           end)
  end

  test "makes cancellation a committed control transition before runtime propagation", %{
    fixture: fixture
  } do
    cancelling =
      Phase08AttemptFixture.transition!(fixture, :cancelling, 925, %{
        origin: :control,
        runtime_event: nil
      })

    assert cancelling.attempt_transition.command.command_type == "RequestExecutionCancellation"
    assert cancelling.attempt_resolution.current_state == :cancelling

    cancelled =
      Phase08AttemptFixture.transition!(cancelling, :cancelled, 926, %{
        origin: :runtime,
        runtime_event: runtime_event(cancelling, 2, :cancelled)
      })

    assert cancelled.attempt_resolution.current_state == :cancelled
    assert cancelled.schedulable_task_resolution.current_state == :cancelled
    assert length(cancelled.attempt_resolution.history) == 4
  end

  test "rejects stale fences and incompatible or unauthorized starts", %{fixture: fixture} do
    assert {:error, %{operation: :transition_execution_attempt}} =
             Knowledge.transition_execution_attempt(
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               fixture.schedulable_task_resolution,
               transition_attributes(fixture, 927, :running, %{fencing_token: 2}),
               clock: fn -> fixture.issued_at end
             )

    assert {:error, %{operation: :execution_attempt_agent}} =
             Knowledge.execution_attempt(fixture.execution_context, %{
               idempotency_key: "unauthorized-agent",
               authorized_agent: %{
                 agent_iri: fixture.actor,
                 capability_iri: fixture.capability,
                 available?: false
               },
               available_runtime_versions: [Version.current()]
             })

    assert {:error, %{operation: :execution_attempt}} =
             Knowledge.execution_attempt(fixture.execution_context, %{
               idempotency_key: "incompatible-runtime",
               authorized_agent: %{
                 agent_iri: fixture.actor,
                 capability_iri: fixture.capability,
                 available?: true
               },
               available_runtime_versions: ["jido:9.0.0/runtime-contract:9.0.0"]
             })
  end

  test "commits before runtime start and records failed-to-start outcomes", %{fixture: fixture} do
    request = Phase08AttemptFixture.request!(fixture)
    parent = self()

    commit = fn command ->
      send(parent, {:committed, command.command_iri})
      {:ok, %{outcome: :committed, command_iri: command.command_iri}}
    end

    failure_recorder = fn error, receipt ->
      send(parent, {:failure_recorded, error.kind, receipt.command_iri})
      {:ok, %{outcome: :committed}}
    end

    assert {:error, %{runtime_error: %{kind: :unavailable}}} =
             ExecutionCoordinator.start(fixture.attempt_start.command, request,
               commit: commit,
               adapter: FakeExecutionRuntime,
               failure_recorder: failure_recorder,
               runtime_options: [
                 authority: AllowExecutionAuthority,
                 scenario: :crash
               ]
             )

    assert_receive {:committed, command_iri}
    assert_receive {:failure_recorded, :unavailable, ^command_iri}

    failed =
      Phase08AttemptFixture.transition!(fixture, :failed, 928, %{
        origin: :runtime,
        runtime_event: runtime_event(fixture, 1, :failure)
      })

    assert failed.attempt_resolution.current_state == :failed
    assert failed.schedulable_task_resolution.current_state == :blocked

    assert {:recover, %{action: :query_runtime_status}} =
             ExecutionCoordinator.start(fixture.attempt_start.command, request,
               commit: commit,
               adapter: FakeExecutionRuntime,
               failure_recorder: failure_recorder,
               runtime_options: [
                 authority: AllowExecutionAuthority,
                 scenario: :lost_response
               ]
             )
  end

  test "creates attributable follow-up identity only when retry policy permits", %{
    fixture: fixture
  } do
    base = %{
      failure_class: :runtime_crash,
      attempt_count: 1,
      max_attempts: 3,
      budget_remaining?: true,
      source_fresh?: true,
      plan_fresh?: true,
      constraints_current?: true,
      policy_current?: true,
      capability_current?: true,
      lease_state: :executing,
      cancelled?: false
    }

    assert {:ok, %{decision: :retry, requires_new_lease?: false}} = RetryPolicy.evaluate(base)

    assert {:ok, %{decision: :reconcile}} =
             base |> Map.put(:source_fresh?, false) |> RetryPolicy.evaluate()

    assert {:ok, %{decision: :decision_required, reason: :attempts_exhausted}} =
             base |> Map.put(:attempt_count, 3) |> RetryPolicy.evaluate()

    assert {:ok, follow_up} =
             Knowledge.execution_attempt(fixture.execution_context, %{
               idempotency_key: "phase-08-attempt-retry-2",
               authorized_agent: %{
                 agent_iri: fixture.actor,
                 capability_iri: fixture.capability,
                 available?: true
               },
               available_runtime_versions: [Version.current()],
               retry_of_iri: fixture.attempt.iri
             })

    refute follow_up.iri == fixture.attempt.iri
    assert follow_up.retry_of_iri == fixture.attempt.iri
  end

  defp runtime_event(fixture, sequence, outcome) do
    %{
      attempt_iri: fixture.attempt.iri,
      sequence: sequence,
      outcome_class: outcome,
      usage: %{input_tokens: 20, output_tokens: 5},
      diagnostic: nil
    }
  end

  defp transition_attributes(fixture, sequence, next_state, overrides) do
    fixture
    |> JidoCode.TestSupport.Phase07Fixture.base_attributes(
      sequence,
      fixture.attempt_resolution.current_transition,
      "transition attempt"
    )
    |> Map.merge(%{
      next_state: next_state,
      origin: :runtime,
      fencing_token: fixture.attempt.fencing_token,
      expected_run_revision:
        Phase08AttemptFixture.graph_revision!(fixture, fixture.attempt.run_graph_iri),
      control_graph_iri: fixture.control_graph,
      expected_control_revision:
        Phase08AttemptFixture.graph_revision!(fixture, fixture.control_graph),
      recorded_at: DateTime.add(fixture.issued_at, 130, :second),
      runtime_event: nil
    })
    |> Map.merge(overrides)
  end

  defp query(fixture, name, graph, resource) do
    QueryRunner.execute(
      name,
      QueryCatalog.execution_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp decoded(row, key) do
    value = Map.get(row, key) || Map.get(row, String.to_existing_atom(key))

    case value do
      %{value: value} -> value
      value -> value
    end
  end
end

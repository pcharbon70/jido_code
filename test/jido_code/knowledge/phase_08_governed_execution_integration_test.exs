defmodule JidoCode.Knowledge.Phase08GovernedExecutionIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Execution.RetryPolicy
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Runtime.Version
  alias JidoCode.TestSupport.Phase08AttemptFixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture

  @jf "https://jido.run/ontology/factory#"
  @prov "http://www.w3.org/ns/prov#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  test "executes one leased task through immutable, attributable graph provenance", context do
    fixture = Phase08ExecutionFixture.completed!(context)
    projection = fixture.projection

    assert fixture.attempt_start_receipt.outcome == :committed
    assert fixture.invocation_start_receipt.outcome == :committed
    assert fixture.tool_outcome_receipt.outcome == :committed
    assert fixture.artifact_receipt.outcome == :committed
    assert fixture.finalization_receipt.outcome == :committed
    assert fixture.schedulable_task_resolution.current_state == :awaiting_evidence
    assert fixture.goal_resolution.current_state == :approved

    assert projection.current_state == :completed
    assert projection.terminal?
    assert projection.operational_completion == :completed
    assert projection.verification_state == :not_evaluated
    assert projection.evidence_state == :not_recorded
    assert projection.decision_state == :not_decided
    assert projection.fencing_token == fixture.lease.fencing_token
    assert projection.runtime_version == Version.current()
    assert projection.source_snapshot_iri == fixture.observation.snapshot_iri
    assert projection.receipt.query_version == QueryCatalog.execution_version()

    assert projection.receipt.graph_revision ==
             fixture.finalization_receipt.graph_revisions[fixture.attempt.run_graph_iri].new

    assert Enum.map(projection.timeline, & &1.revision) == [0, 1, 2, 3]
    assert List.last(projection.timeline).state_iri =~ "ExecutionAttemptCompleted"

    assert [tool] = projection.tool_invocations
    assert tool.invocation_iri == fixture.invocation.iri
    assert tool.sequence == fixture.invocation.sequence
    assert tool.result_iri == fixture.tool_outcome_iri
    assert tool.artifact_iris == [fixture.artifact.iri]
    assert is_binary(tool.stdout_digest)
    assert is_binary(tool.stderr_digest)
    assert is_binary(tool.usage_digest)

    assert [artifact] = projection.artifacts
    assert artifact.artifact_iri == fixture.artifact.iri
    assert artifact.source_snapshot_iri == fixture.attempt.snapshot_iri
    assert artifact.generator_iri == fixture.invocation.iri
    assert artifact.content_digest == fixture.artifact.content_digest
    assert artifact.affected_paths == ["config/config.exs"]

    assert Enum.any?(projection.run_completeness.lifecycle_iris, &String.ends_with?(&1, "Closed"))
    assert Enum.any?(projection.run_completeness.state_iris, &String.ends_with?(&1, "Complete"))
    assert projection.run_completeness.runtime_completion_iri =~ "OperationalOnly"
    assert projection.run_completeness.missing_outputs == []

    attempt_predicates = predicates!(fixture, fixture.attempt.iri)

    for predicate <- [
          @jf <> "enrollment",
          @jf <> "inScope",
          @jf <> "executes",
          @jf <> "attempts",
          @jf <> "derivedFrom",
          @jf <> "validFor",
          @jf <> "sourceSnapshot",
          @jf <> "inputPackage",
          @prov <> "wasAssociatedWith",
          @jf <> "delegatedAgent",
          @jf <> "requiresCapability",
          @jf <> "fencingToken",
          @jf <> "sandboxActivity"
        ] do
      assert predicate in attempt_predicates
    end

    invocation_predicates = predicates!(fixture, fixture.invocation.iri)

    for predicate <- [
          @jf <> "attempts",
          @jf <> "executes",
          @jf <> "requiresCapability",
          @jf <> "validFor",
          @prov <> "wasAssociatedWith",
          @jf <> "delegatedAgent",
          @jf <> "fencingToken",
          @prov <> "used"
        ] do
      assert predicate in invocation_predicates
    end

    artifact_classes = objects!(fixture, fixture.artifact.iri, @rdf_type)
    assert (@jf <> "Artifact") in artifact_classes
    assert (@jf <> "Patch") in artifact_classes
    refute (@jf <> "EvidenceBundle") in artifact_classes

    rendered = inspect(projection)
    refute rendered =~ fixture.execution_context.instruction
    refute rendered =~ "sandbox-applied"
    refute rendered =~ fixture.artifact.embedded_content
  end

  test "serializes start races and fences expiry, cancellation, and retry", context do
    base = Phase07SchedulingFixture.leased!(context)
    execution_context = Phase08AttemptFixture.execution_context!(base)
    attempt = Phase08AttemptFixture.attempt!(base, execution_context)
    start = Phase08AttemptFixture.start!(base, attempt, execution_context)

    outcomes =
      [start.command, start.command]
      |> Task.async_stream(
        fn command ->
          {:ok, receipt} = Writer.execute(base.writer, command)
          receipt.outcome
        end,
        max_concurrency: 2,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, outcome} -> outcome end)
      |> Enum.sort()

    assert outcomes == [:already_committed, :committed]

    {:ok, attempt_resolution} = Transition.resolve(start.attempt_transitions)
    lease_transitions = base.lease_transitions ++ [start.lease_transition]
    task_transitions = base.schedulable_task_transitions ++ [start.task_transition]
    {:ok, lease_resolution} = Transition.resolve(lease_transitions)
    {:ok, task_resolution} = Transition.resolve(task_transitions)

    fixture =
      Map.merge(base, %{
        execution_context: execution_context,
        attempt: attempt,
        attempt_start: start,
        attempt_start_receipt: %{outcome: :committed},
        attempt_transitions: start.attempt_transitions,
        attempt_resolution: attempt_resolution,
        lease_transitions: lease_transitions,
        lease_resolution: lease_resolution,
        schedulable_task_transitions: task_transitions,
        schedulable_task_resolution: task_resolution
      })
      |> Phase08AttemptFixture.transition!(:running, 921)

    invocation = Phase08ExecutionFixture.invocation!(fixture)

    attributes =
      Phase08ExecutionFixture.command_attributes(
        fixture,
        930,
        invocation.iri,
        "start race invocation"
      )

    assert {:error, %{operation: :start_tool_invocation}} =
             Knowledge.start_tool_invocation(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               %{attributes | fencing_token: fixture.attempt.fencing_token + 1},
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, invocation_start} =
             Knowledge.start_tool_invocation(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, invocation_start)

    assert {:ok, %{outcome: :already_committed}} =
             Writer.execute(fixture.writer, invocation_start)

    expired_invocation = Phase08ExecutionFixture.invocation!(fixture, 2)

    expired_attributes =
      Phase08ExecutionFixture.command_attributes(
        fixture,
        1_290,
        expired_invocation.iri,
        "reject expired lease effect"
      )

    assert DateTime.compare(expired_attributes.recorded_at, fixture.lease.expires_at) == :gt

    assert {:ok, expired_command} =
             Knowledge.start_tool_invocation(
               expired_invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               expired_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :conflicted}} = Writer.execute(fixture.writer, expired_command)

    fixture =
      Phase08AttemptFixture.transition!(fixture, :cancelling, 940, %{origin: :control})

    fixture = Phase08AttemptFixture.transition!(fixture, :cancelled, 941)
    assert fixture.attempt_resolution.current_state == :cancelled
    assert fixture.schedulable_task_resolution.current_state == :cancelled

    assert {:ok, %{outcome: :already_committed}} =
             Writer.execute(fixture.writer, fixture.attempt_transition.command)

    assert {:error, %{operation: :start_tool_invocation}} =
             Knowledge.start_tool_invocation(
               expired_invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               Phase08ExecutionFixture.command_attributes(
                 fixture,
                 942,
                 expired_invocation.iri,
                 "reject post-cancellation effect"
               ),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{decision: :stop, reason: :cancelled}} =
             RetryPolicy.evaluate(%{
               failure_class: :tool_timeout,
               attempt_count: 1,
               max_attempts: 3,
               budget_remaining?: true,
               source_fresh?: true,
               plan_fresh?: true,
               constraints_current?: true,
               policy_current?: true,
               capability_current?: true,
               lease_state: :executing,
               cancelled?: true
             })

    assert {:ok, follow_up} =
             Knowledge.execution_attempt(fixture.execution_context, %{
               idempotency_key: "phase-08-integration-retry",
               authorized_agent: %{
                 agent_iri: fixture.actor,
                 capability_iri: fixture.capability,
                 available?: true
               },
               available_runtime_versions: [Version.current()],
               retry_of_iri: fixture.attempt.iri
             })

    assert follow_up.retry_of_iri == fixture.attempt.iri
    refute follow_up.iri == fixture.attempt.iri
  end

  defp predicates!(fixture, resource) do
    fixture
    |> description!(resource)
    |> Enum.map(&decoded(&1, "predicate"))
    |> Enum.uniq()
  end

  defp objects!(fixture, resource, predicate) do
    fixture
    |> description!(resource)
    |> Enum.filter(&(decoded(&1, "predicate") == predicate))
    |> Enum.map(&decoded(&1, "object"))
    |> Enum.uniq()
  end

  defp description!(fixture, resource) do
    {:ok, result} =
      QueryRunner.execute(
        :resource_description,
        QueryCatalog.execution_version(),
        %{graph: fixture.attempt.run_graph_iri, resource: resource},
        fixture.authority,
        fixture.repository_scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )

    result.data
  end

  defp decoded(row, key) do
    term = Map.get(row, key) || Map.get(row, String.to_existing_atom(key))
    if is_map(term), do: term.value, else: term
  end
end

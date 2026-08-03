defmodule JidoCode.Factory.Phase08AttemptRecoveryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.AttemptRecovery
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent
  alias JidoCode.Factory.ExecutionCoordinator
  alias JidoCode.Factory.Recovery.Decision
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeExecutionRuntime
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-03 14:00:00Z]
  @runtime_version "jido:2.3.2/runtime-contract:1.0.0"

  test "startup recovery rebuilds requests, inspects ports, and cleans only orphan refs" do
    parent = self()
    projection = projection()
    request = request!(projection)
    control_graph = control_graph!(projection)
    active_ref = Request.runtime_key(request)
    orphan_ref = String.duplicate("f", 64)

    {:ok, recovery} =
      AttemptRecovery.start_link(
        name: nil,
        control_graphs: [control_graph],
        query: fn :active_attempts, %{graph: graph} ->
          send(parent, {:queried, graph})
          {:ok, query_result([candidate_row(projection)], graph)}
        end,
        load_projection: fn candidate ->
          send(parent, {:loaded, candidate})
          {:ok, projection}
        end,
        runtime_adapter: FakeExecutionRuntime,
        runtime_options: [authority: AllowExecutionAuthority, clock: fn -> @now end],
        sandbox_inspector: fn inspected_request ->
          send(parent, {:sandbox_inspected, inspected_request})
          :not_configured
        end,
        transition: fn decision, candidate, loaded_projection ->
          send(parent, {:recovery_decision, decision, candidate, loaded_projection})
          :ok
        end,
        orphan_inventory: fn -> {:ok, [active_ref, orphan_ref]} end,
        cleanup_orphan: fn ref ->
          send(parent, {:cleaned, ref})
          :ok
        end,
        available_runtime_versions: [@runtime_version],
        current_snapshot: fn loaded_projection -> loaded_projection.source_snapshot_iri end,
        policy_current?: fn _loaded_projection -> true end,
        clock: fn -> @now end,
        interval: 60_000
      )

    assert_receive {:queried, _graph}, 1_000
    assert_receive {:loaded, %{lease_current?: true}}, 1_000
    assert_receive {:sandbox_inspected, ^request}, 1_000
    assert_receive {:recovery_decision, :observe, %{attempt_iri: attempt}, ^projection}, 1_000
    assert attempt == projection.attempt_iri
    assert_receive {:cleaned, ^orphan_ref}, 1_000
    refute_receive {:cleaned, ^active_ref}, 50

    assert AttemptRecovery.ready?(recovery)

    assert %{ready?: true, recovering?: false, last_report: report} =
             AttemptRecovery.status(recovery)

    assert report.candidate_count == 1
    assert report.cleaned_orphan_refs == [orphan_ref]
    GenServer.stop(recovery)
  end

  test "recovery policy handles stale authority, callbacks, and resumability explicitly" do
    projection = projection()
    candidate = candidate(projection)
    options = recovery_options(projection)

    assert {:ok, {:recover_terminal, :completed}} =
             Decision.evaluate(
               projection,
               candidate,
               {:ok, event!(projection, :completed, 3)},
               :not_configured,
               @now,
               options
             )

    assert {:ok, :resume} =
             Decision.evaluate(
               projection,
               candidate,
               {:ok, event!(projection, :crashed, 3)},
               :not_configured,
               @now,
               options
             )

    stale_projection = %{projection | timeline: [%{runtime_sequence: 5}]}

    assert {:ok, :reject_stale_event} =
             Decision.evaluate(
               stale_projection,
               candidate,
               {:ok, event!(projection, :heartbeat, 4)},
               :not_configured,
               @now,
               options
             )

    assert {:ok, {:abandon, :lease_expired}} =
             Decision.evaluate(
               projection,
               %{candidate | valid_to: @now},
               {:ok, event!(projection, :heartbeat, 3)},
               :not_configured,
               @now,
               options
             )

    assert {:ok, {:abandon, :lease_inactive}} =
             Decision.evaluate(
               projection,
               %{candidate | lease_current?: false},
               {:ok, event!(projection, :heartbeat, 3)},
               :not_configured,
               @now,
               options
             )

    assert {:ok, {:supersede, :runtime_version_unavailable}} =
             Decision.evaluate(
               projection,
               candidate,
               {:ok, event!(projection, :heartbeat, 3)},
               :not_configured,
               @now,
               Keyword.put(options, :available_runtime_versions, [])
             )

    assert {:ok, {:supersede, :source_snapshot_changed}} =
             Decision.evaluate(
               projection,
               candidate,
               {:ok, event!(projection, :heartbeat, 3)},
               :not_configured,
               @now,
               Keyword.put(options, :current_snapshot_iri, resource!("new-snapshot"))
             )

    assert {:ok, :retry_later} =
             Decision.evaluate(
               projection,
               candidate,
               {:ok, event!(projection, :heartbeat, 3)},
               {:error, AdapterError.new(:unavailable, :sandbox_inspect)},
               @now,
               options
             )

    cancelling = %{projection | current_state: :cancelling}

    assert {:ok, {:recover_terminal, :cancelled}} =
             Decision.evaluate(
               cancelling,
               candidate,
               {:ok, event!(projection, :cancelled, 3)},
               :not_configured,
               @now,
               options
             )

    assert {:ok, :propagate_cancellation} =
             Decision.evaluate(
               cancelling,
               candidate,
               {:ok, event!(projection, :heartbeat, 3)},
               :not_configured,
               @now,
               options
             )
  end

  test "execution admission stays closed until recovery succeeds" do
    projection = projection()
    request = request!(projection)
    parent = self()

    assert {:error, %{runtime_effect: :not_started}} =
             ExecutionCoordinator.start(:command, request,
               recovery_ready?: fn -> false end,
               commit: fn command ->
                 send(parent, {:committed, command})
                 {:ok, %{outcome: :committed}}
               end,
               adapter: FakeExecutionRuntime,
               runtime_options: [authority: AllowExecutionAuthority],
               failure_recorder: fn _error, _receipt -> {:ok, :recorded} end
             )

    refute_received {:committed, _command}

    {:ok, recovery} =
      AttemptRecovery.start_link(
        name: nil,
        control_graphs: [control_graph!(projection)],
        query: fn _name, _params ->
          {:error, AdapterError.new(:unavailable, :catalog_query)}
        end,
        load_projection: fn _candidate -> {:ok, projection} end,
        runtime_adapter: FakeExecutionRuntime,
        transition: fn _decision, _candidate, _projection -> :ok end,
        current_snapshot: fn loaded_projection -> loaded_projection.source_snapshot_iri end,
        policy_current?: fn _loaded_projection -> true end,
        interval: 60_000
      )

    assert {:error, %{kind: :unavailable}} = AttemptRecovery.recover_now(recovery)
    refute AttemptRecovery.ready?(recovery)
    GenServer.stop(recovery)
  end

  defp projection do
    %{
      attempt_iri: resource!("recovery-attempt"),
      lease_iri: resource!("recovery-lease"),
      task_iri: resource!("recovery-task"),
      goal_iri: resource!("recovery-goal"),
      plan_iri: resource!("recovery-plan"),
      repository_iri: resource!("recovery-repository"),
      source_snapshot_iri: resource!("recovery-snapshot"),
      actor_iri: resource!("recovery-actor"),
      agent_iri: resource!("recovery-agent"),
      capability_iri: resource!("recovery-capability"),
      fencing_token: 7,
      context_digest: String.duplicate("a", 64),
      runtime_version: @runtime_version,
      constraints: %{"network" => "deny"},
      current_state: :running,
      timeline: [%{runtime_sequence: 1}]
    }
  end

  defp request!(projection) do
    {:ok, request} =
      Request.new(%{
        attempt_iri: projection.attempt_iri,
        lease_iri: projection.lease_iri,
        task_iri: projection.task_iri,
        goal_iri: projection.goal_iri,
        plan_iri: projection.plan_iri,
        repository_iri: projection.repository_iri,
        snapshot_iri: projection.source_snapshot_iri,
        actor_iri: projection.actor_iri,
        agent_iri: projection.agent_iri,
        capability_iri: projection.capability_iri,
        fencing_token: projection.fencing_token,
        context_digest: projection.context_digest,
        runtime_version: projection.runtime_version,
        constraints: projection.constraints
      })

    request
  end

  defp candidate_row(projection) do
    %{
      "attempt" => iri(projection.attempt_iri),
      "lease" => iri(projection.lease_iri),
      "task" => iri(projection.task_iri),
      "fence" => non_negative_integer(projection.fencing_token),
      "validTo" => date_time(DateTime.add(@now, 300, :second)),
      "state" => iri("https://jido.run/ontology/concept/LeaseExecuting")
    }
  end

  defp candidate(projection) do
    %{
      attempt_iri: projection.attempt_iri,
      lease_iri: projection.lease_iri,
      task_iri: projection.task_iri,
      fencing_token: projection.fencing_token,
      valid_to: DateTime.add(@now, 300, :second),
      lease_current?: true
    }
  end

  defp recovery_options(projection) do
    [
      available_runtime_versions: [@runtime_version],
      current_snapshot_iri: projection.source_snapshot_iri,
      policy_current?: true
    ]
  end

  defp event!(projection, type, sequence) do
    outcome =
      case type do
        :completed -> :success
        :cancelled -> :cancelled
        _other -> :pending
      end

    {:ok, event} =
      RuntimeEvent.new(%{
        attempt_iri: projection.attempt_iri,
        sequence: sequence,
        type: type,
        occurred_at: @now,
        outcome_class: outcome,
        usage: %{}
      })

    event
  end

  defp query_result(data, graph) do
    %QueryResult{
      query_name: :active_attempts,
      query_version: "1.6.0",
      dataset_revision: 10,
      graph_revisions: %{graph => 3},
      ontology_version: "1.0.0",
      completeness: :declared,
      freshness: :current,
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: :snapshot,
      evaluated_at: @now,
      data: data
    }
  end

  defp iri(value), do: %{type: :iri, value: value}

  defp non_negative_integer(value) do
    %{
      type: :literal,
      value: Integer.to_string(value),
      datatype: "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
    }
  end

  defp date_time(value) do
    %{
      type: :literal,
      value: DateTime.to_iso8601(value),
      datatype: "http://www.w3.org/2001/XMLSchema#dateTime"
    }
  end

  defp control_graph!(projection) do
    {:ok, graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: projection.repository_iri})

    graph
  end

  defp resource!(seed), do: Phase04Fixture.resource!(seed)
end

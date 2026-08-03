defmodule JidoCode.Knowledge.Control.Phase07SchedulingTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Scheduler
  alias JidoCode.Knowledge.Control.Eligibility
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture

  setup context do
    {:ok, fixture: Phase07SchedulingFixture.leased!(context)}
  end

  test "blocks every unknown, stale, contradictory, unauthorized, and incomplete condition", %{
    fixture: fixture
  } do
    assert fixture.eligibility.eligible?
    assert fixture.eligibility.blockers == []
    assert length(fixture.eligibility.satisfied) == 13

    cases = [
      {[:boundaries, :dependency], false, :dependency_boundary_incomplete},
      {[:source, :fresh?], false, :source_stale},
      {[:source, :contradictory?], true, :source_contradictory},
      {[:authorization, :authorized?], false, :unauthorized},
      {[:capacity, :available?], false, :over_capacity},
      {[:leases, :complete?], false, :lease_view_incomplete}
    ]

    Enum.each(cases, fn {path, value, reason} ->
      assert {:ok, result} =
               fixture.eligibility_context |> put_in(path, value) |> Eligibility.evaluate()

      refute result.eligible?
      assert reason in result.blockers
      assert result.satisfied == []
    end)

    [capability] = fixture.eligibility_context.capabilities

    assert {:ok, unavailable} =
             fixture.eligibility_context
             |> Map.put(:capabilities, [%{capability | state: :stale}])
             |> Eligibility.evaluate()

    assert :capability_unavailable in unavailable.blockers

    assert {:error, %{operation: :eligibility_context}} =
             fixture.eligibility_context
             |> Map.update!(:current_graph_revisions, fn revisions ->
               Map.update!(revisions, fixture.control_graph, &(&1 + 1))
             end)
             |> Eligibility.evaluate()
  end

  test "atomically persists one eligibility receipt, lease, task transition, and fence", %{
    fixture: fixture
  } do
    assert fixture.lease_receipt.outcome == :committed
    assert fixture.lease_resolution.current_state == :active
    assert fixture.schedulable_task_resolution.current_state == :leased
    assert fixture.lease.fencing_token == 1
    assert QueryCatalog.scheduling_version() == "1.5.0"
    assert :ok = QueryCatalog.verify()

    assert {:ok, lease_result} =
             query(
               fixture,
               :lease_description,
               fixture.control_graph,
               fixture.lease.iri
             )

    assert Enum.any?(lease_result.data, fn row ->
             decoded(row, "predicate") == "https://jido.run/ontology/factory#fencingToken" and
               decoded(row, "object") == "1"
           end)

    assert {:ok, history_result} =
             query(
               fixture,
               :lease_transition_history,
               fixture.control_graph,
               fixture.lease.iri
             )

    assert Enum.map(history_result.data, &decoded(&1, "revision")) == ["0", "1"]

    assert {:ok, candidate_result} =
             QueryRunner.execute(
               :eligible_work_candidates,
               QueryCatalog.scheduling_version(),
               %{graph: fixture.control_graph},
               fixture.authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    refute Enum.any?(candidate_result.data, fn row ->
             decoded(row, "task") == fixture.schedulable_task.iri
           end)

    assert {:current_lease_fence, graph, task, lease, 1, _at} =
             ExecutionLease.execution_guard(
               fixture.lease,
               fixture.control_graph,
               1,
               fixture.eligibility.evaluated_at
             )

    assert graph == fixture.control_graph
    assert task == fixture.schedulable_task.iri
    assert lease == fixture.lease.iri
  end

  test "rejects competing acquisition against the accepted task and lease endpoints", %{
    fixture: fixture
  } do
    attributes =
      fixture
      |> Phase07Fixture.base_attributes(791, fixture.eligibility.receipt_iri, "competing lease")
      |> Map.merge(%{
        holder_iri: fixture.actor,
        capability_iri: fixture.capability,
        fencing_token: 2,
        acquired_at: DateTime.add(fixture.issued_at, 110, :second),
        expires_at: DateTime.add(fixture.issued_at, 410, :second),
        max_expires_at: DateTime.add(fixture.issued_at, 1_010, :second),
        control_graph_iri: fixture.control_graph,
        expected_control_revision:
          Phase07SchedulingFixture.graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 110, :second)
      })

    assert {:ok, competing} =
             ExecutionLease.acquire_command(
               fixture.eligibility,
               task_approved_resolution(fixture),
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :conflicted, retry: :refresh}} =
             Writer.execute(fixture.writer, competing.command)
  end

  test "bounds renewal, rejects stale fences, and releases work for a higher fence", %{
    fixture: fixture
  } do
    liveness = Phase04Fixture.resource!("phase-07-lease-liveness")
    renewed_expiry = DateTime.add(fixture.eligibility.evaluated_at, 600, :second)

    renewed =
      Phase07SchedulingFixture.transition_lease!(fixture, :renew, 800, %{
        expires_at: renewed_expiry,
        liveness_evidence_iri: liveness,
        recorded_at: DateTime.add(fixture.eligibility.evaluated_at, 100, :second)
      })

    assert renewed.lease_resolution.current_state == :active
    assert renewed.lease.expires_at == renewed_expiry
    assert renewed.schedulable_task_resolution.current_state == :leased

    invalid_attributes =
      renewed
      |> Phase07Fixture.base_attributes(801, renewed.lease.iri, "invalid renewal")
      |> Map.merge(%{
        action: :renew,
        fencing_token: 0,
        expires_at: DateTime.add(renewed.lease.max_expires_at, 1, :second),
        liveness_evidence_iri: liveness,
        control_graph_iri: renewed.control_graph,
        expected_control_revision:
          Phase07SchedulingFixture.graph_revision!(renewed, renewed.control_graph),
        recorded_at: DateTime.add(fixture.eligibility.evaluated_at, 200, :second)
      })

    assert {:error, %{operation: :transition_execution_lease}} =
             ExecutionLease.transition_command(
               renewed.lease,
               renewed.lease_resolution,
               renewed.schedulable_task_resolution,
               invalid_attributes,
               clock: fn -> renewed.issued_at end
             )

    released =
      Phase07SchedulingFixture.transition_lease!(renewed, :release, 802, %{
        recorded_at: DateTime.add(fixture.eligibility.evaluated_at, 250, :second)
      })

    assert released.lease_resolution.current_state == :released
    assert released.schedulable_task_resolution.current_state == :eligible

    eligibility_context = refreshed_eligibility_context(released)
    assert {:ok, eligibility} = Eligibility.evaluate(eligibility_context)
    assert eligibility.eligible?

    attributes =
      released
      |> Phase07Fixture.base_attributes(803, eligibility.receipt_iri, "reacquire execution lease")
      |> Map.merge(%{
        holder_iri: released.actor,
        capability_iri: released.capability,
        fencing_token: 2,
        acquired_at: DateTime.add(fixture.eligibility.evaluated_at, 260, :second),
        expires_at: DateTime.add(fixture.eligibility.evaluated_at, 560, :second),
        max_expires_at: DateTime.add(fixture.eligibility.evaluated_at, 860, :second),
        control_graph_iri: released.control_graph,
        expected_control_revision:
          Phase07SchedulingFixture.graph_revision!(released, released.control_graph),
        recorded_at: DateTime.add(fixture.eligibility.evaluated_at, 260, :second)
      })

    assert {:ok, reacquisition} =
             ExecutionLease.acquire_command(
               eligibility,
               released.schedulable_task_resolution,
               attributes,
               clock: fn -> released.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(released.writer, reacquisition.command)
    assert receipt.outcome == :committed
    assert reacquisition.lease.fencing_token == 2
  end

  test "observes expiry only after the fenced lease deadline", %{fixture: fixture} do
    expired =
      Phase07SchedulingFixture.transition_lease!(fixture, :expire, 810, %{
        recorded_at: fixture.lease.expires_at
      })

    assert expired.lease_transition_receipt.outcome == :committed
    assert expired.lease_resolution.current_state == :expired
    assert expired.schedulable_task_resolution.current_state == :eligible

    premature_attributes =
      fixture
      |> Phase07Fixture.base_attributes(811, fixture.lease.iri, "premature expiry")
      |> Map.merge(%{
        action: :expire,
        fencing_token: fixture.lease.fencing_token,
        control_graph_iri: fixture.control_graph,
        expected_control_revision:
          Phase07SchedulingFixture.graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.lease.expires_at, -1, :second)
      })

    assert {:error, %{operation: :expire_execution_lease}} =
             ExecutionLease.transition_command(
               fixture.lease,
               fixture.lease_resolution,
               fixture.schedulable_task_resolution,
               premature_attributes,
               clock: fn -> fixture.issued_at end
             )
  end

  test "cancels a fenced lease and its task without erasing history", %{fixture: fixture} do
    cancelled =
      Phase07SchedulingFixture.transition_lease!(fixture, :cancel, 812, %{
        recorded_at: DateTime.add(fixture.eligibility.evaluated_at, 120, :second)
      })

    assert cancelled.lease_transition_receipt.outcome == :committed
    assert cancelled.lease_resolution.current_state == :cancelled
    assert cancelled.schedulable_task_resolution.current_state == :cancelled
    assert length(cancelled.lease_resolution.history) == 3
  end

  test "supersedes a fenced lease and its task without erasing history", %{fixture: fixture} do
    superseded =
      Phase07SchedulingFixture.transition_lease!(fixture, :supersede, 813, %{
        recorded_at: DateTime.add(fixture.eligibility.evaluated_at, 120, :second)
      })

    assert superseded.lease_transition_receipt.outcome == :committed
    assert superseded.lease_resolution.current_state == :superseded
    assert superseded.schedulable_task_resolution.current_state == :superseded
    assert length(superseded.lease_resolution.history) == 3
  end

  test "rebuilds deterministic scheduling from startup and periodic graph discovery", %{
    fixture: fixture
  } do
    parent = self()
    candidates = Agent.start_link(fn -> [] end) |> elem(1)
    on_exit(fn -> if Process.alive?(candidates), do: Agent.stop(candidates) end)

    provider = Phase07SchedulingFixture.capability_projection(fixture)

    low = scheduler_candidate(fixture, provider, "phase-07-low-priority", 10, 2)
    high = scheduler_candidate(fixture, provider, "phase-07-high-priority", 20, 1)

    discover = fn -> {:ok, Agent.get(candidates, & &1)} end

    acquire = fn candidate, selected_provider ->
      send(parent, {:scheduled, candidate.task_iri, selected_provider.holder_iri})
      {:ok, candidate.task_iri}
    end

    {:ok, scheduler} =
      Scheduler.start_link(
        name: nil,
        discover: discover,
        acquire: acquire,
        rediscovery_interval_ms: 30,
        limits: [global: 2, repository: 1, cohort: 2, capability: 2, risk: 3]
      )

    on_exit(fn -> if Process.alive?(scheduler), do: GenServer.stop(scheduler) end)

    eventually(fn -> Scheduler.status(scheduler).discovery_count >= 1 end)
    Agent.update(candidates, fn _ -> [low, high] end)

    assert_receive {:scheduled, task, holder}, 1_000
    assert task == high.task_iri
    assert holder == fixture.actor
    refute_receive {:scheduled, _, _}, 20

    eventually(fn ->
      status = Scheduler.status(scheduler)
      status.selected_count >= 1 and status.deferred_count >= 1
    end)

    :ok = GenServer.stop(scheduler)
    flush_scheduled()

    Agent.update(candidates, fn _ ->
      %{
        candidates: [high],
        active_leases: [
          %{
            repository_iri: fixture.repository,
            cohort_iris: [fixture.cohort.iri],
            holder_iri: fixture.actor
          }
        ]
      }
    end)

    {:ok, capacity_blocked} =
      Scheduler.start_link(
        name: nil,
        discover: discover,
        acquire: acquire,
        rediscovery_interval_ms: 100,
        limits: [global: 1, repository: 1, cohort: 1, capability: 1, risk: 3]
      )

    eventually(fn -> Scheduler.status(capacity_blocked).deferred_count >= 1 end)
    refute_receive {:scheduled, _, _}, 50
    :ok = GenServer.stop(capacity_blocked)

    Agent.update(candidates, fn _ -> [high] end)

    {:ok, restarted} =
      Scheduler.start_link(
        name: nil,
        discover: discover,
        acquire: acquire,
        rediscovery_interval_ms: 100,
        limits: [global: 1, repository: 1, cohort: 1, capability: 1, risk: 3]
      )

    on_exit(fn -> if Process.alive?(restarted), do: GenServer.stop(restarted) end)

    assert_receive {:scheduled, ^task, ^holder}, 1_000
    assert Scheduler.status(restarted).discovery_count >= 1
  end

  defp query(fixture, name, graph, resource) do
    QueryRunner.execute(
      name,
      QueryCatalog.scheduling_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp task_approved_resolution(fixture) do
    approval =
      Enum.find(
        fixture.plan_adoption.transitions,
        &(&1.subject_iri == fixture.schedulable_task.iri)
      )

    {:ok, resolution} = Transition.resolve([fixture.schedulable_task.transition, approval])
    resolution
  end

  defp refreshed_eligibility_context(fixture) do
    revisions =
      Map.new(fixture.eligibility_context.graph_revisions, fn {graph, _revision} ->
        {graph, Phase07SchedulingFixture.graph_revision!(fixture, graph)}
      end)

    fixture.eligibility_context
    |> put_in([:task, :state], fixture.schedulable_task_resolution.current_state)
    |> put_in(
      [:task, :current_transition],
      fixture.schedulable_task_resolution.current_transition
    )
    |> put_in([:leases, :active], [])
    |> Map.put(:graph_revisions, revisions)
    |> Map.put(:current_graph_revisions, revisions)
    |> Map.put(:authorized_graphs, Map.keys(revisions))
    |> Map.put(:evaluated_at, DateTime.add(fixture.eligibility.evaluated_at, 255, :second))
  end

  defp scheduler_candidate(fixture, provider, slug, priority, fairness) do
    %{
      task_iri: Phase04Fixture.resource!(slug),
      repository_iri: fixture.repository,
      cohort_iris: [fixture.cohort.iri],
      providers: [provider],
      priority: priority,
      fairness: fairness,
      risk: 2
    }
  end

  defp decoded(row, key) do
    case row[key] do
      %{value: value} -> value
      value -> value
    end
  end

  defp flush_scheduled do
    receive do
      {:scheduled, _, _} -> flush_scheduled()
    after
      0 -> :ok
    end
  end

  defp eventually(fun, attempts \\ 50)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      eventually(fun, attempts - 1)
    end
  end
end

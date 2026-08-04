defmodule JidoCode.Factory.FleetAdmissionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Fleet.Admission
  alias JidoCode.Factory.Fleet.Policy
  alias JidoCode.Factory.Scheduler

  test "graph policy can narrow but never widen trusted ceilings" do
    ceilings = %{
      concurrency: %{global: 4, cohort: 3, repository: 2, provider: 2, capability: 2},
      rate_units: 50,
      budget_units: 40,
      max_risk: 6,
      max_candidates: 20,
      max_campaign_repositories: 10,
      starvation_cycles: 8,
      emergency_priority: 100
    }

    graph_policy = %{
      concurrency: %{global: 99, repository: 1},
      rate_units: 20,
      budget_units: 400,
      max_risk: 4,
      policy_revision: 71
    }

    assert {:ok, policy} = Policy.resolve(graph_policy, ceilings)
    assert policy.concurrency.global == 4
    assert policy.concurrency.repository == 1
    assert policy.concurrency.provider == 2
    assert policy.rate_units == 20
    assert policy.budget_units == 40
    assert policy.max_risk == 4
    assert policy.policy_revision == 71

    assert {:error, _error} = Policy.resolve(%{raw_limit_name: 1}, ceilings)
  end

  test "admission is deterministic, starvation-safe, bounded, and explainable" do
    {:ok, policy} =
      Policy.resolve(
        %{
          concurrency: %{global: 2, repository: 1, cohort: 2, provider: 1, capability: 1},
          rate_units: 3,
          budget_units: 3,
          max_risk: 5,
          max_campaign_repositories: 1,
          starvation_cycles: 3,
          emergency_priority: 100
        },
        ceilings()
      )

    starved = candidate("starved", 1, waited_cycles: 3)
    normal = candidate("normal", 90)
    provider_blocked = candidate("provider-blocked", 80, repository: "repo-b")

    provider_blocked =
      update_in(provider_blocked.providers, fn [provider] ->
        [%{provider | rate_available?: false}]
      end)

    over_risk = candidate("over-risk", 70, repository: "repo-c", risk: 6)

    assert {:ok, result} =
             Admission.select([normal, over_risk, provider_blocked, starved], [], policy)

    assert [%{candidate: %{task_iri: selected_task}}] = result.selected
    assert String.ends_with?(selected_task, "/starved")

    reasons = Map.new(result.deferred, &{&1.task_iri, &1.reasons})
    assert :repository_capacity in reasons[normal.task_iri]
    assert :provider_backpressure in reasons[provider_blocked.task_iri]
    assert :risk_limit in reasons[over_risk.task_iri]
    assert :campaign_repository_limit in reasons[over_risk.task_iri]
    assert Enum.all?(result.deferred, &(&1.next_waited_cycles >= 1))

    assert result ==
             elem(Admission.select([normal, over_risk, provider_blocked, starved], [], policy), 1)
  end

  test "emergency policy preserves hard capacity and risk ceilings" do
    {:ok, policy} =
      Policy.resolve(
        %{
          concurrency: %{global: 1},
          max_risk: 2,
          starvation_cycles: 1,
          emergency_priority: 100
        },
        ceilings()
      )

    emergency = candidate("emergency", 100)
    starved = candidate("starved", 20, repository: "repo-b", waited_cycles: 10)

    assert {:ok, result} = Admission.select([starved, emergency], [], policy)
    assert [%{candidate: %{task_iri: task}}] = result.selected
    assert String.ends_with?(task, "/emergency")
    assert [%{reasons: reasons}] = result.deferred
    assert :global_capacity in reasons
  end

  test "scheduler coalesces wakeup storms and rebuilds exclusively from discovery" do
    parent = self()

    discover = fn ->
      send(parent, {:discovered, self()})

      {:ok,
       %{
         candidates: [candidate("restartable", 10)],
         active_leases: [],
         fleet_policy: %{concurrency: %{global: 1}, policy_revision: 9}
       }}
    end

    acquire = fn candidate, _provider ->
      send(parent, {:acquired, self(), candidate.task_iri})
      :ok
    end

    first = scheduler!(discover, acquire)
    assert_receive {:discovered, ^first}, 1_000
    assert_receive {:acquired, _task_pid, _task}, 1_000

    Enum.each(1..20, fn _index -> Scheduler.trigger(first) end)
    eventually(fn -> Scheduler.status(first).coalesced_discovery_count > 0 end)
    GenServer.stop(first)

    second = scheduler!(discover, acquire)
    assert_receive {:discovered, ^second}, 1_000
    assert_receive {:acquired, _task_pid, _task}, 1_000
    refute first == second
    GenServer.stop(second)
  end

  defp scheduler!(discover, acquire) do
    {:ok, scheduler} =
      Scheduler.start_link(
        name: nil,
        discover: discover,
        acquire: acquire,
        rediscovery_interval_ms: 30_000,
        max_candidates: 10,
        limits: [global: 1, repository: 1, cohort: 1, provider: 1, capability: 1, risk: 5]
      )

    scheduler
  end

  defp candidate(name, priority, options \\ []) do
    repository = Keyword.get(options, :repository, "repo-a")

    %{
      task_iri: iri("task/#{name}"),
      repository_iri: iri("repository/#{repository}"),
      cohort_iris: [iri("cohort/default")],
      capability_iri: iri("capability/default"),
      providers: [
        %{
          iri: iri("capability/default"),
          holder_iri: iri("provider/default"),
          active_leases: 0,
          limits: %{concurrency: 4},
          rate_available?: true
        }
      ],
      priority: priority,
      fairness: 0,
      waited_cycles: Keyword.get(options, :waited_cycles, 0),
      risk: Keyword.get(options, :risk, 1),
      rate_units: Keyword.get(options, :rate_units, 1),
      budget_units: Keyword.get(options, :budget_units, 1)
    }
  end

  defp ceilings do
    %{
      concurrency: %{global: 8, cohort: 8, repository: 8, provider: 8, capability: 8},
      rate_units: 100,
      budget_units: 100,
      max_risk: 10,
      max_candidates: 100,
      max_campaign_repositories: 20,
      starvation_cycles: 10,
      emergency_priority: 100
    }
  end

  defp iri(suffix), do: "https://jido.run/id/#{suffix}"

  defp eventually(callback, attempts \\ 50)
  defp eventually(callback, 0), do: assert(callback.())

  defp eventually(callback, attempts) do
    if callback.() do
      :ok
    else
      Process.sleep(10)
      eventually(callback, attempts - 1)
    end
  end
end

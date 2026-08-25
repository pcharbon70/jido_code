defmodule JidoCode.Factory.ManagedCodingPhase05IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.Capacity
  alias JidoCode.Factory.ManagedCoding.CapacityConfig
  alias JidoCode.Factory.ManagedCoding.SecurityPolicy
  alias JidoCode.TestSupport.ManagedCodingPhase05Fixture, as: Phase05Fixture

  test "contains every component crash point without inventing an effect outcome" do
    matrix = Phase05Fixture.crash_matrix()
    assert length(matrix) == 28

    assert Enum.all?(
             matrix,
             &(&1.outcome in [
                 :safe_replay,
                 :reconcile_or_quarantine,
                 :resume_from_outcome,
                 :compare_and_commit
               ])
           )

    assert Enum.count(matrix, &(&1.point == :during_effect)) == 7
  end

  test "fails closed across ambiguity, races, corrupt evidence, isolation, and output floods" do
    matrix = Phase05Fixture.fault_matrix()
    assert length(matrix) == 11
    assert Enum.all?(matrix, &(not &1.authoritative))
    assert Enum.all?(matrix, &(&1.outcome in [:contained, :denied]))

    adversarial = MapSet.new(SecurityPolicy.adversarial_kinds())

    assert MapSet.subset?(
             MapSet.new([:cross_tenant, :symlink_escape, :secret_exfiltration, :output_flood]),
             adversarial
           )
  end

  test "sustains excess load with bounded state, explicit decisions, cleanup, and alerts" do
    state = Capacity.new(config())

    {state, decisions} =
      Enum.reduce(1..100, {state, []}, fn index, {current, decisions} ->
        request = request(index)

        case Capacity.admit(current, request, index) do
          {:admit, next} -> {next, [:admit | decisions]}
          {:defer, next} -> {next, [:defer | decisions]}
          {:reject, :capacity_exhausted, next} -> {next, [:reject | decisions]}
        end
      end)

    assert length(state.active) <= 4
    assert length(state.queue) <= 8
    assert :admit in decisions
    assert :defer in decisions
    assert :reject in decisions

    {state, _started} = Capacity.release(state, hd(state.active).attempt_iri, 5_000)
    assert state.queue == []
    assert state.counters.expired > 0

    health =
      Capacity.health(state, 5_000, %{
        stuck_attempts: 0,
        orphaned_leases: 0,
        orphaned_workspaces: 0,
        missing_outcomes: 0,
        fence_conflicts: 0,
        evidence_gaps: 0
      })

    assert health.active_attempts <= 3
    assert health.queued_attempts == 0
  end

  defp config do
    {:ok, config} =
      CapacityConfig.new(%{
        concurrency: %{
          global: 4,
          tenant: 2,
          repository: 2,
          provider: 4,
          sandbox: 4,
          verifier: 4,
          adapter: 4
        },
        queue: %{
          global: 8,
          tenant: 4,
          repository: 4,
          provider: 8,
          sandbox: 8,
          verifier: 8,
          adapter: 8
        },
        reserved: 1,
        queue_ttl_ms: 500
      })

    config
  end

  defp request(index) do
    %{
      attempt_iri: "https://jido.run/id/activity/load-#{index}",
      tenant: "tenant-#{rem(index, 4)}",
      repository: "repository-#{rem(index, 8)}",
      provider: "provider",
      sandbox: "sandbox",
      verifier: "verifier",
      adapter: "adapter",
      reserved: false
    }
  end
end

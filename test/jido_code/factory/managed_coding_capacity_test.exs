defmodule JidoCode.Factory.ManagedCodingCapacityTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.Capacity
  alias JidoCode.Factory.ManagedCoding.CapacityConfig

  test "bounds active work and queues across every declared dimension" do
    state = Capacity.new(config())
    {:admit, state} = Capacity.admit(state, request("a1", "tenant-a"), 0)
    {:defer, state} = Capacity.admit(state, request("a2", "tenant-a"), 1)
    {:admit, state} = Capacity.admit(state, request("b1", "tenant-b", true), 2)
    {:defer, state} = Capacity.admit(state, request("b2", "tenant-b"), 3)
    {:reject, :capacity_exhausted, state} = Capacity.admit(state, request("c1", "tenant-c"), 4)
    assert length(state.active) == 2
    assert length(state.queue) == 2
    assert state.counters.rejected == 1
  end

  test "expires queue positions and schedules tenants fairly" do
    state = Capacity.new(config())
    {:admit, state} = Capacity.admit(state, request("active", "tenant-a"), 0)
    {:defer, state} = Capacity.admit(state, request("b1", "tenant-b"), 1)
    {:defer, state} = Capacity.admit(state, request("a2", "tenant-a"), 2)

    {state, started} = Capacity.release(state, iri("active"), 3)
    assert started.tenant == "tenant-a"

    {state, started} = Capacity.release(state, iri("a2"), 4)
    assert started.tenant == "tenant-b"

    {:defer, state} = Capacity.admit(state, request("c1", "tenant-c"), 5)
    {state, _started} = Capacity.release(state, iri("b1"), 200)
    assert state.counters.expired == 1
  end

  test "emits low-cardinality measurements and actionable health alerts" do
    state = Capacity.new(config())
    {:ok, state} = Capacity.measure(state, :retries, 3)
    {:ok, state} = Capacity.measure(state, :cancellation_lag_ms, 25)

    health =
      Capacity.health(state, 50, %{
        stuck_attempts: 1,
        orphaned_leases: 1,
        orphaned_workspaces: 0,
        missing_outcomes: 1,
        fence_conflicts: 0,
        evidence_gaps: 0
      })

    assert health.status == :degraded
    assert health.metrics.retries == %{count: 1, max: 3}
    assert health.alerts == [:stuck_attempts, :orphaned_leases, :missing_outcomes]
    refute Map.has_key?(health, :tenant_iri)
    refute Map.has_key?(health, :attempt_iri)
  end

  defp config do
    {:ok, config} =
      CapacityConfig.new(%{
        concurrency: %{
          global: 2,
          tenant: 1,
          repository: 2,
          provider: 2,
          sandbox: 2,
          verifier: 2,
          adapter: 2
        },
        queue: %{
          global: 2,
          tenant: 1,
          repository: 2,
          provider: 2,
          sandbox: 2,
          verifier: 2,
          adapter: 2
        },
        reserved: 1,
        queue_ttl_ms: 100
      })

    config
  end

  defp request(suffix, tenant, reserved \\ false) do
    %{
      attempt_iri: iri(suffix),
      tenant: tenant,
      repository: "repository-#{suffix}",
      provider: "provider",
      sandbox: "sandbox",
      verifier: "verifier",
      adapter: "adapter",
      reserved: reserved
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

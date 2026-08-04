defmodule JidoCode.CapacityTest do
  use ExUnit.Case, async: true

  alias JidoCode.Capacity
  alias JidoCode.Capacity.Benchmark
  alias JidoCode.TestSupport.Phase10CapacityFixture

  test "defines representative fixtures for every graph workload family" do
    for profile <- [:small, :medium, :maximum] do
      fixture = Phase10CapacityFixture.workload!(profile)

      assert {:ok, admission} = Capacity.admit(fixture.counts)
      assert admission.state == :supported
      assert fixture.repositories != []
      assert fixture.snapshots != []
      assert fixture.source_symbols != []
      assert fixture.observations != []
      assert fixture.goals_tasks != []
      assert fixture.runs != []
      assert fixture.evidence != []
      assert fixture.memory != []
      assert fixture.audit != []
      assert fixture.derived != []
      assert Enum.all?(Map.values(Map.drop(fixture, [:profile, :counts])), &(length(&1) <= 100))
    end
  end

  test "fails closed above hard limits and marks soft-limit posture" do
    maximum = Capacity.maximum()
    assert {:ok, %{pressure: :soft_limit, pagination_required?: true}} = Capacity.admit(maximum)

    beyond = Map.update!(maximum, :repositories, &(&1 + 1))
    assert {:error, error} = Capacity.admit(beyond)
    assert error.kind == :conflict
    assert error.operation == :capacity_limit

    refute Map.has_key?(Capacity.limits(), :unbounded)
    assert Capacity.limits().degraded_claim == :stale_or_incomplete
  end

  test "runs the complete operation matrix with bounded timing results" do
    callbacks = Map.new(Benchmark.operations(), &{&1, fn -> Enum.sum(1..100) end})

    assert {:ok, results} = Benchmark.run(callbacks, iterations: 2, timeout: 100)
    assert Map.keys(results) |> Enum.sort() == Benchmark.operations() |> Enum.sort()

    assert Enum.all?(results, fn {_operation, result} ->
             result.outcome == :ok and result.iterations == 2 and result.p95_us >= 0
           end)
  end

  test "times out as a bounded failure rather than waiting indefinitely" do
    callbacks =
      Map.new(Benchmark.operations(), fn operation ->
        callback =
          if operation == :provider_storm, do: fn -> Process.sleep(50) end, else: fn -> :ok end

        {operation, callback}
      end)

    assert {:error, error} = Benchmark.run(callbacks, iterations: 1, timeout: 10)
    assert error.kind == :timeout
    assert error.retry == :verify_receipt
  end
end

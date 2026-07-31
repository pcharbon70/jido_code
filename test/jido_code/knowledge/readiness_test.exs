defmodule JidoCode.Knowledge.ReadinessTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.Readiness

  test "tracks verification, maintenance, and fail-closed owner death" do
    readiness = start_readiness!()

    assert Readiness.snapshot(readiness).state == :starting
    assert {:ok, %{state: :opening}} = Readiness.transition(readiness, :opening)

    assert {:ok, %{state: :verifying_store}} =
             Readiness.transition(readiness, :begin_verification)

    assert {:ok, %{state: :verifying_ontology}} =
             Readiness.transition(readiness, :store_verified)

    assert {:ok, ready} = Readiness.transition(readiness, :ready)
    assert Health.ready?(ready)

    assert {:ok, maintenance} =
             Readiness.transition(readiness, {:enter_maintenance, :restore})

    assert maintenance.state == :maintenance
    assert maintenance.maintenance_reason == :restore
    assert {:error, %Error{kind: :unavailable}} = Readiness.gate(readiness, :write)

    assert {:ok, resumed} = Readiness.transition(readiness, :leave_maintenance)
    assert Health.ready?(resumed)

    owner = spawn(fn -> Process.sleep(:infinity) end)
    assert :ok = Readiness.monitor_store(readiness, owner)
    Process.exit(owner, :kill)

    assert eventually(fn -> Readiness.snapshot(readiness).state == :unavailable end)
    assert {:error, %Error{kind: :unavailable}} = Readiness.gate(readiness, :write)
  end

  test "returns unavailable health when the readiness process is absent" do
    missing = spawn(fn -> :ok end)
    monitor = Process.monitor(missing)
    assert_receive {:DOWN, ^monitor, :process, ^missing, _reason}

    assert Readiness.snapshot(missing).state == :unavailable
    assert {:error, %Error{kind: :unavailable}} = Readiness.gate(missing, :health_check)
  end

  defp start_readiness! do
    spec = Supervisor.child_spec({Readiness, name: nil}, id: make_ref())
    start_supervised!(spec)
  end

  defp eventually(callback, attempts \\ 100)
  defp eventually(callback, 0), do: callback.()

  defp eventually(callback, attempts) do
    if callback.() do
      true
    else
      Process.sleep(10)
      eventually(callback, attempts - 1)
    end
  end
end

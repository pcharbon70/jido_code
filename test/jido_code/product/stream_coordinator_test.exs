defmodule JidoCode.Product.StreamCoordinatorTest do
  use ExUnit.Case, async: false
  alias JidoCode.Product.StreamCoordinator, as: Coordinator

  setup do
    name = Module.concat(__MODULE__, "Admission")
    start_supervised!({Coordinator, name: name})
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:jido_code, :product_stream, :lifecycle],
        &JidoCode.Product.StreamMetrics.handle_event/4,
        :sys.get_state(name).metrics
      )

    on_exit(fn -> :telemetry.detach(handler) end)
    %{server: name}
  end

  test "same session/tab takes over across routes, duplicate nonce never evicts", %{
    server: server
  } do
    context = context()
    assert {:ok, first} = Coordinator.admit(context, server)
    assert {:error, :duplicate} = Coordinator.admit(context, server)
    assert :ok = Coordinator.active(first, server)

    assert {:ok, second} =
             Coordinator.admit(%{context | request: "second", route: "/projects"}, server)

    assert_receive {:product_stream, ^first, {:closed, :takeover}}
    assert :ok = Coordinator.release(first, server)
    assert {:error, :closed} = Coordinator.active(first, server)
    assert :ok = Coordinator.active(second, server)
    assert %{connections: 1, nonce_keys: 2} = Coordinator.stats(server)
  end

  test "two tabs per session, separate sessions and exact owner cleanup", %{server: server} do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:ok, _} = Coordinator.admit(%{context() | tab: "tab2", request: "r2"}, server)

    assert {:error, :rate_limited} =
             Coordinator.admit(%{context() | tab: "tab3", request: "r3"}, server)

    task =
      Task.async(fn ->
        assert {:error, :closed} = Coordinator.active(lease, server)
        assert {:ok, _} = Coordinator.admit(%{context() | session: "another"}, server)
        Coordinator.release_owner(server)
      end)

    assert :ok = Task.await(task)
    assert %{connections: 2} = Coordinator.stats(server)
    assert :ok = Coordinator.release_owner(server)
    assert %{connections: 0} = Coordinator.stats(server)
  end

  test "expired session fails admission without any lease", %{server: server} do
    assert {:error, :expired} = Coordinator.admit(%{context() | hard_expires_at: 0}, server)
    assert %{connections: 0} = Coordinator.stats(server)
  end

  test "guard reporting an already-dead owner first is normal disconnect cleanup", %{
    server: server
  } do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, lease} = Coordinator.admit(context(), server)
        send(parent, {:lease, lease})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:lease, lease}
    entry = :sys.get_state(server).leases[lease]
    monitor = Process.monitor(entry.guard)
    :ok = :sys.suspend(server)

    try do
      send(owner, :stop)
      assert_receive {:DOWN, ^monitor, :process, _, {:shutdown, :owner_down}}

      :sys.replace_state(server, fn state ->
        {:noreply, next} =
          Coordinator.handle_info(
            {:DOWN, entry.guard_monitor, :process, entry.guard, {:shutdown, :owner_down}},
            state
          )

        next
      end)
    after
      :sys.resume(server)
    end

    assert %{connections: 0, metrics: %{guard_failure: 0}} = Coordinator.stats(server)
  end

  test "a crashed guard still kills its owner and records failure", %{server: server} do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, lease} = Coordinator.admit(context(), server)
        send(parent, {:lease, lease})

        receive do
          :stop -> :ok
        end
      end)

    monitor = Process.monitor(owner)
    assert_receive {:lease, lease}
    entry = :sys.get_state(server).leases[lease]
    Process.exit(entry.guard, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}
    assert %{connections: 0, metrics: %{guard_failure: 1}} = Coordinator.stats(server)
  end

  defp context do
    %{
      subject: "human",
      session: "session",
      tenant: "tenant",
      tab: "tab",
      request: "request",
      route: "/factory",
      projection: :factory,
      hard_expires_at: System.system_time(:millisecond) + 60_000,
      idle_expires_at: System.system_time(:millisecond) + 60_000
    }
  end

  test "an enforced guard deadline remains a failure", %{server: server} do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, lease} = Coordinator.admit(context(), server)
        send(parent, {:lease, lease})

        receive do
          :stop -> :ok
        end
      end)

    monitor = Process.monitor(owner)
    assert_receive {:lease, lease}
    guard = :sys.get_state(server).leases[lease].guard
    send(guard, {:deadline, Process.whereis(server), System.monotonic_time(:millisecond) - 1})
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}
    assert %{connections: 0, metrics: %{guard_failure: 1}} = Coordinator.stats(server)
  end

  test "bounded forced terminal cleanup is counted separately from active deadline failure", %{
    server: server
  } do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, lease} = Coordinator.admit(context(), server)
        send(parent, :admitted)
        :ok = Coordinator.terminate_owner(lease, :expired, server)

        receive do
          :never -> :ok
        end
      end)

    monitor = Process.monitor(owner)
    assert_receive :admitted
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1000

    assert %{connections: 0, metrics: %{guard_failure: 0, forced_terminal_cleanup: 1}} =
             Coordinator.stats(server)
  end
end

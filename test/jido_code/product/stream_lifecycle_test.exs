defmodule JidoCode.Product.StreamLifecycleTest do
  use ExUnit.Case, async: false
  alias JidoCode.Product.StreamCoordinator, as: Coordinator

  setup context do
    name = Module.concat(__MODULE__, "Coordinator")
    pid = start_supervised!({Coordinator, name: name, limits: context[:limits] || %{}})
    %{server: name, manager: pid}
  end

  test "every connection ceiling counts closing owners and rejects without evicting" do
    for {cap, changes} <- [
          factory: %{subject: "other", session: "other", tenant: "other"},
          principal: %{session: "other"},
          session: %{},
          tenant: %{subject: "other", session: "other"}
        ] do
      name = Module.concat(__MODULE__, Atom.to_string(cap))
      start_supervised!({Coordinator, name: name, limits: %{cap => 1}}, id: cap)
      {pid, ref, lease} = owner(name)
      other = context() |> Map.merge(changes) |> Map.merge(%{tab: "other", request: "other"})
      assert {:error, :rate_limited} = Coordinator.admit(other, name)
      assert rpc(pid, fn -> Coordinator.active(lease, name) end) == :ok
      send(pid, :stop)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      eventually(fn -> Coordinator.stats(name).connections == 0 end)
    end
  end

  test "admission rate, rate-key and nonce tables have independent fixed ceilings" do
    for cap <- [:admissions, :rate_keys, :nonce_keys] do
      name = Module.concat(__MODULE__, Atom.to_string(cap))
      start_supervised!({Coordinator, name: name, limits: %{cap => 1}}, id: cap)
      assert {:ok, _} = Coordinator.admit(context(), name)
      assert :ok = Coordinator.release_owner(name)
      next = Map.put(context(), :request, "next")
      next = if cap == :rate_keys, do: %{next | subject: "next", session: "next"}, else: next
      assert {:error, :rate_limited} = Coordinator.admit(next, name)
      assert Coordinator.stats(name).connections == 0
    end
  end

  @tag limits: %{window_ms: 20, nonce_ms: 20}
  test "expired correlation tombstones and rate keys are pruned without retaining a grant", %{
    server: server
  } do
    assert {:ok, _} = Coordinator.admit(context(), server)
    Coordinator.release_owner(server)
    eventually(fn -> Coordinator.stats(server).nonce_keys == 0 end)
    assert {:ok, _} = Coordinator.admit(context(), server)
    Coordinator.release_owner(server)
  end

  @tag limits: %{event_bytes: 64, event_interval_ms: 100}
  test "encoded event bytes and rate terminate instead of queueing protected payload", %{
    server: server
  } do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:ok, _} = Coordinator.connect(lease, server)
    assert {:error, :event_overflow} = Coordinator.reserve(lease, 65, server)
    assert {:error, :closed} = Coordinator.active(lease, server)
    Coordinator.release(lease, server)
    assert {:ok, lease} = Coordinator.admit(%{context() | request: "second"}, server)
    assert {:ok, _} = Coordinator.connect(lease, server)
    assert :ok = Coordinator.reserve(lease, 64, server)
    assert :ok = Coordinator.sent(lease, server)
    assert {:error, :event_rate} = Coordinator.reserve(lease, 1, server)
    assert %{queued_payload_bytes: 0} = Coordinator.stats(server)
    Coordinator.release(lease, server)
  end

  @tag limits: %{total_bytes: 1_050}
  test "aggregate bytes reserve a bounded terminal allowance", %{server: server} do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:ok, _} = Coordinator.connect(lease, server)
    assert {:error, :stream_overflow} = Coordinator.reserve(lease, 27, server)
    Coordinator.release(lease, server)
  end

  @tag limits: %{events: 2, event_interval_ms: 1}
  test "the event count includes the final terminal event", %{server: server} do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:ok, _} = Coordinator.connect(lease, server)
    assert :ok = Coordinator.reserve(lease, 1, server)
    assert :ok = Coordinator.sent(lease, server)
    assert {:error, :stream_overflow} = Coordinator.reserve(lease, 1, server)
    Coordinator.release(lease, server)
  end

  @tag limits: %{reauthorize_ms: 20, heartbeat_ms: 50, tick_ms: 5}
  test "one control credit coalesces timer work until acknowledged", %{server: server} do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:ok, _} = Coordinator.connect(lease, server)
    assert :ok = Coordinator.reserve(lease, 1, server)
    assert :ok = Coordinator.sent(lease, server)
    assert_receive {:product_stream, ^lease, {:check, _heartbeat_due}}, 500
    refute_receive {:product_stream, ^lease, {:check, _}}, 100
    assert %{pending_hints: 1, queued_payload_bytes: 0} = Coordinator.stats(server)
    assert :ok = Coordinator.checked(lease, server)
    assert_receive {:product_stream, ^lease, {:check, true}}, 500
    Coordinator.release(lease, server)
  end

  @tag limits: %{admitted_ms: 40, tick_ms: 5, grace_ms: 20}
  test "a stalled admission is killed and releases its capacity", %{server: server} do
    {pid, ref, _} = owner(server, zombie: true)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000
    eventually(fn -> Coordinator.stats(server).connections == 0 end)
  end

  @tag limits: %{work_ms: 40, tick_ms: 5, grace_ms: 20}
  test "a blocked writer cannot retain its owner or lease", %{server: server} do
    {pid, ref, lease} = owner(server, zombie: true)
    assert {:ok, _} = rpc(pid, fn -> Coordinator.connect(lease, server) end)
    assert :ok = rpc(pid, fn -> Coordinator.reserve(lease, 1, server) end)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000
    eventually(fn -> Coordinator.stats(server).connections == 0 end)
  end

  @tag limits: %{
         idle_ms: 100,
         reauthorize_ms: 10,
         heartbeat_ms: 20,
         tick_ms: 5,
         event_interval_ms: 1
       }
  test "heartbeat and reauthorization traffic never extend owner idle lifetime", %{server: server} do
    {pid, ref, _} = owner(server, connected: true)
    assert_receive {:checked, ^pid}, 500
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
    eventually(fn -> Coordinator.stats(server).connections == 0 end)
  end

  @tag limits: %{
         lifetime_ms: 100,
         reauthorize_ms: 10,
         heartbeat_ms: 20,
         tick_ms: 5,
         event_interval_ms: 1
       }
  test "connection hard lifetime is independent of continuous traffic", %{server: server} do
    {pid, ref, _} = owner(server, connected: true)
    assert_receive {:checked, ^pid}, 500
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
  end

  @tag limits: %{grace_ms: 100}
  test "deploy drain closes owners, retains closing capacity and rejects admission", %{
    server: server
  } do
    {pid, ref, _} = owner(server, zombie: true)
    assert :ok = Coordinator.drain(server)
    assert %{connections: 1, closing: 1, draining: true} = Coordinator.stats(server)
    assert {:error, :unavailable} = Coordinator.admit(%{context() | request: "next"}, server)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000
    eventually(fn -> Coordinator.stats(server).connections == 0 end)
  end

  test "owner crash removes its lease and independent watchdog", %{server: server} do
    {pid, ref, lease} = owner(server)
    guard = :sys.get_state(server).leases[lease].guard
    guard_ref = Process.monitor(guard)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
    assert_receive {:DOWN, ^guard_ref, :process, ^guard, _}, 1_000
    eventually(fn -> Coordinator.stats(server).connections == 0 end)
  end

  test "coordinator kill closes even a blocked owner before a supervisor restart", %{
    server: server,
    manager: manager
  } do
    {pid, ref, _} = owner(server, zombie: true)
    Process.exit(manager, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000
    eventually(fn -> is_pid(Process.whereis(server)) and Process.whereis(server) != manager end)
    assert %{connections: 0} = Coordinator.stats(server)
  end

  test "watchdog failure cannot leave an unguarded owner", %{server: server} do
    {pid, ref, lease} = owner(server, zombie: true)
    Process.exit(:sys.get_state(server).leases[lease].guard, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000
    eventually(fn -> Coordinator.stats(server).connections == 0 end)
  end

  test "out-of-order state transitions fail closed", %{server: server} do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:error, :invalid_transition} = Coordinator.reserve(lease, 1, server)
    assert {:error, :closed} = Coordinator.active(lease, server)
    Coordinator.release(lease, server)
    assert {:ok, lease} = Coordinator.admit(%{context() | request: "second"}, server)
    assert {:ok, _} = Coordinator.connect(lease, server)
    assert {:error, :invalid_transition} = Coordinator.checked(lease, server)
    Coordinator.release(lease, server)
  end

  test "lifecycle telemetry contains fixed labels, never correlations or protected context", %{
    server: server
  } do
    parent = self()
    handler = "stream-lifecycle-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler,
        [:jido_code, :product_stream, :lifecycle],
        fn event, measurements, metadata, _ ->
          send(parent, {:observed, event, measurements, metadata})
        end,
        nil
      )

    try do
      assert {:ok, lease} = Coordinator.admit(context(), server)

      assert_receive {:observed, _, %{count: 1},
                      %{reason: :admitted, projection: :factory} = metadata}

      assert Enum.sort(Map.keys(metadata)) == [:projection, :reason]
      Coordinator.release(lease, server)

      assert_receive {:observed, _, %{count: 1},
                      %{reason: :closed, projection: :factory} = metadata}

      assert Enum.sort(Map.keys(metadata)) == [:projection, :reason]
    after
      :telemetry.detach(handler)
    end
  end

  defp owner(server, options \\ []) do
    parent = self()

    pid =
      spawn(fn ->
        {:ok, lease} = Coordinator.admit(context(), server)

        if options[:connected] do
          {:ok, _} = Coordinator.connect(lease, server)
          :ok = Coordinator.reserve(lease, 1, server)
          :ok = Coordinator.sent(lease, server)
        end

        send(parent, {:owner, self(), lease})
        owner_loop(parent, server, lease, options)
      end)

    ref = Process.monitor(pid)
    assert_receive {:owner, ^pid, lease}, 1_000
    {pid, ref, lease}
  end

  defp owner_loop(parent, server, lease, options) do
    receive do
      {:rpc, ref, function} ->
        send(parent, {ref, function.()})
        owner_loop(parent, server, lease, options)

      :stop ->
        Coordinator.release(lease, server)

      {:product_stream, ^lease, {:closed, _}} ->
        if options[:zombie],
          do: owner_loop(parent, server, lease, options),
          else: Coordinator.release(lease, server)

      {:product_stream, ^lease, {:check, heartbeat?}} ->
        unless options[:zombie] do
          Coordinator.checked(lease, server)

          if heartbeat? do
            Coordinator.reserve(lease, 1, server)
            Coordinator.sent(lease, server)
          end

          send(parent, {:checked, self()})
        end

        owner_loop(parent, server, lease, options)
    end
  end

  defp rpc(pid, function) do
    ref = make_ref()
    send(pid, {:rpc, ref, function})
    assert_receive {^ref, result}, 1_000
    result
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

  defp eventually(function, attempts \\ 100)
  defp eventually(function, 0), do: assert(function.())

  defp eventually(function, attempts) do
    if function.(),
      do: :ok,
      else:
        (
          Process.sleep(10)
          eventually(function, attempts - 1)
        )
  end
end

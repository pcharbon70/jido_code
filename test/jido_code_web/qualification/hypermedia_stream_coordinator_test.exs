defmodule JidoCodeWeb.Qualification.HypermediaStreamCoordinatorTest do
  use ExUnit.Case, async: false

  alias JidoCodeWeb.Qualification.HypermediaStreamCoordinator, as: Coordinator

  setup do
    start_supervised!(Coordinator)
    assert :ok = Coordinator.reset()
    :ok
  end

  test "treats tab IDs only as bounded correlation and rejects duplicates" do
    assert {:ok, present_token, :present} = Coordinator.acquire("tab_alpha_001")
    assert {:error, :duplicate_tab} = Coordinator.acquire("tab_alpha_001")
    assert :ok = Coordinator.release(present_token, :completed)

    assert {:ok, missing_token, :missing} = Coordinator.acquire(nil)
    assert {:error, :duplicate_tab} = Coordinator.acquire("")
    assert :ok = Coordinator.release(missing_token, :cancelled)

    assert {:ok, invalid_token, :invalid} = Coordinator.acquire("<invalid>")
    assert {:error, :duplicate_tab} = Coordinator.acquire("also invalid")
    assert :ok = Coordinator.release(invalid_token, :cancelled)

    snapshot = Coordinator.snapshot()
    assert snapshot.active == 0
    assert snapshot.counters.rejected_duplicate == 3
  end

  test "enforces the global connection ceiling without a waiting queue" do
    %{max_connections: maximum, max_queue: 0} = Coordinator.limits()

    tokens =
      for index <- 1..maximum do
        assert {:ok, token, :present} = Coordinator.acquire("tab_ceiling_#{index}")
        token
      end

    assert {:error, :connection_ceiling} = Coordinator.acquire("tab_ceiling_extra")
    assert Coordinator.snapshot().active == maximum

    Enum.each(tokens, &Coordinator.release(&1, :completed))
    assert Coordinator.snapshot().active == 0
  end

  test "enforces event and byte budgets before emission" do
    %{max_events: max_events, max_bytes: max_bytes} = Coordinator.limits()

    assert {:ok, event_token, :present} = Coordinator.acquire("tab_events_001")

    Enum.each(1..max_events, fn _index ->
      assert :ok = Coordinator.record_event(event_token, 1)
    end)

    assert {:error, :event_limit} = Coordinator.record_event(event_token, 1)
    assert :ok = Coordinator.release(event_token, :completed)

    assert {:ok, byte_token, :present} = Coordinator.acquire("tab_bytes_001")
    assert {:error, :byte_limit} = Coordinator.record_event(byte_token, max_bytes + 1)
    assert :ok = Coordinator.release(byte_token, :cancelled)

    snapshot = Coordinator.snapshot()
    assert snapshot.counters.event_limit == 1
    assert snapshot.counters.byte_limit == 1
  end

  test "owner death reclaims zombie connections and emits cleanup accounting" do
    parent = self()
    handler_id = "hui-b3-cleanup-#{System.unique_integer([:positive])}"

    assert :ok =
             :telemetry.attach(
               handler_id,
               [:jido_code, :qualification, :hypermedia_stream, :cleanup],
               fn _event, measurements, metadata, test_pid ->
                 send(test_pid, {:cleanup, measurements, metadata})
               end,
               parent
             )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    owner =
      spawn(fn ->
        send(parent, {:acquired, Coordinator.acquire("tab_zombie_001")})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:acquired, {:ok, _token, :present}}
    Process.exit(owner, :kill)

    wait_until(fn -> Coordinator.snapshot().active == 0 end)
    assert Coordinator.snapshot().counters.owner_down == 1
    assert_receive {:cleanup, %{active: 0}, %{outcome: :owner_down}}
  end

  defp wait_until(assertion, attempts \\ 50)

  defp wait_until(assertion, attempts) when attempts > 0 do
    if assertion.() do
      :ok
    else
      Process.sleep(10)
      wait_until(assertion, attempts - 1)
    end
  end

  defp wait_until(_assertion, 0), do: flunk("coordinator did not reach the expected state")
end

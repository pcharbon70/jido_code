defmodule JidoCode.Product.StreamPressureTest do
  use ExUnit.Case, async: true
  alias JidoCode.Product.{StreamMetrics, StreamPressure}
  alias JidoCode.Product.StreamCoordinator
  @low %{memory_bytes: 100_000_000, query_queue: 0, run_queue: 0, schedulers: 2}

  test "three high samples enter degradation and ten low samples recover without flapping" do
    for high <- [
          %{@low | memory_bytes: 536_870_912},
          %{@low | query_queue: 8},
          %{@low | run_queue: 5}
        ] do
      state =
        Enum.reduce(1..2, StreamPressure.new(), fn _, state ->
          StreamPressure.observe(state, high)
        end)

      assert state.mode == :normal
      state = StreamPressure.observe(state, high)
      assert state.mode == :degraded
      state = Enum.reduce(1..9, state, fn _, state -> StreamPressure.observe(state, @low) end)
      assert state.mode == :degraded
      assert StreamPressure.observe(state, @low).mode == :normal
      assert StreamPressure.observe(state, high).low == 0
    end
  end

  test "metrics discard all identifiers and arbitrary dimensions and retain no payload" do
    table = StreamMetrics.new()

    StreamMetrics.handle_event(
      [:jido_code, :product_stream, :convergence],
      %{duration_ms: 20, payload: "private payload"},
      %{outcome: :refreshed, subject: "private human", graph: "private graph"},
      table
    )

    StreamMetrics.record(table, "attacker-key", 1)
    StreamMetrics.record(table, :reserved_bytes, -1)
    metrics = StreamMetrics.snapshot(table)
    assert Enum.sort(Map.keys(metrics)) == Enum.sort(StreamMetrics.keys())
    assert metrics.refreshed == 1
    assert metrics.convergence_ms == 20
    assert metrics.reserved_bytes == 0
    assert Enum.all?(Map.values(metrics), &is_integer/1)
    assert :ets.info(table, :size) == length(StreamMetrics.keys())
  end

  test "counter memory is bounded under hostile measurement sizes" do
    table = StreamMetrics.new()
    StreamMetrics.record(table, :reserved_bytes, 100_000_000_000)
    assert StreamMetrics.snapshot(table).reserved_bytes == 1_000_000_000
    assert :ets.info(table, :size) == length(StreamMetrics.keys())
  end

  test "authorization counters distinguish caller and store timeouts without retaining payloads" do
    table = StreamMetrics.new()
    event = [:jido_code, :knowledge, :authorization_read]

    StreamMetrics.handle_event(
      event,
      %{duration_ms: 1250},
      %{stage: :caller, outcome: :timeout},
      table
    )

    StreamMetrics.handle_event(
      event,
      %{duration_ms: 1000},
      %{stage: :store, outcome: :timeout},
      table
    )

    StreamMetrics.handle_event(event, %{duration_ms: 7}, %{stage: :store, outcome: :ok}, table)

    StreamMetrics.handle_event(
      event,
      %{duration_ms: 999},
      %{stage: :private, outcome: :timeout},
      table
    )

    metrics = StreamMetrics.snapshot(table)
    assert metrics.authorization_count == 1
    assert metrics.authorization_duration_ms == 1250
    assert metrics.authorization_timeout == 1
    assert metrics.authorization_error == 1
    assert metrics.authorization_store_count == 2
    assert metrics.authorization_store_duration_ms == 1007
    assert metrics.authorization_store_timeout == 1
    assert metrics.authorization_store_error == 1
    assert :ets.info(table, :size) == length(StreamMetrics.keys())
  end

  test "degraded admission returns unavailable without allocating a stream" do
    server = Module.concat(__MODULE__, Coordinator)
    start_supervised!({StreamCoordinator, name: server})
    :sys.replace_state(server, &%{&1 | pressure: %{mode: :degraded, high: 3, low: 0}})

    context = %{
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

    assert {:error, :unavailable} = StreamCoordinator.admit(context, server)
    assert %{connections: 0, metrics: %{rejected: 1}} = StreamCoordinator.stats(server)
  end
end

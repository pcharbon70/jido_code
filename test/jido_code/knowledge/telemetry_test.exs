defmodule JidoCode.Knowledge.TelemetryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.IntegrityReport
  alias JidoCode.Knowledge.Telemetry

  test "emits only low-cardinality error and health metadata" do
    error = Error.new(:persistence_failure, :execute_command)

    assert Telemetry.for_error(error) == %{
             operation: :execute_command,
             outcome: :error,
             error_kind: :persistence_failure,
             retry: :verify_receipt
           }

    assert Telemetry.for_health(Health.new()) == %{health_state: :starting}
  end

  test "rejects raw or unbounded metadata" do
    for key <- [:sparql, :graph, :path, :credential, :iri, :contents] do
      assert_raise ArgumentError, fn -> Telemetry.metadata(%{key => "secret"}) end
    end

    assert_raise ArgumentError, fn ->
      Telemetry.metadata(%{operation: "dynamic-operation"})
    end
  end

  test "spans expose only fixed operation classes and outcomes" do
    handler = "knowledge-telemetry-test-#{System.unique_integer([:positive])}"
    test_pid = self()

    events = [
      [:jido_code, :knowledge, :operation, :start],
      [:jido_code, :knowledge, :operation, :stop]
    ]

    :ok =
      :telemetry.attach_many(
        handler,
        events,
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert {:ok, :value} = Telemetry.span(:read, fn -> {:ok, :value} end)

    assert_receive {:telemetry, [:jido_code, :knowledge, :operation, :start],
                    %{system_time: system_time}, %{operation: :read}}

    assert is_integer(system_time)

    assert_receive {:telemetry, [:jido_code, :knowledge, :operation, :stop],
                    %{duration: duration}, %{operation: :read, outcome: :ok}}

    assert is_integer(duration)
    assert duration >= 0

    assert_raise FunctionClauseError, fn ->
      Telemetry.span(:arbitrary_query, fn -> :ok end)
    end
  end

  test "operation spans expose bounded numeric measurements without identifiers" do
    handler = "knowledge-measurement-test-#{System.unique_integer([:positive])}"
    test_pid = self()
    event = [:jido_code, :knowledge, :operation, :stop]

    :ok =
      :telemetry.attach(
        handler,
        event,
        fn received_event, measurements, metadata, _config ->
          send(test_pid, {:measurement, received_event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    report = %IntegrityReport{
      status: :error,
      dataset_revision: 8,
      graph_count: 3,
      quad_count: 21,
      issues: [:bounded_issue]
    }

    assert {:ok, ^report} =
             Telemetry.span(:integrity, %{queue_duration: 4}, fn -> {:ok, report} end)

    assert_receive {:measurement, ^event,
                    %{
                      duration: duration,
                      queue_duration: 4,
                      result_count: 21,
                      graph_count: 3,
                      issue_count: 1
                    }, %{operation: :integrity, outcome: :ok}}

    assert is_integer(duration)
    assert duration >= 0

    assert_raise ArgumentError, fn ->
      Telemetry.span(:backup, %{path: "/secret"}, fn -> :ok end)
    end

    assert_raise FunctionClauseError, fn ->
      Telemetry.span(:arbitrary_operation, %{}, fn -> :ok end)
    end
  end
end

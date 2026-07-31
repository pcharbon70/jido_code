defmodule JidoCode.Knowledge.TelemetryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health
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
end

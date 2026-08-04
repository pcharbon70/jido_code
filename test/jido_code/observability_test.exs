defmodule JidoCode.ObservabilityTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Observability

  test "correlates fixed stages with opaque refs and low-cardinality metadata" do
    handler = "observability-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:jido_code, :factory, :operation, :start],
          [:jido_code, :factory, :operation, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(parent, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    source_iri = "https://jido.run/id/command/secret-bearing-source"
    correlation_ref = Observability.correlation_ref(source_iri)

    assert {:error, %Error{}} =
             Observability.span(:graph_commit, correlation_ref, fn ->
               {:error, Error.new(:conflict, :commit)}
             end)

    assert_receive {:telemetry, [:jido_code, :factory, :operation, :start], _measurements,
                    start_metadata}

    assert start_metadata == %{stage: :graph_commit, correlation_ref: correlation_ref}

    assert_receive {:telemetry, [:jido_code, :factory, :operation, :stop], measurements,
                    stop_metadata}

    assert is_integer(measurements.duration)
    assert stop_metadata.stage == :graph_commit
    assert stop_metadata.outcome == :error
    assert stop_metadata.error_kind == :conflict
    refute inspect(stop_metadata) =~ source_iri
  end

  test "rejects arbitrary stages, correlation values, dimensions, and measurements" do
    assert_raise ArgumentError, fn ->
      Observability.span(:raw_graph_query, Observability.trace_ref(), fn -> :ok end)
    end

    assert_raise ArgumentError, fn ->
      Observability.span(:command, "https://jido.run/id/command/not-opaque", fn -> :ok end)
    end

    assert_raise ArgumentError, fn ->
      Observability.emit_snapshot(:store, :ready, %{repository_iri: 1})
    end

    assert_raise ArgumentError, fn ->
      Observability.emit_snapshot(:store, :ready, %{graph_count: -1})
    end
  end

  test "objectives and snapshots remain useful without the graph store" do
    assert :ok =
             Observability.emit_snapshot(:store, :unavailable, %{
               queue_depth: 0,
               stale_count: 1,
               backup_age_seconds: 90_000
             })

    alerts =
      Observability.evaluate_objectives(%{
        readiness: false,
        availability_ratio: 0.998,
        unresolved_commit_count: 0,
        backup_age_seconds: 90_000,
        recovery_seconds: 100,
        freshness_seconds: 10,
        query_p95_ms: 200,
        queue_depth: 3,
        ui_projection_error_ratio: 0.0
      })

    assert Enum.map(alerts, & &1.objective) |> Enum.sort() ==
             [:availability_ratio, :backup_age_seconds, :readiness]

    assert Enum.all?(alerts, &(&1.severity in [:warning, :critical]))
  end
end

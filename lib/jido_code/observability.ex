defmodule JidoCode.Observability do
  @moduledoc """
  Safe, low-cardinality factory telemetry and release service objectives.

  Correlation references are opaque SHA-256 prefixes. Arbitrary IRIs, graph
  contents, source text, prompts, paths, and credentials are never accepted as
  telemetry fields.
  """

  alias JidoCode.Knowledge.Error

  @stages [
    :http,
    :liveview,
    :command,
    :graph_commit,
    :reconciliation,
    :scheduling,
    :lease,
    :attempt,
    :tool,
    :evidence,
    :decision,
    :reasoning,
    :projection,
    :backup,
    :retention
  ]
  @snapshot_kinds [
    :store,
    :ingestion,
    :reconciliation,
    :scheduler,
    :execution,
    :evidence,
    :reasoning,
    :projection,
    :backup
  ]
  @states [:ready, :degraded, :unavailable, :maintenance]
  @snapshot_measurements [
    :queue_depth,
    :admission_deferred_count,
    :graph_count,
    :quad_count,
    :stale_count,
    :incomplete_count,
    :active_lease_count,
    :active_attempt_count,
    :decision_pending_count,
    :cache_entry_count,
    :pubsub_lag_ms,
    :backup_age_seconds,
    :projection_error_count
  ]
  @objectives %{
    readiness: %{comparison: :equal, threshold: true, severity: :critical},
    availability_ratio: %{comparison: :minimum, threshold: 0.999, severity: :critical},
    unresolved_commit_count: %{comparison: :maximum, threshold: 0, severity: :critical},
    backup_age_seconds: %{comparison: :maximum, threshold: 86_400, severity: :warning},
    recovery_seconds: %{comparison: :maximum, threshold: 900, severity: :critical},
    freshness_seconds: %{comparison: :maximum, threshold: 300, severity: :warning},
    query_p95_ms: %{comparison: :maximum, threshold: 500, severity: :warning},
    queue_depth: %{comparison: :maximum, threshold: 200, severity: :warning},
    ui_projection_error_ratio: %{comparison: :maximum, threshold: 0.01, severity: :warning}
  }
  @event_prefix [:jido_code, :factory]

  @spec stages() :: [atom()]
  def stages, do: @stages

  @spec objectives() :: map()
  def objectives, do: @objectives

  @spec trace_ref() :: String.t()
  def trace_ref do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  @spec correlation_ref(String.t()) :: String.t()
  def correlation_ref(value) when is_binary(value) do
    value
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end

  @spec span(atom(), (-> result)) :: result when result: term()
  def span(stage, callback) when is_function(callback, 0),
    do: span(stage, trace_ref(), callback)

  @spec span(atom(), String.t(), (-> result)) :: result when result: term()
  def span(stage, correlation_ref, callback)
      when stage in @stages and is_binary(correlation_ref) and is_function(callback, 0) do
    validate_correlation_ref!(correlation_ref)
    started_at = System.monotonic_time()

    :telemetry.execute(
      @event_prefix ++ [:operation, :start],
      %{system_time: System.system_time()},
      %{stage: stage, correlation_ref: correlation_ref}
    )

    try do
      result = callback.()

      :telemetry.execute(
        @event_prefix ++ [:operation, :stop],
        %{duration: System.monotonic_time() - started_at},
        result_metadata(stage, correlation_ref, result)
      )

      result
    catch
      kind, reason ->
        :telemetry.execute(
          @event_prefix ++ [:operation, :exception],
          %{duration: System.monotonic_time() - started_at},
          %{stage: stage, outcome: :error, correlation_ref: correlation_ref}
        )

        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  def span(_stage, _correlation_ref, _callback),
    do: raise(ArgumentError, "invalid factory telemetry span")

  @spec emit_snapshot(atom(), atom(), map()) :: :ok
  def emit_snapshot(kind, state, measurements)
      when kind in @snapshot_kinds and state in @states and is_map(measurements) do
    unknown = Map.keys(measurements) -- @snapshot_measurements

    if unknown == [] and Enum.all?(measurements, &valid_measurement?/1) do
      :telemetry.execute(@event_prefix ++ [:snapshot], measurements, %{kind: kind, state: state})
      :ok
    else
      raise ArgumentError, "unsafe factory telemetry snapshot"
    end
  end

  def emit_snapshot(_kind, _state, _measurements),
    do: raise(ArgumentError, "invalid factory telemetry snapshot")

  @spec evaluate_objectives(map()) :: [map()]
  def evaluate_objectives(samples) when is_map(samples) do
    Enum.flat_map(@objectives, fn {name, objective} ->
      case Map.fetch(samples, name) do
        {:ok, value} ->
          if objective_met?(value, objective) do
            []
          else
            [
              %{
                objective: name,
                severity: objective.severity,
                value: value,
                threshold: objective.threshold
              }
            ]
          end

        :error ->
          [
            %{
              objective: name,
              severity: :critical,
              value: :missing,
              threshold: objective.threshold
            }
          ]
      end
    end)
  end

  def evaluate_objectives(_samples),
    do: [%{objective: :samples, severity: :critical, value: :invalid, threshold: :valid_map}]

  defp result_metadata(stage, correlation_ref, {:error, %Error{} = error}) do
    %{
      stage: stage,
      outcome: :error,
      error_kind: error.kind,
      retry: error.retry,
      correlation_ref: correlation_ref
    }
  end

  defp result_metadata(stage, correlation_ref, _result) do
    %{stage: stage, outcome: :ok, correlation_ref: correlation_ref}
  end

  defp validate_correlation_ref!(value) do
    unless Regex.match?(~r/^[a-f0-9]{32}$/, value),
      do: raise(ArgumentError, "invalid telemetry correlation reference")
  end

  defp valid_measurement?({_key, value}),
    do: (is_integer(value) or is_float(value)) and value >= 0

  defp objective_met?(value, %{comparison: :equal, threshold: threshold}), do: value == threshold

  defp objective_met?(value, %{comparison: :minimum, threshold: threshold}),
    do: is_number(value) and value >= threshold

  defp objective_met?(value, %{comparison: :maximum, threshold: threshold}),
    do: is_number(value) and value <= threshold
end

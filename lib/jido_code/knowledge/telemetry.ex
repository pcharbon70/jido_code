defmodule JidoCode.Knowledge.Telemetry do
  @moduledoc """
  Constructs low-cardinality metadata for knowledge telemetry events.

  Measurements such as duration and counts remain separate. This module never
  accepts raw SPARQL, graph contents, paths, credentials, or arbitrary IRIs.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health

  @allowed_keys [:operation, :outcome, :error_kind, :health_state, :retry]
  @allowed_measurements [
    :duration,
    :system_time,
    :queue_duration,
    :result_count,
    :graph_count,
    :issue_count
  ]
  @outcomes [:ok, :error, :rejected]
  @retry_modes [:retry, :verify_receipt, :refresh, :never]
  @operation_classes [
    :open,
    :verify,
    :read,
    :write,
    :maintenance,
    :commit,
    :backup,
    :restore,
    :export,
    :integrity
  ]
  @event_prefix [:jido_code, :knowledge, :operation]

  @spec span(atom(), (-> result)) :: result when result: term()
  def span(operation, callback)
      when operation in @operation_classes and is_function(callback, 0) do
    span(operation, %{}, callback)
  end

  @spec span(atom(), map(), (-> result)) :: result when result: term()
  def span(operation, measurements, callback)
      when operation in @operation_classes and is_map(measurements) and is_function(callback, 0) do
    measurements = validate_measurements!(measurements)
    started_at = System.monotonic_time()

    :telemetry.execute(
      @event_prefix ++ [:start],
      Map.put(measurements, :system_time, System.system_time()),
      metadata(%{operation: operation})
    )

    try do
      result = callback.()

      :telemetry.execute(
        @event_prefix ++ [:stop],
        measurements
        |> Map.put(:duration, System.monotonic_time() - started_at)
        |> Map.merge(result_measurements(result)),
        result_metadata(operation, result)
      )

      result
    catch
      kind, reason ->
        :telemetry.execute(
          @event_prefix ++ [:exception],
          %{duration: System.monotonic_time() - started_at},
          metadata(%{operation: operation, outcome: :error})
        )

        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  def metadata(attributes) when is_map(attributes) do
    unknown_keys = Map.keys(attributes) -- @allowed_keys

    if unknown_keys != [] do
      raise ArgumentError,
            "unsafe knowledge telemetry keys: #{inspect(Enum.sort(unknown_keys))}"
    end

    Enum.each(attributes, &validate_attribute!/1)
    attributes
  end

  def for_error(%Error{} = error) do
    metadata(%{
      operation: error.operation,
      outcome: :error,
      error_kind: error.kind,
      retry: error.retry
    })
  end

  def for_health(%Health{} = health) do
    metadata(%{health_state: health.state})
  end

  def allowed_keys, do: @allowed_keys

  def operation_classes, do: @operation_classes

  def allowed_measurements, do: @allowed_measurements

  defp result_metadata(operation, {:error, %Error{} = error}) do
    metadata(%{
      operation: operation,
      outcome: :error,
      error_kind: error.kind,
      retry: error.retry
    })
  end

  defp result_metadata(operation, {:error, %Error{} = error, _details}) do
    metadata(%{
      operation: operation,
      outcome: :error,
      error_kind: error.kind,
      retry: error.retry
    })
  end

  defp result_metadata(operation, {:error_with_state, %Error{} = error, _state}) do
    metadata(%{
      operation: operation,
      outcome: :error,
      error_kind: error.kind,
      retry: error.retry
    })
  end

  defp result_metadata(operation, {:error, _reason}) do
    metadata(%{operation: operation, outcome: :error})
  end

  defp result_metadata(operation, _result) do
    metadata(%{operation: operation, outcome: :ok})
  end

  defp result_measurements({:ok, %JidoCode.Knowledge.WriteReceipt{} = receipt}) do
    %{
      result_count: receipt.additions_count + receipt.removals_count,
      graph_count: map_size(receipt.graph_revisions)
    }
  end

  defp result_measurements({:ok, %JidoCode.Knowledge.BackupReceipt{} = receipt}) do
    %{result_count: receipt.quad_count, graph_count: receipt.graph_count}
  end

  defp result_measurements({:ok, %JidoCode.Knowledge.IntegrityReport{} = report}) do
    %{
      result_count: report.quad_count,
      graph_count: report.graph_count,
      issue_count: length(report.issues)
    }
  end

  defp result_measurements({:ok, %JidoCode.Knowledge.IntegrityReport{} = report, _state}) do
    result_measurements({:ok, report})
  end

  defp result_measurements({:ok, %{integrity_status: _status}, _state}) do
    %{result_count: 1}
  end

  defp result_measurements(_result), do: %{}

  defp validate_measurements!(measurements) do
    unknown_keys = Map.keys(measurements) -- @allowed_measurements

    if unknown_keys != [] do
      raise ArgumentError,
            "unsafe knowledge telemetry measurements: #{inspect(Enum.sort(unknown_keys))}"
    end

    Enum.each(measurements, fn
      {_key, value} when is_integer(value) and value >= 0 -> :ok
      {key, value} -> raise ArgumentError, "invalid knowledge telemetry #{key}: #{inspect(value)}"
    end)

    measurements
  end

  defp validate_attribute!({:operation, value}) when is_atom(value), do: :ok
  defp validate_attribute!({:outcome, value}) when value in @outcomes, do: :ok

  defp validate_attribute!({:error_kind, value}) do
    validate_member!(:error_kind, value, Error.kinds())
  end

  defp validate_attribute!({:health_state, value}) do
    validate_member!(:health_state, value, Health.states())
  end

  defp validate_attribute!({:retry, value}) when value in @retry_modes, do: :ok

  defp validate_attribute!({key, value}) do
    raise ArgumentError, "invalid knowledge telemetry #{key}: #{inspect(value)}"
  end

  defp validate_member!(key, value, allowed) do
    if value in allowed do
      :ok
    else
      raise ArgumentError, "invalid knowledge telemetry #{key}: #{inspect(value)}"
    end
  end
end

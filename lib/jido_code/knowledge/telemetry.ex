defmodule JidoCode.Knowledge.Telemetry do
  @moduledoc """
  Constructs low-cardinality metadata for knowledge telemetry events.

  Measurements such as duration and counts remain separate. This module never
  accepts raw SPARQL, graph contents, paths, credentials, or arbitrary IRIs.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health

  @allowed_keys [:operation, :outcome, :error_kind, :health_state, :retry]
  @outcomes [:ok, :error, :rejected]
  @retry_modes [:retry, :verify_receipt, :refresh, :never]
  @operation_classes [:open, :verify, :read, :write, :maintenance]
  @event_prefix [:jido_code, :knowledge, :operation]

  @spec span(atom(), (-> result)) :: result when result: term()
  def span(operation, callback)
      when operation in @operation_classes and is_function(callback, 0) do
    started_at = System.monotonic_time()

    :telemetry.execute(
      @event_prefix ++ [:start],
      %{system_time: System.system_time()},
      metadata(%{operation: operation})
    )

    try do
      result = callback.()

      :telemetry.execute(
        @event_prefix ++ [:stop],
        %{duration: System.monotonic_time() - started_at},
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

  defp result_metadata(operation, {:error, _reason}) do
    metadata(%{operation: operation, outcome: :error})
  end

  defp result_metadata(operation, _result) do
    metadata(%{operation: operation, outcome: :ok})
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

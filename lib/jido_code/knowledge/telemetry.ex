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

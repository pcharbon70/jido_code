defmodule JidoCode.Factory.Sandbox.ResourceEnforcer do
  @moduledoc "Validates attested resource observations and bounded capture before release."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox.Event

  @dimensions [
    {:cpu_ms, :cpu_ms, :sandbox_cpu_limit},
    {:memory_bytes, :memory_bytes, :sandbox_memory_limit},
    {:process_count, :process_count, :sandbox_process_limit},
    {:disk_bytes, :disk_bytes, :sandbox_disk_limit},
    {:output_bytes, :output_bytes, :sandbox_output_limit},
    {:wall_time_ms, :timeout_ms, :sandbox_time_limit}
  ]
  @usage_keys Enum.map(@dimensions, &elem(&1, 0))
  @maximum_candidates 100

  @spec validate_execution(Event.t(), map()) :: :ok | {:error, AdapterError.t()}
  def validate_execution(%Event{operation: :execute, details: details}, limits)
      when is_map(details) and is_map(limits) do
    usage = details[:usage]

    if is_map(usage) and MapSet.new(Map.keys(usage)) == MapSet.new(@usage_keys) do
      Enum.reduce_while(@dimensions, :ok, fn {usage_key, limit_key, operation}, :ok ->
        observed = usage[usage_key]
        maximum = limits[limit_key]

        cond do
          not is_integer(observed) or observed < 0 or not is_integer(maximum) or maximum <= 0 ->
            {:halt, corrupt()}

          observed > maximum ->
            {:halt, {:error, AdapterError.new(:unauthorized, operation)}}

          true ->
            {:cont, :ok}
        end
      end)
    else
      corrupt()
    end
  end

  def validate_execution(_event, _limits), do: corrupt()

  @spec validate_collection(Event.t(), map()) :: :ok | {:error, AdapterError.t()}
  def validate_collection(%Event{operation: :collect, details: details}, limits)
      when is_map(details) and is_map(limits) do
    bytes = details[:byte_count]
    maximum = limits[:output_bytes]

    if is_integer(bytes) and bytes >= 0 and is_integer(maximum) and bytes <= maximum,
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :sandbox_output_limit)}
  end

  def validate_collection(_event, _limits), do: corrupt()

  @spec validate_capture([map()], map()) :: :ok | {:error, AdapterError.t()}
  def validate_capture(candidates, limits)
      when is_list(candidates) and is_map(limits) do
    maximum = limits[:output_bytes]

    result =
      Enum.reduce_while(candidates, {0, 0}, fn candidate, {count, total} ->
        cond do
          count >= @maximum_candidates ->
            {:halt, :exceeded}

          not match?(%{content: content} when is_binary(content), candidate) ->
            {:halt, :invalid}

          true ->
            next = total + byte_size(candidate.content)

            if is_integer(maximum) and maximum > 0 and next <= maximum do
              {:cont, {count + 1, next}}
            else
              {:halt, :exceeded}
            end
        end
      end)

    case result do
      {_count, total} when is_integer(total) -> :ok
      :exceeded -> {:error, AdapterError.new(:unauthorized, :sandbox_artifact_output_limit)}
      :invalid -> corrupt()
    end
  end

  def validate_capture(_candidates, _limits),
    do: {:error, AdapterError.new(:unauthorized, :sandbox_artifact_output_limit)}

  defp corrupt, do: {:error, AdapterError.new(:corrupt, :sandbox_resource_observation)}
end

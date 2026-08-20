defmodule JidoCode.Knowledge.Memory.RetrievalTelemetry do
  @moduledoc "Low-cardinality retrieval telemetry that never accepts payload values."

  @event [:jido_code, :memory, :retrieval]
  @measurement_keys ~w[
    latency_ms estimated_cost_microunits truncated_count unavailable_count source_count
    index_rebuild_count
  ]a
  @metadata_keys ~w[channel outcome query_version ranking_version index_version]a
  @channels ~w[hybrid exact_identifier lexical temporal_graph failure_signature recency current_state]a
  @outcomes ~w[ok rejected unavailable]a

  @spec emit(map(), map()) :: :ok
  def emit(measurements, metadata) when is_map(measurements) and is_map(metadata) do
    if exact_keys?(measurements, @measurement_keys) and
         Enum.all?(measurements, fn {_key, value} -> is_integer(value) and value >= 0 end) and
         exact_keys?(metadata, @metadata_keys) and metadata.channel in @channels and
         metadata.outcome in @outcomes and
         Enum.all?(~w[query_version ranking_version index_version]a, fn key ->
           value = metadata[key]
           is_binary(value) and byte_size(value) in 1..64
         end) do
      :telemetry.execute(@event, measurements, metadata)
      :ok
    else
      raise ArgumentError, "unsafe memory retrieval telemetry"
    end
  end

  def emit(_measurements, _metadata),
    do: raise(ArgumentError, "invalid memory retrieval telemetry")

  @spec event() :: [atom()]
  def event, do: @event

  defp exact_keys?(values, keys), do: MapSet.new(Map.keys(values)) == MapSet.new(keys)
end

defmodule JidoCode.Knowledge.RepositoryWiki.OperationsTelemetry do
  @moduledoc "Bounded, content-free repository-wiki fleet telemetry."

  @event [:jido_code, :repository_wiki, :fleet]
  @measurement_keys ~w[
    repositories current stale queue_pending queue_active reservations_live usage_pending
    usage_unknown retained_bytes alerts duration_ms
  ]a
  @metadata_keys ~w[outcome operation mode generation_profile severity]a
  @outcomes [:ok, :degraded, :failed]
  @operations [:projection, :backup, :restore, :recovery, :reconciliation]
  @modes [:off, :manual, :automatic, :mixed]
  @profiles [:deterministic_only, :synthesis_unavailable, :mixed]
  @severities [:none, :warning, :critical]

  @spec event() :: [atom()]
  def event, do: @event

  @spec emit(map(), map()) :: :ok
  def emit(measurements, metadata) when is_map(measurements) and is_map(metadata) do
    if Map.keys(measurements) |> Enum.sort() == Enum.sort(@measurement_keys) and
         Enum.all?(@measurement_keys, &nonnegative?(measurements[&1])) and
         Map.keys(metadata) |> Enum.sort() == Enum.sort(@metadata_keys) and
         metadata.outcome in @outcomes and metadata.operation in @operations and
         metadata.mode in @modes and metadata.generation_profile in @profiles and
         metadata.severity in @severities do
      :telemetry.execute(@event, measurements, metadata)
    else
      raise ArgumentError, "invalid repository wiki fleet telemetry"
    end
  end

  def emit(_measurements, _metadata),
    do: raise(ArgumentError, "invalid repository wiki fleet telemetry")

  defp nonnegative?(value), do: is_integer(value) and value >= 0
end

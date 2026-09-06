defmodule JidoCode.Product.ReadProjectionTelemetry do
  @moduledoc "Bounded, value-free telemetry for HUI-C4 projection reads."

  alias JidoCode.Product.ReadProjection

  @event [:jido_code, :product, :read_projection]
  @surfaces [
    :factory,
    :fleet,
    :projects,
    :project,
    :project_attempts,
    :project_wiki,
    :project_dependencies,
    :attempt
  ]
  @states ReadProjection.canonical_states()
  @outcomes [:ok, :rejected, :error]
  @cache_statuses [:bypass, :miss, :hit, :refresh, :invalidated]
  @measurement_keys [:duration_ms, :row_count, :truncated_count, :cache_hit_count]
  @metadata_keys [:surface, :outcome, :state, :cache_status, :query_version]

  @spec emit(non_neg_integer(), atom(), term()) :: :ok
  def emit(duration_ms, surface, result)
      when is_integer(duration_ms) and duration_ms >= 0 and surface in @surfaces do
    {projection, outcome} = projection_outcome(result, surface)
    cache_status = projection.cache[:status] || :bypass

    measurements = %{
      duration_ms: duration_ms,
      row_count: row_count(projection),
      truncated_count: if(projection.truncated?, do: 1, else: 0),
      cache_hit_count: if(cache_status == :hit, do: 1, else: 0)
    }

    metadata = %{
      surface: surface,
      outcome: outcome,
      state: projection.state,
      cache_status: cache_status,
      query_version: projection.query_version
    }

    with :ok <- validate(measurements, metadata) do
      :telemetry.execute(@event, measurements, metadata)
      :ok
    end
  end

  def emit(_duration_ms, _surface, _result),
    do: raise(ArgumentError, "invalid read projection telemetry")

  @spec event() :: [atom()]
  def event, do: @event

  defp projection_outcome({:ok, %ReadProjection{} = projection}, _surface) do
    outcome =
      cond do
        projection.state == :unauthorized -> :rejected
        projection.state in [:unavailable, :maintenance, :recovery] -> :error
        true -> :ok
      end

    {projection, outcome}
  end

  defp projection_outcome(_result, surface),
    do: {ReadProjection.unavailable(surface, :error), :error}

  defp row_count(projection) do
    [
      projection.attention,
      projection.health,
      projection.fleet,
      projection.projects,
      projection.attempts,
      projection.dependencies
    ]
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp validate(measurements, metadata) do
    with true <- Map.keys(measurements) |> Enum.sort() == Enum.sort(@measurement_keys),
         true <- Enum.all?(measurements, fn {_key, value} -> is_integer(value) and value >= 0 end),
         true <- Map.keys(metadata) |> Enum.sort() == Enum.sort(@metadata_keys),
         true <- metadata.surface in @surfaces,
         true <- metadata.outcome in @outcomes,
         true <- metadata.state in @states,
         true <- metadata.cache_status in @cache_statuses,
         true <- metadata.query_version == "2.11.0" do
      :ok
    else
      _invalid -> raise ArgumentError, "unsafe read projection telemetry"
    end
  end
end

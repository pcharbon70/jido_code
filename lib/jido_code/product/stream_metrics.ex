defmodule JidoCode.Product.StreamMetrics do
  @moduledoc "Fixed-cardinality local counters; no event payload queue or sensitive dimensions."
  @keys ~w[admitted rejected revoked expired closed slow_owner guard_failure event_overflow stream_overflow event_rate duplicate frames_reserved reserved_bytes cursor_reconnect query_count query_error query_duration_ms hint gap reconcile refreshed graph_lag stale_revision query_unavailable recovery_exhausted subscription_lost convergence_ms pressure_enter pressure_exit]a
  @events [
    [:jido_code, :knowledge, :authorization_read],
    [:jido_code, :product_stream, :lifecycle],
    [:jido_code, :product_stream, :convergence],
    [:jido_code, :product, :read_projection]
  ]
  @ceiling 9_223_372_036_854_775_807
  @keys @keys ++ [:forced_terminal_cleanup]
  @authorization_keys %{
    caller:
      {:authorization_count, :authorization_duration_ms, :authorization_error,
       :authorization_timeout},
    store:
      {:authorization_store_count, :authorization_store_duration_ms, :authorization_store_error,
       :authorization_store_timeout}
  }
  @keys @keys ++ (@authorization_keys |> Map.values() |> Enum.flat_map(&Tuple.to_list/1))

  def keys, do: @keys

  def new do
    table = :ets.new(__MODULE__, [:set, :public, write_concurrency: true])
    true = :ets.insert(table, Enum.map(@keys, &{&1, 0}))
    table
  end

  def attach(table) do
    :telemetry.detach(__MODULE__)
    :telemetry.attach_many(__MODULE__, @events, &__MODULE__.handle_event/4, table)
  end

  def record(table, key, value \\ 1)

  def record(table, key, value) when key in @keys and is_integer(value) and value >= 0 do
    :ets.update_counter(table, key, {2, min(value, 1_000_000_000), @ceiling, @ceiling})
    :ok
  rescue
    ArgumentError -> :ok
  end

  def record(_, _, _), do: :ok

  def snapshot(table) do
    Map.new(:ets.tab2list(table))
  rescue
    ArgumentError -> %{}
  end

  def handle_event([:jido_code, :product_stream, :lifecycle], _, %{reason: reason}, table) do
    record(table, if(reason in @keys, do: reason, else: :closed))
  end

  def handle_event([:jido_code, :product_stream, :convergence], measurements, metadata, table) do
    record(table, metadata[:outcome])
    record(table, :convergence_ms, measurements[:duration_ms])
  end

  def handle_event([:jido_code, :product, :read_projection], measurements, metadata, table) do
    record(table, :query_count)
    record(table, :query_duration_ms, measurements[:duration_ms])
    if metadata[:outcome] != :ok, do: record(table, :query_error)
  end

  def handle_event(
        [:jido_code, :knowledge, :authorization_read],
        measurements,
        %{stage: stage, outcome: outcome},
        table
      )
      when stage in [:caller, :store] and outcome in [:ok, :error, :timeout, :unavailable] do
    {count, duration, error, timeout} = Map.fetch!(@authorization_keys, stage)
    record(table, count)
    record(table, duration, measurements[:duration_ms])
    if outcome != :ok, do: record(table, error)
    if outcome == :timeout, do: record(table, timeout)
    :ok
  end

  def handle_event(_, _, _, _), do: :ok
end

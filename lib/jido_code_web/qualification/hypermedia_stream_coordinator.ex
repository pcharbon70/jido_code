defmodule JidoCodeWeb.Qualification.HypermediaStreamCoordinator do
  @moduledoc """
  Application-owned admission and accounting boundary for the HUI-B3 fixture.

  Tab IDs are untrusted correlation hints. They never become identity or
  authority, and malformed or absent values share bounded sentinel buckets.
  The coordinator has no waiting queue: excess and duplicate connections fail
  immediately, which makes its queue bound exactly zero.
  """

  use GenServer

  @max_connections 4
  @max_events 8
  @max_bytes 12_288
  @tab_id_pattern ~r/\A[a-zA-Z0-9_-]{8,48}\z/

  @counters ~w[
    admitted rejected_ceiling rejected_duplicate released_completed
    released_cancelled owner_down event_limit byte_limit send_error
  ]a

  @type token :: reference()
  @type correlation :: :present | :missing | :invalid

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(options, :name, __MODULE__))
  end

  @spec acquire(term(), pid()) ::
          {:ok, token(), correlation()} | {:error, :connection_ceiling | :duplicate_tab}
  def acquire(tab_id, owner \\ self()) when is_pid(owner) do
    GenServer.call(__MODULE__, {:acquire, tab_id, owner})
  end

  @spec record_event(token(), non_neg_integer()) ::
          :ok | {:error, :event_limit | :byte_limit | :unknown_stream}
  def record_event(token, bytes) when is_reference(token) and is_integer(bytes) and bytes >= 0 do
    GenServer.call(__MODULE__, {:record_event, token, bytes})
  end

  @spec record_send_error(token()) :: :ok
  def record_send_error(token), do: GenServer.cast(__MODULE__, {:send_error, token})

  @spec release(token(), :completed | :cancelled) :: :ok
  def release(token, outcome) when outcome in [:completed, :cancelled] do
    GenServer.call(__MODULE__, {:release, token, outcome})
  end

  @spec snapshot() :: map()
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @doc false
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc false
  def limits do
    %{
      max_connections: @max_connections,
      max_events: @max_events,
      max_bytes: @max_bytes,
      max_queue: 0
    }
  end

  @impl true
  def init(:ok), do: {:ok, initial_state()}

  @impl true
  def handle_call({:acquire, tab_id, owner}, _from, state) do
    {correlation, tab_key} = normalize_tab_id(tab_id)

    cond do
      map_size(state.connections) >= @max_connections ->
        {:reply, {:error, :connection_ceiling}, increment(state, :rejected_ceiling)}

      MapSet.member?(state.tab_keys, tab_key) ->
        {:reply, {:error, :duplicate_tab}, increment(state, :rejected_duplicate)}

      true ->
        token = make_ref()
        monitor = Process.monitor(owner)
        connection = %{monitor: monitor, owner: owner, tab_key: tab_key, events: 0, bytes: 0}

        state =
          state
          |> put_in([:connections, token], connection)
          |> put_in([:monitors, monitor], token)
          |> Map.update!(:tab_keys, &MapSet.put(&1, tab_key))
          |> increment(:admitted)
          |> then(
            &%{&1 | max_observed_active: max(&1.max_observed_active, map_size(&1.connections))}
          )

        {:reply, {:ok, token, correlation}, state}
    end
  end

  def handle_call({:record_event, token, bytes}, _from, state) do
    case Map.fetch(state.connections, token) do
      :error ->
        {:reply, {:error, :unknown_stream}, state}

      {:ok, connection} when connection.events + 1 > @max_events ->
        {:reply, {:error, :event_limit}, increment(state, :event_limit)}

      {:ok, connection} when connection.bytes + bytes > @max_bytes ->
        {:reply, {:error, :byte_limit}, increment(state, :byte_limit)}

      {:ok, connection} ->
        updated = %{connection | events: connection.events + 1, bytes: connection.bytes + bytes}

        state =
          state
          |> put_in([:connections, token], updated)
          |> Map.update!(:total_events, &(&1 + 1))
          |> Map.update!(:total_bytes, &(&1 + bytes))

        {:reply, :ok, state}
    end
  end

  def handle_call({:release, token, outcome}, _from, state) do
    {connection, state} = pop_in(state, [:connections, token])

    state =
      if connection do
        Process.demonitor(connection.monitor, [:flush])

        state
        |> update_in([:monitors], &Map.delete(&1, connection.monitor))
        |> Map.update!(:tab_keys, &MapSet.delete(&1, connection.tab_key))
        |> increment(release_counter(outcome))
        |> emit_cleanup(outcome)
      else
        state
      end

    {:reply, :ok, state}
  end

  def handle_call(:snapshot, _from, state) do
    snapshot = %{
      active: map_size(state.connections),
      max_observed_active: state.max_observed_active,
      total_events: state.total_events,
      total_bytes: state.total_bytes,
      counters: state.counters,
      limits: limits()
    }

    {:reply, snapshot, state}
  end

  def handle_call(:reset, _from, %{connections: connections})
      when map_size(connections) == 0 do
    {:reply, :ok, initial_state()}
  end

  def handle_call(:reset, _from, state), do: {:reply, {:error, :streams_active}, state}

  @impl true
  def handle_cast({:send_error, token}, state) do
    state =
      if Map.has_key?(state.connections, token), do: increment(state, :send_error), else: state

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, monitor) do
      {nil, _monitors} ->
        {:noreply, state}

      {token, monitors} ->
        {connection, connections} = Map.pop(state.connections, token)

        state =
          %{state | monitors: monitors, connections: connections}
          |> Map.update!(:tab_keys, &MapSet.delete(&1, connection.tab_key))
          |> increment(:owner_down)
          |> emit_cleanup(:owner_down)

        {:noreply, state}
    end
  end

  defp initial_state do
    %{
      connections: %{},
      monitors: %{},
      tab_keys: MapSet.new(),
      counters: Map.new(@counters, &{&1, 0}),
      total_events: 0,
      total_bytes: 0,
      max_observed_active: 0
    }
  end

  defp normalize_tab_id(tab_id) when is_binary(tab_id) do
    cond do
      tab_id == "" -> {:missing, {:sentinel, :missing}}
      Regex.match?(@tab_id_pattern, tab_id) -> {:present, {:tab, tab_id}}
      true -> {:invalid, {:sentinel, :invalid}}
    end
  end

  defp normalize_tab_id(_tab_id), do: {:missing, {:sentinel, :missing}}

  defp increment(state, counter) do
    update_in(state, [:counters, counter], &(&1 + 1))
  end

  defp release_counter(:completed), do: :released_completed
  defp release_counter(:cancelled), do: :released_cancelled

  defp emit_cleanup(state, outcome) do
    :telemetry.execute(
      [:jido_code, :qualification, :hypermedia_stream, :cleanup],
      %{active: map_size(state.connections)},
      %{outcome: outcome}
    )

    state
  end
end

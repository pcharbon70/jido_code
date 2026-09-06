defmodule JidoCode.Product.ReadRequestLimiter do
  @moduledoc "Bounded, disposable principal read admission; it stores no projection or grants."
  use GenServer

  @window_ms 60_000
  @per_principal 30
  @max_principals 256
  @max_concurrent 16

  def start_link(options),
    do: GenServer.start_link(__MODULE__, %{}, name: Keyword.get(options, :name, __MODULE__))

  def acquire(principal, server \\ __MODULE__) do
    GenServer.call(server, {:acquire, principal})
  catch
    :exit, _ -> {:error, :unavailable}
  end

  def release(lease, server \\ __MODULE__), do: GenServer.cast(server, {:release, lease})

  @impl true
  def init(_options), do: {:ok, %{windows: %{}, leases: %{}}}

  @impl true
  def handle_call({:acquire, principal}, {pid, _}, state)
      when is_binary(principal) and byte_size(principal) in 1..512 do
    now = System.monotonic_time(:millisecond)
    windows = Map.reject(state.windows, fn {_, {started, _}} -> now - started >= @window_ms end)
    {started, count} = Map.get(windows, principal, {now, 0})
    concurrent = Enum.count(state.leases, fn {_, owner} -> owner == principal end)

    if count >= @per_principal or concurrent >= 2 or map_size(state.leases) >= @max_concurrent or
         (not Map.has_key?(windows, principal) and map_size(windows) >= @max_principals) do
      {:reply, {:error, :rate_limited}, %{state | windows: windows}}
    else
      lease = Process.monitor(pid)

      next = %{
        windows: Map.put(windows, principal, {started, count + 1}),
        leases: Map.put(state.leases, lease, principal)
      }

      {:reply, {:ok, lease}, next}
    end
  end

  def handle_call({:acquire, _invalid}, _from, state),
    do: {:reply, {:error, :unavailable}, state}

  @impl true
  def handle_cast({:release, lease}, state) do
    Process.demonitor(lease, [:flush])
    {:noreply, %{state | leases: Map.delete(state.leases, lease)}}
  end

  @impl true
  def handle_info({:DOWN, lease, :process, _pid, _reason}, state),
    do: {:noreply, %{state | leases: Map.delete(state.leases, lease)}}
end

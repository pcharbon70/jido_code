defmodule JidoCode.Product.StreamCoordinator do
  @moduledoc "Application-owned, bounded, disposable page/tab transport admission."
  use GenServer

  @limits %{
    factory: 32,
    principal: 4,
    session: 2,
    tenant: 16,
    admissions: 16,
    window_ms: 60_000,
    rate_keys: 256,
    nonce_keys: 1_024,
    nonce_ms: 120_000
  }

  def limits, do: @limits

  def start_link(options),
    do: GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))

  def admit(context, server \\ __MODULE__), do: call(server, {:admit, context})
  def active(lease, server \\ __MODULE__), do: call(server, {:active, lease})
  def release_owner(server \\ __MODULE__), do: call(server, :release_owner)
  def stats(server \\ __MODULE__), do: call(server, :stats)

  defp call(server, message) do
    GenServer.call(server, message)
  catch
    :exit, _ -> {:error, :unavailable}
  end

  @impl true
  def init(_options), do: {:ok, %{leases: %{}, windows: %{}, nonces: %{}}}

  @impl true
  def handle_call({:admit, context}, {owner, _}, state) do
    now = System.monotonic_time(:millisecond)
    state = prune(state, now)
    key = {context.session, context.tab}
    nonce = {context.session, context.request}
    old = Enum.find(state.leases, fn {_, lease} -> lease.key == key end)
    current = if old, do: Map.delete(state.leases, elem(old, 0)), else: state.leases
    {started, count} = Map.get(state.windows, context.subject, {now, 0})

    cond do
      Map.has_key?(state.nonces, nonce) ->
        {:reply, {:error, :duplicate}, state}

      map_size(state.nonces) >= @limits.nonce_keys or
        (not Map.has_key?(state.windows, context.subject) and
           map_size(state.windows) >= @limits.rate_keys) or
        count >= @limits.admissions or capped?(current, context) ->
        {:reply, {:error, :rate_limited}, state}

      System.system_time(:millisecond) >= min(context.hard_expires_at, context.idle_expires_at) ->
        {:reply, {:error, :expired}, state}

      true ->
        state = if old, do: close(state, elem(old, 0), :takeover), else: state
        lease = Process.monitor(owner)
        entry = %{owner: owner, key: key, context: context, state: :admitted}

        state = %{
          state
          | leases: Map.put(state.leases, lease, entry),
            windows: Map.put(state.windows, context.subject, {started, count + 1}),
            nonces: Map.put(state.nonces, nonce, now)
        }

        emit(:admitted, context.projection)
        {:reply, {:ok, lease}, state}
    end
  end

  def handle_call({:active, lease}, {owner, _}, state) do
    reply =
      case state.leases[lease] do
        %{owner: ^owner} -> :ok
        _ -> {:error, :closed}
      end

    {:reply, reply, state}
  end

  def handle_call(:release_owner, {owner, _}, state) do
    state =
      Enum.reduce(state.leases, state, fn {lease, entry}, acc ->
        if entry.owner == owner, do: close(acc, lease, :closed), else: acc
      end)

    {:reply, :ok, state}
  end

  def handle_call(:stats, _from, state),
    do:
      {:reply,
       %{
         connections: map_size(state.leases),
         rate_keys: map_size(state.windows),
         nonce_keys: map_size(state.nonces)
       }, state}

  @impl true
  def handle_info({:DOWN, lease, :process, _pid, _reason}, state),
    do: {:noreply, close(state, lease, :disconnect)}

  defp capped?(leases, context) do
    map_size(leases) >= @limits.factory or
      Enum.any?([{:subject, :principal}, {:session, :session}, {:tenant, :tenant}], fn {field,
                                                                                        cap} ->
        Enum.count(leases, fn {_, entry} ->
          Map.fetch!(entry.context, field) == Map.fetch!(context, field)
        end) >= Map.fetch!(@limits, cap)
      end)
  end

  defp close(state, lease, reason) do
    case Map.pop(state.leases, lease) do
      {nil, _} ->
        state

      {entry, leases} ->
        Process.demonitor(lease, [:flush])
        send(entry.owner, {:product_stream, lease, {:closed, reason}})
        emit(reason, entry.context.projection)
        %{state | leases: leases}
    end
  end

  defp prune(state, now),
    do: %{
      state
      | windows:
          Map.reject(state.windows, fn {_, {started, _}} -> now - started >= @limits.window_ms end),
        nonces: Map.reject(state.nonces, fn {_, started} -> now - started >= @limits.nonce_ms end)
    }

  defp emit(reason, projection),
    do:
      :telemetry.execute([:jido_code, :product_stream, :lifecycle], %{count: 1}, %{
        reason: reason,
        projection: projection
      })
end

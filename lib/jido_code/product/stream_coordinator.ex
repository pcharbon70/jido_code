defmodule JidoCode.Product.StreamCoordinator do
  @moduledoc "One supervised owner of bounded page/tab lifecycle; no protected payload queue."
  use GenServer
  alias JidoCode.Product.StreamOwnerGuard
  alias JidoCode.Product.{StreamMetrics, StreamPressure}
  alias JidoCode.Identity.{RevocationEvent, Revocations}

  @states ~w[admitted connected idle retrying revoked expired closing closed]a
  @limits %{
    factory: 32,
    principal: 4,
    session: 2,
    tenant: 16,
    admissions: 16,
    window_ms: 60_000,
    rate_keys: 256,
    nonce_keys: 1_024,
    nonce_ms: 120_000,
    lifetime_ms: 60_000,
    idle_ms: 30_000,
    admitted_ms: 10_000,
    heartbeat_ms: 5_000,
    reauthorize_ms: 2_000,
    work_ms: 2_000,
    grace_ms: 250,
    tick_ms: 100,
    event_bytes: 131_072,
    total_bytes: 1_048_576,
    events: 120,
    terminal_bytes: 1_024,
    event_interval_ms: 100,
    queued_hints: 1,
    queued_payload_bytes: 0,
    retry_max: 2,
    retry_initial_ms: 1_000,
    retry_max_ms: 2_000
  }

  def limits, do: @limits
  def states, do: @states

  def start_link(options),
    do: GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))

  def admit(context, server \\ __MODULE__), do: call(server, {:admit, context})
  def active(lease, server \\ __MODULE__), do: call(server, {:active, lease})
  def connect(lease, server \\ __MODULE__), do: call(server, {:connect, lease})
  def reserve(lease, bytes, server \\ __MODULE__), do: call(server, {:reserve, lease, bytes})
  def sent(lease, server \\ __MODULE__), do: call(server, {:sent, lease})
  def checked(lease, server \\ __MODULE__), do: call(server, {:checked, lease})
  def release(lease, server \\ __MODULE__), do: call(server, {:release, lease})
  def release_owner(server \\ __MODULE__), do: call(server, :release_owner)

  def terminate_owner(lease, reason, server \\ __MODULE__)
      when reason in [:revoked, :expired, :unavailable],
      do: call(server, {:terminate, lease, reason})

  def drain(server \\ __MODULE__), do: call(server, :drain)
  def stats(server \\ __MODULE__), do: call(server, :stats)

  defp call(server, message) do
    GenServer.call(server, message)
  catch
    :exit, _ -> {:error, :unavailable}
  end

  @impl true
  def init(options) do
    :ok = Revocations.subscribe()

    limits =
      Enum.reduce(Keyword.get(options, :limits, %{}), @limits, fn {key, value}, acc ->
        if is_integer(value) and value > 0 and value <= Map.fetch!(@limits, key),
          do: Map.put(acc, key, value),
          else: raise(ArgumentError, "stream limits may only be reduced")
      end)

    Process.send_after(self(), :tick, limits.tick_ms)
    metrics = StreamMetrics.new()
    if Process.whereis(__MODULE__) == self(), do: StreamMetrics.attach(metrics)

    {:ok,
     %{
       leases: %{},
       windows: %{},
       nonces: %{},
       draining: false,
       limits: limits,
       metrics: metrics,
       pressure: StreamPressure.new(),
       next_sample: now() + 1_000,
       pressure_enabled:
         Keyword.get(options, :pressure_enabled, JidoCode.LocalDeployment.active?())
     }}
  end

  @impl true
  def handle_call({:admit, context}, {owner, _}, state) do
    now = now()
    state = prune(state, now)
    key = {context.session, context.tab}
    nonce = {context.session, context.request}

    old =
      Enum.find(state.leases, fn {_, entry} -> entry.key == key and entry.state != :closing end)

    {started, count} = Map.get(state.windows, context.subject, {now, 0})

    remaining =
      min(context.hard_expires_at, context.idle_expires_at) - System.system_time(:millisecond)

    cond do
      state.draining or state.pressure.mode == :degraded ->
        StreamMetrics.record(state.metrics, :rejected)
        {:reply, {:error, :unavailable}, state}

      Map.has_key?(state.nonces, nonce) ->
        StreamMetrics.record(state.metrics, :duplicate)
        {:reply, {:error, :duplicate}, state}

      map_size(state.nonces) >= state.limits.nonce_keys or
        (not Map.has_key?(state.windows, context.subject) and
           map_size(state.windows) >= state.limits.rate_keys) or
        count >= state.limits.admissions or capped?(state, context) ->
        StreamMetrics.record(state.metrics, :rejected)
        {:reply, {:error, :rate_limited}, state}

      remaining <= 0 ->
        {:reply, {:error, :expired}, state}

      true ->
        deadline = now + min(remaining, state.limits.lifetime_ms)
        idle = now + state.limits.idle_ms
        busy = now + state.limits.admitted_ms
        guard_deadline = Enum.min([deadline, idle, busy]) + state.limits.grace_ms

        case DynamicSupervisor.start_child(
               JidoCode.Product.StreamOwnerSupervisor,
               {StreamOwnerGuard,
                owner: owner,
                coordinator: self(),
                deadline: guard_deadline,
                projection: context.projection}
             ) do
          {:ok, guard} ->
            if Map.get(context, :minimum_revision, 0) > 0,
              do: StreamMetrics.record(state.metrics, :cursor_reconnect)

            state = if old, do: close(state, elem(old, 0), :takeover), else: state
            lease = Process.monitor(owner)

            entry = %{
              owner: owner,
              key: key,
              context: context,
              state: :admitted,
              guard: guard,
              guard_monitor: Process.monitor(guard),
              deadline: deadline,
              idle_at: idle,
              busy_until: busy,
              next_check: now,
              next_heartbeat: now,
              check_pending: false,
              hint_pending: false,
              events: 0,
              bytes: 0,
              last_event: nil
            }

            state = %{
              state
              | leases: Map.put(state.leases, lease, entry),
                windows: Map.put(state.windows, context.subject, {started, count + 1}),
                nonces: Map.put(state.nonces, nonce, now)
            }

            emit(:admitted, entry)
            {:reply, {:ok, lease}, state}

          _ ->
            {:reply, {:error, :unavailable}, state}
        end
    end
  end

  def handle_call({:release, lease}, {owner, _}, state) do
    case state.leases[lease] do
      %{owner: ^owner} -> {:reply, :ok, remove(state, lease, :closed)}
      _ -> {:reply, {:error, :closed}, state}
    end
  end

  def handle_call(:release_owner, {owner, _}, state) do
    state =
      Enum.reduce(state.leases, state, fn {lease, entry}, acc ->
        if entry.owner == owner, do: remove(acc, lease, :closed), else: acc
      end)

    {:reply, :ok, state}
  end

  def handle_call(:drain, _from, state) do
    state =
      Enum.reduce(state.leases, state, fn {lease, _}, acc -> close(acc, lease, :deploy_drain) end)

    {:reply, :ok, %{state | draining: true}}
  end

  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       connections: map_size(state.leases),
       closing: Enum.count(state.leases, fn {_, e} -> e.state == :closing end),
       pending_hints: Enum.count(state.leases, fn {_, e} -> e.check_pending end),
       queued_payload_bytes: 0,
       rate_keys: map_size(state.windows),
       nonce_keys: map_size(state.nonces),
       draining: state.draining,
       pressure: state.pressure.mode,
       metrics: StreamMetrics.snapshot(state.metrics)
     }, state}
  end

  def handle_call(message, {owner, _}, state)
      when is_tuple(message) and tuple_size(message) >= 2 do
    lease = elem(message, 1)

    case state.leases[lease] do
      %{owner: ^owner, state: phase} = entry when phase != :closing ->
        case expiry(entry, now()) do
          nil -> operate(message, lease, entry, state)
          reason -> {:reply, {:error, reason}, close(state, lease, reason)}
        end

      _ ->
        {:reply, {:error, :closed}, state}
    end
  end

  defp operate({:active, _}, _, _, state), do: {:reply, :ok, state}

  defp operate({:connect, _}, lease, %{state: :admitted} = entry, state) do
    entry = %{
      entry
      | state: :connected,
        busy_until: now() + state.limits.work_ms,
        next_check: now() + state.limits.reauthorize_ms,
        next_heartbeat: now() + state.limits.heartbeat_ms
    }

    {:reply,
     {:ok,
      %{coordinator: self(), deadline: min(entry.deadline, entry.idle_at), limits: state.limits}},
     put_entry(state, lease, entry)}
  end

  defp operate({:reserve, _, bytes}, lease, %{state: phase} = entry, state)
       when phase in [:connected, :idle] and is_integer(bytes) and bytes > 0 do
    reason =
      cond do
        bytes > state.limits.event_bytes ->
          :event_overflow

        entry.bytes + bytes > state.limits.total_bytes - state.limits.terminal_bytes or
            entry.events >= state.limits.events - 1 ->
          :stream_overflow

        entry.last_event != nil and now() - entry.last_event < state.limits.event_interval_ms ->
          :event_rate

        true ->
          nil
      end

    if reason do
      {:reply, {:error, reason}, close(state, lease, reason)}
    else
      StreamMetrics.record(state.metrics, :frames_reserved)
      StreamMetrics.record(state.metrics, :reserved_bytes, bytes)

      entry = %{
        entry
        | state: :connected,
          bytes: entry.bytes + bytes,
          events: entry.events + 1,
          last_event: now(),
          busy_until: now() + state.limits.work_ms
      }

      {:reply, :ok, put_entry(state, lease, entry)}
    end
  end

  defp operate({:sent, _}, lease, %{state: :connected} = entry, state) do
    entry = %{
      entry
      | state: :idle,
        busy_until: nil,
        next_heartbeat: now() + state.limits.heartbeat_ms
    }

    {:reply, :ok, put_entry(state, lease, entry)}
  end

  defp operate({:checked, _}, lease, %{check_pending: true} = entry, state) do
    entry = %{
      entry
      | check_pending: false,
        busy_until: nil,
        next_check: if(entry.hint_pending, do: now(), else: now() + state.limits.reauthorize_ms),
        hint_pending: false
    }

    {:reply, :ok, put_entry(state, lease, entry)}
  end

  defp operate({:terminate, _, reason}, lease, _, state),
    do: {:reply, :ok, close(state, lease, reason)}

  defp operate(_, lease, _, state),
    do: {:reply, {:error, :invalid_transition}, close(state, lease, :invalid_transition)}

  @impl true
  def handle_info({:identity_revoked, %RevocationEvent{dimension: dimension}}, state)
      when dimension in [
             :account,
             :session,
             :role,
             :delegation,
             :project,
             :tenant,
             :graph,
             :incident
           ] do
    # Generations in AuthorityBuilder are global invalidation fences. Fanout is
    # conservatively bounded by the factory cap; an event is never a grant.
    state =
      Enum.reduce(state.leases, state, fn {lease, entry}, acc ->
        if entry.state == :closing do
          acc
        else
          entry = %{entry | hint_pending: true, next_check: now()}
          request_check(%{acc | leases: Map.put(acc.leases, lease, entry)}, lease, now())
        end
      end)

    {:noreply, state}
  end

  def handle_info(:tick, state) do
    now = now()
    state = sample_pressure(state, now)

    state =
      Enum.reduce(state.leases, prune(state, now), fn {lease, entry}, acc ->
        cond do
          entry.state == :closing ->
            acc

          reason = expiry(entry, now) ->
            close(acc, lease, reason)

          entry.state != :admitted and entry.busy_until == nil and not entry.check_pending and
              (now >= entry.next_check or now >= entry.next_heartbeat) ->
            request_check(acc, lease, now)

          true ->
            acc
        end
      end)

    Process.send_after(self(), :tick, state.limits.tick_ms)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case state.leases[ref] do
      nil ->
        case Enum.find(state.leases, fn {_, e} -> e.guard_monitor == ref end) do
          {lease, entry} ->
            if reason in [{:shutdown, :owner_down}, {:shutdown, :deadline_enforced}] and
                 not Process.alive?(entry.owner) do
              {:noreply, remove(state, lease, :disconnect)}
            else
              Process.exit(entry.owner, :kill)
              {:noreply, remove(state, lease, :guard_failure)}
            end

          nil ->
            {:noreply, state}
        end

      _ ->
        {:noreply, remove(state, ref, :disconnect)}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp request_check(state, lease, now) do
    entry = Map.fetch!(state.leases, lease)

    if entry.check_pending or entry.busy_until != nil or entry.state in [:admitted, :closing] do
      state
    else
      send(entry.owner, {:product_stream, lease, {:check, now >= entry.next_heartbeat}})

      put_entry(state, lease, %{
        entry
        | check_pending: true,
          busy_until: now + state.limits.work_ms
      })
    end
  end

  defp put_entry(state, lease, entry) do
    deadlines =
      [entry.deadline, entry.idle_at] ++ if(entry.busy_until, do: [entry.busy_until], else: [])

    deadline = Enum.min(deadlines)

    kind =
      cond do
        deadline == entry.deadline -> :lifetime
        deadline == entry.idle_at -> :idle
        true -> :work
      end

    send(entry.guard, {:deadline, self(), deadline + state.limits.grace_ms, kind})
    %{state | leases: Map.put(state.leases, lease, entry)}
  end

  defp expiry(entry, now) do
    cond do
      now >= entry.deadline or
          System.system_time(:millisecond) >=
            min(entry.context.hard_expires_at, entry.context.idle_expires_at) ->
        :expired

      now >= entry.idle_at ->
        :idle_timeout

      entry.busy_until != nil and now >= entry.busy_until ->
        :slow_owner

      true ->
        nil
    end
  end

  defp capped?(state, context) do
    map_size(state.leases) >= state.limits.factory or
      Enum.any?([{:subject, :principal}, {:session, :session}, {:tenant, :tenant}], fn {field,
                                                                                        cap} ->
        Enum.count(state.leases, fn {_, entry} ->
          Map.fetch!(entry.context, field) == Map.fetch!(context, field)
        end) >= Map.fetch!(state.limits, cap)
      end)
  end

  defp close(state, lease, reason) do
    case state.leases[lease] do
      nil ->
        state

      %{state: :closing} ->
        state

      entry ->
        send(entry.owner, {:product_stream, lease, {:closed, reason}})
        send(entry.guard, {:deadline, self(), now() + state.limits.grace_ms, :terminal})
        emit(reason, entry)

        %{
          state
          | leases: Map.put(state.leases, lease, %{entry | state: :closing, check_pending: false})
        }
    end
  end

  defp remove(state, lease, reason) do
    case Map.pop(state.leases, lease) do
      {nil, _} ->
        state

      {entry, leases} ->
        Process.demonitor(lease, [:flush])
        Process.demonitor(entry.guard_monitor, [:flush])
        send(entry.guard, {:retire, self()})
        emit(reason, entry)
        %{state | leases: leases}
    end
  end

  defp prune(state, now),
    do: %{
      state
      | windows:
          Map.reject(state.windows, fn {_, {started, _}} ->
            now - started >= state.limits.window_ms
          end),
        nonces:
          Map.reject(state.nonces, fn {_, started} -> now - started >= state.limits.nonce_ms end)
    }

  defp now, do: System.monotonic_time(:millisecond)

  defp sample_pressure(%{pressure_enabled: false} = state, _now), do: state
  defp sample_pressure(state, now) when now < state.next_sample, do: state

  defp sample_pressure(state, now) do
    pressure = StreamPressure.observe(state.pressure, StreamPressure.sample())
    changed? = pressure.mode != state.pressure.mode
    state = %{state | pressure: pressure, next_sample: now + 1_000}

    if changed? do
      StreamMetrics.record(
        state.metrics,
        if(pressure.mode == :degraded, do: :pressure_enter, else: :pressure_exit)
      )

      if pressure.mode == :degraded,
        do: Enum.reduce(Map.keys(state.leases), state, &close(&2, &1, :overload)),
        else: state
    else
      state
    end
  end

  defp emit(reason, entry),
    do:
      :telemetry.execute([:jido_code, :product_stream, :lifecycle], %{count: 1}, %{
        reason: reason,
        projection: entry.context.projection
      })
end

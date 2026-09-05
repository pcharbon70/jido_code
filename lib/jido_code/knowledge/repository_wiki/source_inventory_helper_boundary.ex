defmodule JidoCode.Knowledge.RepositoryWiki.SourceInventoryHelperBoundary do
  @moduledoc false

  @required_options ~w[slot_scope concurrency receiver_timeout_ms helper_wall_ms heap_words]a

  @spec run(
          (-> term()),
          integer(),
          atom(),
          atom(),
          %{
            slot_scope: term(),
            concurrency: pos_integer(),
            receiver_timeout_ms: pos_integer(),
            helper_wall_ms: pos_integer(),
            heap_words: pos_integer()
          }
        ) :: term() | {:error, atom()}
  def run(operation, deadline, limit_error, timeout_error, options)
      when is_function(operation, 0) and is_integer(deadline) and is_atom(limit_error) and
             is_atom(timeout_error) and is_map(options) do
    if valid_options?(options) and remaining_milliseconds(deadline) >= options.receiver_timeout_ms do
      coordinate(operation, deadline, limit_error, timeout_error, options)
    else
      {:error, timeout_error}
    end
  end

  def run(_operation, _deadline, _limit_error, timeout_error, _options)
      when is_atom(timeout_error),
      do: {:error, timeout_error}

  defp coordinate(operation, deadline, limit_error, timeout_error, options) do
    caller = self()
    token = make_ref()

    {coordinator, monitor} =
      spawn_monitor(fn ->
        caller_monitor = Process.monitor(caller)

        result =
          case acquire_slot(
                 deadline - options.receiver_timeout_ms,
                 caller_monitor,
                 options
               ) do
            {:ok, lock} ->
              try do
                cond do
                  caller_down?(caller_monitor) ->
                    :caller_down

                  remaining_milliseconds(deadline) < options.receiver_timeout_ms ->
                    {:error, timeout_error}

                  true ->
                    run_worker(
                      operation,
                      deadline,
                      limit_error,
                      timeout_error,
                      caller_monitor,
                      options
                    )
                end
              after
                :global.del_lock(lock, [node()])
              end

            {:error, :caller_down} ->
              :caller_down

            {:error, :slot_timeout} ->
              {:error, timeout_error}
          end

        Process.demonitor(caller_monitor, [:flush])

        if result != :caller_down and Process.alive?(caller) and before_deadline?(deadline) do
          send(caller, {token, result})
        end
      end)

    timeout = remaining_milliseconds(deadline)

    if timeout > 0 do
      receive do
        {^token, result} ->
          Process.demonitor(monitor, [:flush])
          result

        {:DOWN, ^monitor, :process, ^coordinator, _reason} ->
          {:error, limit_error}
      after
        timeout ->
          Process.demonitor(monitor, [:flush])
          {:error, timeout_error}
      end
    else
      Process.demonitor(monitor, [:flush])
      {:error, timeout_error}
    end
  end

  defp acquire_slot(deadline, caller_monitor, options) do
    if before_deadline?(deadline) do
      lock =
        Enum.find_value(1..options.concurrency, fn slot ->
          identifier = {{options.slot_scope, :inventory_helper, slot}, self()}

          if :global.set_lock(identifier, [node()], 0), do: identifier
        end)

      if lock do
        {:ok, lock}
      else
        receive do
          {:DOWN, ^caller_monitor, :process, _caller, _reason} ->
            {:error, :caller_down}
        after
          min(10, remaining_milliseconds(deadline)) ->
            acquire_slot(deadline, caller_monitor, options)
        end
      end
    else
      {:error, :slot_timeout}
    end
  end

  defp run_worker(operation, scan_deadline, limit_error, timeout_error, caller_monitor, options) do
    coordinator = self()
    token = make_ref()
    started_at = System.monotonic_time(:millisecond)

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          result = operation.()
          send(coordinator, {token, result})
        end,
        [
          :monitor,
          {:max_heap_size,
           %{
             size: options.heap_words,
             kill: true,
             error_logger: false,
             include_shared_binaries: true
           }}
        ]
      )

    helper_deadline = min(scan_deadline, started_at + options.receiver_timeout_ms)

    await_worker(
      pid,
      monitor,
      token,
      helper_deadline,
      limit_error,
      timeout_error,
      caller_monitor,
      options
    )
  end

  defp await_worker(
         pid,
         monitor,
         token,
         helper_deadline,
         limit_error,
         timeout_error,
         caller_monitor,
         options
       ) do
    timeout = remaining_milliseconds(helper_deadline)

    if timeout > 0 do
      receive do
        {^token, result} ->
          Process.demonitor(monitor, [:flush])
          result

        {:DOWN, ^monitor, :process, ^pid, _reason} ->
          hold_failed_slot(options)
          {:error, limit_error}

        {:DOWN, ^caller_monitor, :process, _caller, _reason} ->
          await_worker(
            pid,
            monitor,
            token,
            helper_deadline,
            limit_error,
            timeout_error,
            caller_monitor,
            options
          )
      after
        timeout ->
          stop_worker(pid, monitor)
          hold_failed_slot(options)
          {:error, timeout_error}
      end
    else
      stop_worker(pid, monitor)
      hold_failed_slot(options)
      {:error, timeout_error}
    end
  end

  defp stop_worker(pid, monitor) do
    if Process.alive?(pid), do: Process.exit(pid, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
    after
      100 -> Process.demonitor(monitor, [:flush])
    end
  end

  # A fresh receiver window begins only after abnormal worker termination is
  # observed. It is required to exceed the outer helper wall, so no external
  # child can be launched after observation and still outlive the permit.
  defp hold_failed_slot(options) do
    receive do
    after
      options.receiver_timeout_ms -> :ok
    end
  end

  defp caller_down?(caller_monitor) do
    receive do
      {:DOWN, ^caller_monitor, :process, _caller, _reason} -> true
    after
      0 -> false
    end
  end

  defp valid_options?(options) do
    Map.keys(options) |> Enum.sort() == Enum.sort(@required_options) and
      is_integer(options.concurrency) and options.concurrency in 1..64 and
      is_integer(options.receiver_timeout_ms) and options.receiver_timeout_ms > 0 and
      is_integer(options.helper_wall_ms) and options.helper_wall_ms > 0 and
      options.receiver_timeout_ms > options.helper_wall_ms and is_integer(options.heap_words) and
      options.heap_words > 0
  rescue
    _error -> false
  end

  defp remaining_milliseconds(deadline) do
    max(deadline - System.monotonic_time(:millisecond), 0)
  end

  defp before_deadline?(deadline), do: remaining_milliseconds(deadline) > 0
end

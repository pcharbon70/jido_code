defmodule JidoCode.Product.StreamOwnerGuard do
  @moduledoc "Independent deadline and coordinator-death watchdog for one bounded HTTP owner."
  use GenServer, restart: :temporary

  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    owner = Keyword.fetch!(options, :owner)
    coordinator = Keyword.fetch!(options, :coordinator)

    state = %{
      owner: owner,
      coordinator: coordinator,
      owner_monitor: Process.monitor(owner),
      coordinator_monitor: Process.monitor(coordinator),
      deadline: Keyword.fetch!(options, :deadline),
      deadline_kind: :admission,
      projection: Keyword.get(options, :projection, :factory),
      timer: nil
    }

    {:ok, schedule(state)}
  end

  @impl true
  def handle_info({:deadline, coordinator, deadline}, %{coordinator: coordinator} = state),
    do: {:noreply, schedule(%{state | deadline: deadline})}

  def handle_info({:deadline, coordinator, deadline, kind}, %{coordinator: coordinator} = state)
      when kind in [:work, :lifetime, :idle, :terminal] do
    {:noreply, schedule(%{state | deadline: deadline, deadline_kind: kind})}
  end

  def handle_info({:retire, coordinator}, %{coordinator: coordinator} = state),
    do: {:stop, :normal, state}

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_monitor: ref} = state),
    do: {:stop, {:shutdown, :owner_down}, state}

  def handle_info({:DOWN, ref, :process, _, _}, %{coordinator_monitor: ref} = state) do
    Process.exit(state.owner, :kill)
    {:stop, :normal, state}
  end

  def handle_info(:check_deadline, state) do
    if System.monotonic_time(:millisecond) >= state.deadline do
      :telemetry.execute([:jido_code, :product_stream, :guard_deadline], %{count: 1}, %{
        kind: state.deadline_kind
      })

      reason =
        if state.deadline_kind == :terminal, do: :forced_terminal_cleanup, else: :guard_failure

      :telemetry.execute([:jido_code, :product_stream, :lifecycle], %{count: 1}, %{
        reason: reason,
        projection: state.projection
      })

      Process.exit(state.owner, :kill)
      {:stop, {:shutdown, :deadline_enforced}, state}
    else
      {:noreply, schedule(state)}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp schedule(state) do
    if state.timer, do: Process.cancel_timer(state.timer)

    timer =
      Process.send_after(
        self(),
        :check_deadline,
        max(state.deadline - System.monotonic_time(:millisecond), 0)
      )

    %{state | timer: timer}
  end
end

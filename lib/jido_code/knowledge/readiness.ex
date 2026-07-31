defmodule JidoCode.Knowledge.Readiness do
  @moduledoc """
  Independently supervised readiness state for the knowledge substrate.

  The process stays queryable when the store is unavailable and monitors the
  exclusive store owner so durable operations fail closed after owner death.
  """

  use GenServer

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health

  @type server :: GenServer.server()

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec snapshot(server()) :: Health.t()
  def snapshot(server \\ __MODULE__) do
    call(server, :snapshot, Health.fail(Health.new(), Error.new(:unavailable, :health_check)))
  end

  @spec gate(server(), atom()) :: :ok | {:error, Error.t()}
  def gate(server \\ __MODULE__, operation) when is_atom(operation) do
    server
    |> snapshot()
    |> Health.gate(operation)
  end

  @doc false
  def monitor_store(server, pid) when is_pid(pid) do
    call(server, {:monitor_store, pid}, {:error, Error.new(:unavailable, :monitor_store)})
  end

  @doc false
  def transition(server, event) do
    call(server, {:transition, event}, {:error, Error.new(:unavailable, :health_transition)})
  end

  @impl true
  def init(options) do
    health = Keyword.get(options, :health, Health.new())
    {:ok, %{health: health, store_pid: nil, store_monitor: nil}}
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, state.health, state}

  def handle_call({:monitor_store, pid}, _from, state) do
    demonitor(state.store_monitor)
    monitor = Process.monitor(pid)
    {:reply, :ok, %{state | store_pid: pid, store_monitor: monitor}}
  end

  def handle_call({:transition, event}, _from, state) do
    case apply_transition(state.health, event) do
      {:ok, health} -> {:reply, {:ok, health}, %{state | health: health}}
      {:error, %Error{} = error} -> {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, %{store_monitor: monitor} = state) do
    error = Error.new(:unavailable, :store_owner_down)
    health = Health.fail(state.health, error)
    {:noreply, %{state | health: health, store_pid: nil, store_monitor: nil}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp apply_transition(health, :opening), do: Health.opening(health)
  defp apply_transition(health, :begin_verification), do: Health.begin_verification(health)
  defp apply_transition(health, :store_verified), do: Health.store_verified(health)
  defp apply_transition(health, :ready), do: Health.ontology_verified(health)

  defp apply_transition(health, {:enter_maintenance, reason}) do
    Health.enter_maintenance(health, reason)
  end

  defp apply_transition(health, :begin_backup), do: Health.begin_backup(health)
  defp apply_transition(health, :finish_backup), do: Health.finish_backup(health)
  defp apply_transition(health, :begin_recovery), do: Health.begin_recovery(health)
  defp apply_transition(health, :finish_recovery), do: Health.finish_recovery(health)
  defp apply_transition(health, :leave_maintenance), do: Health.leave_maintenance(health)
  defp apply_transition(health, {:fail, %Error{} = error}), do: {:ok, Health.fail(health, error)}

  defp apply_transition(_health, _event),
    do: {:error, Error.new(:invalid_input, :health_transition)}

  defp call(server, request, fallback) do
    GenServer.call(server, request)
  catch
    :exit, _reason -> fallback
  end

  defp demonitor(nil), do: :ok
  defp demonitor(reference), do: Process.demonitor(reference, [:flush])
end

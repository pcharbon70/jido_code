defmodule JidoCode.Factory.ManagedCoding.Service do
  @moduledoc "Factory-owned ledger-first admission and managed attempt coordination entry point."

  use GenServer

  @behaviour JidoCode.Factory.Ports.ManagedCoding

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.Outcome
  alias JidoCode.Factory.ManagedCoding.ResolvedAdmission

  @operations ~w[admit start steer cancel status await handoff]a

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    server_options = if options[:name], do: [name: options[:name]], else: []
    GenServer.start_link(__MODULE__, options, server_options)
  end

  for operation <- @operations do
    @impl true
    def unquote(operation)(%Command{operation: unquote(operation)} = command, options) do
      GenServer.call(
        Keyword.get(options, :server, __MODULE__),
        {unquote(operation), command, options}
      )
    catch
      :exit, _reason -> {:error, AdapterError.new(:unavailable, unquote(operation))}
    end
  end

  @impl true
  def init(options) do
    with {ledger_module, ledger} when is_atom(ledger_module) <- options[:ledger],
         {runtime_module, runtime} when is_atom(runtime_module) <- options[:runtime],
         capacity when is_function(capacity, 0) <- options[:capacity],
         maximum when is_integer(maximum) and maximum > 0 <- options[:max_active],
         true <- ledger?(ledger_module),
         true <- runtime?(runtime_module) do
      {:ok,
       %{
         ledger: {ledger_module, ledger},
         runtime: {runtime_module, runtime},
         capacity: capacity,
         max_active: maximum,
         monitors: %{}
       }}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :managed_coding_service)}
    end
  end

  @impl true
  def handle_call({:admit, command, _options}, _from, state) do
    {ledger_module, ledger} = state.ledger

    result =
      with :ok <- capacity(state),
           {:ok, %ResolvedAdmission{} = resolved} <- ledger_module.resolve(ledger, command),
           :ok <- command_matches?(command, resolved),
           {:ok, receipt} <- ledger_module.commit(ledger, command, resolved),
           true <- receipt[:outcome] in [:committed, :idempotent] do
        outcome(resolved, :admitted, 0, [resolved.admission_evidence_iri])
      else
        {:error, %AdapterError{} = error} -> {:error, error}
        _invalid -> {:error, AdapterError.new(:conflict, :managed_coding_admission)}
      end

    {:reply, result, state}
  rescue
    _error -> {:reply, {:error, AdapterError.new(:unavailable, :managed_coding_admission)}, state}
  end

  def handle_call({:start, command, options}, _from, state) do
    {ledger_module, ledger} = state.ledger
    {runtime_module, runtime} = state.runtime
    runtime_options = Keyword.delete(options, :server)

    with {:ok, admission} <-
           ledger_module.fetch(ledger, command.attempt_iri, command.fencing_token),
         %ResolvedAdmission{} = resolved <- admission[:resolved],
         {:ok, runtime_receipt} <- runtime_module.start(runtime, resolved, runtime_options),
         :ok <- ledger_module.runtime_started(ledger, admission, runtime_receipt),
         {:ok, result} <- outcome(resolved, :preparing, 1, references(runtime_receipt)) do
      {:reply, {:ok, result}, monitor_runtime(state, command.attempt_iri, runtime_receipt)}
    else
      {:error, %AdapterError{} = error} ->
        reconcile_start_failure(ledger_module, ledger, command, error)
        {:reply, {:error, error}, state}

      _invalid ->
        error = AdapterError.new(:corrupt, :managed_coding_runtime_start)
        reconcile_start_failure(ledger_module, ledger, command, error)
        {:reply, {:error, error}, state}
    end
  rescue
    _error ->
      {ledger_module, ledger} = state.ledger
      error = AdapterError.new(:unavailable, :managed_coding_runtime_start)
      reconcile_start_failure(ledger_module, ledger, command, error)
      {:reply, {:error, error}, state}
  end

  def handle_call({:await, command, options}, _from, state) do
    {runtime_module, runtime} = state.runtime
    timeout = Keyword.get(options, :timeout, 30_000)
    {:reply, runtime_result(runtime_module.await(runtime, command, timeout), command), state}
  end

  def handle_call({operation, command, options}, _from, state)
      when operation in [:steer, :cancel, :status, :handoff] do
    {runtime_module, runtime} = state.runtime
    {:reply, runtime_result(runtime_module.command(runtime, command, options), command), state}
  end

  @impl true
  def handle_info({:DOWN, reference, :process, _pid, reason}, state) do
    case Map.pop(state.monitors, reference) do
      {nil, _monitors} ->
        {:noreply, state}

      {_attempt, monitors} ->
        {:noreply, %{state | monitors: monitors, last_runtime_exit: classify_exit(reason)}}
    end
  end

  defp capacity(state) do
    case state.capacity.() do
      count when is_integer(count) and count >= 0 and count < state.max_active ->
        :ok

      count when is_integer(count) and count >= state.max_active ->
        {:error, AdapterError.new(:unavailable, :managed_coding_capacity)}

      _invalid ->
        {:error, AdapterError.new(:unavailable, :managed_coding_capacity)}
    end
  end

  defp command_matches?(command, resolved) do
    if command.repository_iri == resolved.repository_iri and command.task_iri == resolved.task_iri and
         command.actor_iri == resolved.actor_iri and command.profile_iri == resolved.profile.iri and
         command.capability_iri == resolved.capability_iri,
       do: :ok,
       else: {:error, AdapterError.new(:unauthorized, :managed_coding_admission_binding)}
  end

  defp runtime_result({:ok, attributes}, command) when is_map(attributes) do
    Outcome.new(%{
      attempt_iri: command.attempt_iri,
      fencing_token: command.fencing_token,
      state: attributes[:state],
      sequence: attributes[:sequence],
      occurred_at: attributes[:occurred_at] || DateTime.utc_now(),
      references: references(attributes),
      classification: attributes[:classification]
    })
  end

  defp runtime_result({:error, %AdapterError{} = error}, _command), do: {:error, error}

  defp runtime_result(_invalid, _command),
    do: {:error, AdapterError.new(:corrupt, :managed_coding_runtime)}

  defp outcome(resolved, state, sequence, references) do
    Outcome.new(%{
      attempt_iri: resolved.attempt_iri,
      fencing_token: resolved.fencing_token,
      state: state,
      sequence: sequence,
      occurred_at: DateTime.utc_now(),
      references: references,
      classification: :pending
    })
  end

  defp monitor_runtime(state, attempt, %{pid: pid}) when is_pid(pid) do
    reference = Process.monitor(pid)
    %{state | monitors: Map.put(state.monitors, reference, attempt)}
  end

  defp monitor_runtime(state, _attempt, _receipt), do: state

  defp reconcile_start_failure(module, ledger, command, error) do
    case module.fetch(ledger, command.attempt_iri, command.fencing_token) do
      {:ok, admission} -> module.start_failed(ledger, admission, error)
      _unavailable -> :ok
    end
  rescue
    _error -> :ok
  end

  defp references(map), do: map |> Map.get(:references, []) |> Enum.uniq() |> Enum.sort()
  defp classify_exit(:normal), do: :normal
  defp classify_exit(:shutdown), do: :shutdown
  defp classify_exit(_reason), do: :crashed

  defp ledger?(module),
    do:
      Code.ensure_loaded?(module) and
        Enum.all?(
          [resolve: 2, commit: 3, fetch: 3, runtime_started: 3, start_failed: 3],
          fn {name, arity} -> function_exported?(module, name, arity) end
        )

  defp runtime?(module),
    do:
      Code.ensure_loaded?(module) and
        Enum.all?(
          [start: 3, command: 3, await: 3],
          fn {name, arity} -> function_exported?(module, name, arity) end
        )
end

defmodule JidoCode.Runtime.ManagedCoding.Dispatcher do
  @moduledoc "Bounded supervised directive dispatcher with exact result correlation."

  use GenServer

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.TrustBoundary
  alias JidoCode.Runtime.ManagedCoding.Directive.Actor
  alias JidoCode.Runtime.ManagedCoding.Directive.Candidate
  alias JidoCode.Runtime.ManagedCoding.Directive.Context
  alias JidoCode.Runtime.ManagedCoding.Directive.Continuation
  alias JidoCode.Runtime.ManagedCoding.Directive.Model
  alias JidoCode.Runtime.ManagedCoding.Directive.Observation
  alias JidoCode.Runtime.ManagedCoding.Directive.Tool

  @kinds ~w[context model tool actor candidate observation continuation]a
  @result_types %{
    context: "jido_code.managed_coding.context_result",
    model: "jido_code.managed_coding.model_result",
    tool: "jido_code.managed_coding.tool_result",
    actor: "jido_code.managed_coding.actor_response",
    candidate: "jido_code.managed_coding.candidate_result",
    observation: "jido_code.managed_coding.observation_result",
    continuation: "jido_code.managed_coding.continuation_result"
  }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    server_options =
      case Keyword.get(options, :name) do
        nil -> []
        name -> [name: name]
      end

    GenServer.start_link(__MODULE__, options, server_options)
  end

  @spec dispatch(GenServer.server(), struct(), pid()) :: :ok | {:error, AdapterError.t()}
  def dispatch(server, directive, target) when is_pid(target),
    do: GenServer.call(server, {:dispatch, directive, target})

  def dispatch(_server, _directive, _target), do: invalid(:managed_coding_dispatch)

  @spec cancel(GenServer.server(), String.t(), pos_integer()) :: :ok
  def cancel(server, attempt_iri, fencing_token),
    do: GenServer.call(server, {:cancel, attempt_iri, fencing_token})

  @spec status(GenServer.server()) :: map()
  def status(server), do: GenServer.call(server, :status)

  @impl true
  def init(options) do
    handlers = Keyword.get(options, :handlers)
    current_provider = Keyword.get(options, :current_provider)
    delivery = Keyword.get(options, :delivery)
    maximum = Keyword.get(options, :max_concurrency, 8)
    per_attempt = Keyword.get(options, :max_per_attempt, 1)
    max_queue = Keyword.get(options, :max_queue, 64)

    with :ok <- handlers(handlers),
         true <- is_function(current_provider, 1),
         true <- is_function(delivery, 2),
         true <- is_integer(maximum) and maximum in 1..64,
         true <- is_integer(per_attempt) and per_attempt in 1..maximum,
         true <- is_integer(max_queue) and max_queue in 1..1_024,
         {:ok, supervisor} <- Task.Supervisor.start_link() do
      {:ok,
       %{
         handlers: handlers,
         current_provider: current_provider,
         delivery: delivery,
         max_concurrency: maximum,
         max_per_attempt: per_attempt,
         max_queue: max_queue,
         task_supervisor: supervisor,
         queue: :queue.new(),
         queued: 0,
         active: %{},
         active_by_attempt: %{}
       }}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :managed_coding_dispatcher)}
    end
  end

  @impl true
  def handle_call({:dispatch, directive, target}, _from, state) do
    with {:ok, envelope} <- envelope(directive),
         :ok <- current?(state, envelope, target),
         :ok <- deadline_current?(envelope) do
      item = %{directive: directive, envelope: envelope, target: target}

      cond do
        available?(state, envelope.attempt_iri) ->
          {:reply, :ok, start_item(state, item)}

        state.queued < state.max_queue ->
          {:reply, :ok, %{state | queue: :queue.in(item, state.queue), queued: state.queued + 1}}

        true ->
          {:reply, {:error, AdapterError.new(:unavailable, :managed_coding_backpressure)}, state}
      end
    else
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, invalid(:managed_coding_dispatch), state}
    end
  end

  def handle_call({:cancel, attempt, fence}, _from, state) do
    {cancelled, queue} = remove_queued(state.queue, attempt, fence)
    Enum.each(cancelled, &deliver_failure(state, &1, :cancelled))

    state = %{state | queue: queue, queued: state.queued - length(cancelled)}

    state =
      state.active
      |> Enum.filter(fn {_ref, job} ->
        job.envelope.attempt_iri == attempt and job.envelope.fencing_token == fence
      end)
      |> Enum.reduce(state, fn {ref, job}, current ->
        Process.cancel_timer(job.timer)
        Task.Supervisor.terminate_child(current.task_supervisor, job.task.pid)
        deliver_failure(current, job, :cancelled)
        drop_active(current, ref, job)
      end)

    {:reply, :ok, pump(state)}
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       active: map_size(state.active),
       queued: state.queued,
       active_by_attempt: state.active_by_attempt
     }, state}
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    case Map.fetch(state.active, ref) do
      {:ok, job} ->
        Process.demonitor(ref, [:flush])
        Process.cancel_timer(job.timer)
        deliver_result(state, job, normalize_result(job.envelope.kind, result))
        {:noreply, state |> drop_active(ref, job) |> pump()}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.fetch(state.active, ref) do
      {:ok, job} ->
        Process.cancel_timer(job.timer)
        deliver_failure(state, job, :crash)
        {:noreply, state |> drop_active(ref, job) |> pump()}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:directive_timeout, ref}, state) do
    case Map.fetch(state.active, ref) do
      {:ok, job} ->
        Task.Supervisor.terminate_child(state.task_supervisor, job.task.pid)
        deliver_failure(state, job, :timeout)
        {:noreply, state |> drop_active(ref, job) |> pump()}

      :error ->
        {:noreply, state}
    end
  end

  defp start_item(state, item) do
    {module, adapter_state} = Map.fetch!(state.handlers, item.envelope.kind)

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        module.execute(adapter_state, item.envelope, [])
      end)

    timeout = max(DateTime.diff(item.envelope.deadline, DateTime.utc_now(), :millisecond), 1)
    timer = Process.send_after(self(), {:directive_timeout, task.ref}, timeout)
    job = Map.merge(item, %{task: task, timer: timer})

    %{
      state
      | active: Map.put(state.active, task.ref, job),
        active_by_attempt:
          Map.update(state.active_by_attempt, item.envelope.attempt_iri, 1, &(&1 + 1))
    }
  end

  defp pump(state) do
    items = :queue.to_list(state.queue)

    case Enum.split_while(items, &(not available?(state, &1.envelope.attempt_iri))) do
      {_blocked, []} ->
        state

      {before, [item | remaining]} ->
        state
        |> Map.merge(%{queue: :queue.from_list(before ++ remaining), queued: state.queued - 1})
        |> start_item(item)
        |> pump()
    end
  end

  defp drop_active(state, ref, job) do
    attempt = job.envelope.attempt_iri

    counts =
      case Map.get(state.active_by_attempt, attempt, 0) - 1 do
        0 -> Map.delete(state.active_by_attempt, attempt)
        count -> Map.put(state.active_by_attempt, attempt, count)
      end

    %{state | active: Map.delete(state.active, ref), active_by_attempt: counts}
  end

  defp deliver_result(state, job, {:ok, result}) do
    if current?(state, job.envelope, job.target) == :ok do
      data = correlation(job.envelope) |> Map.merge(result)

      case Jido.Signal.new(Map.fetch!(@result_types, job.envelope.kind), data) do
        {:ok, signal} -> state.delivery.(job.target, signal)
        _invalid -> :ok
      end
    end
  end

  defp deliver_result(state, job, {:error, reason}), do: deliver_failure(state, job, reason)

  defp deliver_failure(state, job, reason) do
    safe = %{outcome: :failed, error: reason}
    safe = if job.envelope.kind == :model, do: Map.put(safe, :kind, :failure), else: safe
    safe = if job.envelope.kind == :tool, do: Map.put(safe, :kind, :failed), else: safe
    deliver_result(state, job, {:ok, safe})
  end

  defp normalize_result(_kind, {:ok, result}) when is_map(result) do
    if TrustBoundary.validate_payload(result) == :ok,
      do: {:ok, result},
      else: {:error, :corrupt}
  end

  defp normalize_result(_kind, {:error, %AdapterError{kind: kind}}), do: {:error, kind}
  defp normalize_result(_kind, _result), do: {:error, :corrupt}

  defp correlation(envelope) do
    %{
      attempt_iri: envelope.attempt_iri,
      fencing_token: envelope.fencing_token,
      sequence: envelope.sequence,
      invocation_iri: envelope.invocation_iri,
      effect_type: envelope.kind,
      payload_digest: envelope.payload_digest
    }
  end

  defp current?(state, envelope, target) do
    case state.current_provider.(envelope.attempt_iri) do
      %{
        attempt_iri: attempt,
        fencing_token: fence,
        target: current_target,
        current?: true
      }
      when attempt == envelope.attempt_iri and fence == envelope.fencing_token and
             current_target == target ->
        :ok

      _stale ->
        {:error, AdapterError.new(:unauthorized, :managed_coding_dispatch_identity)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_dispatch_identity)}
  end

  defp deadline_current?(envelope) do
    if DateTime.compare(envelope.deadline, DateTime.utc_now()) == :gt,
      do: :ok,
      else: {:error, AdapterError.new(:timeout, :managed_coding_directive_deadline)}
  end

  defp available?(state, attempt) do
    map_size(state.active) < state.max_concurrency and
      Map.get(state.active_by_attempt, attempt, 0) < state.max_per_attempt
  end

  defp remove_queued(queue, attempt, fence) do
    queue
    |> :queue.to_list()
    |> Enum.split_with(fn item ->
      item.envelope.attempt_iri == attempt and item.envelope.fencing_token == fence
    end)
    |> then(fn {removed, kept} -> {removed, :queue.from_list(kept)} end)
  end

  defp envelope(%Context{envelope: envelope}), do: {:ok, envelope}
  defp envelope(%Model{envelope: envelope}), do: {:ok, envelope}
  defp envelope(%Tool{envelope: envelope}), do: {:ok, envelope}
  defp envelope(%Actor{envelope: envelope}), do: {:ok, envelope}
  defp envelope(%Candidate{envelope: envelope}), do: {:ok, envelope}
  defp envelope(%Observation{envelope: envelope}), do: {:ok, envelope}
  defp envelope(%Continuation{envelope: envelope}), do: {:ok, envelope}
  defp envelope(_directive), do: invalid(:managed_coding_directive_type)

  defp handlers(handlers) when is_map(handlers) do
    if MapSet.new(Map.keys(handlers)) == MapSet.new(@kinds) and
         Enum.all?(handlers, fn {_kind, value} -> handler?(value) end),
       do: :ok,
       else: :error
  end

  defp handlers(_handlers), do: :error

  defp handler?({module, _state}) when is_atom(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :execute, 3)

  defp handler?(_handler), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

defmodule JidoCode.Runtime.JidoAdapter do
  @moduledoc "Jido 2.3 adapter implementing the bounded execution runtime port."

  @behaviour JidoCode.Factory.Ports.ExecutionRuntime

  alias Jido.AgentServer
  alias Jido.Signal
  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent
  alias JidoCode.Runtime.ExecutionAgent
  alias JidoCode.Runtime.JidoInstance

  @impl true
  def prepare(%Request{} = request, options) do
    key = Request.runtime_key(request)

    case JidoInstance.whereis(key) do
      pid when is_pid(pid) ->
        event(request, :prepared, :pending, options)

      nil ->
        case JidoInstance.start_agent(ExecutionAgent,
               id: key,
               state: %{attempt_iri: request.attempt_iri, fencing_token: request.fencing_token}
             ) do
          {:ok, _pid} -> event(request, :prepared, :pending, options)
          {:error, {:already_started, _pid}} -> event(request, :prepared, :pending, options)
          _error -> adapter_error(:unavailable, :prepare)
        end
    end
  rescue
    _error -> adapter_error(:unavailable, :prepare)
  end

  @impl true
  def start(%Request{} = request, options) do
    transition(request, :running, :started, :pending, options)
  end

  @impl true
  def signal(%Request{} = request, %RuntimeEvent{} = incoming, options) do
    transition(
      request,
      :running,
      :progress,
      incoming.outcome_class,
      Keyword.put(options, :sequence, incoming.sequence)
    )
  end

  @impl true
  def cancel(%Request{} = request, cancellation, options) when is_map(cancellation) do
    with {:ok, event} <- transition(request, :cancelling, :cancelling, :pending, options),
         :ok <- stop(request) do
      event(request, :cancelled, :cancelled, Keyword.put(options, :sequence, event.sequence + 1))
    end
  end

  @impl true
  def status(%Request{} = request, options) do
    case runtime_state(request) do
      {:ok, %{execution_status: status, last_sequence: sequence}} ->
        type = if status == :prepared, do: :prepared, else: :progress
        event(request, type, :pending, Keyword.put(options, :sequence, sequence))

      {:error, :not_found} ->
        event(request, :crashed, :unknown, options)

      _error ->
        adapter_error(:unavailable, :status)
    end
  end

  @impl true
  def terminate(%Request{} = request, reason, options) when is_map(reason) do
    case stop(request) do
      :ok -> event(request, :cancelled, :cancelled, options)
      {:error, :not_found} -> event(request, :cancelled, :cancelled, options)
      _error -> adapter_error(:unavailable, :terminate)
    end
  end

  defp transition(request, status, type, outcome, options) do
    sequence = Keyword.get(options, :sequence, 1)

    with pid when is_pid(pid) <- JidoInstance.whereis(Request.runtime_key(request)),
         {:ok, signal} <-
           Signal.new("jido_code.runtime.transition", %{
             execution_status: status,
             sequence: sequence
           }),
         {:ok, _agent} <- AgentServer.call(pid, signal) do
      event(request, type, outcome, Keyword.put(options, :sequence, sequence))
    else
      nil -> adapter_error(:unavailable, type)
      _error -> adapter_error(:unavailable, type)
    end
  rescue
    _error -> adapter_error(:unavailable, type)
  catch
    :exit, _reason -> adapter_error(:unavailable, type)
  end

  defp runtime_state(request) do
    case JidoInstance.whereis(Request.runtime_key(request)) do
      pid when is_pid(pid) ->
        with {:ok, state} <- AgentServer.state(pid) do
          {:ok, Map.take(state.agent.state, [:execution_status, :last_sequence])}
        end

      nil ->
        {:error, :not_found}
    end
  end

  defp stop(request) do
    case JidoInstance.whereis(Request.runtime_key(request)) do
      pid when is_pid(pid) -> JidoInstance.stop_agent(pid)
      nil -> {:error, :not_found}
    end
  end

  defp event(request, type, outcome, options) do
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)

    RuntimeEvent.new(%{
      attempt_iri: request.attempt_iri,
      sequence: Keyword.get(options, :sequence, 0),
      type: type,
      occurred_at: clock.(),
      outcome_class: outcome,
      usage: %{}
    })
  end

  defp adapter_error(kind, operation), do: {:error, AdapterError.new(kind, operation)}
end

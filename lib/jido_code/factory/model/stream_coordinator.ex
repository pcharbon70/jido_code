defmodule JidoCode.Factory.Model.StreamCoordinator do
  @moduledoc """
  Commits exactly one stream outcome and coordinates cancellation cleanup.

  Cancellation or timeout closes the response from this process, waits a
  finite grace period, then terminates a consumer that did not stop.
  """

  use GenServer

  alias JidoCode.Factory.Model.Stream
  alias JidoCode.Factory.Model.StreamConsumer
  alias JidoCode.Factory.Model.StreamResult

  @default_cancel_wait_ms 250

  @spec start_link({Stream.t(), keyword()}) :: GenServer.on_start()
  def start_link({%Stream{} = stream, options}) when is_list(options) do
    GenServer.start_link(__MODULE__, {stream, options})
  end

  @spec child_spec({Stream.t(), keyword()}) :: Supervisor.child_spec()
  def child_spec({%Stream{} = stream, options}) do
    %{
      id: {__MODULE__, stream.invocation_iri},
      start: {__MODULE__, :start_link, [{stream, options}]},
      restart: :temporary
    }
  end

  @spec await(pid(), timeout()) :: StreamResult.t()
  def await(coordinator, timeout \\ 65_000), do: GenServer.call(coordinator, :await, timeout)

  @spec cancel(pid(), :cancelled | :lease_lost) :: :ok
  def cancel(coordinator, reason \\ :cancelled) when reason in [:cancelled, :lease_lost] do
    GenServer.call(coordinator, {:cancel, reason})
  end

  @impl true
  def init({stream, options}) do
    reference = make_ref()
    subscriber = Keyword.get(options, :subscriber)
    cancel_wait_ms = Keyword.get(options, :cancel_wait_ms, @default_cancel_wait_ms)
    timeout_ms = consumption_timeout(stream)

    case StreamConsumer.start(stream, self(), reference, options) do
      {:ok, consumer} ->
        monitor = Process.monitor(consumer)
        timeout_timer = Process.send_after(self(), :stream_timeout, timeout_ms)

        {:ok,
         %{
           cancel_timer: nil,
           cancel_wait_ms: cancel_wait_ms,
           consumer: consumer,
           monitor: monitor,
           options: options,
           outcome: nil,
           reference: reference,
           stream: stream,
           subscriber: subscriber,
           timeout_timer: timeout_timer,
           waiters: []
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:await, _from, %{outcome: %StreamResult{} = outcome} = state),
    do: {:reply, outcome, state}

  def handle_call(:await, from, state), do: {:noreply, %{state | waiters: [from | state.waiters]}}

  def handle_call({:cancel, reason}, _from, state) do
    outcome = StreamResult.cancellation(state.stream.request, reason)
    state = commit(state, outcome)
    close(state.stream)
    timer = Process.send_after(self(), :force_consumer_stop, state.cancel_wait_ms)
    {:reply, :ok, %{state | cancel_timer: timer}}
  end

  @impl true
  def handle_info({:model_stream_delta, reference, text}, %{reference: reference} = state) do
    if is_nil(state.outcome) and is_pid(state.subscriber) do
      send(state.subscriber, {:model_stream_delta, state.stream.invocation_iri, text})
    end

    {:noreply, state}
  end

  def handle_info({:model_stream_result, reference, result}, %{reference: reference} = state) do
    {:noreply, commit(state, result)}
  end

  def handle_info(:stream_timeout, state) do
    state = commit(state, StreamResult.timeout(state.stream.request))
    close(state.stream)
    timer = Process.send_after(self(), :force_consumer_stop, state.cancel_wait_ms)
    {:noreply, %{state | cancel_timer: timer}}
  end

  def handle_info(:force_consumer_stop, state) do
    if Process.alive?(state.consumer), do: StreamConsumer.terminate(state.consumer, state.options)
    {:noreply, state}
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, %{monitor: monitor} = state) do
    state =
      if is_nil(state.outcome) do
        commit(state, failed_result(state.stream))
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    close(state.stream)

    if Process.alive?(state.consumer), do: StreamConsumer.terminate(state.consumer, state.options)
    :ok
  end

  defp commit(%{outcome: %StreamResult{}} = state, _losing_result), do: state

  defp commit(state, %StreamResult{} = outcome) do
    Enum.each(state.waiters, &GenServer.reply(&1, outcome))
    cancel_timer(state.timeout_timer)
    %{state | outcome: outcome, waiters: []}
  end

  defp consumption_timeout(stream) do
    deadline_ms = DateTime.diff(stream.request.deadline, DateTime.utc_now(), :millisecond)

    max(
      1,
      Enum.min([
        deadline_ms,
        stream.profile.timeouts.total_ms,
        stream.profile.timeouts.metadata_ms
      ])
    )
  end

  defp close(stream) do
    stream.adapter_module.close(stream.adapter, stream.handle)
  rescue
    _error -> :ok
  catch
    _kind, _reason -> :ok
  end

  defp failed_result(stream) do
    {:ok, result} =
      StreamResult.new(%{
        status: :failed,
        invocation_iri: stream.invocation_iri,
        text: "",
        tool_calls: [],
        usage: %{},
        finish_reason: :error,
        diagnostic: "stream=consumer_terminated"
      })

    result
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
end

defmodule JidoCode.Factory.Model.StreamConsumer do
  @moduledoc "Supervised single owner of one model stream enumeration."

  alias JidoCode.Factory.Model.Stream
  alias JidoCode.Factory.Model.StreamEvent
  alias JidoCode.Factory.Model.StreamResult

  @max_text_bytes 262_144

  @spec start(Stream.t(), pid(), reference(), keyword()) ::
          DynamicSupervisor.on_start_child()
  def start(%Stream{} = stream, coordinator, reference, options) do
    supervisor = Keyword.get(options, :task_supervisor, JidoCode.Factory.Model.StreamSupervisor)

    Task.Supervisor.start_child(supervisor, fn ->
      result =
        try do
          consume(stream, coordinator, reference)
        rescue
          _error -> failed(stream, "stream=consumer_exception")
        catch
          :exit, _reason -> failed(stream, "stream=consumer_exit")
          _kind, _reason -> failed(stream, "stream=consumer_failure")
        after
          close(stream)
        end

      send(coordinator, {:model_stream_result, reference, result})
    end)
  end

  @spec terminate(pid(), keyword()) :: :ok | {:error, :not_found}
  def terminate(pid, options) when is_pid(pid) do
    supervisor = Keyword.get(options, :task_supervisor, JidoCode.Factory.Model.StreamSupervisor)
    Task.Supervisor.terminate_child(supervisor, pid)
  end

  defp consume(stream, coordinator, reference) do
    initial = %{
      finish_reason: nil,
      policy_violation?: false,
      terminal: nil,
      terminal_count: 0,
      text_bytes: 0,
      text: [],
      tool_calls: [],
      usage: %{}
    }

    state =
      stream.adapter_module.events(stream.adapter, stream.handle)
      |> Enum.reduce(initial, fn
        %StreamEvent{} = event, state -> consume_event(event, state, coordinator, reference)
        _invalid, state -> %{state | policy_violation?: true}
      end)

    terminal_result(stream, state)
  end

  defp consume_event(_event, %{terminal_count: count} = state, _coordinator, _reference)
       when count > 0,
       do: %{state | terminal_count: count + 1, policy_violation?: true}

  defp consume_event(%StreamEvent{type: :text_delta, data: text}, state, coordinator, reference)
       when is_binary(text) do
    bytes = state.text_bytes + byte_size(text)

    if bytes <= @max_text_bytes do
      send(coordinator, {:model_stream_delta, reference, text})
      %{state | text: [text | state.text], text_bytes: bytes}
    else
      %{state | policy_violation?: true}
    end
  end

  defp consume_event(%StreamEvent{type: type}, state, _coordinator, _reference)
       when type in [:tool_call_start, :tool_call_delta],
       do: %{state | policy_violation?: true}

  defp consume_event(%StreamEvent{type: :tool_call, data: call}, state, _coordinator, _reference),
    do: %{state | tool_calls: [call | state.tool_calls], policy_violation?: true}

  defp consume_event(%StreamEvent{type: :usage, data: usage}, state, _coordinator, _reference)
       when is_map(usage),
       do: %{state | usage: usage}

  defp consume_event(%StreamEvent{type: type, data: data}, state, _coordinator, _reference)
       when type in [:finish, :cancelled, :error] do
    %{
      state
      | terminal: type,
        terminal_count: state.terminal_count + 1,
        finish_reason: finish_reason(data)
    }
  end

  defp consume_event(%StreamEvent{type: :policy_violation}, state, _coordinator, _reference),
    do: %{state | policy_violation?: true}

  defp consume_event(_event, state, _coordinator, _reference), do: state

  defp terminal_result(stream, state) do
    {status, diagnostic} = terminal_status(state)

    text =
      if status == :completed and not state.policy_violation?,
        do: state.text |> Enum.reverse() |> IO.iodata_to_binary(),
        else: ""

    {:ok, result} =
      StreamResult.new(%{
        status: status,
        invocation_iri: stream.invocation_iri,
        text: text,
        tool_calls: if(state.policy_violation?, do: [], else: Enum.reverse(state.tool_calls)),
        usage: state.usage,
        finish_reason: state.finish_reason,
        diagnostic: diagnostic
      })

    result
  end

  defp terminal_status(%{terminal_count: count}) when count != 1,
    do: {:failed, "stream=invalid_terminal_count"}

  defp terminal_status(%{policy_violation?: true}),
    do: {:failed, "stream=policy_violation"}

  defp terminal_status(%{terminal: :finish}), do: {:completed, "stream=completed"}
  defp terminal_status(%{terminal: :cancelled}), do: {:cancelled, "stream=cancelled"}
  defp terminal_status(%{terminal: :error}), do: {:failed, "stream=provider_error"}
  defp terminal_status(_state), do: {:failed, "stream=invalid_terminal"}

  defp finish_reason(%{finish_reason: reason}) when is_atom(reason), do: reason
  defp finish_reason(_data), do: nil

  defp close(stream) do
    stream.adapter_module.close(stream.adapter, stream.handle)
  rescue
    _error -> :ok
  catch
    _kind, _reason -> :ok
  end

  defp failed(stream, diagnostic) do
    {:ok, result} =
      StreamResult.new(%{
        status: :failed,
        invocation_iri: stream.invocation_iri,
        text: "",
        tool_calls: [],
        usage: %{},
        finish_reason: :error,
        diagnostic: diagnostic
      })

    result
  end
end

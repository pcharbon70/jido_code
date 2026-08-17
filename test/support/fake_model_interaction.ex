defmodule JidoCode.TestSupport.FakeModelInteraction do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ModelInteraction

  @impl true
  def generate(adapter, request) do
    send(adapter.owner, {:model_generate, request})
    adapter.generate_result
  end

  @impl true
  def stream(adapter, request) do
    send(adapter.owner, {:model_stream, request})
    adapter.stream_result
  end

  @impl true
  def events(adapter, %{events: events} = handle) do
    send(adapter.owner, {:model_stream_events, handle})
    events
  end

  def events(_adapter, _handle), do: []

  @impl true
  def close(adapter, handle) do
    send(adapter.owner, {:model_stream_close, handle})
    if is_map(handle) and is_function(handle[:close], 0), do: handle.close.(), else: :ok
    :ok
  end
end

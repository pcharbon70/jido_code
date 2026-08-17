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
end

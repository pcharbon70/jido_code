defmodule JidoCode.TestSupport.SequencedModelInteraction do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ModelInteraction

  @impl true
  def generate(adapter, request) do
    send(adapter.owner, {:model_generate, request})
    Agent.get_and_update(adapter.responses, fn [next | remaining] -> {next, remaining} end)
  end

  @impl true
  def stream(_adapter, _request), do: {:error, :unsupported}

  @impl true
  def events(_adapter, _handle), do: []

  @impl true
  def close(_adapter, _handle), do: :ok
end

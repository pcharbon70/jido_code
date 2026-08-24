defmodule JidoCode.TestSupport.AgentManagedCodingContextSink do
  @moduledoc false

  def put(agent, context) do
    Agent.update(agent, &Map.put(&1, :context, context))
    :ok
  end
end

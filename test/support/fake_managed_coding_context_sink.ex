defmodule JidoCode.TestSupport.FakeManagedCodingContextSink do
  @moduledoc false

  def put(state, context) do
    send(state.owner, {:managed_coding_context, context})
    Map.get(state, :result, :ok)
  end
end

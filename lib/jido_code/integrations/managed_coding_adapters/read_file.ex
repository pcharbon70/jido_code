defmodule JidoCode.Integrations.ManagedCodingAdapters.ReadFile do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "read_file",
        state,
        request,
        options
      )
end

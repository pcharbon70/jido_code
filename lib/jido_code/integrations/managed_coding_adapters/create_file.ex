defmodule JidoCode.Integrations.ManagedCodingAdapters.CreateFile do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "create_file",
        state,
        request,
        options
      )
end

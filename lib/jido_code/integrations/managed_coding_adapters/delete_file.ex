defmodule JidoCode.Integrations.ManagedCodingAdapters.DeleteFile do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "delete_file",
        state,
        request,
        options
      )
end

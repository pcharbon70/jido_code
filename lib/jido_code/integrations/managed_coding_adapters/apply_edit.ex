defmodule JidoCode.Integrations.ManagedCodingAdapters.ApplyEdit do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "apply_edit",
        state,
        request,
        options
      )
end

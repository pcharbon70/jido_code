defmodule JidoCode.Integrations.ManagedCodingAdapters.InspectSymbol do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "inspect_symbol",
        state,
        request,
        options
      )
end

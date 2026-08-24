defmodule JidoCode.Integrations.ManagedCodingAdapters.SearchSource do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "search_source",
        state,
        request,
        options
      )
end

defmodule JidoCode.Integrations.ManagedCodingAdapters.RunRegisteredCheck do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "run_registered_check",
        state,
        request,
        options
      )
end

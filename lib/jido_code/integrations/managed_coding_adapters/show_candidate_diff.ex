defmodule JidoCode.Integrations.ManagedCodingAdapters.ShowCandidateDiff do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.Tool
  def execute(state, request, options),
    do:
      JidoCode.Integrations.ManagedCodingAdapters.Dispatcher.execute(
        "show_candidate_diff",
        state,
        request,
        options
      )
end

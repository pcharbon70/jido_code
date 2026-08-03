defmodule JidoCode.Factory.Ports.SourceAnalyzer do
  @moduledoc "Deterministic, bounded source semantic extraction port."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.SourceAnalysis.Request
  alias JidoCode.Factory.SourceAnalysis.Result

  @callback analyze(adapter :: term(), Request.t()) ::
              {:ok, Result.t()} | {:error, AdapterError.t()}
end

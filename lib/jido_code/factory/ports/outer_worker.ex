defmodule JidoCode.Factory.Ports.OuterWorker do
  @moduledoc "Independent process-namespace termination boundary for delegated CLIs."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request

  @callback kill_namespace(term(), Request.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback destroy(term(), Request.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

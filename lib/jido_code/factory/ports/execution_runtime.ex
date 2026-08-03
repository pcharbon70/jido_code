defmodule JidoCode.Factory.Ports.ExecutionRuntime do
  @moduledoc "Provider-neutral lifecycle contract for one fenced execution attempt."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent

  @callback prepare(Request.t(), keyword()) ::
              {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}
  @callback start(Request.t(), keyword()) ::
              {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}
  @callback signal(Request.t(), RuntimeEvent.t(), keyword()) ::
              {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}
  @callback cancel(Request.t(), map(), keyword()) ::
              {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}
  @callback status(Request.t(), keyword()) ::
              {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}
  @callback terminate(Request.t(), map(), keyword()) ::
              {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}
end

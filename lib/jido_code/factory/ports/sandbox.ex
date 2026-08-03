defmodule JidoCode.Factory.Ports.Sandbox do
  @moduledoc "Disposable, resource-bounded repository sandbox port."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox.Event
  alias JidoCode.Factory.Sandbox.Request

  @callback provision(term(), Request.t(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
  @callback materialize(term(), Request.t(), map(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
  @callback execute(term(), Request.t(), map(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
  @callback inspect(term(), Request.t(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
  @callback cancel(term(), Request.t(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
  @callback collect(term(), Request.t(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
  @callback destroy(term(), Request.t(), keyword()) ::
              {:ok, Event.t()} | {:error, AdapterError.t()}
end

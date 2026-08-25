defmodule JidoCode.Factory.Ports.ManagedCodingRuntime do
  @moduledoc "Accepted supervised runtime seam used only after durable admission."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.ResolvedAdmission

  @callback start(term(), ResolvedAdmission.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback command(term(), Command.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback await(term(), Command.t(), timeout()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

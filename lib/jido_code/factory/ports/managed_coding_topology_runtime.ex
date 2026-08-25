defmodule JidoCode.Factory.Ports.ManagedCodingTopologyRuntime do
  @moduledoc "Disposable runtime seam for graph-projected managed coding topology operations."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.TopologyContract

  @callback reconcile(TopologyContract.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback stop(TopologyContract.t(), keyword()) :: :ok | {:error, AdapterError.t()}
end

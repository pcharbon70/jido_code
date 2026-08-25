defmodule JidoCode.Factory.Ports.ManagedCodingLifecycleLedger do
  @moduledoc "Durable graph ledger boundary for managed coding lifecycle facts."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.LifecycleEvent

  @callback current(term(), String.t(), pos_integer()) ::
              {:ok, %{state: atom(), sequence: non_neg_integer()}}
              | {:error, AdapterError.t()}
  @callback find(term(), String.t(), pos_integer(), {atom(), String.t()}) ::
              {:ok, LifecycleEvent.t()} | :not_found | {:error, AdapterError.t()}
  @callback append(term(), LifecycleEvent.t(), non_neg_integer()) ::
              {:ok, :committed | :idempotent} | {:error, AdapterError.t()}
  @callback events(term(), String.t(), pos_integer()) ::
              {:ok, [LifecycleEvent.t()]} | {:error, AdapterError.t()}
end

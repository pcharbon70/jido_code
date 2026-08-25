defmodule JidoCode.Factory.Ports.ManagedCodingRecoveryLedger do
  @moduledoc "Durable discovery, fencing, and quarantine boundary for managed recovery."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.RecoveryPlan
  alias JidoCode.Factory.ManagedCoding.RecoveryRecord

  @callback discover(term(), map()) :: {:ok, [map()]} | {:error, AdapterError.t()}
  @callback acquire_fence(term(), RecoveryRecord.t(), pos_integer()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback recovered(term(), RecoveryPlan.t(), map()) :: :ok | {:error, AdapterError.t()}
  @callback quarantine(term(), map() | RecoveryRecord.t(), atom()) ::
              :ok | {:error, AdapterError.t()}
end

defmodule JidoCode.Factory.Ports.ManagedCodingRecoveryRuntime do
  @moduledoc "Disposable workspace and agent reconstruction boundary."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.RecoveryPlan

  @callback recreate(term(), RecoveryPlan.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

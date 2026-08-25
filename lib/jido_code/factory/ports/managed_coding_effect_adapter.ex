defmodule JidoCode.Factory.Ports.ManagedCodingEffectAdapter do
  @moduledoc "External effect dispatch and authoritative reconciliation boundary."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.EffectIntent

  @callback dispatch(term(), EffectIntent.t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  @callback query(term(), EffectIntent.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  @callback compare(term(), EffectIntent.t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  @callback compensate(term(), EffectIntent.t()) :: :ok | {:error, AdapterError.t()}
end

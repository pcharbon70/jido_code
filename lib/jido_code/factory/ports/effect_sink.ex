defmodule JidoCode.Factory.Ports.EffectSink do
  @moduledoc "Atomic replay boundary implemented by every effect sink."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.EffectIdentity
  alias JidoCode.Factory.Tool.Result

  @callback claim(term(), atom(), EffectIdentity.t()) ::
              {:ok, :dispatch}
              | {:ok, {:replay, Result.t()}}
              | {:error, AdapterError.t()}

  @callback complete(term(), atom(), EffectIdentity.t(), Result.t()) ::
              {:ok, :committed | :idempotent} | {:error, AdapterError.t()}

  @callback ambiguous(term(), atom(), EffectIdentity.t()) ::
              {:ok, :committed | :idempotent} | {:error, AdapterError.t()}
end

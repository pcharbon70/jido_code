defmodule JidoCode.Factory.Ports.ManagedCodingEffectLedger do
  @moduledoc "Durable intent, outcome, retry, and ambiguity evidence boundary."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.EffectIntent

  @callback intent(term(), EffectIntent.t()) :: :ok | {:error, AdapterError.t()}
  @callback outcome(term(), EffectIntent.t(), map()) :: :ok | {:error, AdapterError.t()}
  @callback retry(term(), EffectIntent.t(), map()) :: :ok | {:error, AdapterError.t()}
  @callback ambiguous(term(), EffectIntent.t(), atom()) :: :ok | {:error, AdapterError.t()}
  @callback resolution_interaction(term(), EffectIntent.t(), map()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end

defmodule JidoCode.Factory.Ports.ManagedCodingCancellation do
  @moduledoc "Durable and operational boundary for race-safe managed cancellation."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CancellationRequest

  @callback commit_request(term(), CancellationRequest.t()) :: :ok | {:error, AdapterError.t()}
  @callback stop_dispatch(term(), CancellationRequest.t()) :: :ok | {:error, AdapterError.t()}
  @callback revoke_capabilities(term(), CancellationRequest.t()) ::
              :ok | {:error, AdapterError.t()}
  @callback cancel_queued(term(), CancellationRequest.t()) :: :ok | {:error, AdapterError.t()}
  @callback terminate_effects(term(), CancellationRequest.t(), non_neg_integer()) ::
              :ok | {:error, AdapterError.t()}
  @callback cleanup(term(), CancellationRequest.t()) :: {:ok, atom()} | {:error, AdapterError.t()}
  @callback release_capacity(term(), CancellationRequest.t()) :: :ok | {:error, AdapterError.t()}
  @callback finalize(term(), CancellationRequest.t(), atom()) ::
              {:ok, atom()} | {:error, AdapterError.t()}
  @callback observe_late(term(), CancellationRequest.t(), map()) ::
              :ok | {:error, AdapterError.t()}
end

defmodule JidoCode.Factory.ManagedCoding.Cancellation do
  @moduledoc "Cancellation protocol that removes authority before stopping replaceable runtime material."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CancellationRequest

  @spec execute(module(), term(), CancellationRequest.t(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def execute(adapter_module, adapter, %CancellationRequest{} = request, options \\ []) do
    grace_ms = Keyword.get(options, :grace_ms, 5_000)

    with true <- is_integer(grace_ms) and grace_ms >= 0,
         :ok <- adapter_module.commit_request(adapter, request),
         :ok <- adapter_module.stop_dispatch(adapter, request),
         :ok <- adapter_module.revoke_capabilities(adapter, request),
         :ok <- adapter_module.cancel_queued(adapter, request),
         :ok <- adapter_module.terminate_effects(adapter, request, grace_ms),
         {:ok, cleanup} <- adapter_module.cleanup(adapter, request),
         :ok <- adapter_module.release_capacity(adapter, request),
         {:ok, terminal} <- adapter_module.finalize(adapter, request, :cancelled) do
      {:ok, %{terminal: terminal, cleanup: cleanup, fencing_token: request.target_fencing_token}}
    else
      false -> {:error, AdapterError.new(:invalid_input, :managed_coding_cancellation)}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  @spec late_output(module(), term(), CancellationRequest.t(), map()) ::
          {:ok, :non_authoritative} | {:error, AdapterError.t()}
  def late_output(adapter_module, adapter, %CancellationRequest{} = request, output)
      when is_map(output) do
    observation =
      output
      |> Map.drop([:authority, :advance_state, :candidate_closure, :disposition])
      |> Map.merge(%{
        authority: :none,
        advance_state: false,
        candidate_closure: false,
        disposition: false,
        target_fencing_token: request.target_fencing_token
      })

    case adapter_module.observe_late(adapter, request, observation) do
      :ok -> {:ok, :non_authoritative}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end
end

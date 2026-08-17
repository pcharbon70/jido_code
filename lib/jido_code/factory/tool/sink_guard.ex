defmodule JidoCode.Factory.Tool.SinkGuard do
  @moduledoc "Complete stale-fence and replay mediation for Factory-owned effect sinks."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Tool.EffectIdentity
  alias JidoCode.Factory.Tool.Result

  @sinks ~w[
    graph_command sandbox_mutation tool_execution git_write provider_write
    artifact_publication execution_outcome
  ]a

  @spec inventory() :: [atom()]
  def inventory, do: @sinks

  @spec claim(atom(), Request.t(), EffectIdentity.t(), map(), {module(), term()}) ::
          {:ok, :dispatch}
          | {:ok, {:replay, Result.t()}}
          | {:error, AdapterError.t()}
  def claim(sink, execution, identity, current, effect_sink)

  def claim(
        sink,
        %Request{} = execution,
        %EffectIdentity{} = identity,
        current,
        {module, state}
      )
      when sink in @sinks and is_map(current) and is_atom(module) do
    with :ok <- current?(execution, identity, current),
         true <- sink?(module),
         result <- module.claim(state, sink, identity) do
      normalize_claim(result)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unauthorized, sink)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, sink)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, sink)}
  end

  def claim(sink, _execution, _identity, _current, _effect_sink),
    do: {:error, AdapterError.new(:invalid_input, sink)}

  defp current?(execution, identity, current) do
    valid? =
      current[:lease_state] == :active and
        current[:attempt_iri] == execution.attempt_iri and
        current[:lease_iri] == execution.lease_iri and
        current[:snapshot_iri] == execution.snapshot_iri and
        current[:fencing_token] == execution.fencing_token and
        identity.attempt_iri == execution.attempt_iri and
        identity.snapshot_iri == execution.snapshot_iri and
        identity.fencing_token == execution.fencing_token

    if valid?, do: :ok, else: {:error, AdapterError.new(:unauthorized, :stale_effect_fence)}
  end

  defp normalize_claim({:ok, :dispatch}), do: {:ok, :dispatch}
  defp normalize_claim({:ok, {:replay, %Result{} = result}}), do: {:ok, {:replay, result}}
  defp normalize_claim({:error, %AdapterError{} = error}), do: {:error, error}
  defp normalize_claim(_invalid), do: {:error, AdapterError.new(:corrupt, :effect_sink_claim)}

  defp sink?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :claim, 3) and
      function_exported?(module, :complete, 4) and function_exported?(module, :ambiguous, 3)
  end
end

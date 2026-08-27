defmodule JidoCode.Integrations.DelegatedRecoveryCoordinator do
  @moduledoc "Revalidates accepted checkpoint bytes before deriving graph-only recovery action."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCheckpoint
  alias JidoCode.Factory.DelegatedRecovery

  @spec reconcile(map(), DelegatedCheckpoint.t() | nil, module(), term()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def reconcile(graph, nil, _artifact_module, _artifact_store) when is_map(graph),
    do: DelegatedRecovery.plan(graph, nil)

  def reconcile(
        graph,
        %DelegatedCheckpoint{} = checkpoint,
        artifact_module,
        artifact_store
      )
      when is_map(graph) and is_atom(artifact_module) do
    with true <-
           Code.ensure_loaded?(artifact_module) and function_exported?(artifact_module, :fetch, 2),
         {:ok, artifact} <-
           artifact_module.fetch(artifact_store, %{
             artifact_iri: checkpoint.patch_artifact_iri,
             digest: checkpoint.patch_digest,
             maximum_bytes: checkpoint.patch_bytes + 1
           }),
         true <- artifact.byte_count == checkpoint.patch_bytes,
         {:ok, plan} <- DelegatedRecovery.plan(graph, checkpoint) do
      {:ok, Map.put(plan, :checkpoint_artifact_verified, true)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :delegated_recovery_checkpoint)}
    end
  end

  def reconcile(_graph, _checkpoint, _artifact_module, _artifact_store),
    do: {:error, AdapterError.new(:invalid_input, :delegated_recovery)}
end

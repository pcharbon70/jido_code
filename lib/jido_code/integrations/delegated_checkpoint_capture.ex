defmodule JidoCode.Integrations.DelegatedCheckpointCapture do
  @moduledoc "Captures an exact workspace patch into an immutable artifact-backed checkpoint."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCheckpoint
  alias JidoCode.Integrations.DelegatedWorkspaceController

  @spec capture(GenServer.server(), String.t(), map(), module(), term(), map()) ::
          {:ok, DelegatedCheckpoint.t()} | {:error, AdapterError.t()}
  def capture(controller, workspace_iri, current, artifact_module, artifact_store, attributes)
      when is_binary(workspace_iri) and is_atom(artifact_module) and is_map(attributes) do
    with true <- artifact_store?(artifact_module),
         {:ok, snapshot} <-
           DelegatedWorkspaceController.checkpoint(controller, workspace_iri, current),
         {:ok, artifact} <-
           artifact_module.put(artifact_store, %{
             content: snapshot.patch,
             expected_digest: snapshot.patch_digest,
             media_type: "application/vnd.jido.checkpoint"
           }),
         true <- artifact.digest == snapshot.patch_digest,
         true <- artifact.byte_count == snapshot.patch_bytes,
         {:ok, checkpoint} <-
           snapshot
           |> Map.merge(attributes)
           |> Map.merge(%{
             patch_artifact_iri: artifact.artifact_iri,
             patch_digest: artifact.digest,
             patch_bytes: artifact.byte_count
           })
           |> DelegatedCheckpoint.new() do
      {:ok, checkpoint}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :delegated_checkpoint_capture)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :delegated_checkpoint_capture)}
  end

  def capture(
        _controller,
        _workspace_iri,
        _current,
        _artifact_module,
        _artifact_store,
        _attributes
      ),
      do: {:error, AdapterError.new(:invalid_input, :delegated_checkpoint_capture)}

  defp artifact_store?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :put, 2) and
      function_exported?(module, :fetch, 2)
  end
end

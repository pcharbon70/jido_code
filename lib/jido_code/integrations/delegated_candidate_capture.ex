defmodule JidoCode.Integrations.DelegatedCandidateCapture do
  @moduledoc "Controller-owned closure that distrusts delegated candidate and check claims."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCandidate
  alias JidoCode.Factory.DelegatedCheckpoint
  alias JidoCode.Integrations.DelegatedWorkspaceController

  @spec close(
          GenServer.server(),
          String.t(),
          map(),
          DelegatedCheckpoint.t(),
          module(),
          term(),
          map(),
          keyword()
        ) :: {:ok, DelegatedCandidate.t()} | {:error, AdapterError.t()}
  def close(
        controller,
        workspace_iri,
        current,
        checkpoint,
        artifact_module,
        artifact_store,
        attributes,
        options \\ []
      )

  def close(
        controller,
        workspace_iri,
        current,
        %DelegatedCheckpoint{} = checkpoint,
        artifact_module,
        artifact_store,
        attributes,
        options
      )
      when is_binary(workspace_iri) and is_atom(artifact_module) and is_map(attributes) and
             is_list(options) do
    with true <- artifact_store?(artifact_module),
         commit when is_function(commit, 1) <- Keyword.get(options, :commit),
         {:ok, snapshot} <-
           DelegatedWorkspaceController.checkpoint(controller, workspace_iri, current),
         :ok <- exact_checkpoint(checkpoint, snapshot),
         {:ok, patch} <- fetch_patch(artifact_module, artifact_store, checkpoint),
         true <- patch.content == snapshot.patch,
         true <- patch.byte_count == snapshot.patch_bytes,
         :ok <- generated_policy(snapshot.changed_files, attributes),
         {:ok, secret_scan_iri} <- secret_scan_identity(checkpoint, snapshot),
         candidate_attributes <-
           attributes
           |> Map.merge(Map.take(snapshot, [:changed_files, :patch_digest, :tree_digest]))
           |> Map.merge(%{
             attempt_iri: checkpoint.attempt_iri,
             lease_iri: checkpoint.lease_iri,
             fencing_token: checkpoint.fencing_token,
             source_snapshot_iri: checkpoint.source_snapshot_iri,
             base_commit: checkpoint.base_commit,
             generated_artifacts: generated_artifacts(snapshot.changed_files, attributes),
             secret_scan_evidence_iri: secret_scan_iri,
             secret_scan_digest: digest({:clean, snapshot.patch_digest})
           }),
         {:ok, candidate} <- DelegatedCandidate.new(checkpoint, candidate_attributes),
         {:ok, receipt} <- commit.(candidate),
         true <- receipt[:outcome] in [:committed, :idempotent] do
      {:ok, candidate}
    else
      {:checkpoint_mismatch, _reason} ->
        quarantine(controller, workspace_iri, current, :candidate_digest_mismatch)

      {:artifact_error, _error} ->
        quarantine(controller, workspace_iri, current, :candidate_artifact_integrity)

      {:error, %AdapterError{} = error} ->
        {:error, error}

      false ->
        quarantine(controller, workspace_iri, current, :candidate_digest_mismatch)

      _invalid ->
        quarantine(controller, workspace_iri, current, :candidate_policy)
    end
  rescue
    _error -> quarantine(controller, workspace_iri, current, :candidate_capture_failure)
  end

  def close(
        _controller,
        _workspace_iri,
        _current,
        _checkpoint,
        _artifact_module,
        _artifact_store,
        _attributes,
        _options
      ),
      do: {:error, AdapterError.new(:invalid_input, :delegated_candidate_capture)}

  defp exact_checkpoint(checkpoint, snapshot) do
    if checkpoint.attempt_iri == snapshot.attempt_iri and
         checkpoint.lease_iri == snapshot.lease_iri and
         checkpoint.fencing_token == snapshot.fencing_token and
         checkpoint.source_snapshot_iri == snapshot.source_snapshot_iri and
         checkpoint.base_commit == snapshot.base_commit and
         checkpoint.workspace_iri == snapshot.workspace_iri and
         checkpoint.workspace_digest == snapshot.workspace_digest and
         checkpoint.patch_digest == snapshot.patch_digest and
         checkpoint.patch_bytes == snapshot.patch_bytes and
         checkpoint.tree_digest == snapshot.tree_digest and
         checkpoint.changed_paths == snapshot.changed_paths,
       do: :ok,
       else: {:checkpoint_mismatch, :workspace_recomputation}
  end

  defp fetch_patch(artifact_module, artifact_store, checkpoint) do
    case artifact_module.fetch(artifact_store, %{
           artifact_iri: checkpoint.patch_artifact_iri,
           digest: checkpoint.patch_digest,
           maximum_bytes: checkpoint.patch_bytes + 1
         }) do
      {:ok, patch} -> {:ok, patch}
      {:error, error} -> {:artifact_error, error}
    end
  end

  defp generated_policy(changed_files, attributes) do
    declared = Map.get(attributes, :generated_paths, [])
    allowed = Map.get(attributes, :allowed_generated_paths, [])

    if valid_paths?(declared) and valid_paths?(allowed) and
         Enum.all?(declared, &(&1 in allowed)) and
         Enum.all?(declared, fn path -> Enum.any?(changed_files, &(&1.path == path)) end),
       do: :ok,
       else: :error
  end

  defp generated_artifacts(changed_files, attributes) do
    generated = Map.get(attributes, :generated_paths, [])

    changed_files
    |> Enum.filter(&(&1.path in generated and &1.operation != :delete))
    |> Enum.map(&Map.take(&1, [:path, :digest]))
  end

  defp valid_paths?(paths) when is_list(paths) and length(paths) <= 128 do
    paths == Enum.uniq(paths) and
      Enum.all?(paths, fn path ->
        is_binary(path) and Path.type(path) == :relative and
          Enum.all?(Path.split(path), &(&1 not in ["", ".", ".."]))
      end)
  end

  defp valid_paths?(_paths), do: false

  defp secret_scan_identity(checkpoint, snapshot) do
    DelegatedCandidate.secret_scan_identity(checkpoint, snapshot.patch_digest)
  end

  defp quarantine(controller, workspace_iri, current, reason) do
    _ = DelegatedWorkspaceController.quarantine(controller, workspace_iri, current, reason)
    {:error, AdapterError.new(:unauthorized, :delegated_candidate_quarantined)}
  end

  defp artifact_store?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :put, 2) and
      function_exported?(module, :fetch, 2)
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end

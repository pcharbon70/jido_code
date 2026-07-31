defmodule JidoCode.Knowledge.Backup do
  @moduledoc false

  @architecture_file_role :graph_backup

  alias JidoCode.Knowledge.Backend.Checkpoint
  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.BackupManifest
  alias JidoCode.Knowledge.BackupReceipt
  alias JidoCode.Knowledge.Error
  alias TripleStore.Exporter
  alias TripleStore.QuadOperations

  @manifest_file "manifest.json"
  @artifact_pattern ~r/^artifact-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$/

  @spec create_checkpoint(TripleStore.store(), map(), JidoCode.Knowledge.Config.t()) ::
          {:ok, BackupReceipt.t()} | {:error, Error.t()}
  def create_checkpoint(store, metadata, config) do
    create_artifact(store, metadata, config, :checkpoint, fn artifact_root ->
      payload_path = Path.join(artifact_root, "checkpoint")

      with :ok <- Checkpoint.create(store, payload_path),
           :ok <- make_tree_private(payload_path),
           {:ok, digest} <- digest_payload(payload_path) do
        {:ok, "checkpoint", digest}
      end
    end)
  end

  @spec create_export(TripleStore.store(), map(), JidoCode.Knowledge.Config.t(), atom()) ::
          {:ok, BackupReceipt.t()} | {:error, Error.t()}
  def create_export(store, metadata, config, format) when format in [:nquads, :trig] do
    create_artifact(store, metadata, config, format, fn artifact_root ->
      {filename, serializer} = export_contract(format)
      payload_path = Path.join(artifact_root, filename)

      with {:ok, dataset} <- Exporter.export_dataset(store.db),
           {:ok, body} <- serializer.(dataset),
           :ok <- write_private(payload_path, body),
           {:ok, digest} <- digest_payload(payload_path) do
        {:ok, filename, digest}
      else
        {:error, %Error{} = error} -> {:error, error}
        {:error, reason} -> {:error, BackendFailure.translate(reason, :export_dataset)}
      end
    end)
  end

  def create_export(_store, _metadata, _config, _format) do
    {:error, Error.new(:invalid_input, :export_format)}
  end

  @spec load_checkpoint(JidoCode.Knowledge.Config.t(), String.t()) ::
          {:ok, BackupManifest.t(), Path.t()} | {:error, Error.t()}
  def load_checkpoint(config, artifact_id) do
    with :ok <- validate_artifact_id(artifact_id),
         artifact_root <- Path.join(config.backup_root, artifact_id),
         {:ok, encoded} <- read_file(Path.join(artifact_root, @manifest_file)),
         {:ok, manifest} <- BackupManifest.decode(encoded),
         :ok <- verify_manifest_identity(manifest, artifact_id),
         :ok <- verify_manifest_compatibility(manifest, config.schema_version),
         payload_path <- Path.join(artifact_root, manifest.payload_path),
         {:ok, digest} <- digest_payload(payload_path),
         :ok <- verify_payload_digest(manifest, digest) do
      {:ok, manifest, payload_path}
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, _reason} -> {:error, Error.new(:corrupt, :validate_restore_artifact)}
    end
  end

  @spec stage_checkpoint(JidoCode.Knowledge.Config.t(), Path.t()) ::
          {:ok, String.t(), Path.t()} | {:error, Error.t()}
  def stage_checkpoint(config, checkpoint_path) do
    dataset_id = "dataset-restore-" <> random_hex(8)
    datasets_root = Path.join(config.root, "datasets")
    destination = Path.join(datasets_root, dataset_id)

    with :ok <- private_directory(datasets_root),
         {:ok, _paths} <- File.cp_r(checkpoint_path, destination),
         :ok <- make_tree_private(destination) do
      {:ok, dataset_id, destination}
    else
      {:error, reason, _path} ->
        remove_tree(destination)
        {:error, BackendFailure.translate(reason, :stage_restore)}

      {:error, %Error{} = error} ->
        remove_tree(destination)
        {:error, error}

      {:error, reason} ->
        remove_tree(destination)
        {:error, BackendFailure.translate(reason, :stage_restore)}
    end
  end

  @spec retention_candidates(JidoCode.Knowledge.Config.t(), non_neg_integer()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def retention_candidates(config, keep_latest)
      when is_integer(keep_latest) and keep_latest >= 0 do
    case File.ls(config.backup_root) do
      {:ok, entries} ->
        candidates =
          entries
          |> Enum.filter(&Regex.match?(@artifact_pattern, &1))
          |> Enum.filter(&private_artifact?(config.backup_root, &1))
          |> Enum.sort(:desc)
          |> Enum.drop(keep_latest)

        {:ok, candidates}

      {:error, reason} ->
        {:error, BackendFailure.translate(reason, :list_backup_artifacts)}
    end
  end

  def retention_candidates(_config, _keep_latest) do
    {:error, Error.new(:invalid_input, :backup_retention)}
  end

  @spec latest_checkpoint(JidoCode.Knowledge.Config.t()) ::
          {:ok, BackupReceipt.t() | nil} | {:error, Error.t()}
  def latest_checkpoint(config) do
    case File.ls(config.backup_root) do
      {:ok, entries} ->
        receipt =
          entries
          |> Enum.filter(&Regex.match?(@artifact_pattern, &1))
          |> Enum.sort(:desc)
          |> Enum.find_value(&checkpoint_receipt(config, &1))

        {:ok, receipt}

      {:error, reason} ->
        {:error, BackendFailure.translate(reason, :list_backup_artifacts)}
    end
  end

  @spec remove_staged(Path.t()) :: :ok
  def remove_staged(path), do: remove_tree(path)

  defp create_artifact(store, metadata, config, kind, writer) do
    artifact_id = artifact_id()
    artifact_root = Path.join(config.backup_root, artifact_id)

    with :ok <- private_artifact_directory(artifact_root),
         {:ok, payload_path, digest} <- writer.(artifact_root),
         {:ok, counts} <- graph_counts(store),
         {:ok, manifest} <-
           BackupManifest.new(%{
             artifact_id: artifact_id,
             artifact_kind: kind,
             created_at:
               DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
             dataset_revision: metadata.dataset_revision,
             system_graph_revision: metadata.system_graph_revision,
             store_schema_version: metadata.store_schema_version,
             backend_schema_version: metadata.backend_schema_version,
             lineage: metadata.lineage,
             graph_count: counts.graph_count,
             quad_count: counts.quad_count,
             payload_path: payload_path,
             payload_sha256: digest.sha256,
             payload_bytes: digest.bytes,
             file_count: digest.file_count
           }),
         :ok <-
           write_private(
             Path.join(artifact_root, @manifest_file),
             BackupManifest.encode!(manifest) <> "\n"
           ) do
      {:ok, receipt(manifest)}
    else
      {:error, %Error{} = error} ->
        remove_tree(artifact_root)
        {:error, error}

      {:error, reason} ->
        remove_tree(artifact_root)
        {:error, BackendFailure.translate(reason, :create_backup_artifact)}
    end
  end

  defp graph_counts(store) do
    case QuadOperations.graphs_summary(store.db) do
      {:ok, graphs} ->
        named_graphs = Map.delete(graphs, :default)

        {:ok,
         %{
           graph_count: map_size(named_graphs),
           quad_count: graphs |> Map.values() |> Enum.sum()
         }}

      {:error, reason} ->
        {:error, BackendFailure.translate(reason, :backup_graph_counts)}
    end
  end

  defp receipt(manifest) do
    %BackupReceipt{
      artifact_id: manifest.artifact_id,
      artifact_kind: manifest.artifact_kind,
      created_at: manifest.created_at,
      dataset_revision: manifest.dataset_revision,
      graph_count: manifest.graph_count,
      quad_count: manifest.quad_count,
      payload_sha256: manifest.payload_sha256,
      payload_bytes: manifest.payload_bytes,
      consistency: manifest.consistency
    }
  end

  defp checkpoint_receipt(config, artifact_id) do
    manifest_path = Path.join([config.backup_root, artifact_id, @manifest_file])

    with {:ok, encoded} <- read_file(manifest_path),
         {:ok, manifest} <- BackupManifest.decode(encoded),
         :ok <- verify_manifest_identity(manifest, artifact_id),
         true <- manifest.artifact_kind == :checkpoint,
         :ok <- verify_manifest_compatibility(manifest, config.schema_version) do
      receipt(manifest)
    else
      _invalid -> nil
    end
  end

  defp export_contract(:nquads) do
    {"dataset.nq", fn dataset -> RDF.NQuads.write_string(dataset, sort: true) end}
  end

  defp export_contract(:trig) do
    {"dataset.trig", fn dataset -> RDF.TriG.write_string(dataset) end}
  end

  defp digest_payload(path) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} -> digest_files(path, [{Path.basename(path), path}])
      {:ok, %{type: :directory}} -> digest_directory(path)
      _other -> {:error, Error.new(:corrupt, :digest_backup_payload)}
    end
  end

  defp digest_directory(root) do
    entries =
      root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)

    with true <- Enum.all?(entries, &safe_payload_entry?/1),
         files when files != [] <-
           entries
           |> Enum.filter(&regular_file?/1)
           |> Enum.map(&{Path.relative_to(&1, root), &1})
           |> Enum.sort() do
      digest_files(root, files)
    else
      _invalid -> {:error, Error.new(:corrupt, :digest_backup_payload)}
    end
  end

  defp safe_payload_entry?(path) do
    case File.lstat(path) do
      {:ok, %{type: type}} when type in [:directory, :regular] -> true
      _other -> false
    end
  end

  defp regular_file?(path) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} -> true
      _other -> false
    end
  end

  defp private_artifact?(backup_root, artifact_id) do
    case File.lstat(Path.join(backup_root, artifact_id)) do
      {:ok, %{type: :directory}} -> true
      _other -> false
    end
  end

  defp digest_files(_root, []) do
    {:error, Error.new(:corrupt, :digest_backup_payload)}
  end

  defp digest_files(_root, files) do
    Enum.reduce_while(files, {:ok, :crypto.hash_init(:sha256), 0}, fn {relative, path},
                                                                      {:ok, hash, bytes} ->
      case File.read(path) do
        {:ok, body} ->
          file_digest = :crypto.hash(:sha256, body)
          framed = [relative, <<0>>, file_digest, <<0>>]
          {:cont, {:ok, :crypto.hash_update(hash, framed), bytes + byte_size(body)}}

        {:error, reason} ->
          {:halt, {:error, BackendFailure.translate(reason, :digest_backup_payload)}}
      end
    end)
    |> case do
      {:ok, hash, bytes} ->
        {:ok,
         %{
           sha256: hash |> :crypto.hash_final() |> Base.encode16(case: :lower),
           bytes: bytes,
           file_count: length(files)
         }}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp write_private(path, body) do
    with :ok <- File.write(path, body, [:binary, :sync]),
         :ok <- File.chmod(path, 0o600) do
      :ok
    else
      {:error, reason} -> {:error, BackendFailure.translate(reason, :write_backup_artifact)}
    end
  end

  defp read_file(path) do
    with {:ok, %{type: :regular}} <- File.lstat(path),
         {:ok, body} <- File.read(path) do
      {:ok, body}
    else
      {:ok, _stat} -> {:error, Error.new(:corrupt, :read_backup_artifact)}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :read_backup_artifact)}
    end
  end

  defp private_directory(path) do
    with :ok <- File.mkdir_p(path),
         :ok <- File.chmod(path, 0o700) do
      :ok
    else
      {:error, reason} -> {:error, BackendFailure.translate(reason, :prepare_backup_artifact)}
    end
  end

  defp private_artifact_directory(path) do
    with :ok <- File.mkdir(path),
         :ok <- File.chmod(path, 0o700) do
      :ok
    else
      {:error, reason} -> {:error, BackendFailure.translate(reason, :prepare_backup_artifact)}
    end
  end

  defp make_tree_private(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reduce_while(File.chmod(root, 0o700), fn path, :ok ->
      mode = if File.dir?(path), do: 0o700, else: 0o600

      case File.chmod(path, mode) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, BackendFailure.translate(reason, :secure_restore_candidate)}
    end
  end

  defp validate_artifact_id(value) when is_binary(value) do
    if Regex.match?(@artifact_pattern, value) do
      :ok
    else
      {:error, Error.new(:invalid_input, :validate_restore_artifact)}
    end
  end

  defp validate_artifact_id(_value) do
    {:error, Error.new(:invalid_input, :validate_restore_artifact)}
  end

  defp verify_manifest_identity(manifest, artifact_id) do
    if manifest.artifact_id == artifact_id do
      :ok
    else
      {:error, Error.new(:corrupt, :validate_restore_artifact)}
    end
  end

  defp verify_manifest_compatibility(manifest, schema_version) do
    if BackupManifest.compatible?(manifest, schema_version) do
      :ok
    else
      {:error, Error.new(:incompatible, :validate_restore_artifact)}
    end
  end

  defp verify_payload_digest(manifest, digest) do
    if digest.sha256 == manifest.payload_sha256 and
         digest.bytes == manifest.payload_bytes and
         digest.file_count == manifest.file_count do
      :ok
    else
      {:error, Error.new(:corrupt, :validate_restore_artifact)}
    end
  end

  defp artifact_id do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%dT%H%M%SZ")
    "artifact-#{timestamp}-#{random_hex(8)}"
  end

  defp random_hex(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

  defp remove_tree(path) do
    case File.rm_rf(path) do
      {:ok, _paths} -> :ok
      {:error, _reason, _path} -> :ok
    end
  end

  @doc false
  def architecture_file_role, do: @architecture_file_role
end

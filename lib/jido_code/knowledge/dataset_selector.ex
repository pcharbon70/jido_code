defmodule JidoCode.Knowledge.DatasetSelector do
  @moduledoc false

  @architecture_file_role :graph_backup

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error

  @selector_file "ACTIVE"
  @legacy_id "active"
  @dataset_pattern ~r/^dataset-restore-[0-9a-f]{16}$/

  @type selection :: %{id: String.t(), path: Path.t()}

  @spec current(JidoCode.Knowledge.Config.t()) :: {:ok, selection()} | {:error, Error.t()}
  def current(config) do
    selector = Path.join(config.root, @selector_file)

    case File.read(selector) do
      {:ok, encoded} -> decode_selection(config, String.trim(encoded))
      {:error, :enoent} -> legacy_selection(config)
      {:error, reason} -> {:error, BackendFailure.translate(reason, :read_dataset_selector)}
    end
  end

  @spec dataset_path(JidoCode.Knowledge.Config.t(), String.t()) ::
          {:ok, Path.t()} | {:error, Error.t()}
  def dataset_path(config, @legacy_id), do: {:ok, Path.join(config.root, @legacy_id)}

  def dataset_path(config, dataset_id) when is_binary(dataset_id) do
    if Regex.match?(@dataset_pattern, dataset_id) do
      {:ok, Path.join([config.root, "datasets", dataset_id])}
    else
      {:error, Error.new(:invalid_input, :validate_dataset_selector)}
    end
  end

  def dataset_path(_config, _dataset_id) do
    {:error, Error.new(:invalid_input, :validate_dataset_selector)}
  end

  @spec activate(JidoCode.Knowledge.Config.t(), String.t()) :: :ok | {:error, Error.t()}
  def activate(config, dataset_id) do
    with {:ok, dataset_path} <- dataset_path(config, dataset_id),
         true <- private_directory?(dataset_path),
         :ok <- write_selector(config, dataset_id) do
      :ok
    else
      false -> {:error, Error.new(:invalid_input, :activate_dataset_selector)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp decode_selection(config, dataset_id) do
    with {:ok, path} <- dataset_path(config, dataset_id),
         true <- private_directory?(path) do
      {:ok, %{id: dataset_id, path: path}}
    else
      false -> {:error, Error.new(:corrupt, :read_dataset_selector)}
      {:error, %Error{}} -> {:error, Error.new(:corrupt, :read_dataset_selector)}
    end
  end

  defp legacy_selection(config) do
    path = Path.join(config.root, @legacy_id)

    case File.lstat(path) do
      {:ok, %{type: :directory}} -> {:ok, %{id: @legacy_id, path: path}}
      {:error, :enoent} -> {:ok, %{id: @legacy_id, path: path}}
      _invalid -> {:error, Error.new(:corrupt, :read_dataset_selector)}
    end
  end

  defp private_directory?(path) do
    case File.lstat(path) do
      {:ok, %{type: :directory}} -> true
      _other -> false
    end
  end

  defp write_selector(config, dataset_id) do
    selector = Path.join(config.root, @selector_file)
    temporary = selector <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive]))

    with :ok <- File.write(temporary, dataset_id <> "\n", [:binary, :sync]),
         :ok <- File.chmod(temporary, 0o600),
         :ok <- File.rename(temporary, selector) do
      :ok
    else
      {:error, reason} ->
        File.rm(temporary)
        {:error, BackendFailure.translate(reason, :activate_dataset_selector)}
    end
  end

  def architecture_file_role, do: @architecture_file_role
end

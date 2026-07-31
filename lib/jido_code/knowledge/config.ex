defmodule JidoCode.Knowledge.Config do
  @moduledoc """
  Trusted runtime configuration for the authoritative embedded graph store.

  Paths come only from application configuration or internal test support.
  Request and user data must never be passed to this module.
  """

  alias JidoCode.Knowledge.Error

  @supported_schema_version 1
  @default_open_timeout 15_000

  @enforce_keys [
    :enabled?,
    :runtime_mode,
    :schema,
    :schema_version,
    :durability,
    :open_timeout
  ]
  defstruct [
    :root,
    :backup_root,
    :test_instance_id,
    :lineage_iri,
    enabled?: true,
    runtime_mode: :prod,
    schema: :quad,
    schema_version: @supported_schema_version,
    durability: :sync,
    open_timeout: @default_open_timeout
  ]

  @type runtime_mode :: :dev | :test | :prod

  @type t :: %__MODULE__{
          root: Path.t() | nil,
          backup_root: Path.t() | nil,
          enabled?: boolean(),
          runtime_mode: runtime_mode(),
          schema: :quad,
          schema_version: pos_integer(),
          durability: :sync,
          open_timeout: pos_integer(),
          test_instance_id: String.t() | nil,
          lineage_iri: String.t() | nil
        }

  @spec load(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def load(overrides \\ []) when is_list(overrides) do
    configured = Application.get_env(:jido_code, :knowledge_store, [])
    options = Keyword.merge(configured, overrides)

    with {:ok, config} <- build(options),
         :ok <- validate_contract(config),
         :ok <- validate_paths(config) do
      {:ok, config}
    end
  end

  @spec for_test(Path.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def for_test(root, overrides \\ []) when is_binary(root) and is_list(overrides) do
    instance_id =
      Keyword.get_lazy(overrides, :test_instance_id, fn ->
        "case-#{System.unique_integer([:positive, :monotonic])}"
      end)

    test_options = [
      enabled: true,
      runtime_mode: :test,
      root: Path.expand(root),
      backup_root:
        root
        |> Path.dirname()
        |> Path.join(Path.basename(root) <> "-backups")
        |> Path.expand(),
      test_instance_id: instance_id
    ]

    load(Keyword.merge(test_options, overrides))
  end

  @spec prepare_directories(t()) :: :ok | {:error, Error.t()}
  def prepare_directories(%__MODULE__{enabled?: false}), do: :ok

  def prepare_directories(%__MODULE__{} = config) do
    with :ok <- create_private_directory(config.root, :prepare_store_root),
         :ok <- create_private_directory(config.backup_root, :prepare_backup_root),
         :ok <- reject_symlink_components(config.root, :validate_store_root),
         :ok <- reject_symlink_components(config.backup_root, :validate_backup_root),
         :ok <- reject_world_writable(config.root, :validate_store_root),
         :ok <- reject_world_writable(config.backup_root, :validate_backup_root) do
      :ok
    end
  end

  @spec active_store_path(t()) :: Path.t()
  def active_store_path(%__MODULE__{root: root}) when is_binary(root) do
    Path.join(root, "active")
  end

  @spec supported_schema_version() :: pos_integer()
  def supported_schema_version, do: @supported_schema_version

  defp build(options) do
    runtime_mode = Keyword.get(options, :runtime_mode, runtime_mode())
    enabled? = Keyword.get(options, :enabled, true)

    config = %__MODULE__{
      root: normalize_path(Keyword.get(options, :root)),
      backup_root: normalize_path(Keyword.get(options, :backup_root)),
      enabled?: enabled?,
      runtime_mode: runtime_mode,
      schema: Keyword.get(options, :schema, :quad),
      schema_version: Keyword.get(options, :schema_version, @supported_schema_version),
      durability: Keyword.get(options, :durability, :sync),
      open_timeout: Keyword.get(options, :open_timeout, @default_open_timeout),
      test_instance_id: Keyword.get(options, :test_instance_id),
      lineage_iri: Keyword.get(options, :lineage_iri)
    }

    {:ok, config}
  rescue
    _error -> {:error, Error.new(:invalid_input, :load_store_config)}
  end

  defp validate_contract(%__MODULE__{enabled?: enabled?}) when not is_boolean(enabled?) do
    {:error, Error.new(:invalid_input, :validate_store_enabled)}
  end

  defp validate_contract(%__MODULE__{enabled?: false}), do: :ok

  defp validate_contract(%__MODULE__{} = config) do
    cond do
      config.runtime_mode not in [:dev, :test, :prod] ->
        {:error, Error.new(:invalid_input, :validate_runtime_mode)}

      config.schema != :quad ->
        {:error, Error.new(:incompatible, :validate_store_schema)}

      config.schema_version != @supported_schema_version ->
        {:error, Error.new(:incompatible, :validate_store_schema_version)}

      config.durability != :sync ->
        {:error, Error.new(:incompatible, :validate_store_durability)}

      not is_integer(config.open_timeout) or config.open_timeout < 100 or
          config.open_timeout > 120_000 ->
        {:error, Error.new(:invalid_input, :validate_store_open_timeout)}

      not valid_optional_lineage?(config.lineage_iri) ->
        {:error, Error.new(:invalid_input, :validate_dataset_lineage)}

      true ->
        validate_test_contract(config)
    end
  end

  defp validate_test_contract(%__MODULE__{runtime_mode: :test} = config) do
    temporary_root = Path.expand(System.tmp_dir!())

    cond do
      not is_binary(config.test_instance_id) or config.test_instance_id == "" ->
        {:error, Error.new(:invalid_input, :validate_test_store_identity)}

      not descendant?(config.root, temporary_root) ->
        {:error, Error.new(:invalid_input, :validate_test_store_root)}

      not descendant?(config.backup_root, temporary_root) ->
        {:error, Error.new(:invalid_input, :validate_test_backup_root)}

      true ->
        :ok
    end
  end

  defp validate_test_contract(%__MODULE__{}), do: :ok

  defp validate_paths(%__MODULE__{enabled?: false}), do: :ok

  defp validate_paths(%__MODULE__{} = config) do
    with :ok <- validate_root(config.root, :validate_store_root),
         :ok <- validate_root(config.backup_root, :validate_backup_root),
         :ok <- reject_overlapping_roots(config.root, config.backup_root) do
      :ok
    end
  end

  defp validate_root(path, operation) when is_binary(path) do
    workspace = Path.expand(File.cwd!())
    home = System.user_home!() |> Path.expand()

    cond do
      String.contains?(path, <<0>>) ->
        {:error, Error.new(:invalid_input, operation)}

      Path.type(path) != :absolute ->
        {:error, Error.new(:invalid_input, operation)}

      ".." in Path.split(path) ->
        {:error, Error.new(:invalid_input, operation)}

      path in [Path.expand("/"), workspace, home, Path.expand(System.tmp_dir!())] ->
        {:error, Error.new(:invalid_input, operation)}

      true ->
        with :ok <- reject_symlink_components(path, operation),
             :ok <- reject_world_writable(path, operation) do
          :ok
        end
    end
  end

  defp validate_root(_path, operation), do: {:error, Error.new(:invalid_input, operation)}

  defp reject_overlapping_roots(root, backup_root) do
    if descendant_or_same?(root, backup_root) or descendant_or_same?(backup_root, root) do
      {:error, Error.new(:invalid_input, :validate_store_root_separation)}
    else
      :ok
    end
  end

  defp reject_symlink_components(path, operation) do
    if Enum.any?(path_ancestors(path), &symlink?/1) do
      {:error, Error.new(:invalid_input, operation)}
    else
      :ok
    end
  end

  defp reject_world_writable(path, operation) do
    case File.stat(path) do
      {:ok, stat} ->
        if Bitwise.band(stat.mode, 0o002) == 0 do
          :ok
        else
          {:error, Error.new(:invalid_input, operation)}
        end

      {:error, :enoent} ->
        :ok

      {:error, _reason} ->
        {:error, Error.new(:persistence_failure, operation)}
    end
  end

  defp create_private_directory(path, operation) do
    with :ok <- File.mkdir_p(path),
         :ok <- File.chmod(path, 0o700) do
      :ok
    else
      {:error, _reason} -> {:error, Error.new(:persistence_failure, operation)}
    end
  end

  defp path_ancestors(path) do
    path
    |> Stream.iterate(&Path.dirname/1)
    |> Enum.reduce_while([], fn current, acc ->
      parent = Path.dirname(current)
      next = [current | acc]

      if parent == current, do: {:halt, next}, else: {:cont, next}
    end)
  end

  defp symlink?(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} -> true
      _other -> false
    end
  end

  defp descendant?(path, parent) when is_binary(path) and is_binary(parent) do
    prefix = if parent == "/", do: "/", else: parent <> "/"
    path != parent and String.starts_with?(path, prefix)
  end

  defp descendant?(_path, _parent), do: false

  defp descendant_or_same?(path, parent), do: path == parent or descendant?(path, parent)

  defp normalize_path(nil), do: nil

  defp normalize_path(path) when is_binary(path) do
    if Path.type(path) == :absolute and ".." not in Path.split(path) do
      Path.expand(path)
    else
      path
    end
  end

  defp normalize_path(_path), do: nil

  defp valid_optional_lineage?(nil), do: true

  defp valid_optional_lineage?(lineage) when is_binary(lineage) do
    Regex.match?(~r/^urn:jido-code:lineage:[A-Za-z0-9_-]{8,128}$/, lineage)
  end

  defp valid_optional_lineage?(_lineage), do: false

  defp runtime_mode do
    Application.get_env(:jido_code, :runtime_mode, :prod)
  end
end

defmodule JidoCode.Knowledge.ConfigTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  test "prepares isolated test roots with private permissions", %{root: root} do
    store_root = Path.join(root, "store")
    assert {:ok, config} = Config.for_test(store_root)
    assert config.runtime_mode == :test
    assert config.schema == :quad
    assert config.durability == :sync
    assert config.root != config.backup_root

    assert :ok = Config.prepare_directories(config)
    assert private_directory?(config.root)
    assert private_directory?(config.backup_root)
    assert Config.active_store_path(config) == Path.join(config.root, "active")
  end

  test "rejects broad, relative, traversing, and overlapping roots", %{root: root} do
    backup = Path.join(root, "backup")

    for invalid_root <- [
          "/",
          System.user_home!(),
          File.cwd!(),
          System.tmp_dir!(),
          "relative/store"
        ] do
      assert {:error, %Error{kind: :invalid_input}} =
               load_paths(invalid_root, backup)
    end

    assert {:error, %Error{kind: :invalid_input}} =
             load_paths(Path.join(root, "../escape"), backup)

    assert {:error, %Error{kind: :invalid_input}} =
             load_paths(Path.join(root, "store"), Path.join(root, "store/backups"))
  end

  test "rejects symlink and world-writable targets", %{root: root} do
    target = Path.join(root, "target")
    symlink = Path.join(root, "symlink")
    backup = Path.join(root, "backup")
    File.mkdir_p!(target)
    File.ln_s!(target, symlink)

    assert {:error, %Error{kind: :invalid_input}} = load_paths(symlink, backup)

    world_writable = Path.join(root, "world-writable")
    File.mkdir_p!(world_writable)
    File.chmod!(world_writable, 0o777)

    assert {:error, %Error{kind: :invalid_input}} = load_paths(world_writable, backup)
  end

  test "requires unique temporary test identity and rejects production path reuse", %{root: root} do
    assert {:error, %Error{kind: :invalid_input, operation: :validate_test_store_identity}} =
             Config.load(
               enabled: true,
               runtime_mode: :test,
               root: Path.join(root, "store"),
               backup_root: Path.join(root, "backup")
             )

    assert {:error, %Error{kind: :invalid_input, operation: :validate_test_store_root}} =
             Config.load(
               enabled: true,
               runtime_mode: :test,
               root: "/var/lib/jido_code/test-reuse",
               backup_root: Path.join(root, "backup"),
               test_instance_id: "isolated-case"
             )
  end

  test "rejects unsupported storage contracts", %{root: root} do
    base = [
      enabled: true,
      runtime_mode: :dev,
      root: Path.join(root, "store"),
      backup_root: Path.join(root, "backup")
    ]

    assert {:error, %Error{kind: :incompatible, operation: :validate_store_schema}} =
             Config.load(Keyword.put(base, :schema, :triple))

    assert {:error, %Error{kind: :incompatible, operation: :validate_store_schema_version}} =
             Config.load(Keyword.put(base, :schema_version, 2))

    assert {:error, %Error{kind: :incompatible, operation: :validate_store_durability}} =
             Config.load(Keyword.put(base, :durability, :async))

    assert {:error, %Error{kind: :invalid_input, operation: :validate_store_open_timeout}} =
             Config.load(Keyword.put(base, :open_timeout, 0))
  end

  defp load_paths(root, backup_root) do
    Config.load(
      enabled: true,
      runtime_mode: :dev,
      root: root,
      backup_root: backup_root
    )
  end

  defp private_directory?(path) do
    case File.stat(path) do
      {:ok, %{type: :directory, mode: mode}} -> Bitwise.band(mode, 0o077) == 0
      _other -> false
    end
  end

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-config-#{name}-#{unique}")
  end
end

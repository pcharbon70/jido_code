defmodule JidoCode.Runtime.JidoHarness.ExecutableRegistry do
  @moduledoc "Closed executable registry with ownership, path, digest, and version verification."

  import Bitwise

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.CodexRelease

  @architecture_file_role :temporary
  @max_executable_bytes 512 * 1_024 * 1_024

  @spec descriptor(String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def descriptor("codex_cli") do
    root = codex_root()

    {:ok,
     %{
       key: "codex_cli",
       path: Path.join(root, "codex"),
       installation_root: root,
       sha256: CodexRelease.executable_sha256(),
       version: CodexRelease.cli_version(),
       version_prefix: "codex-cli "
     }}
  end

  def descriptor(_key), do: invalid(:delegated_executable_registry)

  @spec resolve(String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def resolve(key) do
    with {:ok, descriptor} <- descriptor(key), do: verify(descriptor)
  end

  @doc false
  @spec verify(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def verify(descriptor) when is_map(descriptor) do
    path = descriptor[:path]
    root = descriptor[:installation_root]

    with :ok <- bounded_absolute(path, :delegated_executable_path),
         :ok <- bounded_absolute(root, :delegated_executable_root),
         true <- Path.dirname(path) == Path.expand(root),
         {:ok, stat} <- File.lstat(path, time: :posix),
         :regular <- stat.type,
         true <- stat.size in 1..@max_executable_bytes,
         true <- executable_mode?(stat.mode),
         {:ok, root_stat} <- File.stat(root, time: :posix),
         true <- stat.uid == root_stat.uid,
         {:ok, digest} <- file_digest(path),
         true <- secure_compare?(digest, descriptor[:sha256]),
         {:ok, version} <- executable_version(path, descriptor[:version_prefix]),
         true <- version == descriptor[:version] do
      {:ok,
       %{
         key: descriptor[:key],
         path: path,
         installation_root: root,
         sha256: digest,
         version: version,
         owner_uid: stat.uid,
         mode: stat.mode
       }}
    else
      {:error, _reason} -> unavailable(:delegated_executable_verification)
      _invalid -> incompatible(:delegated_executable_verification)
    end
  rescue
    _error -> unavailable(:delegated_executable_verification)
  end

  def verify(_descriptor), do: invalid(:delegated_executable_verification)

  @doc false
  def architecture_file_role, do: @architecture_file_role

  defp codex_root do
    Path.join([
      System.user_home!(),
      ".codex",
      "packages",
      "standalone",
      "releases",
      "0.144.6-x86_64-unknown-linux-musl",
      "bin"
    ])
  end

  defp bounded_absolute(value, _operation)
       when is_binary(value) and byte_size(value) in 1..1_024 do
    if Path.type(value) == :absolute and Path.expand(value) == value, do: :ok, else: :error
  end

  defp bounded_absolute(_value, _operation), do: :error

  defp executable_mode?(mode), do: (mode &&& 0o111) != 0 and (mode &&& 0o022) == 0

  defp file_digest(path) do
    digest =
      path
      |> File.stream!(1_048_576, [])
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    {:ok, digest}
  rescue
    _error -> {:error, :read_failed}
  end

  defp executable_version(path, prefix) when is_binary(prefix) do
    case System.cmd(path, ["--version"], stderr_to_stdout: true, env: [], cd: Path.dirname(path)) do
      {output, 0} ->
        output = String.trim(output)

        if String.starts_with?(output, prefix) and byte_size(output) <= 128 do
          {:ok, String.replace_prefix(output, prefix, "")}
        else
          {:error, :version_mismatch}
        end

      {_output, _status} ->
        {:error, :version_failed}
    end
  rescue
    _error -> {:error, :version_failed}
  end

  defp secure_compare?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right),
       do: Plug.Crypto.secure_compare(left, right)

  defp secure_compare?(_left, _right), do: false

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp incompatible(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end

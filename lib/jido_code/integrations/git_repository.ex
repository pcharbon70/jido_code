defmodule JidoCode.Integrations.GitRepository do
  @moduledoc """
  Hardened disposable Git adapter.

  Commands execute without a shell, system/global Git configuration,
  credential helpers, interactive prompts, hooks, or LFS smudging. Worktrees
  are operation-scoped caches and are never used as durable repository identity.
  """

  @behaviour JidoCode.Factory.Ports.Git

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Worktree

  @derive {Inspect,
           only: [
             :git_executable,
             :timeout_ms,
             :max_depth,
             :max_disk_bytes,
             :allow_local_fixture?
           ]}
  @enforce_keys [
    :operation_root,
    :git_executable,
    :timeout_ms,
    :max_depth,
    :max_disk_bytes,
    :allow_local_fixture?,
    :fixture_root,
    :command_runner,
    :clock
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @environment [
    {"GIT_CONFIG_NOSYSTEM", "1"},
    {"GIT_CONFIG_GLOBAL", "/dev/null"},
    {"GIT_TERMINAL_PROMPT", "0"},
    {"GIT_OPTIONAL_LOCKS", "0"},
    {"GIT_LFS_SKIP_SMUDGE", "1"},
    {"LC_ALL", "C"}
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(options) when is_list(options) do
    root = options |> Keyword.fetch!(:operation_root) |> Path.expand()
    executable = Keyword.get(options, :git_executable, "git")
    timeout = Keyword.get(options, :timeout_ms, 30_000)
    depth = Keyword.get(options, :max_depth, 50)
    disk = Keyword.get(options, :max_disk_bytes, 500_000_000)
    allow_local = Keyword.get(options, :allow_local_fixture?, false)
    fixture_root = options |> Keyword.get(:fixture_root) |> expand_optional()
    runner = Keyword.get(options, :command_runner, &System.cmd/3)
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)

    with true <- Path.type(root) == :absolute,
         true <- is_binary(executable) and byte_size(executable) in 1..256,
         true <- is_integer(timeout) and timeout in 100..120_000,
         true <- is_integer(depth) and depth in 1..1_000,
         true <- is_integer(disk) and disk in 1_000_000..10_000_000_000,
         true <- is_boolean(allow_local),
         true <- not allow_local or valid_fixture_root?(fixture_root),
         true <- is_function(runner, 3),
         true <- is_function(clock, 0) do
      {:ok,
       %__MODULE__{
         operation_root: root,
         git_executable: executable,
         timeout_ms: timeout,
         max_depth: depth,
         max_disk_bytes: disk,
         allow_local_fixture?: allow_local,
         fixture_root: fixture_root,
         command_runner: runner,
         clock: clock
       }}
    else
      _invalid -> invalid(:git_adapter_config)
    end
  rescue
    _error -> invalid(:git_adapter_config)
  end

  @impl true
  def materialize(%__MODULE__{} = adapter, request) when is_map(request) do
    remote = request[:remote]
    ref = request[:ref]
    operation_id = request[:operation_id]
    depth = Map.get(request, :depth, adapter.max_depth)

    with :ok <- validate_remote(remote, adapter),
         true <- valid_ref?(ref),
         true <- valid_operation_id?(operation_id),
         true <- is_integer(depth) and depth in 1..adapter.max_depth,
         :ok <- ensure_root(adapter.operation_root),
         {:ok, target} <- operation_path(adapter.operation_root, operation_id, remote),
         false <- File.exists?(target),
         :ok <- clone(adapter, remote, ref, target, depth),
         :ok <- disk_with_cleanup(target, adapter.max_disk_bytes),
         %DateTime{} = created_at <- adapter.clock.() do
      {:ok,
       %Worktree{
         operation_id: operation_id,
         remote_digest: digest(remote),
         ref: ref,
         created_at: DateTime.truncate(created_at, :microsecond),
         path: target
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      true -> {:error, AdapterError.new(:conflict, :git_operation_path)}
      _invalid -> invalid(:git_materialize)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :git_materialize)}
  end

  def materialize(_adapter, _request), do: invalid(:git_materialize)

  @impl true
  def inspect_snapshot(%__MODULE__{} = adapter, %Worktree{} = worktree) do
    with :ok <- contained_path(adapter.operation_root, worktree.path),
         {:ok, commit_sha} <- git_output(adapter, worktree.path, ["rev-parse", "HEAD"]),
         {:ok, tree_sha} <- git_output(adapter, worktree.path, ["rev-parse", "HEAD^{tree}"]),
         {:ok, lineage} <-
           git_output(adapter, worktree.path, ["rev-list", "--parents", "-n", "1", "HEAD"]),
         {:ok, status} <- git_output(adapter, worktree.path, ["status", "--porcelain=v1"]),
         {:ok, format} <- object_format(adapter, worktree.path),
         %DateTime{} = observed_at <- adapter.clock.(),
         {:ok, snapshot} <-
           GitSnapshot.new(%{
             commit_sha: commit_sha,
             tree_sha: tree_sha,
             parents: lineage |> String.split() |> Enum.drop(1),
             ref: worktree.ref,
             object_format: format,
             submodules?: File.regular?(Path.join(worktree.path, ".gitmodules")),
             lfs?: lfs?(worktree.path),
             clean?: status == "",
             observed_at: observed_at,
             limitations: []
           }) do
      {:ok, snapshot}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :git_snapshot_inspection)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :git_snapshot_inspection)}
  end

  def inspect_snapshot(_adapter, _worktree), do: invalid(:git_snapshot_inspection)

  @impl true
  def cleanup(%__MODULE__{} = adapter, %Worktree{} = worktree) do
    with :ok <- contained_path(adapter.operation_root, worktree.path),
         {:ok, _entries} <- File.rm_rf(worktree.path) do
      :ok
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unavailable, :git_cleanup)}
    end
  end

  def cleanup(_adapter, _worktree), do: invalid(:git_cleanup)

  @spec compare_revision(String.t(), GitSnapshot.t()) :: :match | {:contradiction, map()}
  def compare_revision(advertised_sha, %GitSnapshot{} = snapshot)
      when is_binary(advertised_sha) do
    if String.downcase(advertised_sha) == snapshot.commit_sha do
      :match
    else
      {:contradiction,
       %{
         kind: :provider_git_revision_mismatch,
         provider_revision_digest: digest(String.downcase(advertised_sha)),
         git_revision: snapshot.commit_sha
       }}
    end
  end

  defp clone(adapter, remote, ref, target, depth) do
    prefix =
      hardened_prefix(if(local_fixture?(remote, adapter), do: "always", else: "never"))

    clone_args =
      prefix ++
        [
          "clone",
          "--no-checkout",
          "--depth",
          Integer.to_string(depth),
          "--filter=blob:none",
          "--",
          remote,
          target
        ]

    with {:ok, _output} <- run(adapter, clone_args),
         {:ok, _output} <-
           run(
             adapter,
             prefix ++
               ["-C", target, "fetch", "--depth", Integer.to_string(depth), "origin", ref]
           ),
         {:ok, _output} <-
           run(adapter, prefix ++ ["-C", target, "checkout", "--detach", "FETCH_HEAD"]) do
      :ok
    else
      {:error, %AdapterError{} = error} ->
        File.rm_rf(target)
        {:error, error}
    end
  end

  defp git_output(adapter, path, args) do
    with {:ok, output} <- run(adapter, hardened_prefix("never") ++ ["-C", path | args]) do
      {:ok, String.trim(output)}
    end
  end

  defp object_format(adapter, path) do
    case git_output(adapter, path, ["rev-parse", "--show-object-format"]) do
      {:ok, "sha1"} -> {:ok, :sha1}
      {:ok, "sha256"} -> {:ok, :sha256}
      _unsupported -> {:ok, :sha1}
    end
  end

  defp run(adapter, args) do
    task =
      Task.async(fn ->
        adapter.command_runner.(adapter.git_executable, args,
          env: @environment,
          stderr_to_stdout: true
        )
      end)

    case Task.yield(task, adapter.timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {_output, 0} = result} -> {:ok, elem(result, 0)}
      {:ok, {_output, _status}} -> {:error, AdapterError.new(:unavailable, :git_command)}
      nil -> {:error, AdapterError.new(:timeout, :git_command)}
      _invalid -> {:error, AdapterError.new(:unavailable, :git_command)}
    end
  end

  defp hardened_prefix(file_protocol) when file_protocol in ["always", "never"] do
    [
      "-c",
      "credential.helper=",
      "-c",
      "core.hooksPath=/dev/null",
      "-c",
      "protocol.file.allow=#{file_protocol}"
    ]
  end

  defp validate_remote(remote, adapter) when is_binary(remote) do
    cond do
      local_fixture?(remote, adapter) -> :ok
      safe_https_remote?(remote) -> :ok
      safe_ssh_remote?(remote) -> :ok
      true -> invalid(:git_remote)
    end
  end

  defp validate_remote(_remote, _adapter), do: invalid(:git_remote)

  defp safe_https_remote?(remote) do
    uri = URI.parse(remote)

    uri.scheme == "https" and is_binary(uri.host) and is_nil(uri.userinfo) and
      is_binary(uri.path) and uri.path != "" and is_nil(uri.query) and is_nil(uri.fragment)
  end

  defp safe_ssh_remote?(remote) do
    uri = URI.parse(remote)

    (uri.scheme == "ssh" and is_binary(uri.host) and uri.userinfo in [nil, "git"] and
       is_binary(uri.path) and uri.path != "" and is_nil(uri.query) and is_nil(uri.fragment)) or
      Regex.match?(~r/^git@[A-Za-z0-9.-]+:[A-Za-z0-9._\/-]+$/, remote)
  end

  defp local_fixture?(remote, %{allow_local_fixture?: true, fixture_root: root}) do
    expanded = Path.expand(remote)
    contained?(root, expanded) and File.dir?(expanded)
  end

  defp local_fixture?(_remote, _adapter), do: false

  defp valid_ref?(ref) do
    is_binary(ref) and byte_size(ref) in 1..256 and
      (ref == "HEAD" or
         Regex.match?(~r/^refs\/(?:heads|tags)\/[A-Za-z0-9][A-Za-z0-9._\/-]*$/, ref) or
         Regex.match?(~r/^[a-fA-F0-9]{40}(?:[a-fA-F0-9]{24})?$/, ref)) and
      not String.contains?(ref, ["..", "@{", "//"])
  end

  defp valid_operation_id?(value) do
    is_binary(value) and Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/, value)
  end

  defp operation_path(root, operation_id, remote) do
    target = Path.join(root, operation_id <> "-" <> binary_part(digest(remote), 0, 12))

    case contained_path(root, target) do
      :ok -> {:ok, target}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  defp contained_path(root, path) do
    if contained?(Path.expand(root), Path.expand(path)), do: :ok, else: invalid(:git_path)
  end

  defp contained?(root, path), do: path == root or String.starts_with?(path, root <> "/")

  defp ensure_root(root) do
    case File.mkdir_p(root) do
      :ok -> :ok
      {:error, _reason} -> {:error, AdapterError.new(:unavailable, :git_operation_root)}
    end
  end

  defp disk_within_limit(path, limit) do
    case directory_size(path, limit) do
      {:ok, size} when size <= limit -> :ok
      {:ok, _size} -> {:error, AdapterError.new(:invalid_input, :git_disk_limit)}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  defp disk_with_cleanup(path, limit) do
    case disk_within_limit(path, limit) do
      :ok ->
        :ok

      {:error, %AdapterError{} = error} ->
        File.rm_rf(path)
        {:error, error}
    end
  end

  defp directory_size(root, limit) do
    walk_size([root], 0, limit, 0)
  end

  defp walk_size(_paths, _total, _limit, entries) when entries > 200_000,
    do: {:error, AdapterError.new(:invalid_input, :git_file_limit)}

  defp walk_size([], total, _limit, _entries), do: {:ok, total}
  defp walk_size(_paths, total, limit, _entries) when total > limit, do: {:ok, total}

  defp walk_size([path | rest], total, limit, entries) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} ->
        case File.ls(path) do
          {:ok, names} ->
            children = Enum.map(names, &Path.join(path, &1))
            walk_size(children ++ rest, total, limit, entries + 1)

          {:error, _reason} ->
            {:error, AdapterError.new(:unavailable, :git_disk_scan)}
        end

      {:ok, %File.Stat{size: size}} ->
        walk_size(rest, total + size, limit, entries + 1)

      {:error, _reason} ->
        {:error, AdapterError.new(:unavailable, :git_disk_scan)}
    end
  end

  defp lfs?(path) do
    attributes = Path.join(path, ".gitattributes")

    case File.stat(attributes) do
      {:ok, %File.Stat{size: size}} when size <= 100_000 ->
        attributes |> File.read!() |> String.contains?("filter=lfs")

      _missing_or_large ->
        false
    end
  rescue
    _error -> false
  end

  defp digest(value) do
    value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp expand_optional(nil), do: nil
  defp expand_optional(value) when is_binary(value), do: Path.expand(value)
  defp expand_optional(_value), do: :invalid
  defp valid_fixture_root?(root), do: is_binary(root) and Path.type(root) == :absolute
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

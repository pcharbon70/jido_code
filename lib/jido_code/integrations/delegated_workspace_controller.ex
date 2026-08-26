defmodule JidoCode.Integrations.DelegatedWorkspaceController do
  @moduledoc "Controller-owned custody, inspection, quarantine, and cleanup for DGA1 workspaces."

  use GenServer

  @architecture_file_role :external_worktree

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Integrations.GitWorkspace
  alias JidoCode.Security.Redactor

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @doc false
  def architecture_file_role, do: @architecture_file_role

  @spec provision(GenServer.server(), WorkspaceSpec.t()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def provision(server, %WorkspaceSpec{} = spec),
    do: GenServer.call(server, {:provision, spec}, :infinity)

  def provision(_server, _spec), do: invalid(:delegated_workspace_provision)

  @spec inspect_workspace(GenServer.server(), String.t(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def inspect_workspace(server, workspace_iri, current)
      when is_binary(workspace_iri) and is_map(current),
      do: GenServer.call(server, {:inspect, workspace_iri, current}, :infinity)

  def inspect_workspace(_server, _workspace_iri, _current),
    do: invalid(:delegated_workspace_inspect)

  @spec fetch(GenServer.server(), String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def fetch(server, workspace_iri) when is_binary(workspace_iri),
    do: GenServer.call(server, {:fetch, workspace_iri})

  def fetch(_server, _workspace_iri), do: invalid(:delegated_workspace_fetch)

  @spec check_environment(GenServer.server(), String.t()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def check_environment(server, workspace_iri) when is_binary(workspace_iri),
    do: GenServer.call(server, {:check_environment, workspace_iri})

  def check_environment(_server, _workspace_iri),
    do: invalid(:delegated_workspace_check_environment)

  @spec cleanup(GenServer.server(), String.t(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def cleanup(server, workspace_iri, current)
      when is_binary(workspace_iri) and is_map(current),
      do: GenServer.call(server, {:cleanup, workspace_iri, current}, :infinity)

  def cleanup(_server, _workspace_iri, _current), do: invalid(:delegated_workspace_cleanup)

  @impl true
  def init(options) do
    workspace_server = Keyword.get(options, :workspace_server)
    control_root = Keyword.get(options, :control_root)
    worker_identity = Keyword.get(options, :worker_identity, "jido-code-unprivileged")

    with true <- is_pid(workspace_server),
         :ok <- secure_control_root(control_root),
         true <- is_binary(worker_identity) and byte_size(worker_identity) in 1..128 do
      {:ok,
       %{
         workspace_server: workspace_server,
         control_root: control_root,
         worker_identity: worker_identity,
         workspaces: %{}
       }}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :delegated_workspace_controller)}
    end
  end

  @impl true
  def handle_call({:provision, spec}, _from, state) do
    with false <- Map.has_key?(state.workspaces, spec.iri),
         {:ok, workspace} <- GitWorkspace.provision(state.workspace_server, spec),
         {:ok, private} <- protect_git(workspace, spec, state),
         {:ok, receipt} <- inspect_private(private),
         public <- public_workspace(private, receipt) do
      private = %{private | public: public}
      {:reply, {:ok, public}, put_in(state, [:workspaces, spec.iri], private)}
    else
      true -> {:reply, conflict(:delegated_workspace_provision), state}
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, unavailable(:delegated_workspace_provision), state}
    end
  rescue
    _error -> {:reply, unavailable(:delegated_workspace_provision), state}
  end

  def handle_call({:inspect, workspace_iri, current}, _from, state) do
    with {:ok, private} <- Map.fetch(state.workspaces, workspace_iri),
         :ready <- private.public.status,
         :ok <- current(private.spec, current),
         {:ok, receipt} <- inspect_private(private) do
      public = public_workspace(private, receipt)
      private = %{private | public: public}
      {:reply, {:ok, receipt}, put_in(state, [:workspaces, workspace_iri], private)}
    else
      {:violation, reason} -> quarantine_reply(state, workspace_iri, reason)
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, unauthorized(:delegated_workspace_inspect), state}
    end
  rescue
    _error -> quarantine_reply(state, workspace_iri, :inspection_failure)
  end

  def handle_call({:fetch, workspace_iri}, _from, state) do
    reply =
      case Map.fetch(state.workspaces, workspace_iri) do
        {:ok, private} -> {:ok, private.public}
        :error -> unavailable(:delegated_workspace_fetch)
      end

    {:reply, reply, state}
  end

  def handle_call({:check_environment, workspace_iri}, _from, state) do
    reply =
      with {:ok, private} <- Map.fetch(state.workspaces, workspace_iri),
           :ready <- private.public.status do
        {:ok,
         %{
           "GIT_CONFIG_NOSYSTEM" => "1",
           "GIT_CONFIG_GLOBAL" => "/dev/null",
           "GIT_TERMINAL_PROMPT" => "0",
           "GIT_ASKPASS" => "/bin/false",
           "GIT_DIR" => private.git_dir,
           "GIT_WORK_TREE" => private.workspace.root
         }}
      else
        _invalid -> unauthorized(:delegated_workspace_check_environment)
      end

    {:reply, reply, state}
  end

  def handle_call({:cleanup, workspace_iri, current}, _from, state) do
    with {:ok, private} <- Map.fetch(state.workspaces, workspace_iri),
         :ok <- current(private.spec, current),
         :ok <- restore_git_marker(private),
         {:ok, receipt} <- GitWorkspace.cleanup(state.workspace_server, private.spec) do
      public = Map.merge(receipt, %{workspace_iri: workspace_iri, control_data_destroyed: true})
      {:reply, {:ok, public}, update_in(state, [:workspaces], &Map.delete(&1, workspace_iri))}
    else
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, unauthorized(:delegated_workspace_cleanup), state}
    end
  rescue
    _error -> {:reply, unavailable(:delegated_workspace_cleanup), state}
  end

  defp secure_control_root(root) when is_binary(root) do
    with true <- Path.type(root) == :absolute and Path.expand(root) == root,
         :ok <- File.mkdir_p(root),
         :ok <- File.chmod(root, 0o700),
         {:ok, %File.Stat{type: :directory}} <- File.lstat(root) do
      :ok
    else
      _invalid -> :error
    end
  end

  defp secure_control_root(_root), do: :error

  defp protect_git(workspace, spec, state) do
    marker = Path.join(workspace.root, ".git")
    custody = Path.join(state.control_root, WorkspaceDigest.digest(spec.iri) <> ".gitlink")

    with {:ok, %File.Stat{type: :regular}} <- File.lstat(marker),
         {:ok, content} <- File.read(marker),
         {:ok, git_dir} <- git_dir(content, workspace.root, spec.source_root),
         :ok <- File.rename(marker, custody),
         :ok <- File.chmod(custody, 0o600) do
      {:ok,
       %{
         spec: spec,
         workspace: workspace,
         custody: custody,
         git_dir: git_dir,
         worker_identity: state.worker_identity,
         public: nil
       }}
    else
      _invalid -> unavailable(:delegated_workspace_git_custody)
    end
  end

  defp git_dir("gitdir: " <> value, workspace_root, source_root) do
    path = String.trim(value)

    if Path.type(path) == :absolute and descendant?(path, source_root) and
         not descendant?(path, workspace_root) and File.dir?(path),
       do: {:ok, path},
       else: :error
  end

  defp git_dir(_content, _workspace_root, _source_root), do: :error

  defp inspect_private(private) do
    root = private.workspace.root
    limits = private.spec.limits

    with false <- File.exists?(Path.join(root, ".git")),
         {:ok, paths} <- filesystem_paths(root),
         true <- length(paths.regular) <= limits.file_count,
         true <- paths.bytes <= limits.disk_bytes,
         {:ok, status} <-
           git(private, [
             "status",
             "--porcelain=v1",
             "-z",
             "--untracked-files=all",
             "--no-renames"
           ]),
         changed = changed_paths(status),
         true <- length(changed) <= limits.changed_files,
         true <- Enum.all?(changed, &allowed_path?(&1, private.spec.allowed_paths)),
         :ok <- sensitive_changes(root, changed, limits.input_bytes),
         {:ok, patch} <-
           git(private, ["diff", "--binary", "--no-ext-diff", "--no-renames", "HEAD", "--"]),
         {:ok, untracked} <- untracked_evidence(root, changed, status),
         diff_bytes = byte_size(patch) + Enum.reduce(untracked, 0, &(&1.bytes + &2)),
         true <- diff_bytes <= limits.diff_bytes,
         {:ok, tree} <- WorkspaceDigest.tree(root, limits) do
      {:ok,
       %{
         status: :ready,
         workspace_iri: private.spec.iri,
         attempt_iri: private.spec.attempt_iri,
         lease_iri: private.spec.lease_iri,
         fencing_token: private.spec.fencing_token,
         snapshot_iri: private.spec.snapshot_iri,
         base_commit: private.spec.base_commit,
         workspace_digest: WorkspaceDigest.digest({private.spec.iri, tree.digest}),
         current_tree_digest: tree.digest,
         changed_paths: changed,
         changed_files: length(changed),
         diff_bytes: diff_bytes,
         diff_digest: WorkspaceDigest.digest({patch, untracked, changed}),
         file_count: tree.file_count,
         disk_bytes: tree.byte_count,
         git_control_data: :controller_custody,
         worker_identity: private.worker_identity,
         network: :deny,
         limits: limits
       }}
    else
      true -> {:violation, :git_control_data}
      false -> {:violation, :workspace_limit}
      {:special, reason} -> {:violation, reason}
      {:sensitive, _path} -> {:violation, :sensitive_content}
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:violation, :workspace_policy}
    end
  end

  defp filesystem_paths(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reduce_while({:ok, %{regular: [], bytes: 0}}, fn path, {:ok, state} ->
      case File.lstat(path) do
        {:ok, %File.Stat{type: :directory}} ->
          {:cont, {:ok, state}}

        {:ok, %File.Stat{type: :regular, size: size}} ->
          {:cont, {:ok, %{regular: [path | state.regular], bytes: state.bytes + size}}}

        {:ok, %File.Stat{type: :symlink}} ->
          {:halt, {:special, :symlink}}

        {:ok, %File.Stat{}} ->
          {:halt, {:special, :special_file}}

        _error ->
          {:halt, {:special, :filesystem_race}}
      end
    end)
  end

  defp sensitive_changes(root, changed, maximum) do
    Enum.reduce_while(changed, :ok, fn relative, :ok ->
      path = Path.join(root, relative)

      case File.lstat(path) do
        {:error, :enoent} ->
          {:cont, :ok}

        {:ok, %File.Stat{type: :regular, size: size}} when size <= maximum ->
          case File.read(path) do
            {:ok, content} ->
              case Redactor.reject_sensitive(content) do
                :ok -> {:cont, :ok}
                _sensitive -> {:halt, {:sensitive, relative}}
              end

            _error ->
              {:halt, {:special, :filesystem_race}}
          end

        _invalid ->
          {:halt, {:special, :input_limit}}
      end
    end)
  end

  defp changed_paths(status) do
    status
    |> String.split(<<0>>, trim: true)
    |> Enum.map(fn entry -> binary_part(entry, 3, byte_size(entry) - 3) end)
    |> Enum.sort()
  end

  defp allowed_path?(path, allowed) do
    Enum.any?(allowed, &(path == &1 or String.starts_with?(path, &1 <> "/")))
  end

  defp untracked_evidence(root, changed, status) do
    untracked =
      status
      |> String.split(<<0>>, trim: true)
      |> Enum.filter(&String.starts_with?(&1, "?? "))
      |> Enum.map(&binary_part(&1, 3, byte_size(&1) - 3))
      |> MapSet.new()

    changed
    |> Enum.filter(&MapSet.member?(untracked, &1))
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, entries} ->
      with {:ok, %File.Stat{type: :regular, size: size}} <- File.lstat(Path.join(root, path)),
           {:ok, content} <- File.read(Path.join(root, path)) do
        entry = %{path: path, bytes: size, digest: WorkspaceDigest.digest(content)}
        {:cont, {:ok, [entry | entries]}}
      else
        _invalid -> {:halt, {:special, :filesystem_race}}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp git(private, arguments) do
    environment = [
      {"GIT_CONFIG_NOSYSTEM", "1"},
      {"GIT_CONFIG_GLOBAL", "/dev/null"},
      {"GIT_TERMINAL_PROMPT", "0"},
      {"GIT_ASKPASS", "/bin/false"},
      {"SSH_AUTH_SOCK", nil},
      {"GIT_DIR", private.git_dir},
      {"GIT_WORK_TREE", private.workspace.root}
    ]

    case System.cmd("git", arguments,
           cd: private.workspace.root,
           env: environment,
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output}
      _failure -> unavailable(:delegated_workspace_git)
    end
  end

  defp public_workspace(private, receipt) do
    %{
      iri: private.spec.iri,
      root: private.workspace.root,
      status: receipt.status,
      snapshot_iri: private.spec.snapshot_iri,
      base_commit: private.spec.base_commit,
      workspace_digest: receipt.workspace_digest,
      current_tree_digest: receipt.current_tree_digest,
      changed_paths: receipt.changed_paths,
      git_control_data: :controller_custody,
      worker_identity: private.worker_identity,
      limits: private.spec.limits
    }
  end

  defp quarantine_reply(state, workspace_iri, reason) do
    case Map.fetch(state.workspaces, workspace_iri) do
      {:ok, private} ->
        _ = GitWorkspace.disposition(state.workspace_server, private.spec, :crash)
        public = Map.merge(private.public, %{status: :quarantined, quarantine_reason: reason})
        state = put_in(state, [:workspaces, workspace_iri, :public], public)
        {:reply, unauthorized(:delegated_workspace_quarantined), state}

      :error ->
        {:reply, unavailable(:delegated_workspace_inspect), state}
    end
  end

  defp restore_git_marker(private) do
    marker = Path.join(private.workspace.root, ".git")

    with :ok <- remove_untrusted_marker(marker),
         :ok <- File.rename(private.custody, marker) do
      :ok
    else
      _invalid -> unavailable(:delegated_workspace_git_restore)
    end
  end

  defp remove_untrusted_marker(marker) do
    case File.lstat(marker) do
      {:error, :enoent} -> :ok
      {:ok, _stat} -> marker |> File.rm_rf() |> normalize_remove()
      _error -> unavailable(:delegated_workspace_git_restore)
    end
  end

  defp normalize_remove({:ok, _paths}), do: :ok
  defp normalize_remove(_error), do: unavailable(:delegated_workspace_git_restore)

  defp current(spec, current) do
    if current[:attempt_iri] == spec.attempt_iri and current[:lease_iri] == spec.lease_iri and
         current[:fencing_token] == spec.fencing_token and
         current[:snapshot_iri] == spec.snapshot_iri and
         current[:lease_current?] == true,
       do: :ok,
       else: :error
  end

  defp descendant?(path, root) do
    relative = Path.relative_to(Path.expand(path), Path.expand(root))

    Path.type(relative) != :absolute and relative != "." and relative != ".." and
      not String.starts_with?(relative, "../")
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end

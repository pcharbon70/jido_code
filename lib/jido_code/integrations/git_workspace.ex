defmodule JidoCode.Integrations.GitWorkspace do
  @moduledoc "Disposable exact-commit Git worktree provider for managed coding."

  use Agent

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(options) do
    base = Keyword.fetch!(options, :base)
    Agent.start_link(fn -> %{base: base, workspaces: %{}} end)
  end

  @spec provision(Agent.agent(), WorkspaceSpec.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def provision(server, %WorkspaceSpec{} = spec) do
    commit = spec.base_commit

    with {:ok, base} <- base(server),
         :ok <- ensure_base(base),
         target = target(base, spec.iri),
         :ok <- absent(target),
         {:ok, ^commit} <- git(spec.source_root, ["rev-parse", "#{commit}^{commit}"]),
         {:ok, _output} <-
           git(spec.source_root, [
             "-c",
             "credential.helper=",
             "-c",
             "core.hooksPath=/dev/null",
             "worktree",
             "add",
             "--detach",
             target,
             commit
           ]),
         {:ok, ^commit} <- git(target, ["rev-parse", "HEAD"]),
         {:ok, tree} <- WorkspaceDigest.tree(target, spec.limits),
         workspace <- workspace(spec, target, tree),
         :ok <- put(server, workspace) do
      {:ok, workspace}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:conflict, :workspace_provision)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :workspace_provision)}
  end

  def provision(_server, _spec),
    do: {:error, AdapterError.new(:invalid_input, :workspace_provision)}

  @spec fetch(Agent.agent(), String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def fetch(server, iri) when is_binary(iri) do
    Agent.get(server, &Map.fetch(&1.workspaces, iri))
    |> case do
      {:ok, workspace} -> {:ok, workspace}
      :error -> {:error, AdapterError.new(:unavailable, :workspace_fetch)}
    end
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :workspace_fetch)}
  end

  @spec cleanup(Agent.agent(), WorkspaceSpec.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def cleanup(server, %WorkspaceSpec{} = spec) do
    with {:ok, workspace} <- fetch(server, spec.iri),
         {:ok, _output} <-
           git(spec.source_root, ["worktree", "remove", "--force", workspace.root]),
         :ok <- drop(server, spec.iri) do
      {:ok,
       %{
         status: :destroyed,
         cleanup_digest: WorkspaceDigest.digest({spec.iri, workspace.current_tree_digest})
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unavailable, :workspace_cleanup)}
    end
  end

  def cleanup(_server, _spec), do: {:error, AdapterError.new(:invalid_input, :workspace_cleanup)}

  @spec disposition(Agent.agent(), WorkspaceSpec.t(), atom()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def disposition(server, %WorkspaceSpec{} = spec, action)
      when action in [:hold, :cancel, :crash, :candidate_retention] do
    with {:ok, workspace} <- fetch(server, spec.iri) do
      status = if action in [:hold, :candidate_retention], do: :held, else: :quarantined
      updated = Map.merge(workspace, %{status: status, disposition: action})
      :ok = put(server, updated)
      {:ok, Map.take(updated, [:iri, :status, :disposition, :workspace_digest])}
    end
  end

  def disposition(_server, _spec, _action),
    do: {:error, AdapterError.new(:invalid_input, :workspace_disposition)}

  defp workspace(spec, target, tree) do
    pins =
      Map.take(spec, [
        :attempt_iri,
        :lease_iri,
        :fencing_token,
        :snapshot_iri,
        :base_commit,
        :sandbox_profile_revision
      ])

    %{
      iri: spec.iri,
      root: target,
      status: :ready,
      base_tree_digest: tree.digest,
      current_tree_digest: tree.digest,
      parent_directory_digest: WorkspaceDigest.digest(Path.dirname(target)),
      candidate_diff_digest: WorkspaceDigest.digest([]),
      cleanup_digest: WorkspaceDigest.digest({spec.iri, :cleanup}),
      workspace_digest: WorkspaceDigest.digest({pins, tree.digest}),
      file_count: tree.file_count,
      byte_count: tree.byte_count
    }
  end

  defp base(server) do
    case Agent.get(server, & &1.base) do
      base when is_binary(base) ->
        if Path.type(base) == :absolute,
          do: {:ok, base},
          else: {:error, AdapterError.new(:invalid_input, :workspace_base)}

      _invalid ->
        {:error, AdapterError.new(:invalid_input, :workspace_base)}
    end
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :workspace_base)}
  end

  defp ensure_base(base) do
    case File.mkdir_p(base) do
      :ok -> :ok
      _error -> {:error, AdapterError.new(:unavailable, :workspace_base)}
    end
  end

  defp absent(path) do
    case File.lstat(path) do
      {:error, :enoent} -> :ok
      _present -> {:error, AdapterError.new(:conflict, :workspace_identity)}
    end
  end

  defp put(server, workspace) do
    Agent.update(server, &put_in(&1, [:workspaces, workspace.iri], workspace))
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :workspace_state)}
  end

  defp drop(server, iri) do
    Agent.update(
      server,
      &update_in(&1, [:workspaces], fn workspaces -> Map.delete(workspaces, iri) end)
    )
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :workspace_state)}
  end

  defp target(base, iri), do: Path.join(base, WorkspaceDigest.digest(iri))

  defp git(root, arguments) do
    environment = [
      {"GIT_TERMINAL_PROMPT", "0"},
      {"GIT_ASKPASS", ""},
      {"SSH_AUTH_SOCK", ""},
      {"DOCKER_HOST", ""}
    ]

    task =
      Task.async(fn ->
        System.cmd("git", arguments,
          cd: root,
          env: environment,
          stderr_to_stdout: true
        )
      end)

    case Task.yield(task, 30_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} -> {:ok, String.trim(output)}
      _failure -> {:error, AdapterError.new(:unavailable, :workspace_git)}
    end
  end
end

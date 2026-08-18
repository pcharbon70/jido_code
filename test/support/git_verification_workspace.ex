defmodule JidoCode.TestSupport.GitVerificationWorkspace do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.VerificationWorkspace

  alias JidoCode.Factory.AdapterError

  @impl true
  def checkout(state, admission, _options) do
    path = Path.join(state.root, "verification-base")

    with {_, 0} <-
           git(state.repository, ["worktree", "add", "--detach", path, admission.base_commit]),
         {commit, 0} <- git(path, ["rev-parse", "HEAD"]),
         {tree, 0} <- git(path, ["rev-parse", "HEAD^{tree}"]) do
      notify(state, {:git_verification, :checkout, String.trim(commit)})

      {:ok,
       %{
         handle: :base,
         path: path,
         base_commit: String.trim(commit),
         workspace_digest: digest(String.trim(tree))
       }}
    else
      _error -> unavailable(:git_verification_checkout)
    end
  end

  @impl true
  def apply_candidate(state, base, artifacts, patch_digest, _options) do
    candidate_path = Path.join(state.root, "verification-candidate")
    patch_path = Path.join(state.root, "candidate.patch")

    with patch when is_binary(patch) <- Map.get(state.artifacts, patch_digest),
         :ok <- File.write(patch_path, patch),
         {_, 0} <-
           git(state.repository, ["worktree", "add", "--detach", candidate_path, base.base_commit]),
         {_, 0} <- git(candidate_path, ["apply", "--index", "--binary", patch_path]),
         {tree, 0} <- git(candidate_path, ["write-tree"]) do
      notify(state, {:git_verification, :applied, patch_digest})

      {:ok,
       %{
         handle: :candidate,
         path: candidate_path,
         patch_path: patch_path,
         patch_digest: patch_digest,
         applied_artifact_digests: Enum.map(artifacts, & &1.digest),
         workspace_digest: digest(String.trim(tree)),
         complete?: true,
         executor_state_used?: false
       }}
    else
      _error -> unavailable(:git_verification_apply)
    end
  end

  @impl true
  def changed_paths(state, candidate, _options) do
    case git(candidate.path, ["diff", "--name-only", "HEAD"]) do
      {output, 0} ->
        paths = output |> String.split("\n", trim: true) |> Enum.sort()
        notify(state, {:git_verification, :paths, paths})
        {:ok, paths}

      _error ->
        unavailable(:git_verification_paths)
    end
  end

  @impl true
  def run_check(state, workspace, check, options) do
    {executable, arguments} = Map.fetch!(state.commands, check.id)

    {output, exit_status} =
      System.cmd(executable, arguments,
        cd: workspace.path,
        stderr_to_stdout: true,
        env: [{"LC_ALL", "C"}]
      )

    status = if exit_status == 0, do: :passed, else: :failed
    notify(state, {:git_verification, :check, workspace.handle, check.id, status})

    {:ok,
     %{
       check_id: check.id,
       status: status,
       environment_digest: Keyword.fetch!(options, :environment_digest),
       command_digest: check.command_digest,
       result_digest: digest(Integer.to_string(exit_status)),
       output_digest: digest(output),
       workspace_digest: workspace.workspace_digest
     }}
  end

  @impl true
  def cleanup(state, handles, _options) do
    handles
    |> Enum.map(& &1.path)
    |> Enum.uniq()
    |> Enum.each(fn path -> git(state.repository, ["worktree", "remove", "--force", path]) end)

    state.root |> Path.join("candidate.patch") |> File.rm()
    notify(state, {:git_verification, :cleanup})
    :ok
  end

  defp git(repository, arguments),
    do: System.cmd("git", ["-C", repository | arguments], stderr_to_stdout: true)

  defp notify(%{owner: owner}, message) when is_pid(owner), do: send(owner, message)
  defp notify(_state, _message), do: :ok

  defp digest(material),
    do: :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)

  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end

defmodule JidoCode.Factory.ManagedCodingWorkspaceTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Factory.Tool.RepositoryPathGuard
  alias JidoCode.Integrations.GitWorkspace
  alias JidoCode.Knowledge.ResourceIdentity

  setup context do
    root = Path.join(System.tmp_dir!(), "jido-code-managed-workspace-#{context.test}")
    File.rm_rf!(root)
    source = Path.join(root, "source")
    workspaces = Path.join(root, "workspaces")
    File.mkdir_p!(Path.join(source, "lib"))
    File.write!(Path.join(source, "lib/example.ex"), "defmodule Example do\nend\n")
    File.write!(Path.join(source, "README.md"), "managed fixture\n")
    git!(source, ["init"])
    git!(source, ["config", "user.email", "fixture@example.test"])
    git!(source, ["config", "user.name", "Fixture"])
    git!(source, ["add", "."])
    git!(source, ["commit", "-m", "fixture"])
    commit = git!(source, ["rev-parse", "HEAD"])
    server = start_supervised!({GitWorkspace, base: workspaces})

    on_exit(fn ->
      git!(source, ["worktree", "prune"])
      File.rm_rf!(root)
    end)

    %{source: source, workspaces: workspaces, commit: commit, server: server}
  end

  test "provisions an exact isolated commit with deterministic identity and digests", fixture do
    spec = spec!(fixture)

    assert {:ok, workspace} = GitWorkspace.provision(fixture.server, spec)
    assert workspace.status == :ready
    assert workspace.base_tree_digest == workspace.current_tree_digest
    assert workspace.file_count == 2
    assert File.read!(Path.join(workspace.root, "lib/example.ex")) =~ "Example"
    assert git!(workspace.root, ["rev-parse", "HEAD"]) == fixture.commit

    assert {:error, %{kind: :conflict}} = GitWorkspace.provision(fixture.server, spec)
    assert {:ok, %{status: :held}} = GitWorkspace.disposition(fixture.server, spec, :hold)
    assert {:ok, %{status: :destroyed}} = GitWorkspace.cleanup(fixture.server, spec)
    refute File.exists?(workspace.root)
  end

  test "rejects traversal, symlink escape, special files, and exceeded limits", fixture do
    spec = spec!(fixture)
    assert {:ok, workspace} = GitWorkspace.provision(fixture.server, spec)

    assert {:error, %{kind: :unauthorized}} =
             RepositoryPathGuard.resolve(workspace.root, "../outside", ["lib"], :existing_file)

    File.ln_s!(Path.join(workspace.root, "README.md"), Path.join(workspace.root, "lib/link"))

    assert {:error, %{kind: :unauthorized}} =
             RepositoryPathGuard.resolve(workspace.root, "lib/link", ["lib"], :existing_file)

    assert {:error, %{kind: :unauthorized}} =
             WorkspaceDigest.tree(workspace.root, %{spec.limits | file_count: 1})
  end

  test "rejects Unicode ambiguity and incomplete resource ceilings", fixture do
    attributes = spec_attributes(fixture)

    assert {:error, _error} =
             WorkspaceSpec.new(%{attributes | allowed_paths: ["lib/e\u0301xample.ex"]})

    assert {:error, _error} =
             WorkspaceSpec.new(%{
               attributes
               | limits: Map.delete(attributes.limits, :idle_time_ms)
             })
  end

  defp spec!(fixture) do
    {:ok, spec} = WorkspaceSpec.new(spec_attributes(fixture))
    spec
  end

  defp spec_attributes(fixture) do
    %{
      attempt_iri: resource(:execution_attempt, "workspace-attempt"),
      lease_iri: resource(:execution_lease, "workspace-lease"),
      repository_iri: resource(:repository_snapshot, "workspace-repository"),
      snapshot_iri: resource(:repository_snapshot, "workspace-snapshot"),
      fencing_token: 3,
      source_root: fixture.source,
      base_commit: fixture.commit,
      sandbox_profile_revision: digest("sandbox-profile"),
      allowed_paths: ["README.md", "lib"],
      limits: %{
        file_count: 10,
        input_bytes: 32_768,
        output_bytes: 32_768,
        disk_bytes: 65_536,
        processes: 2,
        memory_bytes: 64_000_000,
        wall_time_ms: 30_000,
        idle_time_ms: 5_000,
        changed_files: 4,
        diff_bytes: 32_768
      }
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp git!(root, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end
end

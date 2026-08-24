defmodule JidoCode.Factory.ManagedCodingCandidateToolsTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Integrations.ManagedCodingCandidateTools
  alias JidoCode.Knowledge.ResourceIdentity

  setup context do
    root = Path.join(System.tmp_dir!(), "jido-code-candidate-#{context.test}")
    File.rm_rf!(root)
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "lib/example.ex"), "defmodule Example do\nend\n")
    git!(root, ["init"])
    git!(root, ["config", "user.email", "fixture@example.test"])
    git!(root, ["config", "user.name", "Fixture"])
    git!(root, ["add", "."])
    git!(root, ["commit", "-m", "fixture"])
    on_exit(fn -> File.rm_rf!(root) end)

    request = request!(root)
    %{root: root, request: request, current: current(request), catalog: catalog!()}
  end

  test "executes only a registered server-owned check and classifies its observation", fixture do
    runner = fn command, timeout ->
      assert command.executable == "/usr/bin/git"
      assert command.arguments == ["diff", "--check"]
      assert command.cwd == fixture.root
      assert command.network == :deny
      assert timeout == 10_000
      {:ok, %{exit_code: 0, output: "clean\n", duration_ms: 12}}
    end

    assert {:ok, result} =
             ManagedCodingCandidateTools.run_registered_check(
               fixture.request,
               %{check: "git-diff-check", status: "failure"},
               common_options(fixture, check_catalog: fixture.catalog, check_runner: runner)
             )

    assert result.status == :success
    assert result.output == "clean\n"
    assert result.catalog_revision == fixture.catalog.revision

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingCandidateTools.run_registered_check(
               fixture.request,
               %{check: "arbitrary-shell"},
               common_options(fixture, check_catalog: fixture.catalog, check_runner: runner)
             )
  end

  test "classifies timeout, cancellation, infrastructure, failure, and flake evidence", fixture do
    cases = [
      {%{exit_code: nil, output: "", timed_out?: true}, :timeout},
      {%{exit_code: nil, output: "", cancelled?: true}, :cancelled},
      {%{exit_code: nil, output: "", infrastructure_error?: true}, :infrastructure_failure},
      {%{exit_code: 2, output: "failed", flake_suspected?: true}, :failure}
    ]

    Enum.each(cases, fn {observation, expected} ->
      assert {:ok, result} =
               ManagedCodingCandidateTools.run_registered_check(
                 fixture.request,
                 %{check: "git-diff-check"},
                 common_options(fixture,
                   check_catalog: fixture.catalog,
                   check_runner: fn _command, _timeout -> {:ok, observation} end
                 )
               )

      assert result.status == expected
    end)
  end

  test "renders bounded deterministic diffs and scans sensitive content", fixture do
    File.write!(Path.join(fixture.root, "lib/example.ex"), "defmodule Changed do\nend\n")
    File.write!(Path.join(fixture.root, "lib/new.ex"), "token = ghp_abcdefghijklmnop\n")

    assert {:ok, diff} =
             ManagedCodingCandidateTools.show_candidate_diff(
               fixture.request,
               %{snapshot_ref: fixture.request.snapshot_iri, max_bytes: 64_000},
               common_options(fixture)
             )

    assert diff.changed_paths == ["lib/example.ex", "lib/new.ex"]
    assert diff.base_tree_digest =~ "git-tree:"
    assert diff.current_tree_digest =~ "sha256:"
    assert diff.redacted?
    assert :sensitive_content in diff.omissions
    refute diff.diff =~ "ghp_abcdefghijklmnop"
  end

  test "captures the same immutable candidate twice without publishing", fixture do
    File.write!(Path.join(fixture.root, "lib/new.ex"), "defmodule New do\nend\n")

    revisions = %{
      toolchain_revision: raw_digest("toolchain"),
      profile_revision: raw_digest("profile")
    }

    assert {:ok, first} =
             ManagedCodingCandidateTools.capture_candidate(
               fixture.request,
               revisions,
               common_options(fixture)
             )

    assert {:ok, second} =
             ManagedCodingCandidateTools.capture_candidate(
               fixture.request,
               revisions,
               common_options(fixture)
             )

    assert first == second
    assert first.changed_paths == ["lib/new.ex"]
    assert first.file_modes["lib/new.ex"] == 0o644
    assert first.patch_digest =~ "sha256:"
    assert byte_size(first.artifact_digest) == 64
    refute Map.has_key?(first, :destination)
  end

  test "rejects stale authority and truncates oversized observations", fixture do
    stale = %{fixture.current | fencing_token: fixture.request.fencing_token + 1}

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingCandidateTools.capture_candidate(
               fixture.request,
               %{
                 toolchain_revision: raw_digest("toolchain"),
                 profile_revision: raw_digest("profile")
               },
               current_provider: fn -> stale end
             )

    runner = fn _command, _timeout ->
      {:ok, %{exit_code: 1, output: String.duplicate("x", 40_000)}}
    end

    assert {:ok, result} =
             ManagedCodingCandidateTools.run_registered_check(
               fixture.request,
               %{check: "git-diff-check"},
               common_options(fixture, check_catalog: fixture.catalog, check_runner: runner)
             )

    assert result.truncated?
    assert byte_size(result.output) == 16_384
  end

  defp catalog! do
    {:ok, definition} =
      CheckDefinition.new(%{
        name: "git-diff-check",
        executable: "/usr/bin/git",
        arguments: ["diff", "--check"],
        cwd: ".",
        environment: %{"LANG" => "C.UTF-8"},
        toolchain_digest: raw_digest("git-toolchain"),
        timeout_ms: 10_000,
        output_bytes: 16_384,
        resources: %{cpu_ms: 5_000, memory_bytes: 64_000_000, process_count: 4},
        retry_policy: :safe_idempotent,
        network: :deny
      })

    {:ok, catalog} = CheckCatalog.new([definition])
    catalog
  end

  defp request!(root) do
    {:ok, tree} =
      WorkspaceDigest.tree(root, %{file_count: 100, input_bytes: 64_000, disk_bytes: 128_000})

    {:ok, request} =
      MutationRequest.new(%{
        attempt_iri: resource(:execution_attempt, "candidate-attempt"),
        lease_iri: resource(:execution_lease, "candidate-lease"),
        fencing_token: 12,
        workspace_iri: resource(:sandbox_instance, "candidate-workspace"),
        workspace_root: root,
        workspace_digest: tree.digest,
        snapshot_iri: resource(:repository_snapshot, "candidate-snapshot"),
        capability_iri: resource(:capability_declaration, "candidate-capability"),
        policy_revision: raw_digest("candidate-policy"),
        allowed_paths: ["lib"],
        protected_paths: [".git"],
        limits: %{disk_bytes: 128_000, changed_files: 8, diff_bytes: 64_000, output_bytes: 32_000}
      })

    request
  end

  defp current(request) do
    %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      workspace_iri: request.workspace_iri,
      snapshot_iri: request.snapshot_iri,
      capability_iri: request.capability_iri,
      policy_revision: request.policy_revision,
      lease_current?: true,
      policy_current?: true
    }
  end

  defp common_options(fixture, extra \\ []) do
    [current_provider: fn -> fixture.current end] ++ extra
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp raw_digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp git!(root, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end
end

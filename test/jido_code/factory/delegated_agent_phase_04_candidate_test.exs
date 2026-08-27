defmodule JidoCode.Factory.DelegatedAgentPhase04CandidateTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedCandidate
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Integrations.DelegatedArtifactRepository
  alias JidoCode.Integrations.DelegatedCandidateCapture
  alias JidoCode.Integrations.DelegatedCheckpointCapture
  alias JidoCode.Integrations.DelegatedWorkspaceController
  alias JidoCode.Integrations.GitWorkspace

  @now ~U[2026-08-27 13:00:00Z]

  setup context do
    suffix = context.test |> Atom.to_string() |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    root = Path.join(System.tmp_dir!(), "dca-phase-04-candidate-#{suffix}")
    File.rm_rf!(root)
    source = Path.join(root, "source")
    File.mkdir_p!(Path.join(source, "lib"))
    File.write!(Path.join(source, "lib/example.ex"), "defmodule Example do\nend\n")
    File.write!(Path.join(source, "README.md"), "candidate fixture\n")
    git!(source, ["init"])
    git!(source, ["config", "user.email", "fixture@example.test"])
    git!(source, ["config", "user.name", "Fixture"])
    git!(source, ["add", "."])
    git!(source, ["commit", "-m", "fixture"])
    commit = git!(source, ["rev-parse", "HEAD"])
    workspace_server = start_supervised!({GitWorkspace, base: Path.join(root, "workspaces")})

    controller =
      start_supervised!(
        {DelegatedWorkspaceController,
         workspace_server: workspace_server,
         control_root: Path.join(root, "control"),
         worker_identity: "uid:65532"}
      )

    {:ok, artifacts} = DelegatedArtifactRepository.open(Path.join(root, "artifacts"))
    spec = spec!(source, commit)
    {:ok, workspace} = DelegatedWorkspaceController.provision(controller, spec)

    on_exit(fn ->
      _ = System.cmd("git", ["worktree", "prune"], cd: source, stderr_to_stdout: true)
      File.rm_rf!(root)
    end)

    %{
      root: root,
      source: source,
      spec: spec,
      controller: controller,
      artifacts: artifacts,
      workspace: workspace
    }
  end

  test "recomputes and closes one immutable candidate with separate authority states", fixture do
    change_workspace(fixture.workspace)
    checkpoint = checkpoint!(fixture)
    owner = self()

    attributes =
      candidate_attributes(checkpoint)
      |> Map.put(:delegated_observations, [
        %{claimed_check: "all green", claimed_patch_digest: digest("untrusted")}
      ])

    assert {:ok, candidate} =
             DelegatedCandidateCapture.close(
               fixture.controller,
               fixture.workspace.iri,
               current(fixture.spec),
               checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts,
               attributes,
               commit: fn %DelegatedCandidate{} = value ->
                 send(owner, {:candidate_committed, value})
                 {:ok, %{outcome: :committed}}
               end
             )

    assert_received {:candidate_committed, ^candidate}

    assert Enum.map(candidate.changed_files, &{&1.path, &1.operation}) == [
             {"README.md", :delete},
             {"lib/example.ex", :modify},
             {"lib/generated.ex", :add}
           ]

    assert [%{path: "lib/generated.ex"}] = candidate.generated_artifacts
    assert [check] = candidate.check_receipts
    assert check.check == "git-diff-check"
    assert candidate.patch_digest == checkpoint.patch_digest
    assert candidate.tree_digest == checkpoint.tree_digest
    assert candidate.candidate_status == :ready
    assert candidate.verification_status == :not_started
    assert candidate.evidence_sufficiency == :unknown
    assert candidate.disposition == :proposed
    refute candidate.acceptance_authority
    refute candidate.publication_authority
    refute candidate.merge_authority
    refute candidate.goal_satisfied
    refute Map.has_key?(Map.from_struct(candidate), :delegated_observations)
  end

  test "candidate identity changes when any governed runtime pin changes", fixture do
    change_workspace(fixture.workspace)
    checkpoint = checkpoint!(fixture)

    {:ok, first} = close(fixture, checkpoint, candidate_attributes(checkpoint))

    changed =
      candidate_attributes(checkpoint)
      |> Map.put(:cli_digest, digest("changed-cli"))

    {:ok, second} = close(fixture, checkpoint, changed)

    assert first.candidate_iri != second.candidate_iri
    assert first.candidate_digest != second.candidate_digest
  end

  test "quarantines checkpoint digest mismatch before candidate commitment", fixture do
    change_workspace(fixture.workspace)
    checkpoint = checkpoint!(fixture)
    corrupted = %{checkpoint | tree_digest: digest("wrong-tree")}
    owner = self()

    assert {:error, %{operation: :delegated_candidate_quarantined}} =
             DelegatedCandidateCapture.close(
               fixture.controller,
               fixture.workspace.iri,
               current(fixture.spec),
               corrupted,
               DelegatedArtifactRepository,
               fixture.artifacts,
               candidate_attributes(corrupted),
               commit: fn _candidate ->
                 send(owner, :committed)
                 {:ok, %{outcome: :committed}}
               end
             )

    refute_received :committed

    assert {:ok, workspace} =
             DelegatedWorkspaceController.fetch(fixture.controller, fixture.workspace.iri)

    assert workspace.status == :quarantined
    assert workspace.quarantine_reason == :candidate_digest_mismatch
  end

  test "quarantines generated-file policy violations", fixture do
    change_workspace(fixture.workspace)
    checkpoint = checkpoint!(fixture)

    attributes =
      candidate_attributes(checkpoint)
      |> Map.put(:allowed_generated_paths, [])

    assert {:error, %{operation: :delegated_candidate_quarantined}} =
             DelegatedCandidateCapture.close(
               fixture.controller,
               fixture.workspace.iri,
               current(fixture.spec),
               checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts,
               attributes,
               commit: fn _candidate -> {:ok, %{outcome: :committed}} end
             )

    assert {:ok, %{status: :quarantined, quarantine_reason: :candidate_policy}} =
             DelegatedWorkspaceController.fetch(fixture.controller, fixture.workspace.iri)
  end

  test "quarantines a dirty admitted source base", fixture do
    change_workspace(fixture.workspace)
    File.write!(Path.join(fixture.source, "dirty.txt"), "dirty\n")

    assert {:error, %{operation: :delegated_workspace_quarantined}} =
             DelegatedWorkspaceController.checkpoint(
               fixture.controller,
               fixture.workspace.iri,
               current(fixture.spec)
             )

    assert {:ok, %{status: :quarantined, quarantine_reason: :dirty_base}} =
             DelegatedWorkspaceController.fetch(fixture.controller, fixture.workspace.iri)
  end

  defp close(fixture, checkpoint, attributes) do
    DelegatedCandidateCapture.close(
      fixture.controller,
      fixture.workspace.iri,
      current(fixture.spec),
      checkpoint,
      DelegatedArtifactRepository,
      fixture.artifacts,
      attributes,
      commit: fn _candidate -> {:ok, %{outcome: :committed}} end
    )
  end

  defp checkpoint!(fixture) do
    {:ok, checkpoint} =
      DelegatedCheckpointCapture.capture(
        fixture.controller,
        fixture.workspace.iri,
        current(fixture.spec),
        DelegatedArtifactRepository,
        fixture.artifacts,
        %{
          turn: 1,
          boundary: :explicit_handoff,
          accounting_digest: digest("accounting"),
          captured_at: @now
        }
      )

    checkpoint
  end

  defp candidate_attributes(checkpoint) do
    check = %{
      attempt_iri: checkpoint.attempt_iri,
      lease_iri: checkpoint.lease_iri,
      fencing_token: checkpoint.fencing_token,
      source_snapshot_iri: checkpoint.source_snapshot_iri,
      workspace_iri: checkpoint.workspace_iri,
      workspace_digest: checkpoint.workspace_digest,
      profile_revision: digest("profile"),
      check: "git-diff-check",
      status: :success,
      command_digest: digest("command"),
      output_digest: digest("output"),
      receipt_digest: digest("check-receipt"),
      catalog_revision: digest("checks")
    }

    %{
      attempt_iri: checkpoint.attempt_iri,
      lease_iri: checkpoint.lease_iri,
      fencing_token: checkpoint.fencing_token,
      source_snapshot_iri: checkpoint.source_snapshot_iri,
      base_commit: checkpoint.base_commit,
      patch_digest: checkpoint.patch_digest,
      tree_digest: checkpoint.tree_digest,
      delegated_profile_iri: resource(:delegated_agent_profile, "codex-dga1"),
      profile_digest: digest("profile"),
      adapter_release_digest: digest("adapter"),
      cli_digest: digest("cli"),
      model_digest: digest("model"),
      sandbox_revision: digest("sandbox"),
      policy_revision: digest("policy"),
      tool_manifest_digest: digest("tools"),
      check_registry_revision: digest("checks"),
      candidate_protocol_revision: digest("candidate-protocol"),
      generated_paths: ["lib/generated.ex"],
      allowed_generated_paths: ["lib/generated.ex"],
      check_receipts: [check],
      accounting_omissions: [
        :internal_prompts,
        :hidden_reasoning,
        :provider_context,
        :internal_tool_mediation,
        :provider_private_state
      ],
      terminal_summary_digest: digest("terminal-summary"),
      captured_at: @now
    }
  end

  defp change_workspace(workspace) do
    File.write!(Path.join(workspace.root, "lib/example.ex"), "defmodule Changed do\nend\n")
    File.write!(Path.join(workspace.root, "lib/generated.ex"), "defmodule Generated do\nend\n")
    File.rm!(Path.join(workspace.root, "README.md"))
  end

  defp spec!(source, commit) do
    {:ok, spec} =
      WorkspaceSpec.new(%{
        attempt_iri: resource(:execution_attempt, "candidate-attempt"),
        lease_iri: resource(:execution_lease, "candidate-lease"),
        repository_iri: resource(:repository_snapshot, "candidate-repository"),
        snapshot_iri: resource(:repository_snapshot, "candidate-snapshot"),
        fencing_token: 46,
        source_root: source,
        base_commit: commit,
        sandbox_profile_revision: digest("sandbox"),
        allowed_paths: ["README.md", "lib"],
        limits: %{
          file_count: 20,
          input_bytes: 65_536,
          output_bytes: 65_536,
          disk_bytes: 131_072,
          processes: 4,
          memory_bytes: 64_000_000,
          wall_time_ms: 30_000,
          idle_time_ms: 5_000,
          changed_files: 8,
          diff_bytes: 65_536
        }
      })

    spec
  end

  defp current(spec) do
    %{
      attempt_iri: spec.attempt_iri,
      lease_iri: spec.lease_iri,
      fencing_token: spec.fencing_token,
      snapshot_iri: spec.snapshot_iri,
      lease_current?: true
    }
  end

  defp git!(root, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end

  defp resource(type, id), do: "https://jido.run/id/#{type}/#{id}"

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end

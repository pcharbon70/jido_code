defmodule JidoCode.Factory.DelegatedAgentPhase03WorkspaceTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Integrations.DelegatedRegisteredChecks
  alias JidoCode.Integrations.DelegatedWorkspaceController
  alias JidoCode.Integrations.GitWorkspace
  alias JidoCode.Knowledge.ResourceIdentity

  setup context do
    suffix = context.test |> Atom.to_string() |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    root = Path.join(System.tmp_dir!(), "dca-phase-03-workspace-#{suffix}")
    File.rm_rf!(root)
    source = Path.join(root, "source")
    workspaces = Path.join(root, "workspaces")
    control = Path.join(root, "control")
    File.mkdir_p!(Path.join(source, "lib"))
    File.write!(Path.join(source, "lib/example.ex"), "defmodule Example do\nend\n")
    File.write!(Path.join(source, "README.md"), "delegated fixture\n")
    git!(source, ["init"])
    git!(source, ["config", "user.email", "fixture@example.test"])
    git!(source, ["config", "user.name", "Fixture"])
    git!(source, ["add", "."])
    git!(source, ["commit", "-m", "fixture"])
    commit = git!(source, ["rev-parse", "HEAD"])
    workspace_server = start_supervised!({GitWorkspace, base: workspaces})

    controller =
      start_supervised!(
        {DelegatedWorkspaceController,
         workspace_server: workspace_server, control_root: control, worker_identity: "uid:65532"}
      )

    spec = spec!(source, commit)

    on_exit(fn ->
      _ = System.cmd("git", ["worktree", "prune"], cd: source, stderr_to_stdout: true)
      File.rm_rf!(root)
    end)

    %{
      root: root,
      source: source,
      control: control,
      controller: controller,
      spec: spec,
      current: current(spec)
    }
  end

  test "materializes the exact editable tree while keeping Git control data in controller custody",
       fixture do
    assert {:ok, workspace} =
             DelegatedWorkspaceController.provision(fixture.controller, fixture.spec)

    assert workspace.status == :ready
    assert workspace.base_commit == fixture.spec.base_commit
    assert workspace.git_control_data == :controller_custody
    assert workspace.worker_identity == "uid:65532"
    refute File.exists?(Path.join(workspace.root, ".git"))
    assert [custody] = Path.wildcard(Path.join(fixture.control, "*.gitlink"))
    assert File.regular?(custody)

    File.write!(Path.join(workspace.root, "lib/example.ex"), "defmodule Changed do\nend\n")
    File.write!(Path.join(workspace.root, "lib/new.ex"), "defmodule New do\nend\n")
    File.rm!(Path.join(workspace.root, "README.md"))

    assert {:ok, receipt} =
             DelegatedWorkspaceController.inspect_workspace(
               fixture.controller,
               workspace.iri,
               fixture.current
             )

    assert receipt.changed_paths == ["README.md", "lib/example.ex", "lib/new.ex"]
    assert receipt.changed_files == 3
    assert receipt.diff_bytes > 0
    assert byte_size(receipt.diff_digest) == 64
    assert receipt.network == :deny

    assert {:ok, cleanup} =
             DelegatedWorkspaceController.cleanup(
               fixture.controller,
               workspace.iri,
               fixture.current
             )

    assert cleanup.status == :destroyed
    assert cleanup.control_data_destroyed
    refute File.exists?(workspace.root)
    refute File.exists?(custody)
  end

  test "quarantines repository-created Git control data", fixture do
    {:ok, workspace} = DelegatedWorkspaceController.provision(fixture.controller, fixture.spec)
    File.mkdir!(Path.join(workspace.root, ".git"))
    File.write!(Path.join(workspace.root, ".git/config"), "[remote \"escape\"]\n")

    assert {:error, %{kind: :unauthorized, operation: :delegated_workspace_quarantined}} =
             DelegatedWorkspaceController.inspect_workspace(
               fixture.controller,
               workspace.iri,
               fixture.current
             )

    assert {:ok, quarantined} =
             DelegatedWorkspaceController.fetch(fixture.controller, workspace.iri)

    assert quarantined.status == :quarantined
    assert quarantined.quarantine_reason == :git_control_data

    assert {:ok, %{status: :destroyed}} =
             DelegatedWorkspaceController.cleanup(
               fixture.controller,
               workspace.iri,
               fixture.current
             )
  end

  test "quarantines symlinks, special files, disallowed paths, secrets, and limit breaches",
       fixture do
    attacks = [
      fn workspace ->
        File.ln_s!(fixture.source, Path.join(workspace.root, "lib/escape"))
      end,
      fn workspace ->
        {_output, 0} = System.cmd("mkfifo", [Path.join(workspace.root, "lib/pipe")])
      end,
      fn workspace ->
        File.write!(Path.join(workspace.root, "outside.txt"), "outside\n")
      end,
      fn workspace ->
        File.write!(Path.join(workspace.root, "lib/leak.txt"), "ghp_abcdefghijklmnopqrstuv\n")
      end,
      fn workspace ->
        for index <- 1..5 do
          File.write!(Path.join(workspace.root, "lib/change-#{index}.ex"), "x\n")
        end
      end
    ]

    Enum.with_index(attacks, 1)
    |> Enum.each(fn {attack, index} ->
      local = isolated_fixture!(fixture, index)
      attack.(local.workspace)

      assert {:error, %{operation: :delegated_workspace_quarantined}} =
               DelegatedWorkspaceController.inspect_workspace(
                 local.controller,
                 local.workspace.iri,
                 local.current
               )

      assert {:ok, %{status: :quarantined}} =
               DelegatedWorkspaceController.fetch(local.controller, local.workspace.iri)

      assert {:ok, %{status: :destroyed}} =
               DelegatedWorkspaceController.cleanup(
                 local.controller,
                 local.workspace.iri,
                 local.current
               )
    end)
  end

  test "runs only controller-selected registered checks after a turn boundary", fixture do
    {:ok, workspace} = DelegatedWorkspaceController.provision(fixture.controller, fixture.spec)
    File.write!(Path.join(workspace.root, "lib/example.ex"), "defmodule Checked do\nend\n")

    {:ok, inspected} =
      DelegatedWorkspaceController.inspect_workspace(
        fixture.controller,
        workspace.iri,
        fixture.current
      )

    request = mutation_request!(fixture.spec, workspace, inspected)
    catalog = catalog!()
    authority = check_authority(request, catalog)

    runner = fn command, _timeout ->
      assert command.executable == "/usr/bin/git"
      assert command.arguments == ["diff", "--check"]
      assert command.network == :deny
      assert command.environment["GIT_WORK_TREE"] == workspace.root
      assert Path.type(command.environment["GIT_DIR"]) == :absolute

      {output, exit_code} =
        System.cmd(command.executable, command.arguments,
          cd: command.cwd,
          env: Map.to_list(command.environment),
          stderr_to_stdout: true
        )

      {:ok, %{exit_code: exit_code, output: output, duration_ms: 1}}
    end

    options =
      check_options(fixture.controller, workspace, request, catalog, runner)

    event = %{
      boundary: :completed_turn,
      observation_trust: :untrusted,
      observations: [%{claimed_check: "repository-controlled", status: :success}],
      registered_checks: ["repository-controlled"]
    }

    assert {:ok, receipt} = DelegatedRegisteredChecks.run(request, event, authority, options)
    assert receipt.observation_trust == :untrusted
    assert [check] = receipt.authoritative_checks
    assert check.check == "git-diff-check"
    assert check.status == :success
    assert check.source_snapshot_iri == request.snapshot_iri
    assert check.workspace_digest == request.workspace_digest
    assert check.profile_revision == authority.profile_revision
    assert check.limits.network == :deny
    assert byte_size(check.output_digest) == 64
    refute Map.has_key?(check, :output)

    assert {:error, %{kind: :unauthorized}} =
             DelegatedRegisteredChecks.run(
               request,
               event,
               %{authority | registered_checks: ["repository-controlled"]},
               options
             )

    assert {:error, %{kind: :unauthorized}} =
             DelegatedRegisteredChecks.run(
               request,
               %{event | boundary: :mid_turn},
               authority,
               options
             )
  end

  defp isolated_fixture!(fixture, index) do
    workspaces = Path.join(fixture.root, "workspaces-#{index}")
    control = Path.join(fixture.root, "control-#{index}")

    workspace_server =
      start_supervised!({GitWorkspace, base: workspaces}, id: {:git_workspace, index})

    controller =
      start_supervised!(
        {DelegatedWorkspaceController,
         workspace_server: workspace_server, control_root: control, worker_identity: "uid:65532"},
        id: {:delegated_workspace_controller, index}
      )

    spec =
      spec!(fixture.source, fixture.spec.base_commit,
        attempt: "workspace-attempt-#{index}",
        lease: "workspace-lease-#{index}",
        snapshot: "workspace-snapshot-#{index}",
        fence: index + 40
      )

    {:ok, workspace} = DelegatedWorkspaceController.provision(controller, spec)
    %{controller: controller, workspace: workspace, current: current(spec)}
  end

  defp spec!(source, commit, options \\ []) do
    {:ok, spec} =
      WorkspaceSpec.new(%{
        attempt_iri:
          resource(:execution_attempt, Keyword.get(options, :attempt, "workspace-attempt")),
        lease_iri: resource(:execution_lease, Keyword.get(options, :lease, "workspace-lease")),
        repository_iri: resource(:repository_snapshot, "workspace-repository"),
        snapshot_iri:
          resource(:repository_snapshot, Keyword.get(options, :snapshot, "workspace-snapshot")),
        fencing_token: Keyword.get(options, :fence, 33),
        source_root: source,
        base_commit: commit,
        sandbox_profile_revision: digest("sandbox-profile"),
        allowed_paths: ["README.md", "lib"],
        limits: %{
          file_count: 20,
          input_bytes: 32_768,
          output_bytes: 32_768,
          disk_bytes: 65_536,
          processes: 4,
          memory_bytes: 64_000_000,
          wall_time_ms: 30_000,
          idle_time_ms: 5_000,
          changed_files: 4,
          diff_bytes: 32_768
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

  defp mutation_request!(spec, workspace, inspected) do
    {:ok, request} =
      MutationRequest.new(%{
        attempt_iri: spec.attempt_iri,
        lease_iri: spec.lease_iri,
        fencing_token: spec.fencing_token,
        workspace_iri: workspace.iri,
        workspace_root: workspace.root,
        workspace_digest: inspected.workspace_digest,
        snapshot_iri: spec.snapshot_iri,
        capability_iri: resource(:capability_declaration, "workspace-check-capability"),
        policy_revision: digest("workspace-check-policy"),
        allowed_paths: spec.allowed_paths,
        protected_paths: [".git"],
        limits: %{
          disk_bytes: spec.limits.disk_bytes,
          changed_files: spec.limits.changed_files,
          diff_bytes: spec.limits.diff_bytes,
          output_bytes: spec.limits.output_bytes
        }
      })

    request
  end

  defp catalog! do
    {:ok, definition} =
      CheckDefinition.new(%{
        name: "git-diff-check",
        executable: "/usr/bin/git",
        arguments: ["diff", "--check"],
        cwd: ".",
        environment: %{"LANG" => "C.UTF-8"},
        toolchain_digest: digest("git-toolchain"),
        timeout_ms: 10_000,
        output_bytes: 16_384,
        resources: %{cpu_ms: 5_000, memory_bytes: 64_000_000, process_count: 4},
        retry_policy: :safe_idempotent,
        network: :deny
      })

    {:ok, catalog} = CheckCatalog.new([definition])
    catalog
  end

  defp check_authority(request, catalog) do
    %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      snapshot_iri: request.snapshot_iri,
      workspace_iri: request.workspace_iri,
      policy_revision: request.policy_revision,
      profile_revision: digest("codex-dga1-profile"),
      catalog_revision: catalog.revision,
      registered_checks: ["git-diff-check"]
    }
  end

  defp check_options(controller, workspace, request, catalog, runner) do
    current = %{
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

    [
      current_provider: fn -> current end,
      workspace_provider: fn ->
        {:ok, value} = DelegatedWorkspaceController.fetch(controller, workspace.iri)
        value
      end,
      check_environment_provider: fn ->
        {:ok, value} = DelegatedWorkspaceController.check_environment(controller, workspace.iri)
        value
      end,
      check_catalog: catalog,
      check_runner: runner
    ]
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "dca-phase-03-#{seed}")
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp git!(root, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end
end

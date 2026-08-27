defmodule JidoCode.Factory.DelegatedAgentPhase04IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedAccounting
  alias JidoCode.Factory.DelegatedCandidate
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Integrations.DelegatedArtifactRepository
  alias JidoCode.Integrations.DelegatedCandidateCapture
  alias JidoCode.Integrations.DelegatedCheckpointCapture
  alias JidoCode.Integrations.DelegatedFreshCheckoutVerifier
  alias JidoCode.Integrations.DelegatedRegisteredChecks
  alias JidoCode.Integrations.DelegatedRecoveryCoordinator
  alias JidoCode.Integrations.DelegatedWorkspaceController
  alias JidoCode.Integrations.GitWorkspace

  @now ~U[2026-08-27 15:00:00Z]

  setup context do
    fixture = fixture!(context)

    on_exit(fn ->
      _ =
        System.cmd("git", ["worktree", "prune"],
          cd: fixture.source,
          stderr_to_stdout: true
        )

      File.rm_rf!(fixture.root)
    end)

    fixture
  end

  test "runs accounting through independent evidence and graph-only recovery", fixture do
    assert fixture.accounting.accounting_scope == :outer_controller_only
    refute fixture.accounting.internal_accounting_complete?
    assert fixture.checks.observation_trust == :untrusted
    assert hd(fixture.checks.authoritative_checks).status == :success
    assert fixture.candidate.candidate_status == :ready

    owner = self()

    assert {:ok, verification} =
             DelegatedFreshCheckoutVerifier.verify(
               fixture.candidate,
               DelegatedArtifactRepository,
               fixture.artifacts,
               verification_attributes(fixture),
               completed_at: @now,
               record_evidence: fn report ->
                 send(owner, {:phase_04_evidence, report})

                 {:ok,
                  %{
                    outcome: :committed,
                    evidence_iri: resource(:evidence_bundle, "phase-04-integration"),
                    evidence_digest: digest("phase-04-evidence")
                  }}
               end
             )

    assert_receive {:phase_04_evidence, evidence}
    assert evidence.status == :passed
    assert verification.status == :passed

    graph = %{
      attempt_iri: fixture.spec.attempt_iri,
      lease_iri: fixture.spec.lease_iri,
      current_fencing_token: fixture.spec.fencing_token,
      lifecycle: :running,
      effect_state: :completed,
      failure_outcome: :process_crash,
      cancellation_committed?: false,
      accepted_checkpoint_iri: fixture.checkpoint.checkpoint_iri,
      accepted_checkpoint_digest: fixture.checkpoint.checkpoint_digest
    }

    assert {:ok, recovery} =
             DelegatedRecoveryCoordinator.reconcile(
               graph,
               fixture.checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts
             )

    assert recovery.action == :reconstruct_from_checkpoint
    assert recovery.checkpoint_artifact_verified
    assert recovery.generic_retry == :forbidden
    refute recovery.provider_session_reuse
    refute recovery.process_reference_reuse

    for value <- [fixture.candidate, verification] do
      authority = Map.from_struct(value)
      refute authority[:acceptance_authority]
      refute authority[:publication_authority]
      refute authority[:merge_authority]
      refute authority[:goal_satisfied]
      refute authority[:goal_satisfaction_authority]
      refute Map.has_key?(authority, :policy_mutation_authority)
      refute Map.has_key?(authority, :knowledge_adoption_authority)
    end
  end

  test "fails closed when the accepted checkpoint artifact is corrupted", fixture do
    artifact_path = Path.join(fixture.artifacts.root, fixture.checkpoint.patch_digest)
    File.chmod!(artifact_path, 0o600)
    File.write!(artifact_path, "corrupt checkpoint\n")
    owner = self()

    assert {:error, %{kind: :conflict, operation: :delegated_artifact_integrity}} =
             DelegatedFreshCheckoutVerifier.verify(
               fixture.candidate,
               DelegatedArtifactRepository,
               fixture.artifacts,
               verification_attributes(fixture),
               record_evidence: fn _report ->
                 send(owner, :evidence_recorded)
                 {:ok, %{}}
               end
             )

    refute_received :evidence_recorded

    assert {:error, %{kind: :conflict, operation: :delegated_artifact_integrity}} =
             DelegatedRecoveryCoordinator.reconcile(
               %{
                 attempt_iri: fixture.spec.attempt_iri,
                 lease_iri: fixture.spec.lease_iri,
                 current_fencing_token: fixture.spec.fencing_token,
                 lifecycle: :running,
                 effect_state: :completed,
                 failure_outcome: :process_crash,
                 cancellation_committed?: false,
                 accepted_checkpoint_iri: fixture.checkpoint.checkpoint_iri,
                 accepted_checkpoint_digest: fixture.checkpoint.checkpoint_digest
               },
               fixture.checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts
             )
  end

  test "rejects candidate check receipts from a different profile or registry", fixture do
    base =
      fixture.candidate
      |> DelegatedCandidate.material()
      |> Map.merge(%{
        attempt_iri: fixture.checkpoint.attempt_iri,
        lease_iri: fixture.checkpoint.lease_iri,
        fencing_token: fixture.checkpoint.fencing_token,
        source_snapshot_iri: fixture.checkpoint.source_snapshot_iri,
        base_commit: fixture.checkpoint.base_commit,
        patch_digest: fixture.checkpoint.patch_digest,
        tree_digest: fixture.checkpoint.tree_digest,
        captured_at: @now
      })

    [receipt] = base.check_receipts

    for mutation <- [
          &Map.put(&1, :profile_revision, digest("wrong-profile")),
          &Map.put(&1, :catalog_revision, digest("wrong-catalog"))
        ] do
      attributes = Map.put(base, :check_receipts, [mutation.(receipt)])

      assert {:error, %{operation: :delegated_candidate}} =
               DelegatedCandidate.new(fixture.checkpoint, attributes)
    end
  end

  defp fixture!(context) do
    suffix = context.test |> Atom.to_string() |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    root = Path.join(System.tmp_dir!(), "dca-phase-04-integration-#{suffix}")
    File.rm_rf!(root)
    source = Path.join(root, "source")
    File.mkdir_p!(Path.join(source, "lib"))
    File.write!(Path.join(source, "lib/example.ex"), "defmodule Example do\nend\n")
    File.write!(Path.join(source, "README.md"), "integration fixture\n")
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
    catalog = catalog!()
    spec = spec!(source, commit)
    {:ok, workspace} = DelegatedWorkspaceController.provision(controller, spec)
    accounting = accounting!(spec, workspace)

    {:ok, accounting, codex_effect} =
      DelegatedAccounting.start_effect(accounting, effect(spec, :codex_run, "codex-turn"))

    File.write!(Path.join(workspace.root, "lib/example.ex"), "defmodule Integrated do\nend\n")
    File.write!(Path.join(workspace.root, "lib/new.ex"), "defmodule New do\nend\n")
    File.rm!(Path.join(workspace.root, "README.md"))

    {:ok, accounting, _terminal} =
      DelegatedAccounting.finish_effect(
        accounting,
        codex_effect.effect_iri,
        effect_outcome(spec, :succeeded, %{
          changed_paths: ["README.md", "lib/example.ex", "lib/new.ex"]
        })
      )

    {:ok, inspected} =
      DelegatedWorkspaceController.inspect_workspace(controller, workspace.iri, current(spec))

    request = mutation_request!(spec, workspace, inspected)
    authority = check_authority(request, catalog)

    {:ok, accounting, check_effect} =
      DelegatedAccounting.start_effect(
        accounting,
        effect(spec, :registered_check, "git-diff-check")
      )

    runner = fn command, _timeout ->
      {output, exit_code} =
        System.cmd(command.executable, command.arguments,
          cd: command.cwd,
          env: Map.to_list(command.environment),
          stderr_to_stdout: true
        )

      {:ok, %{exit_code: exit_code, output: output, duration_ms: 1}}
    end

    {:ok, checks} =
      DelegatedRegisteredChecks.run(
        request,
        %{
          boundary: :handoff,
          observation_trust: :untrusted,
          observations: [%{claimed_check: "untrusted", status: :success}]
        },
        authority,
        check_options(controller, workspace, request, catalog, runner)
      )

    {:ok, accounting, _terminal} =
      DelegatedAccounting.finish_effect(
        accounting,
        check_effect.effect_iri,
        effect_outcome(spec, :succeeded, %{check_receipt_digest: checks.receipt_digest})
      )

    {:ok, accounting, checkpoint_effect} =
      DelegatedAccounting.start_effect(
        accounting,
        effect(spec, :checkpoint_capture, "checkpoint-1")
      )

    {:ok, checkpoint} =
      DelegatedCheckpointCapture.capture(
        controller,
        workspace.iri,
        current(spec),
        DelegatedArtifactRepository,
        artifacts,
        %{
          turn: 1,
          boundary: :explicit_handoff,
          accounting_digest: digest("phase-04-accounting-segment"),
          captured_at: @now
        }
      )

    {:ok, accounting, _terminal} =
      DelegatedAccounting.finish_effect(
        accounting,
        checkpoint_effect.effect_iri,
        effect_outcome(spec, :succeeded, %{checkpoint_iri: checkpoint.checkpoint_iri})
      )

    {:ok, accounting} = DelegatedAccounting.attach_checkpoint(accounting, checkpoint)

    {:ok, accounting_manifest} =
      DelegatedAccounting.close(accounting, %{
        attempt_iri: spec.attempt_iri,
        lease_iri: spec.lease_iri,
        fencing_token: spec.fencing_token,
        outcome: :succeeded,
        occurred_at: DateTime.add(@now, 10, :second)
      })

    candidate =
      candidate!(controller, workspace, spec, artifacts, checkpoint, catalog, checks)

    %{
      root: root,
      source: source,
      controller: controller,
      artifacts: artifacts,
      catalog: catalog,
      spec: spec,
      workspace: workspace,
      checks: checks,
      checkpoint: checkpoint,
      accounting: accounting_manifest,
      candidate: candidate
    }
  end

  defp candidate!(controller, workspace, spec, artifacts, checkpoint, catalog, checks) do
    attributes = %{
      attempt_iri: checkpoint.attempt_iri,
      lease_iri: checkpoint.lease_iri,
      fencing_token: checkpoint.fencing_token,
      source_snapshot_iri: checkpoint.source_snapshot_iri,
      base_commit: checkpoint.base_commit,
      patch_digest: checkpoint.patch_digest,
      tree_digest: checkpoint.tree_digest,
      delegated_profile_iri: resource(:delegated_agent_profile, "codex-dga1"),
      profile_digest: digest("codex-dga1-profile"),
      adapter_release_digest: digest("adapter-release"),
      cli_digest: digest("codex-cli"),
      model_digest: digest("gpt-5.3-codex"),
      sandbox_revision: digest("sandbox"),
      policy_revision: digest("candidate-policy"),
      tool_manifest_digest: digest("tool-manifest"),
      check_registry_revision: catalog.revision,
      candidate_protocol_revision: digest("candidate-protocol"),
      generated_paths: [],
      allowed_generated_paths: [],
      check_receipts: checks.authoritative_checks,
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

    {:ok, candidate} =
      DelegatedCandidateCapture.close(
        controller,
        workspace.iri,
        current(spec),
        checkpoint,
        DelegatedArtifactRepository,
        artifacts,
        attributes,
        commit: fn %DelegatedCandidate{} -> {:ok, %{outcome: :committed}} end
      )

    candidate
  end

  defp verification_attributes(fixture) do
    %{
      verifier_actor_iri: resource(:execution_attempt, "phase-04-verifier"),
      producer_actor_iri: resource(:execution_attempt, "phase-04-codex"),
      verifier_profile_revision: digest("verifier-profile"),
      environment_revision: digest("verifier-environment"),
      source_root: fixture.source,
      verifier_root: Path.join(fixture.root, "verifier"),
      producer_workspace_root: fixture.workspace.root,
      provider_session_ref: nil,
      cli_process_ref: nil,
      limits: fixture.spec.limits,
      check_catalog: fixture.catalog,
      required_checks: ["git-diff-check"]
    }
  end

  defp accounting!(spec, workspace) do
    {:ok, accounting} =
      DelegatedAccounting.new(%{
        attempt_iri: spec.attempt_iri,
        lease_iri: spec.lease_iri,
        fencing_token: spec.fencing_token,
        profile_digest: digest("codex-dga1-profile"),
        run_iri: resource(:run_graph, "phase-04-run"),
        delegated_input_manifest_digest: digest("delegated-input"),
        policy_revision: digest("accounting-policy"),
        started_at: @now,
        workspace_iri: workspace.iri
      })

    accounting
  end

  defp effect(spec, kind, identity) do
    %{
      attempt_iri: spec.attempt_iri,
      lease_iri: spec.lease_iri,
      fencing_token: spec.fencing_token,
      kind: kind,
      effect_identity: identity,
      occurred_at: @now
    }
  end

  defp effect_outcome(spec, outcome, observation) do
    %{
      attempt_iri: spec.attempt_iri,
      lease_iri: spec.lease_iri,
      fencing_token: spec.fencing_token,
      outcome: outcome,
      occurred_at: DateTime.add(@now, 1, :second),
      observation: observation
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
        capability_iri: resource(:capability_declaration, "phase-04-check"),
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
        {:ok, value} =
          DelegatedWorkspaceController.check_environment(controller, workspace.iri)

        value
      end,
      check_catalog: catalog,
      check_runner: runner
    ]
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

  defp spec!(source, commit) do
    {:ok, spec} =
      WorkspaceSpec.new(%{
        attempt_iri: resource(:execution_attempt, "phase-04-attempt"),
        lease_iri: resource(:execution_lease, "phase-04-lease"),
        repository_iri: resource(:repository_snapshot, "phase-04-repository"),
        snapshot_iri: resource(:repository_snapshot, "phase-04-snapshot"),
        fencing_token: 48,
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
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

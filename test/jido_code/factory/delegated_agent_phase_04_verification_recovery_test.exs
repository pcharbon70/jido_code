defmodule JidoCode.Factory.DelegatedAgentPhase04VerificationRecoveryTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedCancellationSequence
  alias JidoCode.Factory.DelegatedCandidate
  alias JidoCode.Factory.DelegatedResultGate
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Integrations.DelegatedArtifactRepository
  alias JidoCode.Integrations.DelegatedCandidateCapture
  alias JidoCode.Integrations.DelegatedCheckpointCapture
  alias JidoCode.Integrations.DelegatedFreshCheckoutVerifier
  alias JidoCode.Integrations.DelegatedRecoveryCoordinator
  alias JidoCode.Integrations.DelegatedWorkspaceController
  alias JidoCode.Integrations.GitWorkspace

  @now ~U[2026-08-27 14:00:00Z]

  setup context do
    suffix = context.test |> Atom.to_string() |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    root = Path.join(System.tmp_dir!(), "dca-phase-04-verifier-#{suffix}")
    File.rm_rf!(root)
    source = Path.join(root, "source")
    File.mkdir_p!(Path.join(source, "lib"))
    File.write!(Path.join(source, "lib/example.ex"), "defmodule Example do\nend\n")
    File.write!(Path.join(source, "README.md"), "verification fixture\n")
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
    {:ok, definition} = check_definition()
    {:ok, catalog} = CheckCatalog.new([definition])
    spec = spec!(source, commit)
    {:ok, workspace} = DelegatedWorkspaceController.provision(controller, spec)
    File.write!(Path.join(workspace.root, "lib/example.ex"), "defmodule Verified do\nend\n")
    File.write!(Path.join(workspace.root, "lib/new.ex"), "defmodule New do\nend\n")
    File.rm!(Path.join(workspace.root, "README.md"))

    checkpoint = checkpoint!(controller, workspace, spec, artifacts)
    candidate = candidate!(controller, workspace, spec, artifacts, checkpoint, catalog)

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
      catalog: catalog,
      workspace: workspace,
      checkpoint: checkpoint,
      candidate: candidate
    }
  end

  test "verifies from a fresh clone and emits evidence without decision authority", fixture do
    owner = self()
    attributes = verification_attributes(fixture)

    assert {:ok, result} =
             DelegatedFreshCheckoutVerifier.verify(
               fixture.candidate,
               DelegatedArtifactRepository,
               fixture.artifacts,
               attributes,
               completed_at: @now,
               record_evidence: fn report ->
                 send(owner, {:evidence_report, report})

                 {:ok,
                  %{
                    outcome: :committed,
                    evidence_iri: resource(:evidence_bundle, "delegated-verification"),
                    evidence_digest: digest("evidence")
                  }}
               end
             )

    assert_received {:evidence_report, report}
    assert report.fresh_checkout
    assert report.status == :passed
    refute report.acceptance_authority
    assert result.status == :passed
    assert result.fresh_checkout
    refute result.delegated_workspace_reused
    refute result.provider_session_reused
    refute result.cli_process_reused
    refute result.acceptance_authority
    refute result.publication_authority
    refute result.merge_authority
    refute result.goal_satisfaction_authority
    assert [%{check: "git-diff-check", status: :passed}] = result.checks
    refute File.exists?(Path.join(attributes.verifier_root, fixture.candidate.candidate_digest))
  end

  test "rejects verifier identity, workspace, process, and provider-session reuse", fixture do
    base = verification_attributes(fixture)

    mutations = [
      &Map.put(&1, :verifier_actor_iri, &1.producer_actor_iri),
      &Map.put(&1, :verifier_root, &1.producer_workspace_root),
      &Map.put(&1, :provider_session_ref, "provider-session"),
      &Map.put(&1, :cli_process_ref, "pid-123")
    ]

    for mutation <- mutations do
      assert {:error, %{operation: :delegated_verifier_independence}} =
               DelegatedFreshCheckoutVerifier.verify(
                 fixture.candidate,
                 DelegatedArtifactRepository,
                 fixture.artifacts,
                 mutation.(base),
                 record_evidence: fn _report -> raise "must not record" end
               )
    end
  end

  test "uses verifier checks instead of the delegated check claim", fixture do
    runner = fn _command, _timeout ->
      {:ok, %{exit_code: 1, output: "verifier disagreement\n", duration_ms: 1}}
    end

    assert hd(fixture.candidate.check_receipts).status == :success

    assert {:ok, result} =
             DelegatedFreshCheckoutVerifier.verify(
               fixture.candidate,
               DelegatedArtifactRepository,
               fixture.artifacts,
               verification_attributes(fixture),
               check_runner: runner,
               completed_at: @now,
               record_evidence: fn report ->
                 assert report.status == :failed

                 {:ok,
                  %{
                    outcome: :committed,
                    evidence_iri: resource(:evidence_bundle, "delegated-disagreement"),
                    evidence_digest: digest("disagreement")
                  }}
               end
             )

    assert result.status == :failed
    assert hd(result.checks).status == :failed
  end

  test "recovers only from graph facts and a rehashed accepted checkpoint", fixture do
    graph = recovery_graph(fixture.checkpoint)

    assert {:ok, plan} =
             DelegatedRecoveryCoordinator.reconcile(
               graph,
               fixture.checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts
             )

    assert plan.action == :reconstruct_from_checkpoint
    assert plan.checkpoint_artifact_verified
    assert plan.new_fencing_token_required
    assert plan.generic_retry == :forbidden
    refute plan.provider_session_reuse
    refute plan.process_reference_reuse

    assert {:error, %{operation: :delegated_recovery_disposable_state}} =
             DelegatedRecoveryCoordinator.reconcile(
               Map.put(graph, :provider_session_ref, "opaque-session"),
               fixture.checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts
             )

    assert {:ok, ambiguous} =
             DelegatedRecoveryCoordinator.reconcile(
               %{graph | effect_state: :ambiguous},
               fixture.checkpoint,
               DelegatedArtifactRepository,
               fixture.artifacts
             )

    assert ambiguous.action == :reconcile_effect_identity
    assert ambiguous.ambiguity == :effect_classification
    assert ambiguous.generic_retry == :forbidden
  end

  test "executes cancellation in mandatory order even when native stop fails" do
    owner = self()

    correlation = %{
      attempt_iri: resource(:execution_attempt, "cancel-attempt"),
      lease_iri: resource(:execution_lease, "cancel-lease"),
      fencing_token: 90
    }

    callback = fn step, receipt ->
      fn _value ->
        send(owner, {:cancellation_step, step})
        receipt
      end
    end

    assert {:error, results} =
             DelegatedCancellationSequence.execute(:cancel_command, correlation,
               graph_intent: callback.(:graph_intent, {:ok, %{outcome: :committed}}),
               permit_revocation: callback.(:permit_revocation, {:ok, %{status: :revoked}}),
               adapter_cancel: callback.(:adapter_cancel, {:error, :provider_unavailable}),
               namespace_kill: callback.(:namespace_kill, {:ok, %{namespace: :terminated}}),
               workspace_cleanup: callback.(:workspace_cleanup, {:ok, %{status: :destroyed}}),
               late_output_rejection:
                 callback.(:late_output_rejection, {:ok, %{late_results: :rejected}}),
               terminal_accounting: callback.(:terminal_accounting, {:ok, %{outcome: :committed}})
             )

    for step <- [
          :graph_intent,
          :permit_revocation,
          :adapter_cancel,
          :namespace_kill,
          :workspace_cleanup,
          :late_output_rejection,
          :terminal_accounting
        ] do
      assert_receive {:cancellation_step, ^step}
    end

    assert results.adapter_cancel == {:error, :provider_unavailable}
    assert results.namespace_kill == {:ok, %{namespace: :terminated}}
    assert results.workspace_cleanup == {:ok, %{status: :destroyed}}
  end

  test "rejects stale streams, files, candidates, verification, and terminal results" do
    request = request!()

    current = %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token + 1,
      lease_state: :active,
      lease_expires_at: DateTime.add(@now, 300, :second)
    }

    for kind <- [:stream, :file, :candidate, :verification, :terminal] do
      assert {:error, %{kind: :unauthorized, operation: :delegated_result_fence}} =
               DelegatedResultGate.dispatch(request, current, kind, %{bounded: true}, at: @now)
    end
  end

  defp checkpoint!(controller, workspace, spec, artifacts) do
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
          accounting_digest: digest("accounting"),
          captured_at: @now
        }
      )

    checkpoint
  end

  defp candidate!(controller, workspace, spec, artifacts, checkpoint, catalog) do
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
      command_digest: CheckDefinition.digest(Map.fetch!(catalog.definitions, "git-diff-check")),
      output_digest: digest("delegated-output"),
      receipt_digest: digest("delegated-check-receipt"),
      catalog_revision: catalog.revision
    }

    attributes = %{
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
      check_registry_revision: catalog.revision,
      candidate_protocol_revision: digest("candidate-protocol"),
      generated_paths: [],
      allowed_generated_paths: [],
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
      verifier_actor_iri: resource(:execution_attempt, "independent-verifier"),
      producer_actor_iri: resource(:execution_attempt, "codex-producer"),
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

  defp recovery_graph(checkpoint) do
    %{
      attempt_iri: checkpoint.attempt_iri,
      lease_iri: checkpoint.lease_iri,
      current_fencing_token: checkpoint.fencing_token,
      lifecycle: :running,
      effect_state: :completed,
      failure_outcome: nil,
      cancellation_committed?: false,
      accepted_checkpoint_iri: checkpoint.checkpoint_iri,
      accepted_checkpoint_digest: checkpoint.checkpoint_digest
    }
  end

  defp request! do
    attributes = %{
      attempt_iri: resource(:execution_attempt, "late-attempt"),
      lease_iri: resource(:execution_lease, "late-lease"),
      task_iri: resource(:task_proposal, "late-task"),
      goal_iri: resource(:goal_proposal, "late-goal"),
      plan_iri: resource(:plan_proposal, "late-plan"),
      repository_iri: resource(:repository_snapshot, "late-repository"),
      snapshot_iri: resource(:repository_snapshot, "late-snapshot"),
      actor_iri: resource(:execution_attempt, "late-actor"),
      agent_iri: resource(:delegated_agent_profile, "late-agent"),
      capability_iri: resource(:capability_declaration, "late-capability"),
      fencing_token: 91,
      context_digest: digest("late-context"),
      runtime_version: "delegated-codex/1",
      constraints: %{}
    }

    {:ok, request} = Request.new(attributes)
    request
  end

  defp check_definition do
    CheckDefinition.new(%{
      name: "git-diff-check",
      executable: "/usr/bin/git",
      arguments: ["diff", "--check"],
      cwd: ".",
      environment: %{
        "GIT_CONFIG_NOSYSTEM" => "1",
        "GIT_CONFIG_GLOBAL" => "/dev/null",
        "GIT_TERMINAL_PROMPT" => "0"
      },
      toolchain_digest: digest("git-toolchain"),
      timeout_ms: 5_000,
      output_bytes: 16_384,
      resources: %{cpu: 1, memory_bytes: 64_000_000},
      retry_policy: :never,
      network: :deny
    })
  end

  defp spec!(source, commit) do
    {:ok, spec} =
      WorkspaceSpec.new(%{
        attempt_iri: resource(:execution_attempt, "verification-attempt"),
        lease_iri: resource(:execution_lease, "verification-lease"),
        repository_iri: resource(:repository_snapshot, "verification-repository"),
        snapshot_iri: resource(:repository_snapshot, "verification-snapshot"),
        fencing_token: 47,
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

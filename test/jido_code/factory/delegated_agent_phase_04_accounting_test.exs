defmodule JidoCode.Factory.DelegatedAgentPhase04AccountingTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedAccounting
  alias JidoCode.Factory.ManagedCoding.WorkspaceSpec
  alias JidoCode.Integrations.DelegatedArtifactRepository
  alias JidoCode.Integrations.DelegatedCheckpointCapture
  alias JidoCode.Integrations.DelegatedWorkspaceController
  alias JidoCode.Integrations.GitWorkspace

  @now ~U[2026-08-27 12:00:00Z]

  setup context do
    suffix = context.test |> Atom.to_string() |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    root = Path.join(System.tmp_dir!(), "dca-phase-04-accounting-#{suffix}")
    File.rm_rf!(root)
    source = Path.join(root, "source")
    File.mkdir_p!(Path.join(source, "lib"))
    File.write!(Path.join(source, "lib/example.ex"), "defmodule Example do\nend\n")
    File.write!(Path.join(source, "README.md"), "checkpoint fixture\n")
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

    on_exit(fn ->
      _ = System.cmd("git", ["worktree", "prune"], cd: source, stderr_to_stdout: true)
      File.rm_rf!(root)
    end)

    %{root: root, spec: spec, controller: controller, artifacts: artifacts}
  end

  test "accounts only bounded controller-visible effects and explicit omissions" do
    accounting = accounting!()

    assert {:ok, started, invocation} =
             DelegatedAccounting.start_effect(accounting, %{
               attempt_iri: accounting.attempt_iri,
               lease_iri: accounting.lease_iri,
               fencing_token: accounting.fencing_token,
               kind: :codex_run,
               effect_identity: "outer-run-1",
               occurred_at: @now
             })

    assert invocation.invocation == :committed_before_effect
    assert invocation.status == :started

    assert {:ok, observed} =
             DelegatedAccounting.observe(
               started,
               :usage,
               %{input_tokens: 12, output_tokens: 8, provider_reported?: true},
               DateTime.add(@now, 1, :second)
             )

    assert {:ok, finished, terminal} =
             DelegatedAccounting.finish_effect(observed, invocation.effect_iri, %{
               attempt_iri: accounting.attempt_iri,
               lease_iri: accounting.lease_iri,
               fencing_token: accounting.fencing_token,
               outcome: :succeeded,
               occurred_at: DateTime.add(@now, 2, :second),
               observation: %{changed_paths: ["lib/example.ex"]}
             })

    assert terminal.status == :terminal

    assert {:ok, manifest} =
             DelegatedAccounting.close(finished, %{
               attempt_iri: accounting.attempt_iri,
               lease_iri: accounting.lease_iri,
               fencing_token: accounting.fencing_token,
               outcome: :succeeded,
               occurred_at: DateTime.add(@now, 3, :second)
             })

    assert manifest.accounting_scope == :outer_controller_only
    refute manifest.internal_accounting_complete?

    assert manifest.unavailable_dimensions == [
             :internal_prompts,
             :hidden_reasoning,
             :provider_context,
             :internal_tool_mediation,
             :provider_private_state
           ]

    refute inspect(manifest, limit: :infinity) =~ "provider session"
  end

  test "rejects raw prompts, transcripts, credentials, and closure with an open effect" do
    accounting = accounting!()

    assert {:error, %{operation: :delegated_accounting_observation}} =
             DelegatedAccounting.observe(accounting, :terminal, %{raw_prompt: "private"}, @now)

    assert {:error, %{operation: :delegated_accounting_observation}} =
             DelegatedAccounting.observe(
               accounting,
               :terminal,
               %{message: "token=ghp_abcdefghijklmnopqrstuvwxyz"},
               @now
             )

    {:ok, started, _effect} =
      DelegatedAccounting.start_effect(accounting, %{
        attempt_iri: accounting.attempt_iri,
        lease_iri: accounting.lease_iri,
        fencing_token: accounting.fencing_token,
        kind: :credential_release,
        effect_identity: "credential-permit-1",
        occurred_at: @now
      })

    assert {:error, %{kind: :conflict, operation: :delegated_accounting_close}} =
             DelegatedAccounting.close(started, %{
               attempt_iri: accounting.attempt_iri,
               lease_iri: accounting.lease_iri,
               fencing_token: accounting.fencing_token,
               outcome: :succeeded,
               occurred_at: DateTime.add(@now, 1, :second)
             })
  end

  test "classifies timeout as failure and ambiguity as an effect classification" do
    for {outcome, lifecycle, classification} <- [
          {:timed_out, :failed, :attributable},
          {:ambiguous, :unchanged_pending_reconciliation, :ambiguous}
        ] do
      accounting = accounting!()

      {:ok, started, effect} =
        DelegatedAccounting.start_effect(accounting, %{
          attempt_iri: accounting.attempt_iri,
          lease_iri: accounting.lease_iri,
          fencing_token: accounting.fencing_token,
          kind: :registered_check,
          effect_identity: Atom.to_string(outcome),
          occurred_at: @now
        })

      assert {:ok, _finished, terminal} =
               DelegatedAccounting.finish_effect(started, effect.effect_iri, %{
                 attempt_iri: accounting.attempt_iri,
                 lease_iri: accounting.lease_iri,
                 fencing_token: accounting.fencing_token,
                 outcome: outcome,
                 occurred_at: DateTime.add(@now, 1, :second)
               })

      assert terminal.lifecycle_outcome == lifecycle
      assert terminal.effect_classification == classification
    end
  end

  test "captures a content-addressed checkpoint that survives runtime state loss", fixture do
    {:ok, workspace} =
      DelegatedWorkspaceController.provision(fixture.controller, fixture.spec)

    File.write!(Path.join(workspace.root, "lib/example.ex"), "defmodule Changed do\nend\n")
    File.write!(Path.join(workspace.root, "lib/new.ex"), "defmodule New do\nend\n")
    File.rm!(Path.join(workspace.root, "README.md"))

    assert {:ok, checkpoint} =
             DelegatedCheckpointCapture.capture(
               fixture.controller,
               workspace.iri,
               current(fixture.spec),
               DelegatedArtifactRepository,
               fixture.artifacts,
               %{
                 turn: 1,
                 boundary: :completed_turn,
                 accounting_digest: digest("accounting"),
                 captured_at: @now
               }
             )

    assert checkpoint.changed_paths == ["README.md", "lib/example.ex", "lib/new.ex"]
    assert checkpoint.patch_bytes > 0
    refute checkpoint.provider_session_required
    refute checkpoint.process_reference_required

    {:ok, reopened} = DelegatedArtifactRepository.open(Path.join(fixture.root, "artifacts"))

    assert {:ok, artifact} =
             DelegatedArtifactRepository.fetch(reopened, %{
               artifact_iri: checkpoint.patch_artifact_iri,
               digest: checkpoint.patch_digest,
               maximum_bytes: fixture.spec.limits.diff_bytes
             })

    assert artifact.byte_count == checkpoint.patch_bytes
    assert digest_bytes(artifact.content) == checkpoint.patch_digest
    refute inspect(checkpoint, limit: :infinity) =~ workspace.root
  end

  defp accounting! do
    {:ok, accounting} =
      DelegatedAccounting.new(%{
        attempt_iri: resource(:execution_attempt, "accounting-attempt"),
        lease_iri: resource(:execution_lease, "accounting-lease"),
        fencing_token: 44,
        profile_digest: digest("profile"),
        run_iri: resource(:run_graph, "accounting-run"),
        delegated_input_manifest_digest: digest("delegated-input"),
        policy_revision: digest("policy"),
        started_at: @now
      })

    accounting
  end

  defp spec!(source, commit) do
    {:ok, spec} =
      WorkspaceSpec.new(%{
        attempt_iri: resource(:execution_attempt, "checkpoint-attempt"),
        lease_iri: resource(:execution_lease, "checkpoint-lease"),
        repository_iri: resource(:repository_snapshot, "checkpoint-repository"),
        snapshot_iri: resource(:repository_snapshot, "checkpoint-snapshot"),
        fencing_token: 45,
        source_root: source,
        base_commit: commit,
        sandbox_profile_revision: digest("sandbox-profile"),
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

  defp digest_bytes(value),
    do: :sha256 |> :crypto.hash(value) |> Base.encode16(case: :lower)
end

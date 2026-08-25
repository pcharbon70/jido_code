defmodule JidoCode.Factory.ManagedCodingPhase04IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Lifecycle
  alias JidoCode.Factory.ManagedCoding.LifecycleEvent
  alias JidoCode.Factory.ManagedCoding.Workflow
  alias JidoCode.TestSupport.FakeManagedCodingCandidateStore, as: Store
  alias JidoCode.TestSupport.FakeManagedCodingLifecycleLedger, as: Ledger
  alias JidoCode.TestSupport.FakeManagedCodingVerifier, as: Verifier

  test "runs accepted, rejected, indeterminate, and superseded candidates through disposition" do
    cases = [
      {:passed, :passed, :accepted},
      {:failed, :failed, :rejected},
      {:indeterminate, :unavailable, :indeterminate},
      {:passed, :passed, :superseded}
    ]

    Enum.each(cases, fn {verification_status, check_status, decision} ->
      fixture = fixture()

      Agent.update(fixture.verifier, fn state ->
        Map.put(state, :result, fn request ->
          verifier_result(request, verification_status, check_status)
        end)
      end)

      input = workflow_input(decision)

      assert {:ok, result} = Workflow.close_verify_dispose(dependencies(fixture), input)
      assert result.candidate.status == :ready
      assert result.verification.status == verification_status
      assert result.disposition.decision == decision
      refute result.verification.acceptance_authority
      refute result.verification.publication_authority
      refute result.disposition.publication_authority

      assert {:ok, projection} = Lifecycle.project(Ledger, fixture.lifecycle, iri("attempt"), 7)
      assert projection.state == :dispositioned
      assert :candidate in Map.keys(projection.relationships)
      assert :check in Map.keys(projection.relationships)
    end)
  end

  test "keeps empty and policy-blocked captures out of verification", %{test: test} do
    cases = [
      {%{capture() | changed_files: [], manifest_paths: [], untracked_paths: []}, :empty},
      {%{capture() | secret_scan: :blocked}, :policy_blocked}
    ]

    Enum.each(cases, fn {capture, status} ->
      fixture = fixture()
      input = workflow_input(:accepted) |> Map.put(:capture, capture)

      assert {:ok, result} = Workflow.close_verify_dispose(dependencies(fixture), input)
      assert result.candidate.status == status
      assert is_nil(result.verification)
      assert is_nil(result.disposition)
      refute_receive {:verify, _request}, 20, "unexpected verifier call for #{test}"

      assert {:ok, projection} = Lifecycle.project(Ledger, fixture.lifecycle, iri("attempt"), 7)
      assert projection.state == :assembling_candidate
    end)
  end

  test "records corrupt verifier output as a durable failed lifecycle", _context do
    fixture = fixture()

    Agent.update(fixture.verifier, fn state ->
      Map.put(state, :result, fn request ->
        {:ok, attributes} = verifier_result(request, :passed, :passed)
        {:ok, Map.put(attributes, :candidate_digest, digest("corrupt"))}
      end)
    end)

    assert {:error, %AdapterError{kind: :invalid_input}} =
             Workflow.close_verify_dispose(dependencies(fixture), workflow_input(:accepted))

    assert {:ok, projection} = Lifecycle.project(Ledger, fixture.lifecycle, iri("attempt"), 7)
    assert projection.state == :failed
  end

  test "clarification and cancellation remain durable alternatives to candidate closure" do
    lifecycle = lifecycle_at(:running)

    assert {:ok, _waiting} =
             Lifecycle.transition(
               Ledger,
               lifecycle,
               lifecycle_attributes(:awaiting_actor, "clarify")
             )

    assert {:ok, waiting} = Lifecycle.project(Ledger, lifecycle, iri("attempt"), 7)
    assert waiting.state == :awaiting_actor
    assert waiting.wait_reason == :actor

    assert {:ok, _cancelled} =
             Lifecycle.transition(Ledger, lifecycle, lifecycle_attributes(:cancelled, "cancel"))

    assert {:ok, cancelled} = Lifecycle.project(Ledger, lifecycle, iri("attempt"), 7)
    assert cancelled.state == :cancelled
  end

  defp fixture do
    owner = self()
    lifecycle = lifecycle_at(:assembling_candidate)
    store = start_supervised!({Agent, fn -> %{} end}, id: {:candidate_store, make_ref()})

    verifier =
      start_supervised!({Agent, fn -> %{owner: owner} end}, id: {:verifier, make_ref()})

    flush_mailbox()
    %{lifecycle: lifecycle, store: store, verifier: verifier}
  end

  defp lifecycle_at(target) do
    initial = initial_event()
    owner = self()

    ledger =
      start_supervised!(
        {Agent,
         fn ->
           %{
             owner: owner,
             attempt_iri: initial.attempt_iri,
             fencing_token: initial.fencing_token,
             events: [initial]
           }
         end},
        id: {:lifecycle, make_ref()}
      )

    path =
      case target do
        :running -> [:preparing, :running]
        :assembling_candidate -> [:preparing, :running, :assembling_candidate]
      end

    Enum.each(path, fn state ->
      assert {:ok, _event} =
               Lifecycle.transition(
                 Ledger,
                 ledger,
                 lifecycle_attributes(state, "seed-#{state}")
               )
    end)

    ledger
  end

  defp dependencies(fixture) do
    %{
      lifecycle: {Ledger, fixture.lifecycle},
      candidate_store: {Store, fixture.store},
      verifier: {Verifier, fixture.verifier}
    }
  end

  defp workflow_input(decision) do
    %{
      attempt_iri: iri("attempt"),
      fencing_token: 7,
      actor_iri: iri("producer"),
      occurred_at: ~U[2026-08-25 14:00:00Z],
      recorded_at: ~U[2026-08-25 14:00:00Z],
      budget_use: %{turns: 4},
      closure_evidence_iris: [iri("closure-evidence")],
      failure_evidence_iris: [iri("failure-evidence")],
      cause_iris: %{
        candidate: iri("candidate-fact-command"),
        candidate_ready: iri("candidate-ready-command"),
        verifying: iri("verifying-command"),
        check: iri("verification-fact-command"),
        dispositioned: iri("disposition-command"),
        failure: iri("failure-command")
      },
      capture: capture(),
      candidate_policy: policy(),
      verification: verification_attributes(),
      disposition: disposition_attributes(decision)
    }
  end

  defp capture do
    file = %{path: "lib/a.ex", digest: digest("file"), size: 20, mode: 0o644, binary?: false}

    %{
      capture_status: :complete,
      omissions: [],
      attempt_iri: iri("attempt"),
      fencing_token: 7,
      repository_iri: iri("repository"),
      base_snapshot_iri: iri("snapshot"),
      base_revision: digest("base"),
      normalized_patch_digest: digest("patch"),
      patch_artifact_iri: iri("patch-artifact"),
      tree_digest: digest("tree"),
      changed_files: [file],
      manifest_paths: [file.path],
      untracked_paths: [],
      diff_bytes: 200,
      generated_artifact_iris: [],
      check_evidence_iris: [iri("producer-check")],
      model_invocation_iris: [iri("model")],
      tool_invocation_iris: [iri("tool")],
      terminal_summary_digest: digest("summary"),
      policy_revision: digest("policy"),
      profile_revision: digest("profile"),
      toolchain_revision: digest("toolchain"),
      secret_scan_evidence_iri: iri("secret-scan"),
      forbidden_content_scan: :clean,
      secret_scan: :clean,
      closure_evidence_iris: [iri("closure-evidence")],
      captured_at: ~U[2026-08-25 14:00:00Z]
    }
  end

  defp policy do
    %{allowed_paths: ["lib"], max_changed_files: 10, max_diff_bytes: 10_000, allow_binary?: false}
  end

  defp verification_attributes do
    %{
      verifier_actor_iri: iri("verifier"),
      producer_actor_iri: iri("producer"),
      verifier_profile_iri: iri("verifier-profile"),
      verifier_profile_revision: digest("verifier-profile"),
      environment_revision: digest("environment"),
      toolchain_revision: digest("verifier-toolchain"),
      policy_revision: digest("policy"),
      checks: [%{id: "compile", command_digest: digest("compile-command"), deadline_ms: 10_000}],
      deadline: DateTime.add(DateTime.utc_now(), 3_600, :second),
      evidence_iris: [iri("verification-handoff")]
    }
  end

  defp disposition_attributes(decision) do
    %{
      decision: decision,
      actor_iri: iri("disposition-actor"),
      capability_iri: iri("disposition-capability"),
      policy_revision: digest("policy"),
      policy_current?: true,
      authorized?: true,
      reason_evidence_iris: [iri("disposition-evidence")],
      decided_at: DateTime.utc_now()
    }
  end

  defp verifier_result(request, status, check_status) do
    {:ok,
     %{
       candidate_digest: request.candidate_digest,
       verifier_profile_revision: request.verifier_profile_revision,
       environment_revision: request.environment_revision,
       toolchain_revision: request.toolchain_revision,
       policy_revision: request.policy_revision,
       status: status,
       checks: [
         %{
           id: "compile",
           status: check_status,
           result_digest: digest("result"),
           log_artifact_iri: iri("log"),
           resource_observation_iri: iri("resources")
         }
       ],
       evidence_iris: [iri("verification-evidence")],
       evidence_digest: digest("verification-evidence"),
       completed_at: DateTime.add(request.deadline, -1, :second)
     }}
  end

  defp lifecycle_attributes(state, cause) do
    %{
      attempt_iri: iri("attempt"),
      fencing_token: 7,
      state: state,
      subject_iri: iri("attempt"),
      actor_iri: iri("producer"),
      cause_iri: iri(cause),
      evidence_iris: [iri("evidence-#{cause}")],
      occurred_at: ~U[2026-08-25 14:00:00Z],
      recorded_at: ~U[2026-08-25 14:00:00Z],
      wait_reason: if(state == :awaiting_actor, do: :actor, else: nil),
      progress: state,
      budget_use: %{turns: 1}
    }
  end

  defp initial_event do
    {:ok, event} =
      LifecycleEvent.new(%{
        attempt_iri: iri("attempt"),
        fencing_token: 7,
        sequence: 0,
        origin_sequence: 0,
        kind: :transition,
        state: :admitted,
        previous_state: nil,
        subject_iri: iri("attempt"),
        actor_iri: iri("producer"),
        cause_iri: iri("admission"),
        evidence_iris: [iri("admission-evidence")],
        occurred_at: ~U[2026-08-25 14:00:00Z],
        recorded_at: ~U[2026-08-25 14:00:00Z],
        late_observation: false
      })

    event
  end

  defp flush_mailbox do
    receive do
      _message -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

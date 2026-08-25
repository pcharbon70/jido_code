defmodule JidoCode.Factory.ManagedCodingVerificationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateManifest
  alias JidoCode.Factory.ManagedCoding.Disposition
  alias JidoCode.Factory.ManagedCoding.PublicationHandoff
  alias JidoCode.Factory.ManagedCoding.VerificationCoordinator
  alias JidoCode.TestSupport.FakeManagedCodingCandidateStore, as: Store
  alias JidoCode.TestSupport.FakeManagedCodingVerifier, as: Verifier

  setup do
    candidate = candidate()
    owner = self()

    store =
      start_supervised!({Agent, fn -> %{candidate.candidate_iri => candidate} end}, id: :store)

    verifier = start_supervised!({Agent, fn -> %{owner: owner} end}, id: :verifier)
    %{candidate: candidate, store: store, verifier: verifier}
  end

  test "hands the exact immutable candidate to a distinct fresh verifier", context do
    assert {:ok, result} = verify(context)
    assert result.status == :passed
    assert result.candidate_digest == context.candidate.candidate_digest
    refute result.acceptance_authority
    refute result.publication_authority

    assert_receive {:verify, request}
    assert request.candidate_iri == context.candidate.candidate_iri
    assert request.base_revision == context.candidate.base_revision
    assert request.normalized_patch_digest == context.candidate.normalized_patch_digest
    refute request.producer_workspace_allowed
    refute request.mutable_cache_allowed
    refute request.credential_reuse_allowed
    refute request.publication_authority
  end

  test "rejects verifier output not bound to exact candidate and pinned revisions", context do
    corrupt =
      result_attributes(context.candidate)
      |> Map.put(:candidate_digest, digest("different-candidate"))

    Agent.update(context.verifier, &Map.put(&1, :result, {:ok, corrupt}))

    assert {:error, %AdapterError{kind: :invalid_input}} = verify(context)
  end

  test "classifies independent logs, artifacts, resource observations, and unavailable checks",
       context do
    unavailable =
      context.candidate
      |> result_attributes()
      |> Map.put(:status, :indeterminate)
      |> put_in([:checks, Access.at(0), :status], :unavailable)

    Agent.update(context.verifier, &Map.put(&1, :result, {:ok, unavailable}))

    assert {:ok, result} = verify(context)
    assert result.status == :indeterminate
    assert hd(result.checks).status == :unavailable
    assert hd(result.checks).log_artifact_iri == iri("log-compile")
    assert hd(result.checks).resource_observation_iri == iri("resource-compile")
  end

  test "requires separate authorized disposition and never trusts producer success", context do
    assert {:ok, passed} = verify(context)

    assert {:error, %AdapterError{kind: :unauthorized}} =
             Disposition.decide(passed, disposition_attributes(:accepted, iri("verifier")))

    failed_attributes =
      context.candidate
      |> result_attributes()
      |> Map.put(:status, :failed)
      |> put_in([:checks, Access.at(0), :status], :failed)

    Agent.update(context.verifier, &Map.put(&1, :result, {:ok, failed_attributes}))
    assert {:ok, failed} = verify(context)

    assert {:error, %AdapterError{kind: :unauthorized}} =
             Disposition.decide(
               failed,
               disposition_attributes(:accepted, iri("disposition-actor"))
               |> Map.put(:producer_claim, :success)
             )

    assert {:ok, disposition} =
             Disposition.decide(
               failed,
               disposition_attributes(:rejected, iri("disposition-actor"))
             )

    assert disposition.decision == :rejected
    refute disposition.publication_authority
  end

  test "keeps publication in a human-merge workflow with no inherited effects", context do
    assert {:ok, passed} = verify(context)

    assert {:ok, disposition} =
             Disposition.decide(
               passed,
               disposition_attributes(:accepted, iri("disposition-actor"))
             )

    assert {:ok, handoff} =
             PublicationHandoff.new(disposition, %{
               publication_workflow_iri: iri("publication-workflow"),
               requested_by_iri: iri("publisher"),
               human_merge_required: true
             })

    assert handoff.status == :human_merge_required
    refute handoff.branch_push_authority
    refute handoff.pull_request_authority
    refute handoff.approval_authority
    refute handoff.merge_authority

    assert {:error, %AdapterError{kind: :unauthorized}} =
             PublicationHandoff.new(disposition, %{
               publication_workflow_iri: iri("publication-workflow"),
               requested_by_iri: iri("publisher"),
               human_merge_required: false
             })
  end

  defp verify(context) do
    VerificationCoordinator.verify(
      Store,
      context.store,
      Verifier,
      context.verifier,
      context.candidate.candidate_iri,
      request_attributes()
    )
  end

  defp candidate do
    {:ok, candidate} =
      CandidateManifest.new(%{
        attempt_iri: iri("attempt"),
        fencing_token: 7,
        repository_iri: iri("repository"),
        base_snapshot_iri: iri("snapshot"),
        base_revision: digest("base"),
        normalized_patch_digest: digest("patch"),
        patch_artifact_iri: iri("patch-artifact"),
        tree_digest: digest("tree"),
        changed_files: [
          %{path: "lib/example.ex", digest: digest("file"), size: 50, mode: 0o644, binary?: false}
        ],
        generated_artifact_iris: [],
        check_evidence_iris: [iri("producer-check")],
        model_invocation_iris: [iri("model")],
        tool_invocation_iris: [iri("tool")],
        terminal_summary_digest: digest("summary"),
        policy_revision: digest("policy"),
        profile_revision: digest("profile"),
        toolchain_revision: digest("toolchain"),
        secret_scan_evidence_iri: iri("secret-scan"),
        captured_at: ~U[2026-08-25 12:00:00Z]
      })

    candidate
  end

  defp request_attributes do
    %{
      verifier_actor_iri: iri("verifier"),
      producer_actor_iri: iri("producer"),
      verifier_profile_iri: iri("verifier-profile"),
      verifier_profile_revision: digest("verifier-profile"),
      environment_revision: digest("environment"),
      toolchain_revision: digest("verifier-toolchain"),
      policy_revision: digest("policy"),
      checks: [
        %{id: "compile", command_digest: digest("compile-command"), deadline_ms: 10_000}
      ],
      deadline: DateTime.add(DateTime.utc_now(), 3_600, :second),
      evidence_iris: [iri("handoff-evidence")]
    }
  end

  defp result_attributes(candidate) do
    request = request_attributes()

    %{
      candidate_digest: candidate.candidate_digest,
      verifier_profile_revision: request.verifier_profile_revision,
      environment_revision: request.environment_revision,
      toolchain_revision: request.toolchain_revision,
      policy_revision: request.policy_revision,
      status: :passed,
      checks: [
        %{
          id: "compile",
          status: :passed,
          result_digest: digest("result-compile"),
          log_artifact_iri: iri("log-compile"),
          resource_observation_iri: iri("resource-compile")
        }
      ],
      evidence_iris: [iri("verification-evidence")],
      evidence_digest: digest("evidence"),
      completed_at: DateTime.add(request.deadline, -1, :second)
    }
  end

  defp disposition_attributes(decision, actor) do
    %{
      decision: decision,
      actor_iri: actor,
      capability_iri: iri("disposition-capability"),
      policy_revision: digest("policy"),
      policy_current?: true,
      authorized?: true,
      reason_evidence_iris: [iri("disposition-reason")],
      decided_at: DateTime.utc_now()
    }
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

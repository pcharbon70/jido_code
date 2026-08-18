defmodule JidoCode.Factory.Harness.PhaseH06FreshCheckoutTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Verification.Admission
  alias JidoCode.Factory.Verification.FreshCheckout
  alias JidoCode.Factory.Verification.Policy
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.TestSupport.FakeVerificationWorkspace

  @digest String.duplicate("ab", 32)
  @environment String.duplicate("ef", 32)

  test "reconstructs the complete candidate and emits evidence without acceptance authority" do
    admission = admission!()
    policy = policy!()

    assert {:ok, evidence} =
             verify(admission, policy,
               check_statuses: %{{:base, "candidate-regression"} => :failed}
             )

    assert evidence.evidence_command.command_type == "RecordVerificationEvidence"
    refute evidence.acceptance_authority?
    refute evidence.transition_authority?
    assert Enum.all?(evidence.checks, &(&1.status == :passed))
    assert evidence.findings == []

    assert_receive {:verification_workspace, :checkout, base_commit}
    assert base_commit == admission.base_commit
    assert_receive {:verification_workspace, :apply, :base, patch_digest}
    assert patch_digest == admission.patch_digest
    assert_receive {:verification_workspace, :cleanup, [:base, :candidate]}
  end

  test "candidate-authored tests need a base failure, candidate pass, and stated requirement" do
    admission = admission!()
    policy = policy!()

    assert {:ok, evidence} =
             verify(admission, policy,
               check_statuses: %{{:base, "candidate-regression"} => :failed}
             )

    candidate = Enum.find(evidence.checks, &(&1.owner == :candidate))
    assert candidate.accepted_as_evidence?
    assert candidate.requirement_iri == iri("requirement/regression")
    assert Enum.any?(evidence.checks, & &1.independent?)

    assert {:ok, rejected_evidence} = verify(admission, policy)
    rejected = Enum.find(rejected_evidence.checks, &(&1.owner == :candidate))
    refute rejected.accepted_as_evidence?
    assert [%{kind: :candidate_test_not_independent_evidence}] = rejected_evidence.findings
  end

  test "rejects protected paths, oversized patches, and executor-only materialization" do
    admission = admission!()
    policy = policy!()

    assert {:error, %{kind: :unauthorized, operation: :verification_protected_path}} =
             verify(admission, policy, changed_paths: [".github/workflows/ci.yml"])

    assert {:error, %{kind: :unauthorized, operation: :verification_patch_size}} =
             verify(admission, %{policy | max_patch_bytes: 100})

    poisoned = %{
      handle: :candidate,
      patch_digest: admission.patch_digest,
      applied_artifact_digests: Enum.map(admission.candidate_artifacts, & &1.digest),
      workspace_digest: digest("candidate"),
      complete?: true,
      executor_state_used?: true
    }

    assert {:error, %{operation: :verification_candidate_receipt}} =
             verify(admission, policy, candidate_result: poisoned)
  end

  test "refuses incomplete admissions and digest-substituted command receipts" do
    attributes = admission_attributes(:incomplete)
    assert {:ok, incomplete} = Admission.admit(attributes)

    assert {:error, %{operation: :fresh_checkout_requires_complete_run}} =
             verify(incomplete, policy!())

    bad_builder = fn _report -> {:ok, %{evidence_command() | command_version: "1.6.0"}} end

    assert {:error, %{operation: :verification_evidence_command}} =
             verify(admission!(), policy!(), evidence_command: bad_builder)
  end

  defp verify(admission, policy, extra \\ []) do
    defaults = [
      environment_digest: @environment,
      evidence_command: fn report ->
        send(self(), {:verification_report, report})
        {:ok, evidence_command()}
      end
    ]

    FreshCheckout.verify(
      admission,
      policy,
      FakeVerificationWorkspace,
      %{owner: self()},
      Keyword.merge(defaults, extra)
    )
  end

  defp admission!, do: admission_attributes(:complete) |> Admission.admit() |> elem(1)

  defp admission_attributes(completeness) do
    missing = if completeness == :complete, do: [], else: [:sandbox_output]

    %{
      finalization_receipt: %{
        iri: iri("receipt/finalize-1"),
        command_type: "FinalizeExecutionRun",
        outcome: :committed,
        attempt_iri: iri("attempt/1"),
        run_graph_iri: run_graph(),
        run_graph_revision: 12,
        terminal_sequence: 41,
        completeness: completeness,
        accepted_reference_sets: %{artifact: [iri("artifact/patch")]}
      },
      attempt_iri: iri("attempt/1"),
      lease_iri: iri("lease/1"),
      fencing_token: 7,
      run_graph_iri: run_graph(),
      run_graph_revision: 12,
      terminal_sequence: 41,
      completeness: completeness,
      missing_classes: missing,
      accepted_reference_sets: %{artifact: [iri("artifact/patch")]},
      source_graph_revisions: %{source_graph() => 9},
      control_graph_iri: control_graph(),
      control_graph_revision: 3,
      base_commit: String.duplicate("b", 40),
      base_snapshot_digest: @digest,
      candidate_artifacts: [
        %{
          iri: iri("artifact/patch"),
          digest: @digest,
          media_type: "application/vnd.jido.patch",
          byte_count: 1_024
        }
      ],
      patch_digest: @digest,
      verification_environment_digest: @environment,
      policy_revision: "verification-policy-1",
      rubric_revision: "rubric-1",
      evaluator_iri: iri("actor/verifier"),
      evaluator_capability_iri: iri("capability/verify"),
      execution_actor_iri: iri("actor/executor"),
      policy_verifiable_missing_classes: missing
    }
  end

  defp policy! do
    {:ok, policy} =
      Policy.new(%{
        revision: "verification-policy-1",
        allowed_path_prefixes: [".github", "assets", "config", "docs", "lib", "priv", "test"],
        protected_path_prefixes: [".github/workflows", "config/policy"],
        max_patch_bytes: 10_000,
        evaluator_capability_iri: iri("capability/verify"),
        required_check_classes: [
          :formatting,
          :compilation,
          :static_analysis,
          :type_check,
          :regression,
          :issue,
          :hidden,
          :security
        ],
        checks: checks(),
        flake_policy: %{eligible_statuses: [:failed, :timeout], max_reruns: 1}
      })

    policy
  end

  defp checks do
    [
      check("format", :formatting),
      check("compile", :compilation),
      check("static", :static_analysis),
      check("types", :type_check),
      check("regression", :regression),
      check("issue", :issue),
      check("hidden", :hidden),
      check("security", :security),
      %{
        id: "candidate-regression",
        class: :candidate_test,
        owner: :candidate,
        mandatory?: false,
        command_digest: digest("candidate-regression"),
        requirement_iri: iri("requirement/regression")
      }
    ]
  end

  defp check(id, class) do
    %{
      id: id,
      class: class,
      owner: :verifier,
      mandatory?: true,
      command_digest: digest(id)
    }
  end

  defp evidence_command do
    struct!(CommandEnvelope,
      command_type: "RecordVerificationEvidence",
      command_version: "1.7.0",
      command_iri: iri("command/evidence"),
      principal_iri: iri("actor/principal"),
      actor_iri: iri("actor/verifier"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      scope_iri: iri("scope/repository"),
      idempotency_key: "evidence",
      correlation_iri: iri("correlation/1"),
      causation_iri: iri("causation/1"),
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: 1,
      expected_graph_revisions: %{},
      reason: "verification evidence",
      issued_at: ~U[2026-08-18 12:00:00Z],
      payload: %{changes: [], guards: []}
    )
  end

  defp digest(material), do: :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)
  defp iri(path), do: "https://jido.run/id/phase-h06/#{path}"
  defp run_graph, do: "https://jido.run/graph/run/" <> String.duplicate("a", 32)

  defp source_graph do
    "https://jido.run/graph/repo/" <>
      String.duplicate("b", 32) <> "/source/" <> String.duplicate("c", 32)
  end

  defp control_graph do
    "https://jido.run/graph/repo/" <> String.duplicate("b", 32) <> "/control"
  end
end

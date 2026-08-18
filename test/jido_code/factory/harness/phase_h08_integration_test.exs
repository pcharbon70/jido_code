defmodule JidoCode.Factory.Harness.PhaseH08IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.DelegatedResultGate
  alias JidoCode.Factory.Evaluation.Adversarial.Scenario
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Extensions.AutonomousMerge.Authority
  alias JidoCode.Factory.Extensions.AutonomousMerge.Policy
  alias JidoCode.Factory.Extensions.Registry
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.ReferenceMonitor
  alias JidoCode.Factory.Verification.Admission
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.PhaseH08ExtensionFixture

  @digest "sha256:" <> String.duplicate("a", 64)
  @monitors %{
    mcp: :phase3_reference_monitor,
    remote_agent: :delegated_result_gate,
    multi_agent: :graph_work_contract
  }

  test "every extension is disabled by default and unreachable without its full proof" do
    registry = Registry.disabled()
    assert Registry.valid?(registry)
    assert Registry.extensions() == [:mcp, :remote_agent, :multi_agent, :autonomous_merge]

    for {extension, specification} <- PhaseH08ExtensionFixture.specifications() do
      assert {:error, %{operation: :extension_disabled}} =
               Registry.authorize(registry, extension, specification)

      assert {:error, %{operation: :extension_enablement}} =
               Registry.enable(registry, extension, %{
                 specification: specification,
                 specification_digest: specification.digest,
                 monitor: @monitors[extension]
               })
    end

    assert Enum.all?(Registry.posture(registry), fn {_extension, posture} ->
             posture.runtime == :disabled and is_nil(posture.specification_digest) and
               is_nil(posture.evidence_digest) and is_nil(posture.monitor)
           end)
  end

  test "accepted specifications, evidence digests, and exact monitors enable only their extension" do
    specifications = PhaseH08ExtensionFixture.specifications()

    registry =
      Enum.reduce(specifications, Registry.disabled(), fn {extension, specification}, registry ->
        proof = proof(extension, specification)
        assert {:ok, enabled} = Registry.enable(registry, extension, proof)
        assert :ok = Registry.authorize(enabled, extension, specification)
        enabled
      end)

    for {extension, specification} <- specifications do
      assert :ok = Registry.authorize(registry, extension, specification)
      assert Registry.posture(registry)[extension].runtime == :enabled
    end

    mcp = specifications.mcp

    assert {:error, %{operation: :extension_enablement}} =
             Registry.enable(Registry.disabled(), :mcp, %{
               proof(:mcp, mcp)
               | specification_digest: @digest
             })

    assert {:error, %{operation: :extension_enablement}} =
             Registry.enable(Registry.disabled(), :mcp, %{
               proof(:mcp, mcp)
               | monitor: :unmediated_transport
             })
  end

  test "autonomous merge remains impossible to register or authorize" do
    registry = Registry.disabled()
    policy = Policy.current()

    assert {:error, %{operation: :autonomous_merge_blocked}} =
             Registry.enable(registry, :autonomous_merge, %{
               specification: policy,
               specification_digest: policy.digest,
               evidence_digest: @digest,
               monitor: :protected_branch
             })

    assert {:error, %{operation: :autonomous_merge_blocked}} =
             Registry.authorize(registry, :autonomous_merge, policy)

    assert {:error, %{operation: :autonomous_merge_blocked}} =
             Authority.authorize(policy, :forged_pilot)
  end

  test "a disabled registry leaves authorization, fencing, and verification bit-identical" do
    now = DateTime.utc_now()
    {proposal, capability, current, execution} = base_authorization_fixture(now)
    verification = verification_attributes()
    fence_current = fence_current(execution, now)

    before = %{
      authorization: ReferenceMonitor.authorize(proposal, capability, current),
      fence:
        DelegatedResultGate.dispatch(
          execution,
          fence_current,
          :result,
          %{result_digest: @digest},
          at: now
        ),
      verification: Admission.admit(verification)
    }

    registry = Registry.disabled()
    assert Registry.valid?(registry)

    after_creation = %{
      authorization: ReferenceMonitor.authorize(proposal, capability, current),
      fence:
        DelegatedResultGate.dispatch(
          execution,
          fence_current,
          :result,
          %{result_digest: @digest},
          at: now
        ),
      verification: Admission.admit(verification)
    }

    assert after_creation == before
  end

  test "the Phase 7 adversarial catalog still covers every extension-facing attack family" do
    required = [
      :malicious_tool_description,
      :changed_tool_schema,
      :ssrf,
      :dns_rebinding,
      :redirect_escape,
      :cross_actor_credential_reuse,
      :stale_worker,
      :forged_result,
      :resource_exhaustion,
      :sandbox_escape,
      :branch_movement
    ]

    assert MapSet.subset?(MapSet.new(required), MapSet.new(Scenario.ids()))
    assert Scenario.contract_version() == "1.0.0"
  end

  defp proof(extension, specification) do
    %{
      specification: specification,
      specification_digest: specification.digest,
      evidence_digest: @digest,
      monitor: @monitors[extension]
    }
  end

  defp base_authorization_fixture(now) do
    snapshot_iri = resource!(:repository_snapshot, "base-snapshot")
    invocation_iri = resource!(:tool_invocation, "base-invocation")

    {:ok, proposal} =
      Proposal.from_directive(invocation_iri, %{
        tool_name: "read_file",
        tool_version: "1.0.0",
        classification: :internal,
        input_refs: [snapshot_iri],
        arguments: %{path: "lib/jido_code.ex", expected_digest: @digest}
      })

    {:ok, capability} =
      Capability.new(%{
        attempt_iri: resource!(:execution_attempt, "base-attempt"),
        lease_iri: resource!(:execution_lease, "base-lease"),
        task_iri: resource!(:task_proposal, "base-task"),
        repository_iri: resource!(:repository_snapshot, "base-repository"),
        actor_iri: resource!(:knowledge_assertion, "base-actor"),
        agent_iri: resource!(:knowledge_assertion, "base-agent"),
        profile_iri: resource!(:harness_profile, "base-profile"),
        model: "openai:test",
        tool_catalog_version: "1.0.0",
        snapshot_iri: snapshot_iri,
        source_graph_revisions: %{resource!(:graph_revision_reference, "base-policy") => 1},
        permitted_tools: ["read_file"],
        path_prefixes: ["lib"],
        ref_iris: [snapshot_iri],
        graph_scope_iris: [resource!(:graph_revision_reference, "base-policy")],
        network_destinations: [],
        registered_commands: [],
        data_classes: [:internal],
        resource_ceilings: %{output_bytes: 262_144, timeout_ms: 30_000},
        credential_reference_iris: [],
        expires_at: DateTime.add(now, 300, :second),
        fencing_token: 108,
        idempotency_namespace: @digest,
        policy_revision: 1,
        revocation_generation: 1,
        authority_classes: [:tool_execution]
      })

    current = %{
      now: now,
      invocation_iri: invocation_iri,
      attempt_iri: capability.attempt_iri,
      lease_iri: capability.lease_iri,
      lease_state: :active,
      policy_revision: capability.policy_revision,
      source_graph_revisions: capability.source_graph_revisions,
      snapshot_iri: snapshot_iri,
      fencing_token: capability.fencing_token,
      revocation_generation: capability.revocation_generation,
      approved_tools: [],
      approval_refs: []
    }

    {:ok, execution} =
      Request.new(%{
        attempt_iri: capability.attempt_iri,
        lease_iri: capability.lease_iri,
        task_iri: capability.task_iri,
        goal_iri: resource!(:goal_proposal, "base-goal"),
        plan_iri: resource!(:plan_proposal, "base-plan"),
        repository_iri: capability.repository_iri,
        snapshot_iri: snapshot_iri,
        actor_iri: capability.actor_iri,
        agent_iri: capability.agent_iri,
        capability_iri: resource!(:capability_declaration, "base-capability"),
        fencing_token: capability.fencing_token,
        context_digest: String.duplicate("b", 64),
        runtime_version: "phase-h08-base/1",
        constraints: %{}
      })

    {proposal, capability, current, execution}
  end

  defp fence_current(execution, now) do
    %{
      attempt_iri: execution.attempt_iri,
      lease_iri: execution.lease_iri,
      fencing_token: execution.fencing_token,
      lease_state: :active,
      lease_expires_at: DateTime.add(now, 300, :second)
    }
  end

  defp verification_attributes do
    %{
      finalization_receipt: verification_receipt(),
      attempt_iri: iri("attempt/1"),
      lease_iri: iri("lease/1"),
      fencing_token: 7,
      run_graph_iri: run_graph(),
      run_graph_revision: 12,
      terminal_sequence: 41,
      completeness: :complete,
      missing_classes: [],
      accepted_reference_sets: %{artifact: [iri("artifact/patch")]},
      source_graph_revisions: %{source_graph() => 9},
      control_graph_iri: control_graph(),
      control_graph_revision: 3,
      base_commit: String.duplicate("b", 40),
      base_snapshot_digest: String.duplicate("ab", 32),
      candidate_artifacts: [
        %{
          iri: iri("artifact/patch"),
          digest: String.duplicate("ab", 32),
          media_type: "application/vnd.jido.patch",
          byte_count: 1_024
        }
      ],
      patch_digest: String.duplicate("ab", 32),
      verification_environment_digest: String.duplicate("ab", 32),
      policy_revision: "policy-1",
      rubric_revision: "rubric-1",
      evaluator_iri: iri("actor/verifier"),
      evaluator_capability_iri: iri("capability/verify"),
      execution_actor_iri: iri("actor/executor"),
      policy_verifiable_missing_classes: []
    }
  end

  defp verification_receipt do
    %{
      iri: iri("receipt/finalize-1"),
      command_type: "FinalizeExecutionRun",
      outcome: :committed,
      attempt_iri: iri("attempt/1"),
      run_graph_iri: run_graph(),
      run_graph_revision: 12,
      terminal_sequence: 41,
      completeness: :complete,
      accepted_reference_sets: %{artifact: [iri("artifact/patch")]}
    }
  end

  defp iri(path), do: "https://jido.run/id/phase-h08/#{path}"
  defp run_graph, do: "https://jido.run/graph/run/" <> String.duplicate("a", 32)

  defp source_graph do
    "https://jido.run/graph/repo/" <>
      String.duplicate("b", 32) <> "/source/" <> String.duplicate("c", 32)
  end

  defp control_graph,
    do: "https://jido.run/graph/repo/" <> String.duplicate("b", 32) <> "/control"

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h08-integration-#{seed}")
    iri
  end
end

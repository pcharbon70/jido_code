defmodule JidoCode.Factory.Harness.PhaseH08RemoteAgentsTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Extensions.RemoteAgent.Delegation
  alias JidoCode.Factory.Extensions.RemoteAgent.Result
  alias JidoCode.Factory.Extensions.RemoteAgent.ResultGate
  alias JidoCode.Factory.Extensions.RemoteAgent.Specification
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge.ResourceIdentity

  @digest "sha256:" <> String.duplicate("a", 64)

  test "accepted specifications pin remote identity, protocols, budgets, and closed outputs" do
    assert {:ok, specification} = Specification.new(specification_attributes())
    assert specification.status == :accepted
    assert specification.protocol_versions == %{artifact: "1.0", delegation: "0.3"}
    assert Specification.valid?(specification)
    assert Specification.contract_version() == "1.0.0"

    assert {:error, %{operation: :remote_agent_specification}} =
             specification_attributes()
             |> Map.put(:status, :proposed)
             |> Specification.new()

    assert {:error, %{operation: :remote_agent_output_schema}} =
             specification_attributes()
             |> put_in([:output_schema, :additional_properties], true)
             |> Specification.new()

    assert {:error, %{operation: :remote_agent_specification}} =
             specification_attributes()
             |> Map.put(:unreviewed_authority, :merge)
             |> Specification.new()
  end

  test "every remote task is bound to its own local attempt, lease, fence, and capability receipt" do
    fixture = fixture()
    delegation = fixture.delegation

    assert delegation.execution.attempt_iri == delegation.capability.attempt_iri
    assert delegation.execution.lease_iri == delegation.capability.lease_iri
    assert delegation.execution.fencing_token == delegation.capability.fencing_token
    assert delegation.capability.authority_classes == [:tool_execution]

    assert delegation.capability_receipt.remote_agent_iri ==
             fixture.specification.remote_agent_iri

    assert :ok = Delegation.validate_set([delegation])

    second_attributes =
      Map.put(
        fixture.delegation_attributes,
        :remote_task_reference_iri,
        resource!(:provider_object, "remote-task-2")
      )

    assert {:ok, second} = Delegation.new(fixture.specification, second_attributes)

    assert {:error, %{operation: :remote_agent_delegation_set}} =
             Delegation.validate_set([delegation, second])

    wrong_fence =
      put_in(
        fixture.delegation_attributes,
        [:capability_receipt, :fencing_token],
        delegation.execution.fencing_token + 1
      )

    assert {:error, %{operation: :remote_agent_capability_receipt}} =
             Delegation.new(fixture.specification, wrong_fence)
  end

  test "remote results retain provenance and route only to independent verification and decision" do
    fixture = fixture()
    attributes = result_attributes(fixture)
    owner = self()

    sink = fn receipt ->
      send(owner, {:remote_result_receipt, receipt})
      :ok
    end

    assert {:ok, %{result: %Result{} = result, fence_receipt: fence_receipt}} =
             ResultGate.admit(
               fixture.specification,
               fixture.delegation,
               attributes,
               current(fixture.delegation),
               at: ~U[2026-08-18 12:00:00Z],
               sink: sink
             )

    assert result.provenance.remote_identity == fixture.specification.remote_identity
    assert result.provenance.protocol_versions == fixture.specification.protocol_versions

    assert result.provenance.capability_receipt_iri ==
             fixture.delegation.capability_receipt.iri

    assert result.trust == :untrusted_observation
    assert result.verification == :required
    assert result.decision == :pending
    refute result.accepted
    refute Result.accepting_output?(result)

    persistent = Result.persistent_attributes(result)
    refute Map.has_key?(persistent, :output)
    assert persistent.output_digest == result.output_digest

    route = Result.verification_route(result)
    assert route.verifier_iri == attributes.verifier_iri
    assert route.decision_actor_iri == attributes.decision_actor_iri
    assert route.output == attributes.output
    assert route.verification == :required
    assert route.decision == :pending

    assert fence_receipt.attempt_iri == fixture.delegation.execution.attempt_iri
    assert_received {:remote_result_receipt, %{kind: :result}}
  end

  test "forged provenance, remote self-verification, and oversized output fail closed" do
    fixture = fixture()
    attributes = result_attributes(fixture)

    forged = put_in(attributes, [:provenance, :protocol_versions], %{delegation: "9.9"})

    assert {:error, %{operation: :remote_agent_result}} =
             Result.new(fixture.specification, fixture.delegation, forged)

    self_verified = Map.put(attributes, :verifier_iri, fixture.specification.remote_agent_iri)

    assert {:error, %{operation: :remote_agent_independent_route}} =
             Result.new(fixture.specification, fixture.delegation, self_verified)

    oversized_output =
      attributes
      |> Map.put(:output, %{attributes.output | summary: String.duplicate("x", 70_000)})
      |> Map.put(:output_bytes, 70_000)

    assert {:error, %{operation: :remote_agent_output}} =
             Result.new(fixture.specification, fixture.delegation, oversized_output)
  end

  test "late or stale remote results cannot enter the local verification route" do
    fixture = fixture()
    current = current(fixture.delegation)
    stale = %{current | fencing_token: current.fencing_token + 1}

    assert {:error, %{operation: :delegated_result_fence}} =
             ResultGate.admit(
               fixture.specification,
               fixture.delegation,
               result_attributes(fixture),
               stale,
               at: ~U[2026-08-18 12:00:00Z]
             )
  end

  defp fixture do
    {:ok, specification} = Specification.new(specification_attributes())
    execution = execution_request!(specification)
    capability = capability!(execution)

    receipt_material = %{
      iri: resource!(:eligibility_receipt, "remote-capability"),
      attempt_iri: execution.attempt_iri,
      lease_iri: execution.lease_iri,
      fencing_token: execution.fencing_token,
      remote_agent_iri: specification.remote_agent_iri,
      protocol_versions: specification.protocol_versions,
      capability_digest: Definition.digest(Map.from_struct(capability))
    }

    capability_receipt = Map.put(receipt_material, :digest, Definition.digest(receipt_material))

    delegation_attributes = %{
      specification_digest: specification.digest,
      remote_task_reference_iri: resource!(:provider_object, "remote-task"),
      execution: execution,
      capability: capability,
      context_manifest_iri: resource!(:context_manifest, "remote-context"),
      context_manifest_digest: @digest,
      budget: %{
        output_bytes: 65_536,
        wall_time_ms: 120_000,
        cost_microunits: 25_000,
        model_tokens: 20_000
      },
      capability_receipt: capability_receipt
    }

    {:ok, delegation} = Delegation.new(specification, delegation_attributes)

    %{
      specification: specification,
      delegation: delegation,
      delegation_attributes: delegation_attributes
    }
  end

  defp specification_attributes do
    output_schema = %{
      additional_properties: false,
      required: [:external_references, :patch_digest, :summary],
      properties: %{
        external_references: {:list, :resource_iri, 16},
        patch_digest: :digest,
        summary: {:string, 8_192}
      }
    }

    adapter_identity = "JidoCode.RemoteAgent.A2AAdapter/1"

    %{
      revision: "remote-agent-1",
      status: :accepted,
      specification_iri: resource!(:knowledge_assertion, "remote-agent-spec"),
      evidence_iri: resource!(:evidence_bundle, "remote-agent-evidence"),
      remote_agent_iri: resource!(:knowledge_assertion, "remote-agent"),
      remote_identity: "provider.example/agents/reviewed-coder",
      protocol_versions: %{delegation: "0.3", artifact: "1.0"},
      adapter_identity: adapter_identity,
      adapter_digest: Definition.digest(adapter_identity),
      maximum_budget: %{
        output_bytes: 65_536,
        wall_time_ms: 300_000,
        cost_microunits: 100_000,
        model_tokens: 50_000
      },
      output_schema: output_schema,
      output_schema_digest: Definition.digest(output_schema)
    }
  end

  defp execution_request!(specification) do
    {:ok, execution} =
      Request.new(%{
        attempt_iri: resource!(:execution_attempt, "remote-attempt"),
        lease_iri: resource!(:execution_lease, "remote-lease"),
        task_iri: resource!(:task_proposal, "remote-task"),
        goal_iri: resource!(:goal_proposal, "remote-goal"),
        plan_iri: resource!(:plan_proposal, "remote-plan"),
        repository_iri: resource!(:repository_snapshot, "remote-repository"),
        snapshot_iri: resource!(:repository_snapshot, "remote-snapshot"),
        actor_iri: resource!(:knowledge_assertion, "product-actor"),
        agent_iri: specification.remote_agent_iri,
        capability_iri: resource!(:capability_declaration, "remote-capability"),
        fencing_token: 82,
        context_digest: String.duplicate("b", 64),
        runtime_version: "remote-agent/1",
        constraints: %{delegation_depth: 0}
      })

    execution
  end

  defp capability!(execution) do
    {:ok, capability} =
      Capability.new(%{
        attempt_iri: execution.attempt_iri,
        lease_iri: execution.lease_iri,
        task_iri: execution.task_iri,
        repository_iri: execution.repository_iri,
        actor_iri: execution.actor_iri,
        agent_iri: execution.agent_iri,
        profile_iri: resource!(:harness_profile, "remote-profile"),
        model: "remote:reviewed-coder",
        tool_catalog_version: "1.0.0",
        snapshot_iri: execution.snapshot_iri,
        source_graph_revisions: %{resource!(:graph_revision_reference, "remote-policy") => 1},
        permitted_tools: ["read_file"],
        path_prefixes: ["lib"],
        ref_iris: [execution.snapshot_iri],
        graph_scope_iris: [resource!(:graph_revision_reference, "remote-policy")],
        network_destinations: [],
        registered_commands: [],
        data_classes: [:internal],
        resource_ceilings: %{
          output_bytes: 65_536,
          wall_time_ms: 120_000,
          cost_microunits: 25_000,
          model_tokens: 20_000,
          timeout_ms: 120_000
        },
        credential_reference_iris: [],
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fencing_token: execution.fencing_token,
        idempotency_namespace: @digest,
        policy_revision: 1,
        revocation_generation: 1,
        authority_classes: [:tool_execution]
      })

    capability
  end

  defp result_attributes(fixture) do
    output = %{
      external_references: [resource!(:generated_artifact, "remote-patch")],
      patch_digest: @digest,
      summary: "Candidate patch ready for independent verification."
    }

    %{
      delegation_digest: fixture.delegation.digest,
      remote_task_reference_iri: fixture.delegation.remote_task_reference_iri,
      output: output,
      output_digest: Definition.digest(output),
      output_bytes: byte_size(:erlang.term_to_binary(output, [:deterministic])),
      claim_digests: ["sha256:" <> String.duplicate("c", 64)],
      provenance: Delegation.provenance(fixture.delegation, fixture.specification),
      verifier_iri: resource!(:knowledge_assertion, "independent-verifier"),
      decision_actor_iri: resource!(:knowledge_assertion, "decision-actor"),
      completed_at: ~U[2026-08-18 11:59:00Z]
    }
  end

  defp current(delegation) do
    %{
      attempt_iri: delegation.execution.attempt_iri,
      lease_iri: delegation.execution.lease_iri,
      fencing_token: delegation.execution.fencing_token,
      lease_state: :active,
      lease_expires_at: ~U[2026-08-18 12:05:00Z]
    }
  end

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h08-remote-#{seed}")
    iri
  end
end

defmodule JidoCode.Knowledge.DelegatedAgentCatalogTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.DelegatedAdapterRelease
  alias JidoCode.Knowledge.Control.DelegatedAgentAdmission
  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Control.DelegatedAgentProfile
  alias JidoCode.Knowledge.Control.DelegatedAgentReadiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.AgentOffering

  @now ~U[2026-08-26 15:00:00Z]
  @observed ~U[2026-08-26 14:55:00Z]
  @expiry ~U[2026-09-26 15:00:00Z]

  test "projects native and scoped disabled delegated profiles in one safe catalog" do
    fixture = fixture(:disabled)

    assert {:ok, offerings} =
             Knowledge.agent_catalog([fixture.native], [fixture.delegated], fixture.context)

    assert [%AgentOffering{} = codex, %AgentOffering{} = native] = offerings
    assert codex.runtime_class == :delegated_cli
    assert codex.provider == :codex
    refute codex.selectable
    assert :profile_disabled in codex.limitations

    assert native.runtime_class == :host_controlled
    assert native.selectable

    exposed = inspect(Enum.map(offerings, &AgentOffering.safe_map/1))
    refute exposed =~ fixture.delegated.profile.iri
    refute exposed =~ fixture.delegated.adapter.executable_registry_key
    refute exposed =~ fixture.delegated.model_access.credential_reference_iri
    refute exposed =~ "https://jido.run/graph/"
  end

  test "filters catalog visibility across every authority scope and expired or revoked state" do
    fixture = fixture(:enabled)

    assert {:ok, [_native, _delegated]} =
             Knowledge.agent_catalog([fixture.native], [fixture.delegated], fixture.context)

    for field <- [:actor_iri, :tenant_iri, :repository_iri, :capability_iri] do
      context = Map.put(fixture.context, field, resource(:authorization_grant, "other-#{field}"))
      assert {:ok, []} = Knowledge.agent_catalog([], [fixture.delegated], context)
    end

    for {field, value} <- [task_class: "other_task", language_class: "other_language"] do
      assert {:ok, []} =
               Knowledge.agent_catalog(
                 [],
                 [fixture.delegated],
                 Map.put(fixture.context, field, value)
               )
    end

    revoked = %{
      fixture.delegated
      | lifecycle: %{fixture.delegated.lifecycle | current_state: :revoked}
    }

    assert {:ok, []} = Knowledge.agent_catalog([], [revoked], fixture.context)

    expired_context = %{fixture.context | at: @expiry}
    assert {:ok, []} = Knowledge.agent_catalog([], [fixture.delegated], expired_context)
  end

  test "resolves an opaque delegated selection to exact admission pins" do
    fixture = fixture(:enabled)
    assert {:ok, [offering]} = Knowledge.agent_catalog([], [fixture.delegated], fixture.context)
    assert offering.selectable

    admission = admission()

    assert {:ok, %{outcome: :admitted, binding: binding}} =
             Knowledge.resolve_agent_offering(
               offering.reference,
               [],
               [fixture.delegated],
               fixture.context,
               admission
             )

    assert binding.profile_iri == fixture.delegated.profile.iri
    assert binding.profile_digest == fixture.delegated.profile.profile_digest
    assert binding.adapter_release_iri == fixture.delegated.adapter.iri
    assert binding.adapter_release_digest == fixture.delegated.adapter.release_digest
    assert binding.readiness_iri == fixture.delegated.readiness.iri
    assert binding.credential_generation == 7
    assert binding.attempt_iri == admission.attempt_iri
    assert binding.lease_iri == admission.lease_iri
    assert binding.fencing_token == 19
    assert byte_size(binding.binding_digest) == 64
  end

  test "invalidates opaque selections after readiness, credential, policy, or source drift" do
    fixture = fixture(:enabled)
    assert {:ok, [offering]} = Knowledge.agent_catalog([], [fixture.delegated], fixture.context)

    drifted_readiness = readiness!(fixture.delegated.profile, fixture.delegated.adapter, 8)
    drifted = %{fixture.delegated | readiness: drifted_readiness}

    assert {:ok, %{outcome: :stale}} =
             Knowledge.resolve_agent_offering(
               offering.reference,
               [],
               [drifted],
               fixture.context,
               admission()
             )

    drifted_context = %{
      fixture.context
      | source_graph_revisions:
          Map.put(fixture.context.source_graph_revisions, policy_graph(), 12)
    }

    assert {:ok, %{outcome: :stale}} =
             Knowledge.resolve_agent_offering(
               offering.reference,
               [],
               [fixture.delegated],
               drifted_context,
               admission()
             )

    incompatible = %{
      fixture.delegated
      | harness: %{
          fixture.delegated.harness
          | tool_catalog_version: digest("different-tool-manifest")
        }
    }

    assert {:ok, [changed]} = Knowledge.agent_catalog([], [incompatible], fixture.context)
    refute changed.selectable
    refute changed.reference == offering.reference
    assert :tool_manifest_incompatible in changed.limitations

    assert {:ok, %{outcome: :incompatible}} =
             Knowledge.resolve_agent_offering(
               changed.reference,
               [],
               [incompatible],
               fixture.context,
               admission()
             )
  end

  test "requires the exact admission binding on the execution attempt before effects" do
    fixture = fixture(:enabled)
    assert {:ok, [offering]} = Knowledge.agent_catalog([], [fixture.delegated], fixture.context)

    task_iri = resource(:task_proposal, "bound-task")
    lease_iri = resource(:execution_lease, "bound-lease")
    idempotency_key = "bound-delegated-attempt"

    {:ok, attempt_iri} =
      ResourceIdentity.deterministic(
        :execution_attempt,
        Enum.join([task_iri, lease_iri, "19", idempotency_key], "\n")
      )

    admission = %{
      attempt_iri: attempt_iri,
      lease_iri: lease_iri,
      fencing_token: 19,
      invocation_before_effect_iri: resource(:model_invocation, "bound-invocation"),
      bound_at: @now
    }

    assert {:ok, %{outcome: :admitted, binding: binding}} =
             Knowledge.resolve_agent_offering(
               offering.reference,
               [],
               [fixture.delegated],
               fixture.context,
               admission
             )

    context = %{
      enrollment_iri: resource(:management_enrollment, "bound-enrollment"),
      repository_iri: fixture.context.repository_iri,
      goal_iri: resource(:goal_proposal, "bound-goal"),
      task_iri: task_iri,
      plan_iri: resource(:plan_proposal, "bound-plan"),
      lease_iri: lease_iri,
      snapshot_iri: fixture.context.source_snapshot_iri,
      actor_iri: fixture.context.actor_iri,
      agent_iri: resource(:authorization_grant, "bound-runtime-agent"),
      capability_iri: fixture.context.capability_iri,
      fencing_token: 19,
      digest: digest("bound-context"),
      runtime_version: "jido-runtime-1",
      instruction: "Implement the accepted task",
      source_graph_revisions: fixture.context.source_graph_revisions,
      constraints: %{workspace: "disposable"},
      allowed_effects: ["workspace_write"],
      expected_artifacts: ["patch"],
      expected_evidence: ["fresh_checkout"],
      omissions: [],
      delegated_admission: binding
    }

    attributes = %{
      authorized_agent: %{
        agent_iri: context.agent_iri,
        capability_iri: context.capability_iri,
        available?: true
      },
      available_runtime_versions: ["jido-runtime-1"],
      idempotency_key: idempotency_key,
      retry_of_iri: nil
    }

    assert {:ok, attempt} = Knowledge.execution_attempt(context, attributes)
    assert attempt.delegated_admission.binding_digest == binding.binding_digest

    statements = DelegatedAgentAdmission.statements(binding)
    assert statement?(statements, "delegatedAgentProfile", binding.profile_iri)
    assert statement?(statements, "adapterRelease", binding.adapter_release_iri)
    assert statement?(statements, "readinessEvidence", binding.readiness_iri)
    assert statement?(statements, "invocationBeforeEffect", binding.invocation_before_effect_iri)

    mismatched = %{context | fencing_token: 20}
    assert {:error, _error} = Knowledge.execution_attempt(mismatched, attributes)
  end

  test "returns bounded stale, unavailable, and rejected outcomes without fallback" do
    disabled = fixture(:disabled)
    assert {:ok, [offering]} = Knowledge.agent_catalog([], [disabled.delegated], disabled.context)

    assert {:ok, %{outcome: :unavailable}} =
             Knowledge.resolve_agent_offering(
               offering.reference,
               [],
               [disabled.delegated],
               disabled.context,
               admission()
             )

    assert {:ok, %{outcome: :stale}} =
             Knowledge.resolve_agent_offering(
               "agent_" <> String.duplicate("x", 43),
               [disabled.native],
               [disabled.delegated],
               disabled.context,
               admission()
             )

    enabled = fixture(:enabled)
    assert {:ok, [selectable]} = Knowledge.agent_catalog([], [enabled.delegated], enabled.context)

    assert {:ok, %{outcome: :rejected}} =
             Knowledge.resolve_agent_offering(
               selectable.reference,
               [],
               [enabled.delegated, enabled.delegated],
               enabled.context,
               admission()
             )

    unauthorized_context = Map.put(enabled.context, :authorized?, false)

    assert {:ok, %{outcome: :unauthorized}} =
             Knowledge.resolve_agent_offering(
               selectable.reference,
               [],
               [enabled.delegated],
               unauthorized_context,
               admission()
             )

    assert {:ok, %{outcome: :admitted, binding: binding}} =
             Knowledge.resolve_agent_offering(
               selectable.reference,
               [],
               [enabled.delegated],
               enabled.context,
               admission()
             )

    duplicate = Map.put(admission(), :existing_binding_digest, binding.binding_digest)

    assert {:ok, %{outcome: :duplicate}} =
             Knowledge.resolve_agent_offering(
               selectable.reference,
               [],
               [enabled.delegated],
               enabled.context,
               duplicate
             )
  end

  defp fixture(delegated_state) do
    actor = resource(:authorization_grant, "catalog-actor")
    tenant = resource(:authorization_grant, "catalog-tenant")
    repository = resource(:repository_snapshot, "catalog-repository")
    capability = resource(:capability_declaration, "catalog-capability")
    owner = resource(:authorization_grant, "catalog-owner")
    scope = resource(:execution_context, "catalog-scope")
    source_snapshot = resource(:repository_snapshot, "catalog-source-snapshot")

    context = %{
      actor_iri: actor,
      tenant_iri: tenant,
      repository_iri: repository,
      capability_iri: capability,
      task_class: "focused_change",
      language_class: "elixir_phoenix",
      source_snapshot_iri: source_snapshot,
      source_graph_revisions: %{policy_graph() => 11, control_graph(repository) => 29},
      at: @now,
      selection_key: String.duplicate("catalog-selection-key-", 2)
    }

    adapter = adapter!()
    delegated_access = model_access!(owner, scope, :delegated_cli, "codex", :subscription)

    profile_material = %{
      tool_manifest_digest: digest("delegated-tools"),
      workspace_policy_revision: digest("delegated-workspace"),
      budget: %{wall_ms: 60_000, turns: 10, output_bytes: 100_000}
    }

    harness =
      harness!(
        owner,
        scope,
        delegated_access.iri,
        profile_material.tool_manifest_digest,
        profile_material.workspace_policy_revision,
        Contract.digest(profile_material.budget)
      )

    profile =
      profile!(
        adapter,
        harness,
        delegated_access,
        owner,
        actor,
        tenant,
        repository,
        capability,
        profile_material
      )

    readiness = readiness!(profile, adapter, 7)

    delegated = %{
      profile: profile,
      adapter: adapter,
      model_access: delegated_access,
      harness: harness,
      readiness: readiness,
      lifecycle: %{
        current_state: delegated_state,
        current_revision: if(delegated_state == :enabled, do: 1, else: 0),
        current_transition: resource(:control_transition, "delegated-#{delegated_state}")
      },
      description: "Codex using an existing local subscription session"
    }

    native_access = model_access!(owner, scope, :host_api, "openai", :metered_api)
    native_profile = managed_profile!(native_access, actor, tenant, repository, capability)

    native = %{
      profile: native_profile,
      model_access: native_access,
      lifecycle: %{
        current_state: :enabled,
        current_revision: 1,
        current_transition: resource(:control_transition, "native-enabled")
      },
      display_name: "Native ReqLLM",
      description: "Host-controlled managed coding agent",
      provider: "openai",
      deployment_class: :managed_fleet,
      authentication_kind: :api_key,
      capability_class: :workspace_write_registered_checks,
      language_classes: ["elixir_phoenix"],
      readiness: %{ready?: true, observed_at: @observed, expires_at: @expiry},
      rollout_stage: :production
    }

    %{context: context, delegated: delegated, native: native}
  end

  defp adapter! do
    attributes = %{
      provider: :codex,
      adapter_key: "codex_cli",
      release_revision: 1,
      jido_harness_revision: digest("harness-revision"),
      jido_harness_digest: digest("harness-archive"),
      jido_harness_protocol: "1.0.0",
      cli_product: "codex",
      cli_versions: ["0.50.0"],
      executable_registry_key: "codex_cli",
      prompt_transport: :stdin,
      input_protocol_revision: digest("input"),
      event_protocol_revision: digest("event"),
      status_protocol_revision: digest("status"),
      cancellation_protocol_revision: digest("cancel"),
      candidate_protocol_revision: digest("candidate"),
      capability_classes: [:bounded_read_only],
      deployment_classes: [:developer_local],
      journal_policy: "controller_owned",
      session_policy: "none",
      cancellation_enforcement: :native_and_outer,
      observation_completeness: :partial,
      unavailable_fields: ["internal_tool_arguments"],
      conformance_digest: digest("conformance"),
      security_evidence_digest: digest("security"),
      state: :accepted,
      approved_at: @observed,
      expires_at: @expiry,
      signer_iri: resource(:authorization_grant, "adapter-signer"),
      supersedes_iri: nil,
      signed_digest: digest("adapter-signature")
    }

    attributes =
      Map.put(attributes, :release_digest, DelegatedAdapterRelease.material_digest(attributes))

    {:ok, adapter} = Knowledge.delegated_adapter_release(attributes)
    adapter
  end

  defp profile!(adapter, harness, access, owner, actor, tenant, repository, capability, material) do
    attributes = %{
      revision: 1,
      display_name: "Codex subscription",
      agent_key: "codex_subscription",
      runtime_class: :delegated_cli,
      provider: :codex,
      harness_profile_iri: harness.iri,
      model_access_profile_iri: access.iri,
      adapter_release_iri: adapter.iri,
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_mode: :subscription,
      prompt_transport: :stdin,
      session_policy: :none,
      capability_class: :bounded_read_only,
      tool_manifest_digest: material.tool_manifest_digest,
      workspace_policy_revision: material.workspace_policy_revision,
      sandbox_profile_revision: digest("sandbox"),
      network_policy_revision: digest("network"),
      credential_delivery: :local_reference,
      candidate_protocol_revision: adapter.candidate_protocol_revision,
      verification_profile_revision: digest("verifier"),
      budget: material.budget,
      task_classes: ["focused_change"],
      language_classes: ["elixir_phoenix"],
      owner_iri: owner,
      tenant_iris: [tenant],
      repository_iris: [repository],
      actor_iris: [actor],
      capability_iris: [capability],
      state: :disabled,
      rollout_stage: :evaluation,
      approved_at: @observed,
      expires_at: @expiry,
      signer_iri: resource(:authorization_grant, "profile-signer"),
      supersedes_iri: nil,
      signed_digest: digest("profile-signature")
    }

    attributes =
      Map.put(attributes, :profile_digest, DelegatedAgentProfile.material_digest(attributes))

    {:ok, profile} = Knowledge.delegated_agent_profile(attributes)
    profile
  end

  defp readiness!(profile, adapter, generation) do
    attributes = %{
      profile_iri: profile.iri,
      profile_digest: profile.profile_digest,
      adapter_release_iri: adapter.iri,
      adapter_release_digest: adapter.release_digest,
      cli_version: "0.50.0",
      credential_generation: generation,
      worker_revision: digest("worker"),
      sandbox_profile_revision: profile.sandbox_profile_revision,
      network_policy_revision: profile.network_policy_revision,
      verification_profile_revision: profile.verification_profile_revision,
      candidate_protocol_revision: profile.candidate_protocol_revision,
      worker_ready: true,
      network_ready: true,
      authentication_ready: true,
      candidate_ready: true,
      verifier_ready: true,
      observed_at: @observed,
      expires_at: @expiry
    }

    attributes =
      Map.put(
        attributes,
        :observation_digest,
        DelegatedAgentReadiness.material_digest(attributes)
      )

    {:ok, readiness} = Knowledge.delegated_agent_readiness(attributes)
    readiness
  end

  defp model_access!(owner, scope, mode, provider, billing) do
    {:ok, access} =
      Knowledge.model_access_profile(%{
        owner_iri: owner,
        scope_iri: scope,
        access_mode: mode,
        credential_reference_iri: resource(:authorization_grant, "credential-#{mode}"),
        credential_class: :static_reusable,
        billing_mode: billing,
        provider: provider,
        model: "coding-model",
        endpoint: "provider-registry",
        readiness: [:installed, :credential_available, :authenticated, :model_available],
        revocation_generation: 1
      })

    access
  end

  defp harness!(owner, scope, access, tool_digest, policy_digest, budget_digest) do
    {:ok, harness} =
      Knowledge.harness_profile(%{
        name: "delegated-harness",
        version: "1.0.0",
        owner_iri: owner,
        scope_iri: scope,
        model_access_profile_iri: access,
        workflow_version: "1.0.0",
        prompt_template_version: digest("prompt"),
        tool_catalog_version: tool_digest,
        policy_revision: policy_digest,
        budget_profile: budget_digest
      })

    harness
  end

  defp managed_profile!(access, actor, tenant, repository, capability) do
    {:ok, profile} =
      Knowledge.managed_coding_profile(%{
        iri: resource(:harness_profile, "native-managed-profile"),
        revision: 1,
        profile_digest: digest("native-profile"),
        jido_version: "2.3.2",
        strategy_revision: digest("native-strategy"),
        prompt_bundle_revision: digest("native-prompt"),
        model_access_profile_iri: access.iri,
        context_policy_revision: digest("native-context"),
        memory_policy_revision: digest("native-memory"),
        tool_catalog_revision: digest("native-tools"),
        adapter_set_revision: digest("native-adapters"),
        sandbox_profile_revision: digest("native-sandbox"),
        verifier_profile_revision: digest("native-verifier"),
        candidate_schema_revision: digest("native-candidate"),
        budget_contract: %{turns: %{limit: 20}},
        task_classes: ["focused_change"],
        actor_iris: [actor],
        tenant_iris: [tenant],
        repository_iris: [repository],
        capability_iris: [capability]
      })

    profile
  end

  defp admission do
    %{
      attempt_iri: resource(:execution_attempt, "catalog-attempt"),
      lease_iri: resource(:execution_lease, "catalog-lease"),
      fencing_token: 19,
      invocation_before_effect_iri: resource(:model_invocation, "catalog-invocation"),
      bound_at: @now
    }
  end

  defp policy_graph do
    {:ok, graph} = JidoCode.Knowledge.GraphRegistry.graph_iri(:factory_policy, %{})
    graph
  end

  defp control_graph(repository) do
    {:ok, graph} =
      JidoCode.Knowledge.GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    graph
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp statement?(statements, predicate_local, object) do
    Enum.any?(statements, fn {_subject, predicate, statement_object} ->
      to_string(predicate) == "https://jido.run/ontology/factory##{predicate_local}" and
        to_string(statement_object) == object
    end)
  end
end

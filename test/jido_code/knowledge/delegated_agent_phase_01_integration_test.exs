defmodule JidoCode.Knowledge.DelegatedAgentPhase01IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.DelegatedAdapterRelease
  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Control.DelegatedAgentProfile
  alias JidoCode.Knowledge.Control.DelegatedAgentReadiness
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture

  test "commits and reconstructs one exact delegated profile through the real store", context do
    fixture = Phase07SchedulingFixture.leased!(context)
    expires_at = DateTime.add(fixture.issued_at, 86_400, :second)
    access = access!(fixture)

    execute!(
      fixture,
      Knowledge.enroll_model_access_profile(access, command_attributes(fixture),
        clock: clock(fixture)
      )
    )

    material = %{
      tool_manifest_digest: digest("integration-tools"),
      workspace_policy_revision: digest("integration-workspace"),
      budget: %{wall_ms: 60_000, turns: 10, output_bytes: 100_000}
    }

    harness = harness!(fixture, access, material)

    execute!(
      fixture,
      Knowledge.adopt_harness_profile(harness, command_attributes(fixture), clock: clock(fixture))
    )

    adapter = adapter!(fixture, expires_at)

    execute!(
      fixture,
      Knowledge.register_delegated_adapter_release(adapter, command_attributes(fixture),
        clock: clock(fixture)
      )
    )

    profile = profile!(fixture, adapter, harness, access, material, expires_at)

    {:ok, registration_command} =
      Knowledge.register_delegated_agent_profile(profile, command_attributes(fixture),
        clock: clock(fixture)
      )

    outcomes =
      [registration_command, registration_command]
      |> Task.async_stream(
        fn command ->
          {:ok, receipt} = Writer.execute(fixture.writer, command)
          receipt.outcome
        end,
        max_concurrency: 2,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, outcome} -> outcome end)
      |> Enum.sort()

    assert outcomes == [:already_committed, :committed]

    resolution = %{
      domain: :delegated_agent_profile,
      current_state: :disabled,
      current_revision: 0,
      current_transition: transition_iri(profile, 0, :disabled)
    }

    {:ok, transition_command} =
      Knowledge.transition_delegated_agent_profile(
        profile,
        resolution,
        :enabled,
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert %{outcome: :committed} = execute_command!(fixture, transition_command)

    assert {:ok, stale_command} =
             Knowledge.transition_delegated_agent_profile(
               profile,
               resolution,
               :enabled,
               command_attributes(fixture, expected_policy_revision: 1),
               clock: clock(fixture)
             )

    assert {:ok, %{outcome: :conflicted}} = Writer.execute(fixture.writer, stale_command)

    readiness = readiness!(profile, adapter, fixture.issued_at, expires_at)

    {:ok, readiness_command} =
      Knowledge.record_delegated_agent_readiness(
        readiness,
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert %{outcome: :committed} = execute_command!(fixture, readiness_command)

    assert %{outcome: :already_committed} =
             execute_command!(fixture, readiness_command)

    assert {:ok, history} =
             query(fixture, :delegated_agent_profile_history, %{
               graph: fixture.graphs.policy,
               resource: profile.iri
             })

    assert Enum.map(history.data, &value(&1, "revision")) == ["0", "1"]

    assert {:ok, current_readiness} =
             query(fixture, :delegated_agent_readiness_by_profile, %{
               graph: fixture.graphs.policy,
               resource: profile.iri,
               instant: fixture.issued_at
             })

    assert current_readiness.data != []

    scope_parameters = %{
      graph: fixture.graphs.policy,
      actor: fixture.actor,
      tenant: fixture.factory_scope,
      repository: fixture.repository,
      capability: fixture.capability,
      task_class: "focused_change",
      language_class: "elixir_phoenix",
      instant: fixture.issued_at
    }

    assert {:ok, offerings} =
             query(fixture, :selectable_agent_offerings_by_scope, scope_parameters)

    assert Enum.any?(offerings.data, &(value(&1, "profile") == profile.iri))

    wrong_actor = %{scope_parameters | actor: resource(:authorization_grant, "wrong-actor")}
    assert {:ok, isolated} = query(fixture, :selectable_agent_offerings_by_scope, wrong_actor)
    assert isolated.data == []
  end

  test "fails closed before store mutation for malformed and expired inputs", context do
    fixture = Phase07SchedulingFixture.leased!(context)
    expires_at = DateTime.add(fixture.issued_at, 86_400, :second)
    attributes = adapter_attributes(fixture, expires_at)

    for mutation <- [
          &Map.put(&1, :provider, :unknown),
          &Map.put(&1, :prompt_transport, :argv),
          &Map.put(&1, :executable_registry_key, "repository_binary"),
          &Map.put(&1, :expires_at, fixture.issued_at)
        ] do
      invalid = attributes |> mutation.() |> sign_adapter()
      assert {:error, _error} = Knowledge.delegated_adapter_release(invalid)
    end
  end

  defp access!(fixture) do
    {:ok, access} =
      Knowledge.model_access_profile(%{
        owner_iri: fixture.actor,
        scope_iri: fixture.factory_scope,
        access_mode: :delegated_cli,
        credential_reference_iri: resource(:authorization_grant, "integration-credential"),
        credential_class: :static_reusable,
        billing_mode: :subscription,
        provider: "codex",
        model: "codex-cli",
        endpoint: "application-executable-registry",
        readiness: [:installed, :credential_available, :authenticated, :policy_allowed],
        revocation_generation: 1
      })

    access
  end

  defp harness!(fixture, access, material) do
    {:ok, harness} =
      Knowledge.harness_profile(%{
        name: "codex-developer-local",
        version: "1.0.0",
        owner_iri: fixture.actor,
        scope_iri: fixture.factory_scope,
        model_access_profile_iri: access.iri,
        workflow_version: "1.0.0",
        prompt_template_version: digest("integration-prompt"),
        tool_catalog_version: material.tool_manifest_digest,
        policy_revision: material.workspace_policy_revision,
        budget_profile: Contract.digest(material.budget)
      })

    harness
  end

  defp adapter!(fixture, expires_at) do
    attributes = fixture |> adapter_attributes(expires_at) |> sign_adapter()
    {:ok, adapter} = Knowledge.delegated_adapter_release(attributes)
    adapter
  end

  defp adapter_attributes(fixture, expires_at) do
    %{
      provider: :codex,
      adapter_key: "codex_cli",
      release_revision: 1,
      jido_harness_revision: digest("integration-harness-revision"),
      jido_harness_digest: digest("integration-harness-archive"),
      jido_harness_protocol: "1.0.0",
      cli_product: "codex",
      cli_versions: ["0.50.0"],
      executable_registry_key: "codex_cli",
      prompt_transport: :stdin,
      input_protocol_revision: digest("integration-input"),
      event_protocol_revision: digest("integration-event"),
      status_protocol_revision: digest("integration-status"),
      cancellation_protocol_revision: digest("integration-cancel"),
      candidate_protocol_revision: digest("integration-candidate"),
      capability_classes: [:bounded_read_only],
      deployment_classes: [:developer_local],
      journal_policy: "controller_owned",
      session_policy: "none",
      cancellation_enforcement: :native_and_outer,
      observation_completeness: :partial,
      unavailable_fields: ["internal_tool_arguments"],
      conformance_digest: digest("integration-conformance"),
      security_evidence_digest: digest("integration-security"),
      state: :accepted,
      approved_at: fixture.issued_at,
      expires_at: expires_at,
      signer_iri: fixture.actor,
      supersedes_iri: nil,
      signed_digest: digest("integration-adapter-signature")
    }
  end

  defp sign_adapter(attributes),
    do: Map.put(attributes, :release_digest, DelegatedAdapterRelease.material_digest(attributes))

  defp profile!(fixture, adapter, harness, access, material, expires_at) do
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
      sandbox_profile_revision: digest("integration-sandbox"),
      network_policy_revision: digest("integration-network"),
      credential_delivery: :local_reference,
      candidate_protocol_revision: adapter.candidate_protocol_revision,
      verification_profile_revision: digest("integration-verifier"),
      budget: material.budget,
      task_classes: ["focused_change"],
      language_classes: ["elixir_phoenix"],
      owner_iri: fixture.actor,
      tenant_iris: [fixture.factory_scope],
      repository_iris: [fixture.repository],
      actor_iris: [fixture.actor],
      capability_iris: [fixture.capability],
      state: :disabled,
      rollout_stage: :evaluation,
      approved_at: fixture.issued_at,
      expires_at: expires_at,
      signer_iri: fixture.actor,
      supersedes_iri: nil,
      signed_digest: digest("integration-profile-signature")
    }

    attributes =
      Map.put(attributes, :profile_digest, DelegatedAgentProfile.material_digest(attributes))

    {:ok, profile} = Knowledge.delegated_agent_profile(attributes)
    profile
  end

  defp readiness!(profile, adapter, observed_at, expires_at) do
    attributes = %{
      profile_iri: profile.iri,
      profile_digest: profile.profile_digest,
      adapter_release_iri: adapter.iri,
      adapter_release_digest: adapter.release_digest,
      cli_version: "0.50.0",
      credential_generation: 1,
      worker_revision: digest("integration-worker"),
      sandbox_profile_revision: profile.sandbox_profile_revision,
      network_policy_revision: profile.network_policy_revision,
      verification_profile_revision: profile.verification_profile_revision,
      candidate_protocol_revision: profile.candidate_protocol_revision,
      worker_ready: true,
      network_ready: true,
      authentication_ready: true,
      candidate_ready: true,
      verifier_ready: true,
      observed_at: observed_at,
      expires_at: expires_at
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

  defp command_attributes(fixture, overrides \\ []) do
    attributes = %{
      policy_graph_iri: fixture.graphs.policy,
      expected_policy_revision:
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.policy),
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      scope_iri: fixture.factory_scope,
      correlation_iri: Phase04Fixture.local!(:activity, System.unique_integer([:positive])),
      causation_iri: fixture.bootstrap_command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      reason: "delegated coding agent phase 1 integration",
      recorded_at: fixture.issued_at
    }

    Map.merge(attributes, Map.new(overrides))
  end

  defp execute!(fixture, {:ok, command}), do: execute_command!(fixture, command)

  defp execute_command!(fixture, command) do
    {:ok, receipt} = Writer.execute(fixture.writer, command)
    receipt
  end

  defp query(fixture, name, parameters) do
    QueryRunner.execute(
      name,
      QueryCatalog.delegated_agent_version(),
      parameters,
      fixture.authority,
      fixture.factory_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp transition_iri(profile, revision, state) do
    resource(
      :control_transition,
      Enum.join([profile.iri, "delegated_agent_profile", revision, state], "\n")
    )
  end

  defp value(row, key) do
    case Map.get(row, key) do
      %{value: value} -> value
      value -> value
    end
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp clock(fixture), do: fn -> fixture.issued_at end
end

defmodule JidoCode.Knowledge.DelegatedAgentGraphProtocolTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Control.DelegatedAdapterRelease
  alias JidoCode.Knowledge.Control.DelegatedAgentProfile
  alias JidoCode.Knowledge.Control.DelegatedAgentReadiness
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryParameters
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-26 15:00:00Z]
  @later ~U[2026-08-26 16:00:00Z]
  @expiry ~U[2026-09-26 15:00:00Z]

  test "publishes protocol 2.9.0 while preserving 2.8.0 read compatibility" do
    assert CommandRegistry.delegated_agent_version() == "2.9.0"

    for command <- [
          "RegisterDelegatedAdapterRelease",
          "RegisterDelegatedAgentProfile",
          "TransitionDelegatedAgentProfile",
          "RecordDelegatedAgentReadiness"
        ] do
      assert {:ok, %{name: ^command, version: "2.9.0"}} =
               CommandRegistry.resolve(command, "2.9.0")
    end

    assert {:ok, %{version: "2.8.0"}} =
             CommandRegistry.resolve("RegisterManagedCodingProfile", "2.8.0")

    assert {:error, %{kind: :invalid_input}} =
             CommandRegistry.resolve("RegisterDelegatedAgentProfile", "2.8.0")

    assert QueryCatalog.delegated_agent_version() == "2.9.0"

    for query <- [
          :selectable_agent_offerings_by_scope,
          :delegated_agent_profile_detail,
          :delegated_agent_readiness_by_profile,
          :delegated_agent_profile_history
        ] do
      assert query in QueryCatalog.names("2.9.0")
      assert {:ok, %{version: "2.9.0"}} = QueryCatalog.fetch(query, "2.9.0")
      refute query in QueryCatalog.names("2.8.0")
    end

    assert :managed_coding_profile in QueryCatalog.names("2.8.0")
    assert :ok = QueryCatalog.verify()
  end

  test "registers an exact adapter, profile, and expiring readiness observation" do
    release = release!()
    profile = profile!(release)
    readiness = readiness!(profile, release)
    attributes = command_attributes()

    assert {:ok, release_command} =
             Knowledge.register_delegated_adapter_release(release, attributes,
               clock: fn -> @now end
             )

    assert release_command.command_type == "RegisterDelegatedAdapterRelease"
    assert release_command.command_version == "2.9.0"
    assert release_command.ontology_version == "1.4.0"

    assert {:ok, profile_command} =
             Knowledge.register_delegated_agent_profile(profile, attributes,
               clock: fn -> @now end
             )

    assert profile_command.command_type == "RegisterDelegatedAgentProfile"

    assert {:ok, enabled} =
             Knowledge.transition_delegated_agent_profile(
               profile,
               %{
                 current_state: :disabled,
                 current_revision: 0,
                 current_transition: initial_transition(profile)
               },
               :enabled,
               %{attributes | expected_dataset_revision: 2, expected_policy_revision: 2},
               clock: fn -> @now end
             )

    assert enabled.command_type == "TransitionDelegatedAgentProfile"

    assert {:ok, readiness_command} =
             Knowledge.record_delegated_agent_readiness(readiness, attributes,
               clock: fn -> @now end
             )

    assert readiness_command.command_type == "RecordDelegatedAgentReadiness"
    assert DelegatedAgentReadiness.selectable?(readiness, @later)
    refute DelegatedAgentReadiness.selectable?(readiness, @expiry)
  end

  test "rejects unknown authority vocabulary and legacy deployment writes" do
    release = release_attributes()

    assert {:error, _error} =
             release
             |> Map.put(:provider, :unreviewed_provider)
             |> signed_release()
             |> Knowledge.delegated_adapter_release()

    assert {:error, _error} =
             release
             |> Map.put(:prompt_transport, :argv)
             |> signed_release()
             |> Knowledge.delegated_adapter_release()

    assert {:error, _error} =
             release
             |> Map.put(:executable_registry_key, "caller_supplied_binary")
             |> signed_release()
             |> Knowledge.delegated_adapter_release()

    accepted = release!()
    profile = profile_attributes(accepted)

    assert {:error, _error} =
             profile
             |> Map.put(:deployment_class, :developer_local_cli)
             |> signed_profile()
             |> Knowledge.delegated_agent_profile()

    assert {:error, _error} =
             profile
             |> Map.put(:runtime_class, :host_controlled)
             |> signed_profile()
             |> Knowledge.delegated_agent_profile()
  end

  test "binds scoped catalog query parameters as data, never query fragments" do
    {:ok, graph} = GraphRegistry.graph_iri(:factory_policy, %{})
    {:ok, definition} = QueryCatalog.fetch(:selectable_agent_offerings_by_scope, "2.9.0")

    parameters = %{
      graph: graph,
      actor: resource(:authorization_grant, "query-actor"),
      tenant: resource(:authorization_grant, "query-tenant"),
      repository: resource(:repository_snapshot, "query-repository"),
      capability: resource(:capability_declaration, "query-capability"),
      task_class: "focused_change",
      language_class: "elixir_phoenix",
      instant: @now
    }

    assert {:ok, bound} = QueryParameters.bind(definition, parameters)
    assert bound.graph_iris == [graph]
    refute bound.query =~ "{{"

    assert {:error, _error} =
             QueryParameters.bind(definition, %{parameters | task_class: "x\n} UNION { ?s ?p ?o"})
  end

  defp release! do
    attributes = release_attributes() |> signed_release()
    assert {:ok, release} = Knowledge.delegated_adapter_release(attributes)
    release
  end

  defp release_attributes do
    %{
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
      capability_classes: [:deny_all, :bounded_read_only],
      deployment_classes: [:developer_local],
      journal_policy: "controller_owned",
      session_policy: "none",
      cancellation_enforcement: :native_and_outer,
      observation_completeness: :partial,
      unavailable_fields: ["internal_tool_arguments"],
      conformance_digest: digest("conformance"),
      security_evidence_digest: digest("security"),
      state: :accepted,
      approved_at: @now,
      expires_at: @expiry,
      signer_iri: resource(:authorization_grant, "release-signer"),
      supersedes_iri: nil
    }
  end

  defp signed_release(attributes) do
    attributes
    |> Map.put(:signed_digest, digest("release-signature"))
    |> then(&Map.put(&1, :release_digest, DelegatedAdapterRelease.material_digest(&1)))
  end

  defp profile!(release) do
    attributes = profile_attributes(release) |> signed_profile()
    assert {:ok, profile} = Knowledge.delegated_agent_profile(attributes)
    profile
  end

  defp profile_attributes(release) do
    %{
      revision: 1,
      display_name: "Codex subscription",
      agent_key: "codex_subscription",
      runtime_class: :delegated_cli,
      provider: :codex,
      harness_profile_iri: resource(:harness_profile, "delegated-harness"),
      model_access_profile_iri: resource(:model_access_profile, "delegated-access"),
      adapter_release_iri: release.iri,
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_mode: :subscription,
      prompt_transport: :stdin,
      session_policy: :none,
      capability_class: :bounded_read_only,
      tool_manifest_digest: digest("tool-manifest"),
      workspace_policy_revision: digest("workspace"),
      sandbox_profile_revision: digest("sandbox"),
      network_policy_revision: digest("network"),
      credential_delivery: :local_reference,
      candidate_protocol_revision: digest("candidate"),
      verification_profile_revision: digest("verifier"),
      budget: %{wall_ms: 60_000, turns: 10, output_bytes: 100_000},
      task_classes: ["focused_change"],
      language_classes: ["elixir_phoenix"],
      owner_iri: resource(:authorization_grant, "profile-owner"),
      tenant_iris: [resource(:authorization_grant, "tenant")],
      repository_iris: [resource(:repository_snapshot, "repository")],
      actor_iris: [resource(:authorization_grant, "actor")],
      capability_iris: [resource(:capability_declaration, "capability")],
      state: :disabled,
      rollout_stage: :evaluation,
      approved_at: @now,
      expires_at: @expiry,
      signer_iri: resource(:authorization_grant, "profile-signer"),
      supersedes_iri: nil
    }
  end

  defp signed_profile(attributes) do
    attributes
    |> Map.put(:signed_digest, digest("profile-signature"))
    |> then(&Map.put(&1, :profile_digest, DelegatedAgentProfile.material_digest(&1)))
  end

  defp readiness!(profile, release) do
    attributes = %{
      profile_iri: profile.iri,
      profile_digest: profile.profile_digest,
      adapter_release_iri: release.iri,
      adapter_release_digest: release.release_digest,
      cli_version: "0.50.0",
      credential_generation: 1,
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
      observed_at: @now,
      expires_at: @expiry
    }

    attributes =
      Map.put(
        attributes,
        :observation_digest,
        DelegatedAgentReadiness.material_digest(attributes)
      )

    assert {:ok, readiness} = Knowledge.delegated_agent_readiness(attributes)
    readiness
  end

  defp command_attributes do
    {:ok, policy_graph} = GraphRegistry.graph_iri(:factory_policy, %{})
    actor = resource(:authorization_grant, "command-actor")

    %{
      policy_graph_iri: policy_graph,
      principal_iri: actor,
      actor_iri: actor,
      scope_iri: resource(:execution_context, "factory-scope"),
      correlation_iri: resource(:command_request, "correlation"),
      causation_iri: resource(:command_request, "causation"),
      expected_dataset_revision: 1,
      expected_policy_revision: 1,
      reason: "record exact delegated agent contract",
      recorded_at: @now
    }
  end

  defp initial_transition(profile) do
    {:ok, iri} =
      ResourceIdentity.deterministic(
        :control_transition,
        Enum.join([profile.iri, "delegated_agent_profile", "0", "disabled"], "\n")
      )

    iri
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

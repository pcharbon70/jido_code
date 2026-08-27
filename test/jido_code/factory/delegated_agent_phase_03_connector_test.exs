defmodule JidoCode.Factory.DelegatedAgentPhase03ConnectorTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CodexProviderEgress
  alias JidoCode.Factory.Credential.CodexLocalConnector
  alias JidoCode.Factory.Credential.Policy
  alias JidoCode.Factory.Credential.ReleaseRequest
  alias JidoCode.Factory.CredentialBroker
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Sandbox.Tier
  alias JidoCode.Runtime.JidoHarness.CodexLocalRelease
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.Runtime.JidoHarness.DeveloperLocalLaunch
  alias JidoCode.TestSupport.FakeCredentialVault
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-26 18:00:00Z]

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "dca-phase-03-connector-#{System.unique_integer([:positive, :monotonic])}"
      )

    credential_root = Path.join(root, "credentials")
    workspace = Path.join(root, "workspace")
    login = Path.join(credential_root, "auth.json")
    File.mkdir_p!(credential_root)
    File.mkdir_p!(workspace)
    File.chmod!(credential_root, 0o700)
    File.write!(login, ~s({"login":"opaque-fixture"}))
    File.chmod!(login, 0o600)
    on_exit(fn -> File.rm_rf!(root) end)

    reference_iri = resource("credential-reference")
    generation = 7
    owner = self()

    connector =
      start_supervised!(
        {CodexLocalConnector,
         credential_root: credential_root,
         references: %{reference_iri => %{path: login, generation: generation}},
         revoker: fn private, reason ->
           send(owner, {:codex_attachment_revoked, private.receipt.attachment_id, reason})
           :ok
         end},
        id: {:codex_local_connector, System.unique_integer([:positive, :monotonic])}
      )

    {:ok,
     root: root,
     credential_root: credential_root,
     workspace: workspace,
     login: login,
     reference_iri: reference_iri,
     generation: generation,
     connector: connector}
  end

  test "attaches only an opaque parent-only local login reference", context do
    {broker, request, current, payload} = release_fixture(context)

    assert {:ok, release} =
             CredentialBroker.release(
               broker,
               request,
               current,
               {CodexLocalConnector, context.connector},
               payload
             )

    attachment = release.connector_result
    assert release.credential_class == :local_cli_reference
    assert attachment.state == :active
    assert attachment.mount_point == CodexLocalConnector.mount_point()
    assert attachment.mount_mode == :read_only
    assert attachment.parent_access == :provider_authentication_only
    assert attachment.tool_descendant_access == :denied
    assert attachment.egress == %{parent: :brokered_provider_only, tool_descendants: :deny}
    assert attachment.environment == CodexLocalConnector.fixed_environment()
    refute attachment.source_path_retained
    refute attachment.reusable_material_exported
    refute Map.has_key?(attachment, :source_path)
    refute inspect(release, limit: :infinity) =~ context.login
    refute_received {:credential_vault_checkout, _reference, _permit}

    live = attachment_current(request, context, @now)

    assert {:ok, ^attachment} =
             CodexLocalConnector.attachment(context.connector, attachment.attachment_id, live)

    assert {:error, %AdapterError{operation: :codex_local_attachment}} =
             CodexLocalConnector.attachment(
               context.connector,
               attachment.attachment_id,
               %{live | fencing_token: live.fencing_token + 1}
             )

    assert {:error, %AdapterError{operation: :codex_local_attachment}} =
             CodexLocalConnector.attachment(
               context.connector,
               attachment.attachment_id,
               %{live | at: request.policy.expires_at}
             )
  end

  test "rejects writable, workspace-owned, and symlink-escaped login material", context do
    File.chmod!(context.login, 0o644)
    assert_release_denied(context)

    File.chmod!(context.login, 0o600)
    assert_release_denied(%{context | workspace: context.credential_root})

    outside = Path.join(context.root, "outside")
    File.mkdir_p!(outside)
    File.chmod!(outside, 0o700)
    escaped = Path.join(outside, "auth.json")
    File.write!(escaped, "opaque")
    File.chmod!(escaped, 0o600)
    link = Path.join(context.credential_root, "linked")
    File.ln_s!(outside, link)

    escaped_context = %{context | login: Path.join(link, "auth.json")}
    connector = connector_for(escaped_context)
    assert_release_denied(%{escaped_context | connector: connector})
  end

  test "destroys the attachment only after the semantic revocation transition", context do
    {broker, request, current, payload} = release_fixture(context)

    assert {:ok, %{connector_result: attachment}} =
             CredentialBroker.release(
               broker,
               request,
               current,
               {CodexLocalConnector, context.connector},
               payload
             )

    live = attachment_current(request, context, @now)

    assert {:error, %AdapterError{operation: :codex_local_attachment_revoke}} =
             CodexLocalConnector.revoke(
               context.connector,
               attachment.attachment_id,
               :cancellation,
               live
             )

    assert {:ok, receipt} =
             CodexLocalConnector.revoke(
               context.connector,
               attachment.attachment_id,
               :cancellation,
               Map.put(live, :semantic_transition_committed, true)
             )

    assert receipt.status == :revoked
    assert receipt.source_destroyed
    assert_received {:codex_attachment_revoked, attachment_id, :cancellation}
    assert attachment_id == attachment.attachment_id

    assert {:error, %AdapterError{operation: :codex_local_attachment}} =
             CodexLocalConnector.attachment(context.connector, attachment.attachment_id, live)
  end

  test "admits only parent provider traffic to the pinned OpenAI API destination" do
    assert {:ok, policy} = CodexProviderEgress.policy(egress_attributes())
    assert [%{host: "api.openai.com", port: 443, path_prefix: "/v1"}] = policy.destinations
    assert policy.maximum_redirects == 0

    assert {:ok, request} =
             CodexProviderEgress.request(policy, :codex_parent, %{
               uri: "https://api.openai.com/v1/responses",
               method: :post,
               request_bytes: 128
             })

    assert request.traffic_class == :provider_api
    assert request.confidentiality == :restricted

    assert {:error, %AdapterError{operation: :codex_tool_descendant_egress}} =
             CodexProviderEgress.request(policy, :tool_descendant, %{
               uri: "https://api.openai.com/v1/responses",
               method: :post,
               request_bytes: 128
             })
  end

  test "binds the Codex launch to exact consent, attachment, namespace, env, and egress",
       context do
    request = execution_request!()
    {broker, release_request, current, payload} = release_fixture(context)

    assert {:ok, %{connector_result: attachment}} =
             CredentialBroker.release(
               broker,
               release_request,
               current,
               {CodexLocalConnector, context.connector},
               payload
             )

    {:ok, profile} = CodexRelease.runtime_profile()
    attributes = launch_attributes(request, context, attachment)

    assert {:ok, launch} = DeveloperLocalLaunch.build(request, profile, attributes)
    assert launch.credential_attachment_digest == attachment.attachment_digest
    assert launch.environment == CodexLocalConnector.fixed_environment()
    assert launch.provider_egress.tool_descendants == :deny
    assert launch.outer_worker.process_namespace == :isolated
    refute launch.outer_worker.store_handle

    mutations = [
      &put_in(&1, [:consent, :actor_iri], resource("other-actor")),
      &put_in(&1, [:environment, "CODEX_HOME"], context.workspace),
      &put_in(&1, [:provider_egress, :tool_descendants], :allow),
      &put_in(&1, [:credential_attachment, :tool_descendant_access], :read_only),
      &put_in(&1, [:worker, :ssh_agent], true)
    ]

    for mutation <- mutations do
      assert {:error, %AdapterError{operation: :jido_harness_developer_local_launch}} =
               DeveloperLocalLaunch.build(request, profile, mutation.(attributes))
    end
  end

  defp assert_release_denied(context) do
    {broker, request, current, payload} = release_fixture(context)

    assert {:error, %AdapterError{operation: :codex_local_attachment}} =
             CredentialBroker.release(
               broker,
               request,
               current,
               {CodexLocalConnector, context.connector},
               payload
             )
  end

  defp connector_for(context) do
    start_supervised!(
      {CodexLocalConnector,
       credential_root: context.credential_root,
       references: %{
         context.reference_iri => %{path: context.login, generation: context.generation}
       }},
      id: {:codex_local_connector, System.unique_integer([:positive, :monotonic])}
    )
  end

  defp release_fixture(context) do
    assert {:ok, reference} =
             CredentialReference.new(%{
               iri: context.reference_iri,
               provider: "codex",
               key: "local/codex/login"
             })

    assert {:ok, identity} = CodexLocalConnector.identity(context.connector)

    assert {:ok, policy} =
             Policy.new(%{
               reference: reference,
               credential_class: :local_cli_reference,
               actor_iri: resource("actor"),
               delegated_agent_iri: resource("agent"),
               delegation_iri: resource("delegation"),
               repository_iri: resource("repository"),
               provider: "codex",
               operation: "codex.authenticate",
               audience: CodexLocalRelease.provider_audience(),
               scopes: ["provider:authenticate"],
               expires_at: DateTime.add(@now, 300, :second),
               single_use: false,
               attempt_iri: resource("attempt"),
               lease_iri: resource("lease"),
               fencing_token: 31,
               trusted_connector_identity: identity.name <> "@" <> identity.digest,
               enforcement: :existing_cli_session,
               profile_revision: 1,
               credential_revision: 1,
               revocation_generation: context.generation,
               invocation_iri: resource("invocation"),
               explicit_local_consent: true,
               managed_eligible: false
             })

    assert {:ok, request} =
             ReleaseRequest.new(policy, %{
               operation: policy.operation,
               audience: policy.audience,
               minimum_scopes: policy.scopes,
               invocation_iri: policy.invocation_iri,
               managed_claim: false
             })

    vault = %{owner: self(), material: "unused-local-reference"}

    broker =
      start_supervised!(
        {CredentialBroker, vault: {FakeCredentialVault, vault}, clock: fn -> @now end},
        id: {:credential_broker, System.unique_integer([:positive, :monotonic])}
      )

    payload = %{
      operation: :attach_codex_login,
      profile_digest: CodexLocalRelease.manifest().profile_digest,
      credential_generation: context.generation,
      workspace_path: context.workspace,
      attempt_iri: policy.attempt_iri,
      fencing_token: policy.fencing_token,
      provider_audience: CodexLocalRelease.provider_audience(),
      environment: CodexLocalConnector.fixed_environment(),
      isolation: %{
        parent_authentication: true,
        tool_descendant_credential_access: false,
        credential_mount: :read_only,
        credential_mount_outside_workspace: true,
        process_namespace: :isolated,
        host_home: false,
        ssh_agent: false,
        docker_socket: false,
        publication_credentials: false,
        arbitrary_egress: false
      }
    }

    {broker, request, current(policy), payload}
  end

  defp current(policy) do
    %{
      lease_state: :active,
      actor_iri: policy.actor_iri,
      delegated_agent_iri: policy.delegated_agent_iri,
      delegation_iri: policy.delegation_iri,
      repository_iri: policy.repository_iri,
      provider: policy.provider,
      attempt_iri: policy.attempt_iri,
      lease_iri: policy.lease_iri,
      fencing_token: policy.fencing_token,
      profile_revision: policy.profile_revision,
      credential_revision: policy.credential_revision,
      revocation_generation: policy.revocation_generation,
      invocation_iri: policy.invocation_iri
    }
  end

  defp attachment_current(request, context, at) do
    %{
      attempt_iri: request.policy.attempt_iri,
      fencing_token: request.policy.fencing_token,
      credential_generation: context.generation,
      at: at
    }
  end

  defp egress_attributes do
    %{
      policy_iri: resource("egress-policy"),
      attempt_iri: resource("attempt"),
      invocation_iri: resource("egress-invocation"),
      lease_iri: resource("lease"),
      fencing_token: 31,
      profile_revision: 1,
      egress_revision: 1,
      revocation_generation: 7,
      resolver_identity: "controlled-resolver@sha256:" <> String.duplicate("a", 64),
      expires_at: DateTime.add(@now, 300, :second)
    }
  end

  defp launch_attributes(request, context, attachment) do
    {:ok, isolation} = Tier.profile(:micro_vm)

    %{
      consent: %{
        consent_digest: String.duplicate("c", 64),
        actor_iri: request.actor_iri,
        repository_iri: request.repository_iri,
        task_iri: request.task_iri,
        attempt_iri: request.attempt_iri,
        lease_iri: request.lease_iri,
        fencing_token: request.fencing_token,
        profile_digest: CodexRelease.profile_digest(),
        credential_reference_iri: context.reference_iri,
        credential_generation: context.generation,
        billing_classification: :subscription,
        purpose: :execution
      },
      worker: %{
        snapshot_iri: request.snapshot_iri,
        workspace_path: context.workspace,
        cli_path: "/opt/jido-code/codex/0.144.6/bin/codex",
        cli_digest: "sha256:" <> CodexRelease.executable_sha256(),
        isolation_profile: isolation,
        process_namespace: :isolated,
        disposable: true,
        store_handle: false,
        publication_credentials: false,
        ssh_agent: false,
        docker_socket: false,
        unrelated_repositories: false
      },
      environment: CodexLocalConnector.fixed_environment(),
      provider_egress: %{
        mode: :brokered,
        destinations: [CodexLocalRelease.provider_audience()],
        parent: :provider_only,
        tool_descendants: :deny
      },
      credential_reference_iri: context.reference_iri,
      credential_attachment: attachment,
      cli_version: CodexRelease.cli_version(),
      provider_version: CodexRelease.model(),
      limits: %{
        run_count: 2,
        cpu_ms: 30_000,
        memory_bytes: 536_870_912,
        process_count: 64,
        disk_bytes: 1_073_741_824,
        output_bytes: 1_048_576,
        wall_ms: 60_000,
        idle_ms: 15_000,
        session_turns: 2
      },
      extensions: [],
      mcp_servers: [],
      skills: [],
      provider_configuration: [],
      additional_directories: []
    }
  end

  defp execution_request! do
    {:ok, request} =
      Request.new(%{
        attempt_iri: resource("attempt"),
        lease_iri: resource("lease"),
        task_iri: resource("task"),
        goal_iri: resource("goal"),
        plan_iri: resource("plan"),
        repository_iri: resource("repository"),
        snapshot_iri: resource("snapshot"),
        actor_iri: resource("actor"),
        agent_iri: resource("agent"),
        capability_iri: resource("capability"),
        fencing_token: 31,
        context_digest: String.duplicate("d", 64),
        runtime_version: "jido-harness:dca-phase-03",
        constraints: %{deployment_class: :developer_local}
      })

    request
  end

  defp resource(seed), do: Phase04Fixture.resource!("dca-phase-03-connector-#{seed}")
end

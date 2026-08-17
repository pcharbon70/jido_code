defmodule JidoCode.Factory.Harness.PhaseH04IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Policy, as: CredentialPolicy
  alias JidoCode.Factory.Credential.ReleaseRequest
  alias JidoCode.Factory.CredentialBroker
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Egress.Destination
  alias JidoCode.Factory.Egress.Policy, as: EgressPolicy
  alias JidoCode.Factory.Egress.Request, as: EgressRequest
  alias JidoCode.Factory.EgressBroker
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Sandbox.IsolationProfile
  alias JidoCode.Factory.Sandbox.Request, as: SandboxRequest
  alias JidoCode.Factory.Sandbox.Tier
  alias JidoCode.Factory.SandboxSupervisor
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeCredentialVault
  alias JidoCode.TestSupport.FakeEgressAudit
  alias JidoCode.TestSupport.FakeEgressResolver
  alias JidoCode.TestSupport.FakeEgressTransport
  alias JidoCode.TestSupport.FakeProductionSandbox
  alias JidoCode.TestSupport.FakeTrustedConnector

  @connector_name "JidoCode.TestSupport.FakeTrustedConnector"
  @connector_digest "sha256:" <> String.duplicate("b", 64)
  @resolver_name "JidoCode.TestSupport.FakeEgressResolver"
  @resolver_digest "sha256:" <> String.duplicate("e", 64)
  @secret "ghp_INTEGRATION1234567890abcdefghijkl"

  test "one attempt keeps sandbox, egress, and credential capabilities disjoint end to end" do
    sandbox = start_supervised!({SandboxSupervisor, [adapters: sandbox_adapters()]})
    sandbox_request = sandbox_request!("end-to-end")

    assert {:ok, session, provisioned} =
             SandboxSupervisor.provision(sandbox, :build, sandbox_request,
               authority: AllowExecutionAuthority
             )

    assert session.tier == :micro_vm
    assert session.profile.network == :deny
    refute session.profile.ambient_credentials

    assert {:ok, executed} =
             SandboxSupervisor.execute(
               sandbox,
               sandbox_request,
               %{name: "mix-test", workload: :build, usage: zero_usage()},
               authority: AllowExecutionAuthority
             )

    {credential_broker, credential_request, credential_current, vault_key} =
      credential_fixture()

    assert {:ok, credential_release} =
             CredentialBroker.release(
               credential_broker,
               credential_request,
               credential_current,
               trusted_connector(),
               %{operation: "repository.write", candidate_digest: String.duplicate("c", 64)}
             )

    assert_received {:credential_vault_checkout, _reference_iri, permit_id}
    assert_received {:trusted_connector_material, ^permit_id, secret_bytes, "repository.write"}
    assert secret_bytes == byte_size(@secret)

    {egress_broker, egress_request, egress_current} = egress_fixture()
    body = "candidate=" <> String.duplicate("c", 64)
    egress_request = %{egress_request | request_bytes: byte_size(body)}

    assert {:ok, egress_result} =
             EgressBroker.request(egress_broker, egress_request, egress_current, body)

    assert_received {:egress_audit, egress_decision}
    assert_received {:egress_transport, ^egress_request, endpoint, ^body}
    assert endpoint.connect_address == {93, 184, 216, 34}
    assert endpoint.tls_server_name == "api.github.com"

    assert {:ok, finished} =
             SandboxSupervisor.finish(
               sandbox,
               sandbox_request,
               [],
               %{
                 base_snapshot_iri: sandbox_request.base_snapshot_iri,
                 generator_iri: credential_request.policy.invocation_iri
               },
               authority: AllowExecutionAuthority
             )

    assert finished.destroyed.details.status == :destroyed

    exposed_surfaces = %{
      prompt_context: %{credential_reference_iri: credential_request.policy.reference.iri},
      tool_arguments: %{operation: credential_request.operation},
      execution_journal: [provisioned, executed, finished.destroyed],
      telemetry: [egress_decision],
      graph_observations: [finished.instance],
      credential_result: credential_release,
      egress_result: egress_result
    }

    serialized = inspect(exposed_surfaces, limit: :infinity, printable_limit: :infinity)
    refute serialized =~ @secret
    refute serialized =~ vault_key
    refute serialized =~ "authorization"
  end

  test "revision, revocation, lease, fence, invocation, and expiry changes stop both brokers" do
    {credential_broker, credential_request, credential_current, _vault_key} =
      credential_fixture()

    credential_mutations = [
      &Map.put(&1, :lease_state, :revoked),
      &Map.update!(&1, :fencing_token, fn value -> value + 1 end),
      &Map.update!(&1, :profile_revision, fn value -> value + 1 end),
      &Map.update!(&1, :credential_revision, fn value -> value + 1 end),
      &Map.update!(&1, :revocation_generation, fn value -> value + 1 end),
      &Map.put(&1, :invocation_iri, resource!(:tool_invocation, "credential-stale"))
    ]

    for mutate <- credential_mutations do
      assert {:error, %AdapterError{operation: :credential_authority}} =
               CredentialBroker.release(
                 credential_broker,
                 credential_request,
                 mutate.(credential_current),
                 trusted_connector(),
                 %{operation: "repository.write"}
               )

      refute_received {:credential_vault_checkout, _reference, _permit}
    end

    {egress_broker, egress_request, egress_current} = egress_fixture()

    egress_mutations = [
      &Map.put(&1, :lease_state, :revoked),
      &Map.update!(&1, :fencing_token, fn value -> value + 1 end),
      &Map.update!(&1, :profile_revision, fn value -> value + 1 end),
      &Map.update!(&1, :egress_revision, fn value -> value + 1 end),
      &Map.update!(&1, :revocation_generation, fn value -> value + 1 end),
      &Map.put(&1, :invocation_iri, resource!(:tool_invocation, "egress-stale"))
    ]

    for mutate <- egress_mutations do
      assert {:error, %AdapterError{operation: :egress_policy}} =
               EgressBroker.request(egress_broker, egress_request, mutate.(egress_current), "")

      refute_received {:egress_resolve, _host}
      refute_received {:egress_transport, _request, _endpoint, _body}
    end
  end

  test "closed tier pins and broker refusals remain visible at the integration boundary" do
    pins = Tier.pins()

    for tier <- Tier.all() do
      assert {:ok, profile} = Tier.profile(tier)
      assert pins[tier].image_digest == profile.image_digest
      assert pins[tier].tool_digests == profile.tool_digests
      assert Regex.match?(~r/^sha256:[a-f0-9]{64}$/, IsolationProfile.digest(profile))
      refute IsolationProfile.admits?(profile, Map.put(profile.limits, :network, :allowlisted))
    end

    {egress_broker, egress_request, egress_current} = egress_fixture()

    assert {:error, %AdapterError{operation: :egress_default_deny}} =
             EgressBroker.request(egress_broker, nil, egress_current, "")

    classified = %{egress_request | confidentiality: :restricted}

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(egress_broker, classified, egress_current, "")

    package = %{egress_request | traffic_class: :package_registry}

    assert {:error, %AdapterError{operation: :egress_incompatible_build}} =
             EgressBroker.request(egress_broker, package, egress_current, "")

    refute_received {:egress_transport, _request, _endpoint, _body}
  end

  defp sandbox_adapters do
    Map.new(Tier.all(), fn tier ->
      {:ok, profile} = Tier.profile(tier)

      {tier,
       {FakeProductionSandbox,
        %{owner: self(), profile: profile, clock: fn -> DateTime.utc_now() end}}}
    end)
  end

  defp sandbox_request!(seed) do
    assert {:ok, execution} =
             ExecutionRequest.new(%{
               attempt_iri: resource!(:execution_attempt, "attempt-#{seed}"),
               lease_iri: resource!(:execution_lease, "lease-#{seed}"),
               task_iri: resource!("task-#{seed}"),
               goal_iri: resource!("goal-#{seed}"),
               plan_iri: resource!("plan-#{seed}"),
               repository_iri: resource!("repository-#{seed}"),
               snapshot_iri: resource!(:repository_snapshot, "snapshot-#{seed}"),
               actor_iri: resource!("actor-#{seed}"),
               agent_iri: resource!("agent-#{seed}"),
               capability_iri: resource!("capability-#{seed}"),
               fencing_token: 421,
               context_digest: String.duplicate("a", 64),
               runtime_version: "phase-h04-integration/1",
               constraints: %{}
             })

    assert {:ok, request} =
             SandboxRequest.new(%{
               execution: execution,
               base_snapshot_iri: execution.snapshot_iri,
               allowed_write_paths: ["artifacts"],
               command_allowlist: ["mix-test"],
               environment_allowlist: [],
               secret_reference_iris: [],
               limits: %{
                 cpu_ms: 1_000,
                 memory_bytes: 1_048_576,
                 process_count: 4,
                 disk_bytes: 4_096,
                 output_bytes: 256,
                 timeout_ms: 1_000,
                 network: :deny
               }
             })

    request
  end

  defp credential_fixture do
    key = "vault/github/integration-writer"

    assert {:ok, reference} =
             CredentialReference.new(%{
               iri: resource!("credential-reference"),
               provider: "github",
               key: key
             })

    attributes = %{
      reference: reference,
      credential_class: :provider_token,
      actor_iri: resource!("credential-actor"),
      delegated_agent_iri: resource!("credential-agent"),
      delegation_iri: resource!("credential-delegation"),
      repository_iri: resource!("credential-repository"),
      provider: "github",
      operation: "repository.write",
      audience: "https://api.github.com",
      scopes: ["contents:write"],
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
      single_use: true,
      attempt_iri: resource!(:execution_attempt, "credential-attempt"),
      lease_iri: resource!(:execution_lease, "credential-lease"),
      fencing_token: 422,
      trusted_connector_identity: @connector_name <> "@" <> @connector_digest,
      enforcement: :attaching_proxy,
      profile_revision: 1,
      credential_revision: 1,
      revocation_generation: 1,
      invocation_iri: resource!(:tool_invocation, "credential-invocation"),
      explicit_local_consent: false,
      managed_eligible: true
    }

    assert {:ok, policy} = CredentialPolicy.new(attributes)

    assert {:ok, request} =
             ReleaseRequest.new(policy, %{
               operation: policy.operation,
               audience: policy.audience,
               minimum_scopes: policy.scopes,
               invocation_iri: policy.invocation_iri,
               managed_claim: true
             })

    current = %{
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

    vault = %{owner: self(), material: @secret, tracker: nil, delay_ms: nil}

    broker =
      start_supervised!(
        {CredentialBroker, [vault: {FakeCredentialVault, vault}]},
        id: {:integration_credential_broker, System.unique_integer([:positive, :monotonic])}
      )

    {broker, request, current, key}
  end

  defp trusted_connector do
    {FakeTrustedConnector,
     %{
       owner: self(),
       identity: %{
         name: @connector_name,
         digest: @connector_digest,
         trusted: true,
         delivery: :direct,
         credential_classes: [:provider_token]
       }
     }}
  end

  defp egress_fixture do
    assert {:ok, destination} =
             Destination.new(%{
               scheme: "https",
               host: "api.github.com",
               port: 443,
               path_prefix: "/repos",
               kind: :approved_api
             })

    assert {:ok, policy} =
             EgressPolicy.new(%{
               policy_iri: resource!("egress-policy"),
               attempt_iri: resource!(:execution_attempt, "egress-attempt"),
               invocation_iri: resource!(:tool_invocation, "egress-invocation"),
               lease_iri: resource!(:execution_lease, "egress-lease"),
               fencing_token: 423,
               profile_revision: 1,
               egress_revision: 1,
               revocation_generation: 1,
               destinations: [destination],
               methods: [:post],
               allowed_integrity: [:verified],
               allowed_confidentiality: [:internal],
               maximum_request_bytes: 1_024,
               maximum_response_bytes: 1_024,
               maximum_redirects: 0,
               rate_limit: %{requests: 20, window_ms: 60_000},
               resolver_identity: @resolver_name <> "@" <> @resolver_digest,
               expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
             })

    assert {:ok, request} =
             EgressRequest.new(policy, %{
               uri: "https://api.github.com/repos/example",
               method: :post,
               traffic_class: :provider_api,
               integrity: :verified,
               confidentiality: :internal,
               request_bytes: 0,
               redirect_count: 0
             })

    current = %{
      lease_state: :active,
      attempt_iri: policy.attempt_iri,
      invocation_iri: policy.invocation_iri,
      lease_iri: policy.lease_iri,
      fencing_token: policy.fencing_token,
      profile_revision: policy.profile_revision,
      egress_revision: policy.egress_revision,
      revocation_generation: policy.revocation_generation
    }

    resolver = %{
      owner: self(),
      identity: %{name: @resolver_name, digest: @resolver_digest, controlled: true},
      resolve: fn _host -> {:ok, [{93, 184, 216, 34}]} end
    }

    transport = %{
      owner: self(),
      request: fn _request, _endpoint, _body ->
        {:ok,
         %{
           status: 200,
           response_bytes: 0,
           location: nil,
           result: %{outcome: :accepted, provider_ref: "provider-operation-1"}
         }}
      end
    }

    audit = %{owner: self(), result: :ok}

    broker =
      start_supervised!(
        {EgressBroker,
         [
           resolver: {FakeEgressResolver, resolver},
           transport: {FakeEgressTransport, transport},
           audit: {FakeEgressAudit, audit}
         ]},
        id: {:integration_egress_broker, System.unique_integer([:positive, :monotonic])}
      )

    {broker, request, current}
  end

  defp zero_usage do
    %{
      cpu_ms: 10,
      memory_bytes: 4_096,
      process_count: 1,
      disk_bytes: 128,
      output_bytes: 32,
      wall_time_ms: 25
    }
  end

  defp resource!(seed), do: resource!(:knowledge_assertion, seed)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h04-integration-#{seed}")
    iri
  end
end

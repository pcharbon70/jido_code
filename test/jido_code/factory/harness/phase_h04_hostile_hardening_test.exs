defmodule JidoCode.Factory.Harness.PhaseH04HostileHardeningTest do
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
  @canary "ghp_CANARY1234567890abcdefghijklmnop"

  test "hooks, workflows, build scripts, and generated binaries cannot select a weaker tier" do
    hostile_workloads = [:package_hook, :git_hook, :workflow, :build_script, :generated_binary]

    for workload <- hostile_workloads do
      assert {:ok, :micro_vm} = Tier.select(workload)
    end

    for tier <- Tier.all() do
      assert {:ok, profile} = Tier.profile(tier)
      assert profile.network == :deny
      refute profile.host_filesystem
      refute profile.docker_socket
      refute profile.ambient_credentials
      assert profile.capabilities == []
      assert profile.no_new_privs
    end

    supervisor = start_supervised!({SandboxSupervisor, [adapters: sandbox_adapters()]})

    other_tiers = [
      restricted_beam: :read_only_analysis,
      container_sandbox: :non_executing_transformation,
      dedicated_host: :unknown_high_risk
    ]

    for {hostile_workload, hostile_index} <- Enum.with_index(hostile_workloads) do
      for {{_tier, provisioned_workload}, tier_index} <- Enum.with_index(other_tiers) do
        request =
          sandbox_request!("downgrade-#{hostile_index}-#{tier_index}", output_bytes: 256)

        assert {:ok, _session, _event} =
                 SandboxSupervisor.provision(supervisor, provisioned_workload, request,
                   authority: AllowExecutionAuthority
                 )

        assert {:error, %AdapterError{operation: :sandbox_workload_boundary}} =
                 SandboxSupervisor.execute(
                   supervisor,
                   request,
                   hostile_command(hostile_workload, zero_usage()),
                   authority: AllowExecutionAuthority
                 )

        refute_received {:production_sandbox, :execute, _attempt}
        assert_received {:production_sandbox, :cancel, attempt}
        assert attempt == request.execution.attempt_iri
        assert_received {:production_sandbox, :destroy, ^attempt}
      end

      request = sandbox_request!("micro-vm-#{hostile_index}", output_bytes: 256)

      assert {:ok, %{tier: :micro_vm}, _event} =
               SandboxSupervisor.provision(supervisor, hostile_workload, request,
                 authority: AllowExecutionAuthority
               )

      assert {:ok, _event} =
               SandboxSupervisor.execute(
                 supervisor,
                 request,
                 hostile_command(hostile_workload, zero_usage()),
                 authority: AllowExecutionAuthority
               )

      assert_received {:production_sandbox, :execute, attempt}
      assert attempt == request.execution.attempt_iri

      assert {:ok, _result} =
               SandboxSupervisor.finish(
                 supervisor,
                 request,
                 [],
                 artifact_context(request, "hostile-#{hostile_index}"),
                 authority: AllowExecutionAuthority
               )
    end
  end

  test "every tier terminates CPU, memory, process, disk, output, and time exhaustion" do
    supervisor = start_supervised!({SandboxSupervisor, [adapters: sandbox_adapters()]})

    workloads = [
      restricted_beam: :read_only_analysis,
      container_sandbox: :non_executing_transformation,
      micro_vm: :build,
      dedicated_host: :unknown_high_risk
    ]

    dimensions = [
      {:cpu_ms, :cpu_ms, :sandbox_cpu_limit},
      {:memory_bytes, :memory_bytes, :sandbox_memory_limit},
      {:process_count, :process_count, :sandbox_process_limit},
      {:disk_bytes, :disk_bytes, :sandbox_disk_limit},
      {:output_bytes, :output_bytes, :sandbox_output_limit},
      {:wall_time_ms, :timeout_ms, :sandbox_time_limit}
    ]

    for {{_tier, workload}, workload_index} <- Enum.with_index(workloads),
        {{usage_key, limit_key, operation}, dimension_index} <- Enum.with_index(dimensions) do
      request =
        sandbox_request!("limit-#{workload_index}-#{dimension_index}", output_bytes: 256)

      assert {:ok, _session, _event} =
               SandboxSupervisor.provision(supervisor, workload, request,
                 authority: AllowExecutionAuthority
               )

      usage = Map.put(zero_usage(), usage_key, request.limits[limit_key] + 1)

      assert {:error, %AdapterError{operation: ^operation}} =
               SandboxSupervisor.execute(
                 supervisor,
                 request,
                 hostile_command(workload, usage),
                 authority: AllowExecutionAuthority
               )

      assert_received {:production_sandbox, :execute, attempt}
      assert attempt == request.execution.attempt_iri
      assert_received {:production_sandbox, :cancel, ^attempt}
      assert_received {:production_sandbox, :destroy, ^attempt}

      assert {:error, %AdapterError{operation: :sandbox_session}} =
               SandboxSupervisor.inspect(supervisor, request, authority: AllowExecutionAuthority)
    end

    stable = sandbox_request!("stable-after-exhaustion", output_bytes: 256)

    assert {:ok, _session, _event} =
             SandboxSupervisor.provision(supervisor, :build, stable,
               authority: AllowExecutionAuthority
             )
  end

  test "artifact count and aggregate output are bounded and destruction still runs" do
    supervisor = start_supervised!({SandboxSupervisor, [adapters: sandbox_adapters()]})

    for {seed, candidates} <- [
          {"artifact-bytes", [candidate(200), candidate(100)]},
          {"artifact-count", List.duplicate(candidate(1), 101)}
        ] do
      request = sandbox_request!(seed, output_bytes: 256)

      assert {:ok, _session, _event} =
               SandboxSupervisor.provision(supervisor, :build, request,
                 authority: AllowExecutionAuthority
               )

      assert {:error, %AdapterError{operation: :sandbox_artifact_output_limit}} =
               SandboxSupervisor.finish(
                 supervisor,
                 request,
                 candidates,
                 artifact_context(request, seed),
                 authority: AllowExecutionAuthority
               )

      assert_received {:production_sandbox, :collect, attempt}
      assert attempt == request.execution.attempt_iri
      assert_received {:production_sandbox, :destroy, ^attempt}
    end
  end

  test "destroy removes attempt state and the next attempt starts without persistence" do
    {:ok, workspace} = Agent.start_link(fn -> %{} end)

    supervisor =
      start_supervised!({SandboxSupervisor, [adapters: sandbox_adapters(workspace: workspace)]})

    first = sandbox_request!("persistence-first", output_bytes: 256)

    assert {:ok, _session, _event} =
             SandboxSupervisor.provision(supervisor, :build, first,
               authority: AllowExecutionAuthority
             )

    assert {:ok, _event} =
             SandboxSupervisor.execute(
               supervisor,
               first,
               hostile_command(:build, zero_usage()) |> Map.put(:write_marker, "persist-me"),
               authority: AllowExecutionAuthority
             )

    assert MapSet.member?(
             Agent.get(workspace, &Map.fetch!(&1, first.execution.attempt_iri)),
             "persist-me"
           )

    assert {:ok, %{destroyed: %{details: %{status: :destroyed}}}} =
             SandboxSupervisor.finish(
               supervisor,
               first,
               [],
               artifact_context(first, "first"),
               authority: AllowExecutionAuthority
             )

    refute Map.has_key?(Agent.get(workspace, & &1), first.execution.attempt_iri)

    second = sandbox_request!("persistence-second", output_bytes: 256)

    assert {:ok, _session, _event} =
             SandboxSupervisor.provision(supervisor, :build, second,
               authority: AllowExecutionAuthority
             )

    assert Agent.get(workspace, &Map.fetch!(&1, second.execution.attempt_iri)) == MapSet.new()
    refute Map.has_key?(Agent.get(workspace, & &1), first.execution.attempt_iri)
  end

  test "credential canaries cannot cross the broker boundary" do
    {policy, request, current} = credential_fixture()

    vault = %{owner: self(), material: @canary, tracker: nil, delay_ms: nil}

    broker =
      start_supervised!(
        {CredentialBroker, [vault: {FakeCredentialVault, vault}]},
        id: {:hostile_credential_broker, System.unique_integer([:positive, :monotonic])}
      )

    payload = %{operation: "repository.write", argument: "token=#{@canary}"}

    assert {:error, %AdapterError{operation: :credential_release}} =
             CredentialBroker.release(broker, request, current, trusted_connector(), payload)

    refute_received {:credential_vault_checkout, _reference, _permit}
    refute_received {:trusted_connector_material, _permit, _bytes, _operation}
    refute inspect(policy) =~ @canary
  end

  test "SSRF, metadata, redirect rebinding, and classified canary exfiltration never pass egress" do
    policy = egress_policy!()
    current = egress_current(policy)

    transport = fn request, _endpoint, _body ->
      if request.redirect_count == 0 do
        {:ok,
         %{
           status: 302,
           response_bytes: 0,
           location: "https://rebound.example/metadata",
           result: %{outcome: :redirected}
         }}
      else
        egress_response()
      end
    end

    resolve = fn
      "api.github.com" -> {:ok, [{93, 184, 216, 34}]}
      "rebound.example" -> {:ok, [{169, 254, 169, 254}]}
    end

    broker = start_egress_broker(resolve, transport)

    redirect_request = egress_request!(policy, default_egress_uri(), :internal, 0)

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(broker, redirect_request, current, "")

    assert_received {:egress_transport, %{redirect_count: 0}, _endpoint, ""}
    refute_received {:egress_transport, %{redirect_count: 1}, _endpoint, _body}
    assert_received {:egress_audit, %{outcome: :denied, reason: :non_public_address}}

    for {uri, confidentiality, body, reason} <- [
          {"https://evil.example/collect", :internal, "", :destination_not_approved},
          {default_egress_uri(), :restricted, @canary, :policy_restriction}
        ] do
      request = egress_request!(policy, uri, confidentiality, byte_size(body))

      assert {:error, %AdapterError{operation: :egress_policy}} =
               EgressBroker.request(broker, request, current, body)

      assert_received {:egress_audit, %{outcome: :denied, reason: ^reason}}
      refute_received {:egress_transport, ^request, _endpoint, _body}
    end
  end

  defp sandbox_adapters(options \\ []) do
    Map.new(Tier.all(), fn tier ->
      {:ok, profile} = Tier.profile(tier)

      adapter = %{
        owner: self(),
        profile: profile,
        clock: fn -> DateTime.utc_now() end
      }

      adapter =
        case Keyword.fetch(options, :workspace) do
          {:ok, workspace} -> Map.put(adapter, :workspace, workspace)
          :error -> adapter
        end

      {tier, {FakeProductionSandbox, adapter}}
    end)
  end

  defp sandbox_request!(seed, options) do
    output_bytes = Keyword.fetch!(options, :output_bytes)

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
               fencing_token: 411,
               context_digest: String.duplicate("a", 64),
               runtime_version: "phase-h04-hostile/1",
               constraints: %{}
             })

    assert {:ok, request} =
             SandboxRequest.new(%{
               execution: execution,
               base_snapshot_iri: execution.snapshot_iri,
               allowed_write_paths: ["artifacts"],
               command_allowlist: ["hostile-probe"],
               environment_allowlist: [],
               secret_reference_iris: [],
               limits: %{
                 cpu_ms: 1_000,
                 memory_bytes: 1_048_576,
                 process_count: 4,
                 disk_bytes: 4_096,
                 output_bytes: output_bytes,
                 timeout_ms: 1_000,
                 network: :deny
               }
             })

    request
  end

  defp hostile_command(workload, usage) do
    %{name: "hostile-probe", workload: workload, usage: usage}
  end

  defp zero_usage do
    %{
      cpu_ms: 0,
      memory_bytes: 0,
      process_count: 0,
      disk_bytes: 0,
      output_bytes: 0,
      wall_time_ms: 0
    }
  end

  defp candidate(bytes) do
    %{
      content: :binary.copy("x", bytes),
      media_type: "text/plain",
      sensitivity: :internal,
      affected_paths: ["artifacts/probe.txt"]
    }
  end

  defp artifact_context(request, seed) do
    %{
      base_snapshot_iri: request.base_snapshot_iri,
      generator_iri: resource!(:tool_invocation, "artifact-#{seed}")
    }
  end

  defp credential_fixture do
    assert {:ok, reference} =
             CredentialReference.new(%{
               iri: resource!("credential-reference"),
               provider: "github",
               key: "vault/github/writer"
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
      fencing_token: 412,
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

    {policy, request, current}
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

  defp egress_policy! do
    destinations = [
      egress_destination!("api.github.com", "/repos"),
      egress_destination!("rebound.example", "/metadata")
    ]

    assert {:ok, policy} =
             EgressPolicy.new(%{
               policy_iri: resource!("egress-policy"),
               attempt_iri: resource!(:execution_attempt, "egress-attempt"),
               invocation_iri: resource!(:tool_invocation, "egress-invocation"),
               lease_iri: resource!(:execution_lease, "egress-lease"),
               fencing_token: 413,
               profile_revision: 1,
               egress_revision: 1,
               revocation_generation: 1,
               destinations: destinations,
               methods: [:post],
               allowed_integrity: [:verified],
               allowed_confidentiality: [:internal],
               maximum_request_bytes: 1_024,
               maximum_response_bytes: 1_024,
               maximum_redirects: 1,
               rate_limit: %{requests: 10, window_ms: 60_000},
               resolver_identity: @resolver_name <> "@" <> @resolver_digest,
               expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
             })

    policy
  end

  defp egress_destination!(host, path) do
    assert {:ok, destination} =
             Destination.new(%{
               scheme: "https",
               host: host,
               port: 443,
               path_prefix: path,
               kind: :approved_api
             })

    destination
  end

  defp egress_request!(policy, uri, confidentiality, bytes) do
    assert {:ok, request} =
             EgressRequest.new(policy, %{
               uri: uri,
               method: :post,
               traffic_class: :provider_api,
               integrity: :verified,
               confidentiality: confidentiality,
               request_bytes: bytes,
               redirect_count: 0
             })

    request
  end

  defp start_egress_broker(resolve, transport) do
    resolver = %{
      owner: self(),
      identity: %{name: @resolver_name, digest: @resolver_digest, controlled: true},
      resolve: resolve
    }

    transport = %{owner: self(), request: transport}
    audit = %{owner: self(), result: :ok}

    start_supervised!(
      {EgressBroker,
       [
         resolver: {FakeEgressResolver, resolver},
         transport: {FakeEgressTransport, transport},
         audit: {FakeEgressAudit, audit}
       ]},
      id: {:hostile_egress_broker, System.unique_integer([:positive, :monotonic])}
    )
  end

  defp egress_current(policy) do
    %{
      lease_state: :active,
      attempt_iri: policy.attempt_iri,
      invocation_iri: policy.invocation_iri,
      lease_iri: policy.lease_iri,
      fencing_token: policy.fencing_token,
      profile_revision: policy.profile_revision,
      egress_revision: policy.egress_revision,
      revocation_generation: policy.revocation_generation
    }
  end

  defp egress_response do
    {:ok,
     %{
       status: 200,
       response_bytes: 0,
       location: nil,
       result: %{outcome: :accepted}
     }}
  end

  defp default_egress_uri, do: "https://api.github.com/repos/example"

  defp resource!(seed), do: resource!(:knowledge_assertion, seed)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h04-hostile-#{seed}")
    iri
  end
end

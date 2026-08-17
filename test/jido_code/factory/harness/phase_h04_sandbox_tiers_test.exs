defmodule JidoCode.Factory.Harness.PhaseH04SandboxTiersTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Sandbox.ArtifactCapture
  alias JidoCode.Factory.Sandbox.Instance
  alias JidoCode.Factory.Sandbox.IsolationProfile
  alias JidoCode.Factory.Sandbox.Request, as: SandboxRequest
  alias JidoCode.Factory.Sandbox.Tier
  alias JidoCode.Factory.SandboxSupervisor
  alias JidoCode.Integrations.MemorySandbox
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeArtifactStore
  alias JidoCode.TestSupport.FakeProductionSandbox
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture

  test "the closed risk table selects all four production isolation tiers" do
    expected = %{
      read_only_analysis: :restricted_beam,
      non_executing_transformation: :container_sandbox,
      build: :micro_vm,
      test: :micro_vm,
      hook: :micro_vm,
      compiler: :micro_vm,
      native_tool: :micro_vm,
      unknown_high_risk: :dedicated_host
    }

    for {workload, tier} <- expected do
      assert {:ok, ^tier} = Tier.select(workload)
    end

    assert Tier.all() == [:restricted_beam, :container_sandbox, :micro_vm, :dedicated_host]
    assert {:error, %AdapterError{operation: :sandbox_workload_class}} = Tier.select(:unknown)
  end

  test "every pinned profile is ephemeral, secret-free, default-deny, and bounded" do
    pins = Tier.pins()
    assert MapSet.new(Map.keys(pins)) == MapSet.new(Tier.all())

    for tier <- Tier.all() do
      assert {:ok, profile} = Tier.profile(tier)
      assert profile.unprivileged
      assert profile.read_only_root
      assert profile.copy_on_write_workspace
      refute profile.host_filesystem
      refute profile.docker_socket
      refute profile.device_access
      refute profile.ambient_credentials
      assert profile.capabilities == []
      assert profile.no_new_privs
      assert profile.network == :deny
      assert MapSet.new(profile.mounts) == MapSet.new([:workspace, :artifact])
      assert Regex.match?(~r/^sha256:[a-f0-9]{64}$/, profile.image_digest)
      assert String.ends_with?(profile.image_reference, "@" <> profile.image_digest)
      assert profile.limits.process_count > 0
      assert profile.limits.output_bytes <= 10_485_760
    end

    assert {:ok, profile} = Tier.profile(:micro_vm)

    for {field, relaxed} <- [
          {:unprivileged, false},
          {:read_only_root, false},
          {:host_filesystem, true},
          {:docker_socket, true},
          {:device_access, true},
          {:ambient_credentials, true},
          {:capabilities, [:sys_admin]},
          {:no_new_privs, false},
          {:network, :allowlisted},
          {:mounts, [:workspace, :host]}
        ] do
      assert {:error, %AdapterError{operation: :sandbox_isolation_profile}} =
               profile
               |> Map.from_struct()
               |> Map.put(field, relaxed)
               |> IsolationProfile.new()
    end
  end

  test "production supervision rejects the memory sandbox and incomplete tier registries" do
    previous = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, previous) end)
    {:ok, profile} = Tier.profile(:restricted_beam)

    assert {:error, %AdapterError{operation: :sandbox_adapter_registry}} =
             SandboxSupervisor.start_link(adapters: %{})

    memory = Map.new(Tier.all(), &{&1, {MemorySandbox, %{profile: profile}}})

    assert {:error, %AdapterError{operation: :sandbox_adapter_attestation}} =
             SandboxSupervisor.start_link(adapters: memory)
  end

  test "supervisor attests the image and chooses the exact tier before provision" do
    supervisor = start_supervised!({SandboxSupervisor, [adapters: adapters()]})

    expected = [
      read_only_analysis: :restricted_beam,
      non_executing_transformation: :container_sandbox,
      build: :micro_vm,
      unknown_high_risk: :dedicated_host
    ]

    for {{workload, tier}, index} <- Enum.with_index(expected) do
      request = sandbox_request!("tier-#{index}")

      assert {:ok, session, event} =
               SandboxSupervisor.provision(supervisor, workload, request,
                 authority: AllowExecutionAuthority
               )

      assert session.tier == tier
      assert event.details.isolation_tier == tier
      assert event.details.image_digest == session.profile.image_digest
      assert event.details.instance_iri == session.instance.iri
      assert event.details.profile_digest == IsolationProfile.digest(session.profile)
      assert_received {:production_sandbox, :provision, attempt}
      assert attempt == request.execution.attempt_iri
    end
  end

  test "requests exceeding a tier or requesting network fail before adapter provision" do
    supervisor = start_supervised!({SandboxSupervisor, [adapters: adapters()]})
    request = sandbox_request!("oversized")

    oversized =
      request
      |> Map.from_struct()
      |> put_in([:limits, :memory_bytes], 536_870_912)
      |> SandboxRequest.new()

    assert {:ok, oversized} = oversized

    assert {:error, %AdapterError{operation: :sandbox_tier_limits}} =
             SandboxSupervisor.provision(supervisor, :read_only_analysis, oversized,
               authority: AllowExecutionAuthority
             )

    networked =
      request
      |> Map.from_struct()
      |> put_in([:limits, :network], :allowlisted)
      |> SandboxRequest.new()

    assert {:ok, networked} = networked

    assert {:error, %AdapterError{operation: :sandbox_tier_limits}} =
             SandboxSupervisor.provision(supervisor, :read_only_analysis, networked,
               authority: AllowExecutionAuthority
             )

    refute_received {:production_sandbox, :provision, _attempt}
  end

  test "bounded capture embeds small text, externalizes binary data, then destroys" do
    supervisor = start_supervised!({SandboxSupervisor, [adapters: adapters()]})
    request = sandbox_request!("capture")

    assert {:ok, _session, _event} =
             SandboxSupervisor.provision(supervisor, :build, request,
               authority: AllowExecutionAuthority
             )

    assert_received {:production_sandbox, :provision, _attempt}

    candidates = [
      %{
        kind: :generated,
        content: "bounded report\n",
        media_type: "text/plain",
        sensitivity: :internal,
        affected_paths: ["artifacts/report.txt"]
      },
      %{
        kind: :generated,
        content: :binary.copy(<<0, 1, 2, 3>>, 9_000),
        media_type: "application/octet-stream",
        sensitivity: :restricted,
        affected_paths: ["artifacts/result.bin"]
      }
    ]

    context = %{
      base_snapshot_iri: request.base_snapshot_iri,
      generator_iri: resource!(:tool_invocation, "capture-generator")
    }

    assert {:ok, result} =
             SandboxSupervisor.finish(supervisor, request, candidates, context,
               authority: AllowExecutionAuthority,
               artifact_store: {FakeArtifactStore, %{owner: self()}},
               now: DateTime.utc_now(),
               retention_seconds: 86_400
             )

    assert Enum.map(result.artifacts, & &1.storage) == [:embedded, :external]
    assert result.destroyed.details.status == :destroyed
    assert_received {:production_sandbox, :collect, _attempt}
    assert_received {:artifact_store_put, stored}
    assert stored.byte_count == 36_000
    assert DateTime.compare(stored.retain_until, DateTime.utc_now()) == :gt
    assert_received {:production_sandbox, :destroy, _attempt}

    assert {:error, %AdapterError{operation: :sandbox_session}} =
             SandboxSupervisor.inspect(supervisor, request, authority: AllowExecutionAuthority)
  end

  test "artifact capture has no external fallback without a declared provider store" do
    request = sandbox_request!("no-blob-store")

    context = %{
      base_snapshot_iri: request.base_snapshot_iri,
      generator_iri: resource!(:tool_invocation, "no-store-generator")
    }

    candidate = %{
      content: :binary.copy(<<1>>, 40_000),
      media_type: "application/octet-stream",
      sensitivity: :restricted,
      affected_paths: []
    }

    assert {:error, %AdapterError{operation: :sandbox_artifact_capture}} =
             ArtifactCapture.capture(candidate, context)
  end

  test "execution reporting records the attested SandboxInstance identity" do
    fixture =
      %{test: :phase_h04_sandbox_instance}
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)
      |> Phase08AttemptFixture.transition!(:completed, 922)

    execution = Phase08AttemptFixture.request!(fixture)
    request = sandbox_request_for_execution!(execution)
    {:ok, profile} = Tier.profile(:micro_vm)
    provider_ref = ExecutionRequest.runtime_key(execution)

    assert {:ok, instance} =
             Instance.new(
               request,
               profile,
               provider_ref,
               DateTime.add(fixture.issued_at, 140, :second)
             )

    {:ok, run_metadata} =
      StoreServer.request(
        fixture.store_server,
        {:graph_metadata, fixture.attempt.run_graph_iri}
      )

    activity = %{
      sequence: 1,
      operation: :provision,
      outcome: :success,
      occurred_at: instance.provisioned_at,
      provider_ref: provider_ref,
      details: Map.put(Instance.event_details(instance), :status, :ready)
    }

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        940,
        fixture.attempt_resolution.current_transition,
        "finalize production sandbox provenance"
      )
      |> Map.merge(%{
        fencing_token: fixture.attempt.fencing_token,
        expected_run_revision:
          Phase08AttemptFixture.graph_revision!(fixture, fixture.attempt.run_graph_iri),
        control_graph_iri: fixture.control_graph,
        expected_control_revision:
          Phase08AttemptFixture.graph_revision!(fixture, fixture.control_graph),
        recorded_at: DateTime.add(fixture.issued_at, 140, :second),
        completeness: :complete,
        lease_mode: :current,
        terminal_sequence: fixture.attempt_resolution.current_revision,
        tool_invocation_iris: [],
        model_invocation_iris: [],
        model_invocation_outcome_iris: [],
        artifact_iris: [],
        required_event_iris: [],
        sandbox_activities: [activity],
        missing_outputs: [],
        limitations: ["sandbox completion is not verification evidence"],
        usage: %{cpu_ms: 1, memory_bytes: 4_096, output_bytes: 0},
        diagnostic: nil,
        cancellation_iri: nil,
        run_metadata: run_metadata
      })

    assert {:ok, command} =
             Knowledge.finalize_execution_run(
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    [target] = command.payload.changes
    assert Enum.any?(target.additions, &(inspect(&1) =~ "SandboxInstance"))
    assert Enum.any?(target.additions, &(inspect(&1) =~ instance.image_digest))
  end

  defp adapters do
    Map.new(Tier.all(), fn tier ->
      {:ok, profile} = Tier.profile(tier)

      {tier,
       {FakeProductionSandbox,
        %{owner: self(), profile: profile, clock: fn -> DateTime.utc_now() end}}}
    end)
  end

  defp sandbox_request!(seed) do
    execution = execution_request!(seed)

    sandbox_request_for_execution!(execution)
  end

  defp sandbox_request_for_execution!(execution) do
    assert {:ok, request} =
             SandboxRequest.new(%{
               execution: execution,
               base_snapshot_iri: execution.snapshot_iri,
               allowed_write_paths: ["artifacts"],
               command_allowlist: ["mix-test"],
               environment_allowlist: [],
               secret_reference_iris: [],
               limits: %{
                 cpu_ms: 10_000,
                 memory_bytes: 134_217_728,
                 process_count: 16,
                 disk_bytes: 33_554_432,
                 timeout_ms: 10_000,
                 output_bytes: 65_536,
                 network: :deny
               }
             })

    request
  end

  defp execution_request!(seed) do
    assert {:ok, request} =
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
               fencing_token: 301,
               context_digest: String.duplicate("a", 64),
               runtime_version: "phase-h04-fixture/1",
               constraints: %{}
             })

    request
  end

  defp resource!(seed), do: resource!(:knowledge_assertion, seed)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h04-sandbox-#{seed}")
    iri
  end
end

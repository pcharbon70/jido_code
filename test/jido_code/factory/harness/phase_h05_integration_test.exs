defmodule JidoCode.Factory.Harness.PhaseH05IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedCancellation
  alias JidoCode.Factory.DelegatedResultGate
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Factory.Sandbox.Tier
  alias JidoCode.Runtime.JidoHarness.ProcessRunner
  alias JidoCode.Runtime.JidoHarness.Readiness
  alias JidoCode.Runtime.JidoHarness.RunRegistry
  alias JidoCode.Runtime.JidoHarnessAdapter
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeJidoHarnessProcessAPI
  alias JidoCode.TestSupport.FakeJidoHarnessReadinessProbe
  alias JidoCode.TestSupport.FakeOuterWorker
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-17 18:00:00Z]
  @prompt_canary "PROMPT-CANARY-phase-h05-integration"
  @journal_canary "JOURNAL-CANARY-phase-h05-integration"
  @cross_actor_canary "CROSS-ACTOR-CANARY-phase-h05-integration"
  @credential_canary "ghp_PHASE05INTEGRATION1234567890abcdefgh"

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase-h05-integration-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  test "authorization, isolated launch, and graph-only restart recovery form one boundary", %{
    root: root
  } do
    request = request!("restart-boundary")
    workspace = workspace!(root, "restart-boundary")
    retention = retention!(root, "restart-boundary")
    registry_name = registry_name("Restart")
    _registry = start_supervised!({RunRegistry, name: registry_name})

    options = runtime_options(request, registry_name, workspace, retention, @prompt_canary)

    assert {:error, %{kind: :unauthorized, operation: :start}} =
             ExecutionRuntime.start(
               JidoHarnessAdapter,
               request,
               Keyword.put(options, :authorized?, false)
             )

    refute_received {:jido_harness_process_api, :start, _spec}

    assert {:ok, %{type: :started, outcome_class: :pending}} =
             ExecutionRuntime.start(JidoHarnessAdapter, request, options)

    assert_receive {:jido_harness_process_api, :start, spec}
    assert_receive {:jido_harness_process_api, :input, process_id, input}
    assert String.starts_with?(process_id, "proc_")
    assert spec.cwd == workspace
    assert spec.env_mode == :replace
    assert spec.retention.memory_bytes == 1_048_576
    assert File.regular?(spec.retention.journal_dir)
    refute Enum.any?(spec.argv, &String.contains?(&1, @prompt_canary))
    assert Jason.decode!(input)["message"] == @prompt_canary

    assert {:ok, before_restart} = RunRegistry.fetch(registry_name, request)
    refute inspect(before_restart, limit: :infinity) =~ @prompt_canary

    old_registry = Process.whereis(registry_name)
    :ok = GenServer.stop(old_registry, :shutdown)
    assert eventually(fn -> is_pid(Process.whereis(registry_name)) end)
    refute Process.whereis(registry_name) == old_registry
    assert :error = RunRegistry.fetch(registry_name, request)

    recovery_options =
      Keyword.put(options, :recovery_context, %{
        terminal_callback_proven: true,
        lease_state: :active,
        runtime_compatible: true,
        cancellation_committed: false
      })

    assert {:ok, recovery} =
             ExecutionRuntime.status(JidoHarnessAdapter, request, recovery_options)

    assert recovery.diagnostic == "runtime_missing:recover"
    assert recovery.outcome_class == :unknown
    refute recovery.type == :crashed
  end

  test "committed cancellation destroys the sandbox and closes every late sink", %{root: root} do
    request = request!("cancel-boundary")
    workspace = workspace!(root, "cancel-boundary")
    retention = retention!(root, "cancel-boundary")
    registry_name = registry_name("Cancel")
    _registry = start_supervised!({RunRegistry, name: registry_name})
    options = runtime_options(request, registry_name, workspace, retention, "bounded work")

    assert {:ok, _event} = ExecutionRuntime.start(JidoHarnessAdapter, request, options)
    assert_receive {:jido_harness_process_api, :start, _spec}
    assert_receive {:jido_harness_process_api, :input, process_id, _input}

    current = current(request)

    assert {:ok, candidate_receipt} =
             DelegatedResultGate.dispatch(
               request,
               current,
               :diff,
               %{candidate_diff_digest: String.duplicate("d", 64)},
               at: @now,
               sink: fn receipt ->
                 send(self(), {:candidate_receipt, receipt})
                 :ok
               end
             )

    assert_receive {:candidate_receipt, ^candidate_receipt}
    refute Map.has_key?(candidate_receipt, :payload)
    assert candidate_receipt.payload_bytes < 1_048_576

    cancellation = %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      reason: :superseded,
      committed_at: @now
    }

    assert {:ok, cancelled} =
             DelegatedCancellation.cancel(:cancel_command, request, cancellation,
               commit: fn command ->
                 send(self(), {:cancellation_commit, command})
                 {:ok, %{outcome: :committed}}
               end,
               adapter: JidoHarnessAdapter,
               runtime_options: options,
               outer_worker: {FakeOuterWorker, %{owner: self()}},
               adapter_stop_timeout_ms: 2_000
             )

    assert_receive {:cancellation_commit, :cancel_command}
    assert_receive {:jido_harness_process_api, :cancel, ^process_id}
    assert_receive {:jido_harness_process_api, :await, ^process_id, 12_000}
    assert_receive {:outer_worker, :kill_namespace, attempt_iri, :superseded}
    assert_receive {:outer_worker, :destroy, ^attempt_iri, :superseded}
    assert cancelled.namespace_kill == {:ok, %{namespace: :terminated, within_bound: true}}
    assert cancelled.destruction == {:ok, %{status: :destroyed}}

    expired = %{current | lease_state: :expired, lease_expires_at: @now}

    for kind <- [:event, :diff, :artifact, :callback, :result] do
      assert {:error, %{kind: :unauthorized, operation: :delegated_result_fence}} =
               DelegatedResultGate.dispatch(
                 request,
                 expired,
                 kind,
                 %{late: kind},
                 at: @now,
                 sink: fn receipt ->
                   send(self(), {:late_effect, receipt})
                   :ok
                 end
               )
    end

    refute_received {:late_effect, _receipt}

    assert {:error, %{operation: :delegated_result_payload}} =
             DelegatedResultGate.dispatch(
               request,
               current,
               :artifact,
               String.duplicate("x", 1_048_577),
               at: @now
             )
  end

  test "both admitted profiles keep prompt, journal, credential, and actor canaries separated", %{
    root: root
  } do
    registry_name = registry_name("Privacy")
    _registry = start_supervised!({RunRegistry, name: registry_name})

    request_a = request!("privacy-actor-a")
    request_b = request!("privacy-actor-b")
    workspace_a = workspace!(root, "actor-a")
    workspace_b = workspace!(root, "actor-b")
    retention = retention!(root, "privacy")
    prompt_a = Enum.join([@prompt_canary, @journal_canary, @cross_actor_canary], " ")
    prompt_b = "actor-b-private-prompt"

    options_a =
      request_a
      |> runtime_options(registry_name, workspace_a, retention, prompt_a)
      |> Keyword.put(:profile, :pi_rpc_deny_all)

    options_b =
      request_b
      |> runtime_options(registry_name, workspace_b, retention, prompt_b)
      |> Keyword.put(:profile, :pi_rpc_read_only)

    poisoned_local =
      options_a
      |> Keyword.fetch!(:developer_local)
      |> put_in([:environment, "JIDO_SUBSCRIPTION_TOKEN"], @credential_canary)

    assert {:error, %{operation: :jido_harness_developer_local_launch}} =
             ExecutionRuntime.start(
               JidoHarnessAdapter,
               request_a,
               Keyword.put(options_a, :developer_local, poisoned_local)
             )

    refute_received {:jido_harness_process_api, :start, _spec}

    assert {:ok, _event} = ExecutionRuntime.start(JidoHarnessAdapter, request_a, options_a)
    assert_receive {:jido_harness_process_api, :start, spec_a}
    assert_receive {:jido_harness_process_api, :input, process_a, input_a}

    assert {:ok, _event} = ExecutionRuntime.start(JidoHarnessAdapter, request_b, options_b)
    assert_receive {:jido_harness_process_api, :start, spec_b}
    assert_receive {:jido_harness_process_api, :input, process_b, input_b}
    refute process_a == process_b

    assert "--no-tools" in spec_a.argv
    assert ["--tools", "read,grep,find,ls"] in Enum.chunk_every(spec_b.argv, 2, 1, :discard)
    assert Jason.decode!(input_a)["message"] == prompt_a
    assert Jason.decode!(input_b)["message"] == prompt_b
    refute input_b =~ @cross_actor_canary

    assert {:ok, record_a} = RunRegistry.fetch(registry_name, request_a)
    assert {:ok, record_b} = RunRegistry.fetch(registry_name, request_b)
    refute record_a.run_id == record_b.run_id

    journal_contents =
      retention
      |> Path.join("jido-code-harness-*")
      |> Path.wildcard()
      |> Enum.flat_map(&Path.wildcard(Path.join(&1, "*")))
      |> Enum.map(&File.read!/1)

    exposed =
      inspect(
        %{specs: [spec_a, spec_b], records: [record_a, record_b], journals: journal_contents},
        limit: :infinity,
        printable_limit: :infinity
      )

    for canary <- [@prompt_canary, @journal_canary, @cross_actor_canary, @credential_canary] do
      refute exposed =~ canary
    end

    assert Enum.all?(journal_contents, &(&1 == "memory-only\n"))

    assert {:ok, _event} =
             ExecutionRuntime.terminate(
               JidoHarnessAdapter,
               request_a,
               %{reason: :test_cleanup},
               options_a
             )

    assert {:ok, _event} =
             ExecutionRuntime.terminate(
               JidoHarnessAdapter,
               request_b,
               %{reason: :test_cleanup},
               options_b
             )

    assert Path.wildcard(Path.join(retention, "jido-code-harness-*")) == []
  end

  test "readiness stays prompt-free until each profile receives explicit billing consent" do
    for profile <- [:pi_rpc_deny_all, :pi_rpc_read_only] do
      probe_options = [owner: self()]

      assert {:ok, discovery} =
               Readiness.discover(profile,
                 probe: FakeJidoHarnessReadinessProbe,
                 probe_options: probe_options
               )

      assert_receive {:jido_harness_readiness, :discover, ^profile}
      assert discovery.profile == profile
      assert discovery.probe == :non_billable_discovery
      refute discovery.prompt_sent
      assert discovery.authentication.actor_identity == :not_claimed

      consent = %{
        granted: false,
        billing_acknowledged: true,
        profile: profile,
        actor_iri: resource!("readiness-actor-#{profile}"),
        expires_at: DateTime.add(@now, 60, :second)
      }

      assert {:error, %{operation: :jido_harness_live_consent}} =
               Readiness.live_smoke(profile, consent,
                 at: @now,
                 probe: FakeJidoHarnessReadinessProbe,
                 probe_options: probe_options
               )

      refute_received {:jido_harness_readiness, :live_smoke, ^profile}

      assert {:ok, live} =
               Readiness.live_smoke(profile, %{consent | granted: true},
                 at: @now,
                 probe: FakeJidoHarnessReadinessProbe,
                 probe_options: probe_options
               )

      assert_receive {:jido_harness_readiness, :live_smoke, ^profile}
      assert live.profile == profile
      assert live.probe == :consented_live_smoke
      assert live.authentication.actor_identity == :not_claimed
    end
  end

  defp runtime_options(request, registry, workspace, retention, prompt) do
    seed = request.attempt_iri |> String.split("/") |> List.last()

    [
      authority: AllowExecutionAuthority,
      registry: registry,
      runner: ProcessRunner,
      runner_options: [
        process_api: FakeJidoHarnessProcessAPI,
        process_api_options: [owner: self(), start_result: {:ok, "proc_#{seed}"}],
        retention_base: retention
      ],
      profile: :pi_rpc_deny_all,
      prompt: prompt,
      developer_local: developer_local(request, workspace),
      clock: fn -> @now end
    ]
  end

  defp developer_local(request, workspace) do
    {:ok, isolation} = Tier.profile(:micro_vm)

    %{
      consent: true,
      worker: %{
        snapshot_iri: request.snapshot_iri,
        workspace_path: workspace,
        cli_path: "/opt/jido-code/bin/pi",
        cli_digest: "sha256:" <> String.duplicate("f", 64),
        isolation_profile: isolation,
        process_namespace: :isolated,
        disposable: true,
        store_handle: false,
        publication_credentials: false,
        ssh_agent: false,
        docker_socket: false,
        unrelated_repositories: false
      },
      environment: %{
        "PATH" => "/opt/jido-code/bin:/usr/bin",
        "HOME" => "/run/jido-code/developer-login",
        "TMPDIR" => "/tmp/jido-code",
        "LANG" => "C.UTF-8"
      },
      provider_egress: %{
        mode: :brokered,
        destinations: ["https://api.openai.com/v1/"]
      },
      credential_reference_iri: resource!("developer-cli-login"),
      cli_version: "pi/0.51.2",
      provider_version: "developer-subscription",
      limits: %{
        run_count: 1,
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

  defp current(request) do
    %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      lease_state: :active,
      lease_expires_at: DateTime.add(@now, 60, :second)
    }
  end

  defp workspace!(root, name) do
    path = Path.join(root, "workspace-#{name}")
    File.mkdir_p!(path)
    path
  end

  defp retention!(root, name) do
    path = Path.join(root, "retention-#{name}")
    File.mkdir_p!(path)
    path
  end

  defp registry_name(suffix) do
    Module.concat(__MODULE__, "#{suffix}Registry#{System.unique_integer([:positive])}")
  end

  defp eventually(function, attempts \\ 100)

  defp eventually(function, attempts) when attempts > 0 do
    if function.() do
      true
    else
      Process.sleep(10)
      eventually(function, attempts - 1)
    end
  end

  defp eventually(_function, 0), do: false

  defp request!(seed) do
    assert {:ok, request} =
             Request.new(%{
               attempt_iri: resource!("#{seed}"),
               lease_iri: resource!("lease-#{seed}"),
               task_iri: resource!("task-#{seed}"),
               goal_iri: resource!("goal-#{seed}"),
               plan_iri: resource!("plan-#{seed}"),
               repository_iri: resource!("repository-#{seed}"),
               snapshot_iri: resource!("snapshot-#{seed}"),
               actor_iri: resource!("actor-#{seed}"),
               agent_iri: resource!("agent-#{seed}"),
               capability_iri: resource!("capability-#{seed}"),
               fencing_token: 504,
               context_digest: String.duplicate("a", 64),
               runtime_version: "jido-harness:e41fc165/runtime-contract:1.0.0",
               constraints: %{deployment_class: :developer_local_cli}
             })

    request
  end

  defp resource!(seed), do: Phase04Fixture.resource!(seed)
end

defmodule JidoCode.Factory.Harness.PhaseH05DeveloperLocalTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Factory.Sandbox.Tier
  alias JidoCode.Runtime.JidoHarness.DeveloperLocalLaunch
  alias JidoCode.Runtime.JidoHarness.ProcessRunner
  alias JidoCode.Runtime.JidoHarness.RunRegistry
  alias JidoCode.Runtime.JidoHarnessAdapter
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeJidoHarnessProcessAPI
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-17 16:00:00Z]

  setup context do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase-h05-local-#{System.unique_integer([:positive, :monotonic])}"
      )

    workspace = Path.join(root, "workspace")
    retention = Path.join(root, "retention")
    File.mkdir_p!(workspace)
    File.mkdir_p!(retention)
    on_exit(fn -> File.rm_rf!(root) end)

    registry_name = Module.concat(__MODULE__, "Registry#{System.unique_integer([:positive])}")
    registry = start_supervised!({RunRegistry, name: registry_name})
    request = request!(Atom.to_string(context.test))
    developer_local = developer_local(request, workspace)

    options = [
      authority: AllowExecutionAuthority,
      registry: registry,
      runner: ProcessRunner,
      runner_options: [
        process_api: FakeJidoHarnessProcessAPI,
        process_api_options: [owner: self()],
        retention_base: retention
      ],
      profile: :pi_rpc_deny_all,
      prompt: "PROMPT-CANARY-developer-local",
      developer_local: developer_local,
      clock: fn -> @now end
    ]

    {:ok,
     root: root,
     workspace: workspace,
     retention: retention,
     registry: registry,
     request: request,
     developer_local: developer_local,
     options: options}
  end

  test "launches the official CLI profile only inside the attested Phase 4 worker", context do
    assert {:ok, %{type: :started, outcome_class: :pending}} =
             ExecutionRuntime.start(JidoHarnessAdapter, context.request, context.options)

    assert_received {:jido_harness_process_api, :start, spec}
    assert spec.executable == "/opt/jido-code/bin/pi"
    assert spec.cwd == context.workspace
    assert spec.env_mode == :replace
    assert spec.stdin
    refute spec.pty
    assert "--no-tools" in spec.argv
    assert "--no-extensions" in spec.argv
    assert "--no-skills" in spec.argv
    assert "--no-context-files" in spec.argv
    refute Enum.any?(spec.argv, &String.contains?(&1, "PROMPT-CANARY"))
    refute inspect(spec.metadata) =~ "PROMPT-CANARY"
    assert spec.runtime_timeout_ms == 60_000
    assert spec.idle_timeout_ms == 15_000
    assert File.regular?(spec.retention.journal_dir)
    refute File.dir?(spec.retention.journal_dir)

    assert_received {:jido_harness_process_api, :input, "proc_developer_local", input}

    assert Jason.decode!(input) == %{
             "type" => "prompt",
             "message" => "PROMPT-CANARY-developer-local"
           }

    assert {:ok, record} = RunRegistry.fetch(context.registry, context.request)
    refute inspect(record, limit: :infinity) =~ "PROMPT-CANARY"
    assert record.versions.cli == "pi/0.51.2"
    assert record.versions.provider == "developer-subscription"
  end

  test "records hard outer ceilings and honest unavailable internal ceilings", context do
    assert {:ok, launch} =
             DeveloperLocalLaunch.build(
               context.request,
               profile!(),
               context.developer_local
             )

    assert launch.limits.run_count == 1
    assert launch.limits.session_turns == 2

    for dimension <- [
          :run_count,
          :cpu_ms,
          :memory_bytes,
          :process_count,
          :disk_bytes,
          :output_bytes,
          :wall_ms,
          :idle_ms,
          :session_turns
        ] do
      assert launch.enforcement.outer[dimension] == :hard
    end

    assert launch.enforcement.cli_internal_turns == :unavailable
    assert launch.enforcement.tokens == :unavailable
    assert launch.enforcement.cost == :unavailable
    assert launch.enforcement.subscription_usage == :observed_only
  end

  test "fails closed for missing consent, relaxed isolation, ambient configuration, or managed claims",
       context do
    mutations = [
      &Map.put(&1, :consent, false),
      &put_in(&1, [:worker, :store_handle], true),
      &put_in(&1, [:worker, :publication_credentials], true),
      &put_in(&1, [:worker, :ssh_agent], true),
      &put_in(&1, [:worker, :docker_socket], true),
      &put_in(&1, [:worker, :unrelated_repositories], true),
      &Map.put(&1, :extensions, ["project-extension"]),
      &Map.put(&1, :mcp_servers, ["repo-mcp"]),
      &Map.put(&1, :skills, ["repo-skill"]),
      &Map.put(&1, :additional_directories, ["../other-repo"]),
      &put_in(&1, [:provider_egress, :mode], :direct),
      &put_in(&1, [:environment, "AWS_SECRET_ACCESS_KEY"], "canary"),
      &put_in(&1, [:limits, :run_count], 2)
    ]

    for mutate <- mutations do
      assert {:error, %{operation: :jido_harness_developer_local_launch}} =
               DeveloperLocalLaunch.build(
                 context.request,
                 profile!(),
                 mutate.(context.developer_local)
               )
    end

    managed_profile = profile!() |> Map.put(:managed_eligible, true)

    assert {:error, %{operation: :jido_harness_developer_local_launch}} =
             DeveloperLocalLaunch.build(
               context.request,
               managed_profile,
               context.developer_local
             )
  end

  test "uses brokered provider-only egress and an opaque existing-login reference", context do
    assert {:ok, launch} =
             DeveloperLocalLaunch.build(
               context.request,
               profile!(),
               context.developer_local
             )

    assert launch.provider_egress == %{
             mode: :brokered,
             destinations: ["https://api.openai.com/v1/"]
           }

    assert launch.credential_reference_iri == resource!("developer-cli-login")
    refute inspect(launch) =~ "authorization"
    refute inspect(launch) =~ "api_key"
    refute launch.outer_worker.store_handle
    refute launch.outer_worker.publication_credentials
    refute launch.outer_worker.ssh_agent
    refute launch.outer_worker.docker_socket
    refute launch.outer_worker.unrelated_repositories
  end

  test "terminates the disposable process and removes the controller retention barrier",
       context do
    assert {:ok, _event} =
             ExecutionRuntime.start(JidoHarnessAdapter, context.request, context.options)

    assert [run_root] = Path.wildcard(Path.join(context.retention, "jido-code-harness-*"))
    assert File.dir?(run_root)

    assert {:ok, %{type: :cancelled}} =
             ExecutionRuntime.terminate(
               JidoHarnessAdapter,
               context.request,
               %{reason: :test},
               context.options
             )

    assert_received {:jido_harness_process_api, :kill, "proc_developer_local"}
    assert_received {:jido_harness_process_api, :prune, "proc_developer_local"}
    refute File.exists?(run_root)
  end

  test "kills a partially started CLI and removes retention when protected input fails",
       context do
    options =
      put_in(
        context.options,
        [:runner_options, :process_api_options, :input_result],
        {:error, :closed}
      )

    assert {:error, %{kind: :unavailable, operation: :start}} =
             ExecutionRuntime.start(JidoHarnessAdapter, context.request, options)

    assert_received {:jido_harness_process_api, :kill, "proc_developer_local"}
    assert_received {:jido_harness_process_api, :prune, "proc_developer_local"}
    assert Path.wildcard(Path.join(context.retention, "jido-code-harness-*")) == []
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

  defp profile! do
    {:ok, profile} = JidoCode.Runtime.JidoHarness.Adoption.profile(:pi_rpc_deny_all)
    profile
  end

  defp request!(seed) do
    safe_seed = seed |> String.replace(~r/[^a-zA-Z0-9-]/, "-") |> String.slice(0, 80)

    assert {:ok, request} =
             Request.new(%{
               attempt_iri: resource!("attempt-local-#{safe_seed}"),
               lease_iri: resource!("lease-local-#{safe_seed}"),
               task_iri: resource!("task-local-#{safe_seed}"),
               goal_iri: resource!("goal-local-#{safe_seed}"),
               plan_iri: resource!("plan-local-#{safe_seed}"),
               repository_iri: resource!("repository-local-#{safe_seed}"),
               snapshot_iri: resource!("snapshot-local-#{safe_seed}"),
               actor_iri: resource!("actor-local-#{safe_seed}"),
               agent_iri: resource!("agent-local-#{safe_seed}"),
               capability_iri: resource!("capability-local-#{safe_seed}"),
               fencing_token: 502,
               context_digest: String.duplicate("a", 64),
               runtime_version: "jido-harness:e41fc165/runtime-contract:1.0.0",
               constraints: %{deployment_class: :developer_local_cli}
             })

    request
  end

  defp resource!(seed), do: Phase04Fixture.resource!(seed)
end

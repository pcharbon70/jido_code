defmodule JidoCode.Knowledge.Phase08RecoverySecurityIntegrationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias JidoCode.Factory.AttemptRecovery
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent
  alias JidoCode.Factory.Execution.RuntimeOutput
  alias JidoCode.Factory.Sandbox
  alias JidoCode.Factory.Sandbox.Event, as: SandboxEvent
  alias JidoCode.Factory.Sandbox.Request, as: SandboxRequest
  alias JidoCode.Factory.Scheduler
  alias JidoCode.Factory.Tool.Request, as: ToolRequest
  alias JidoCode.Factory.ToolRunner
  alias JidoCode.Integrations.MemorySandbox
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Telemetry
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Runtime.AttemptSupervisor
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeExecutionRuntime
  alias JidoCode.TestSupport.FakeToolAdapter
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture

  test "rebuilds active behavior from graphs after disposable process loss", context do
    parent = self()

    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    request = Phase08AttemptFixture.request!(fixture)

    assert {:ok, worker} =
             AttemptSupervisor.start_attempt(request,
               adapter: FakeExecutionRuntime,
               runtime_options: [authority: AllowExecutionAuthority]
             )

    assert Process.alive?(worker)
    assert :ok = AttemptSupervisor.stop_attempt(request)
    refute Process.alive?(worker)

    sandbox = disposable_sandbox!(fixture, fn _command, _files -> successful_result() end)
    sandbox_request = sandbox_request!(request)

    assert {:ok, _event} =
             Sandbox.provision(
               MemorySandbox,
               sandbox,
               sandbox_request,
               authority: AllowExecutionAuthority
             )

    sandbox_ref = Process.monitor(sandbox)
    GenServer.stop(sandbox, :normal)
    assert_receive {:DOWN, ^sandbox_ref, :process, ^sandbox, :normal}

    first_scheduler = scheduler!(parent)
    assert_receive {:scheduler_discovered, ^first_scheduler}, 1_000
    GenServer.stop(first_scheduler, :normal)

    second_scheduler = scheduler!(parent)
    assert_receive {:scheduler_discovered, ^second_scheduler}, 1_000
    refute first_scheduler == second_scheduler

    active_ref = Request.runtime_key(request)
    orphan_ref = String.duplicate("e", 64)

    recovery =
      recovery!(fixture,
        transition: fn decision, candidate, projection ->
          send(parent, {:decision, decision, candidate, projection})
          :ok
        end,
        orphan_inventory: fn -> {:ok, [active_ref, orphan_ref]} end,
        cleanup_orphan: fn ref ->
          send(parent, {:cleaned, ref})
          :ok
        end
      )

    assert_receive {:decision, :observe, %{attempt_iri: attempt}, projection}, 2_000
    assert attempt == fixture.attempt.iri
    assert projection.current_state == :running
    assert projection.fencing_token == fixture.lease.fencing_token
    assert_receive {:cleaned, ^orphan_ref}, 1_000
    refute_receive {:cleaned, ^active_ref}, 50
    assert AttemptRecovery.ready?(recovery)
  end

  test "restores a running attempt lineage and reopens the embedded store", context do
    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    before = Phase08ExecutionFixture.projection!(fixture)
    assert before.current_state == :running
    assert {:ok, backup} = Maintenance.backup(fixture.maintenance, [])

    completed = Phase08AttemptFixture.transition!(fixture, :completed, 950)
    assert Phase08ExecutionFixture.projection!(completed).current_state == :completed

    assert {:ok, restore} =
             Maintenance.restore(fixture.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert restore.integrity_status == :ok
    restored = Phase08ExecutionFixture.projection!(fixture)
    assert restored.current_state == :running
    assert restored.receipt.dataset_revision != before.receipt.dataset_revision
    assert restored.receipt.graph_revision == before.receipt.graph_revision

    restart_store_stack!(fixture)

    reopened = Phase08ExecutionFixture.projection!(fixture)
    assert reopened.current_state == :running
    assert reopened.timeline == restored.timeline
    assert reopened.fencing_token == restored.fencing_token

    parent = self()

    recovery =
      recovery!(fixture,
        transition: fn decision, candidate, projection ->
          send(parent, {:restored_decision, decision, candidate, projection})
          :ok
        end
      )

    assert_receive {:restored_decision, :observe, %{lease_current?: true}, projection}, 2_000
    assert projection.current_state == :running
    assert AttemptRecovery.ready?(recovery)
  end

  test "rejects hostile and secret-bearing runtime, tool, sandbox, and artifact data", context do
    secret = "token=ghp_abcdefghijklmnopqrstuvwxyz"
    attach_telemetry!()

    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    request = Phase08AttemptFixture.request!(fixture)
    invocation = Phase08ExecutionFixture.invocation!(fixture)

    start_attributes =
      Phase08ExecutionFixture.command_attributes(
        fixture,
        930,
        invocation.iri,
        "start hostile-input invocation"
      )

    {:ok, invocation_start} =
      Knowledge.start_tool_invocation(
        invocation,
        fixture.attempt,
        fixture.attempt_resolution,
        fixture.lease,
        start_attributes,
        clock: fn -> fixture.issued_at end
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, invocation_start)

    tool_request = tool_request!(fixture, request, invocation)
    sandbox_request = sandbox_request!(request)

    log =
      capture_log(fn ->
        assert {:error, runtime_error} =
                 RuntimeEvent.new(%{
                   attempt_iri: fixture.attempt.iri,
                   sequence: 2,
                   type: :failed,
                   occurred_at: fixture.issued_at,
                   outcome_class: :failure,
                   usage: %{},
                   diagnostic: secret
                 })

        refute inspect(runtime_error) =~ secret

        assert {:error, runtime_output_error} =
                 RuntimeOutput.new(%{
                   attempt_iri: fixture.attempt.iri,
                   outcome_class: :failure,
                   artifact_iris: [],
                   usage: %{},
                   completed_at: fixture.issued_at,
                   diagnostic: secret
                 })

        refute inspect(runtime_output_error) =~ secret

        assert {:error, runtime_usage_error} =
                 RuntimeEvent.new(%{
                   attempt_iri: fixture.attempt.iri,
                   sequence: 2,
                   type: :failed,
                   occurred_at: fixture.issued_at,
                   outcome_class: :failure,
                   usage: %{diagnostic: secret}
                 })

        refute inspect(runtime_usage_error) =~ secret

        assert {:error, tool_error} =
                 ToolRunner.execute(FakeToolAdapter, nil, tool_request,
                   authority: AllowExecutionAuthority,
                   scenario: :secret
                 )

        refute inspect(tool_error) =~ secret

        secret_outcome =
          fixture
          |> Phase08ExecutionFixture.command_attributes(
            931,
            invocation.iri,
            "reject secret tool output"
          )
          |> Map.merge(%{
            status: :failed,
            exit_status: 1,
            stdout: secret,
            stderr: "",
            external_output_iris: [],
            usage: %{},
            artifact_iris: [],
            redaction: :none
          })

        assert {:error, outcome_error} =
                 Knowledge.record_tool_outcome(
                   invocation,
                   fixture.attempt,
                   fixture.attempt_resolution,
                   fixture.lease,
                   secret_outcome,
                   clock: fn -> fixture.issued_at end
                 )

        refute inspect(outcome_error) =~ secret

        assert {:error, sandbox_event_error} =
                 SandboxEvent.new(%{
                   attempt_iri: fixture.attempt.iri,
                   operation: :execute,
                   outcome: :failure,
                   occurred_at: fixture.issued_at,
                   provider_ref: Request.runtime_key(request),
                   details: %{diagnostic: secret}
                 })

        refute inspect(sandbox_event_error) =~ secret

        sandbox =
          disposable_sandbox!(fixture, fn _command, _files ->
            successful_result(%{stdout: secret})
          end)

        assert {:ok, _event} =
                 Sandbox.provision(
                   MemorySandbox,
                   sandbox,
                   sandbox_request,
                   authority: AllowExecutionAuthority
                 )

        assert {:error, %{kind: :unauthorized}} =
                 Sandbox.materialize(
                   MemorySandbox,
                   sandbox,
                   sandbox_request,
                   %{
                     snapshot_iri: request.snapshot_iri,
                     files: %{".git/hooks/pre-commit" => secret}
                   },
                   authority: AllowExecutionAuthority
                 )

        assert {:error, %{kind: :unauthorized}} =
                 Sandbox.execute(
                   MemorySandbox,
                   sandbox,
                   sandbox_request,
                   %{name: "apply-protection", args: [], environment: %{}, network: true},
                   authority: AllowExecutionAuthority
                 )

        assert {:error, sandbox_error} =
                 Sandbox.execute(
                   MemorySandbox,
                   sandbox,
                   sandbox_request,
                   %{name: "apply-protection", args: [], environment: %{}, network: false},
                   authority: AllowExecutionAuthority
                 )

        refute inspect(sandbox_error) =~ secret

        assert {:error, artifact_error} =
                 Knowledge.execution_artifact(%{
                   kind: :patch,
                   base_snapshot_iri: fixture.attempt.snapshot_iri,
                   generator_iri: invocation.iri,
                   media_type: "text/x-diff",
                   content: secret,
                   content_digest: nil,
                   byte_count: nil,
                   sensitivity: :internal,
                   external_uri: nil,
                   affected_paths: ["config/config.exs"],
                   affected_symbols: [],
                   proposed_commit_iri: nil,
                   proposed_tree_iri: nil,
                   findings: []
                 })

        refute inspect(artifact_error) =~ secret
      end)

    refute log =~ secret

    failed = Phase08AttemptFixture.transition!(fixture, :failed, 940)

    secret_activity = %{
      sequence: 1,
      operation: :destroy,
      outcome: :failure,
      occurred_at: DateTime.add(fixture.issued_at, 145, :second),
      provider_ref: Request.runtime_key(request),
      details: %{diagnostic: secret}
    }

    finalization_attributes =
      failed
      |> Phase08ExecutionFixture.command_attributes(
        941,
        failed.attempt_resolution.current_transition,
        "reject secret provenance detail"
      )
      |> Map.merge(%{
        completeness: :incomplete,
        lease_mode: :current,
        terminal_sequence: failed.attempt_resolution.current_revision,
        tool_invocation_iris: [invocation.iri],
        artifact_iris: [],
        required_event_iris: [],
        sandbox_activities: [secret_activity],
        missing_outputs: ["tool outcome"],
        limitations: [],
        usage: %{},
        diagnostic: nil,
        cancellation_iri: nil,
        run_metadata: run_metadata!(failed)
      })

    assert {:error, provenance_error} =
             Knowledge.finalize_execution_run(
               failed.attempt,
               failed.attempt_resolution,
               failed.lease,
               finalization_attributes,
               clock: fn -> failed.issued_at end
             )

    refute inspect(provenance_error) =~ secret

    projection = Phase08ExecutionFixture.projection!(failed)
    refute inspect(projection) =~ secret
    refute inspect(projection) =~ failed.execution_context.instruction

    dataset = Phase04Fixture.export_dataset!(failed)
    run_graph = RDF.Dataset.graph(dataset, RDF.iri(failed.attempt.run_graph_iri))
    canonical = RDF.NTriples.write_string!(run_graph, sort: true)
    refute canonical =~ secret

    telemetry = drain_telemetry()
    assert telemetry != []
    refute inspect(telemetry) =~ secret

    assert Enum.all?(telemetry, fn {_event, measurements, metadata} ->
             Map.keys(measurements) -- Telemetry.allowed_measurements() == [] and
               Map.keys(metadata) -- Telemetry.allowed_keys() == []
           end)
  end

  defp attach_telemetry! do
    handler = "phase-08-security-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:jido_code, :knowledge, :operation, :start],
          [:jido_code, :knowledge, :operation, :stop],
          [:jido_code, :knowledge, :operation, :exception]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:phase_08_telemetry, event, measurements, metadata})
        end,
        nil
      )

    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(handler) end)
  end

  defp drain_telemetry(events \\ []) do
    receive do
      {:phase_08_telemetry, event, measurements, metadata} ->
        drain_telemetry([{event, measurements, metadata} | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp recovery!(fixture, overrides) do
    defaults = [
      name: nil,
      control_graphs: [fixture.control_graph],
      query: fn name, params -> query(fixture, name, params) end,
      load_projection: fn _candidate -> {:ok, Phase08ExecutionFixture.projection!(fixture)} end,
      runtime_adapter: FakeExecutionRuntime,
      runtime_options: [
        authority: AllowExecutionAuthority,
        clock: fn -> DateTime.add(fixture.issued_at, 200, :second) end
      ],
      sandbox_inspector: fn _request -> :not_configured end,
      transition: fn _decision, _candidate, _projection -> :ok end,
      orphan_inventory: fn -> {:ok, []} end,
      cleanup_orphan: fn _ref -> :ok end,
      available_runtime_versions: [fixture.attempt.runtime_version],
      current_snapshot: fn projection -> projection.source_snapshot_iri end,
      policy_current?: fn _projection -> true end,
      clock: fn -> DateTime.add(fixture.issued_at, 200, :second) end,
      interval: 60_000
    ]

    options = Keyword.merge(defaults, overrides)
    child = Supervisor.child_spec({AttemptRecovery, options}, id: make_ref(), restart: :temporary)
    ExUnit.Callbacks.start_supervised!(child)
  end

  defp query(fixture, name, params) do
    QueryRunner.execute(
      name,
      QueryCatalog.execution_version(),
      params,
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp scheduler!(parent) do
    child =
      Supervisor.child_spec(
        {Scheduler,
         name: nil,
         discover: fn ->
           send(parent, {:scheduler_discovered, self()})
           {:ok, []}
         end,
         acquire: fn _candidate, _provider -> :ok end,
         rediscovery_interval_ms: 300_000},
        id: make_ref(),
        restart: :temporary
      )

    ExUnit.Callbacks.start_supervised!(child)
  end

  defp restart_store_stack!(fixture) do
    Enum.each([fixture.writer, fixture.query_runner, fixture.maintenance], &stop/1)
    stop(fixture.store_server)

    store_child =
      Supervisor.child_spec(
        {StoreServer,
         name: fixture.store_server,
         readiness: fixture.readiness,
         config: fixture.config,
         authorized_callers: %{
           read: [self(), fixture.query_runner],
           write: [fixture.writer],
           maintenance: [fixture.maintenance]
         }},
        id: make_ref(),
        restart: :temporary
      )

    ExUnit.Callbacks.start_supervised!(store_child)
    await_store!(fixture.store_server)

    start_temporary!(
      {QueryRunner, name: fixture.query_runner, store_server: fixture.store_server}
    )

    start_temporary!(
      {Writer,
       name: fixture.writer,
       store_server: fixture.store_server,
       clock: fn -> fixture.issued_at end}
    )

    start_temporary!({Maintenance, name: fixture.maintenance, store_server: fixture.store_server})
  end

  defp start_temporary!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> ExUnit.Callbacks.start_supervised!()
  end

  defp await_store!(server, attempts \\ 500)
  defp await_store!(_server, 0), do: raise("reopened store did not become ready")

  defp await_store!(server, attempts) do
    if StoreServer.summary(server).ready? do
      :ok
    else
      Process.sleep(10)
      await_store!(server, attempts - 1)
    end
  end

  defp stop(server) do
    case GenServer.whereis(server) do
      pid when is_pid(pid) -> GenServer.stop(pid, :normal, 5_000)
      _missing -> :ok
    end
  end

  defp disposable_sandbox!(fixture, runner) do
    child =
      Supervisor.child_spec(
        {MemorySandbox,
         runners: %{"apply-protection" => runner}, clock: fn -> fixture.issued_at end},
        id: make_ref(),
        restart: :temporary
      )

    ExUnit.Callbacks.start_supervised!(child)
  end

  defp sandbox_request!(request) do
    {:ok, sandbox_request} =
      SandboxRequest.new(%{
        execution: request,
        base_snapshot_iri: request.snapshot_iri,
        allowed_write_paths: [".jido-code/patch"],
        command_allowlist: ["apply-protection"],
        environment_allowlist: [],
        secret_reference_iris: [],
        limits: %{
          cpu_ms: 10,
          memory_bytes: 4_096,
          disk_bytes: 4_096,
          timeout_ms: 100,
          output_bytes: 128,
          network: :deny
        }
      })

    sandbox_request
  end

  defp tool_request!(fixture, request, invocation) do
    {:ok, tool_request} =
      ToolRequest.new(%{
        execution: request,
        invocation_iri: invocation.iri,
        tool_iri: invocation.tool_iri,
        tool_version: invocation.tool_version,
        sequence: invocation.sequence,
        deadline: invocation.deadline,
        expected_effect: "repository.settings.write",
        allowed_effects: fixture.execution_context.allowed_effects,
        input_refs: invocation.input_refs,
        input_digests: invocation.input_digests,
        arguments: %{},
        output_bytes: 128
      })

    tool_request
  end

  defp successful_result(overrides \\ %{}) do
    Map.merge(
      %{
        stdout: "ok",
        stderr: "",
        exit_status: 0,
        usage: %{cpu_ms: 1, memory_bytes: 1_024},
        writes: %{}
      },
      overrides
    )
  end

  defp run_metadata!(fixture) do
    {:ok, metadata} =
      StoreServer.request(fixture.store_server, {:graph_metadata, fixture.attempt.run_graph_iri})

    metadata
  end
end

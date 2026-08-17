defmodule JidoCode.Factory.Harness.PhaseH05CancellationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedCancellation
  alias JidoCode.Factory.DelegatedResultGate
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Runtime.JidoHarness.ProcessRunner
  alias JidoCode.Runtime.JidoHarness.Readiness
  alias JidoCode.Runtime.JidoHarness.RunRegistry
  alias JidoCode.Runtime.JidoHarnessAdapter
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeJidoHarnessReadinessProbe
  alias JidoCode.TestSupport.FakeJidoHarnessRunner
  alias JidoCode.TestSupport.FakeOuterWorker
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-17 17:00:00Z]

  setup context do
    registry_name = Module.concat(__MODULE__, "Registry#{System.unique_integer([:positive])}")
    registry = start_supervised!({RunRegistry, name: registry_name})
    request = request!(Atom.to_string(context.test))

    runtime_options = [
      authority: AllowExecutionAuthority,
      registry: registry,
      runner: FakeJidoHarnessRunner,
      runner_options: [owner: self()],
      profile: :pi_rpc_deny_all,
      prompt: "bounded cancellation test",
      clock: fn -> @now end
    ]

    assert {:ok, _started} =
             ExecutionRuntime.start(JidoHarnessAdapter, request, runtime_options)

    cancellation = %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      reason: :lease_expired,
      committed_at: @now
    }

    {:ok,
     request: request,
     registry: registry,
     runtime_options: runtime_options,
     cancellation: cancellation}
  end

  test "commits cancellation before adapter stop, namespace kill, and destruction", context do
    parent = self()

    commit = fn command ->
      send(parent, {:cancellation_order, :commit, command})
      {:ok, %{outcome: :committed}}
    end

    assert {:ok, result} =
             DelegatedCancellation.cancel(:cancel_command, context.request, context.cancellation,
               commit: commit,
               adapter: JidoHarnessAdapter,
               runtime_options: context.runtime_options,
               outer_worker: {FakeOuterWorker, %{owner: self()}},
               adapter_stop_timeout_ms: 100
             )

    assert_receive {:cancellation_order, :commit, :cancel_command}
    assert_receive {:jido_harness_runner, :cancel, _handle, %{reason: :lease_expired}}
    assert_receive {:outer_worker, :kill_namespace, attempt, :lease_expired}
    assert_receive {:outer_worker, :destroy, ^attempt, :lease_expired}
    assert result.namespace_kill == {:ok, %{namespace: :terminated, within_bound: true}}
    assert result.destruction == {:ok, %{status: :destroyed}}
  end

  test "kills and destroys the outer namespace even when the adapter stalls", context do
    runtime_options =
      put_in(context.runtime_options, [:runner_options, :cancel_delay_ms], 250)

    commit = fn _command -> {:ok, %{outcome: :committed}} end

    assert {:ok, result} =
             DelegatedCancellation.cancel(:cancel_command, context.request, context.cancellation,
               commit: commit,
               adapter: JidoHarnessAdapter,
               runtime_options: runtime_options,
               outer_worker: {FakeOuterWorker, %{owner: self()}},
               adapter_stop_timeout_ms: 10
             )

    assert {:error, %{kind: :timeout, operation: :delegated_adapter_stop}} =
             result.adapter_stop

    assert_receive {:outer_worker, :kill_namespace, _attempt, :lease_expired}
    assert_receive {:outer_worker, :destroy, _attempt, :lease_expired}
  end

  test "a commit failure performs no runtime or outer-worker effect", context do
    assert {:error, %{runtime_effect: :not_started}} =
             DelegatedCancellation.cancel(:cancel_command, context.request, context.cancellation,
               commit: fn _command -> {:error, :conflict} end,
               adapter: JidoHarnessAdapter,
               runtime_options: context.runtime_options,
               outer_worker: {FakeOuterWorker, %{owner: self()}}
             )

    refute_received {:jido_harness_runner, :cancel, _handle, _cancellation}
    refute_received {:outer_worker, _operation, _attempt, _reason}
  end

  test "rejects every late delegated sink after fence expiry or supersession", context do
    current = current(context.request)

    for kind <- [:event, :diff, :artifact, :callback, :result] do
      stale = %{current | fencing_token: current.fencing_token + 1}

      assert {:error, %{kind: :unauthorized, operation: :delegated_result_fence}} =
               DelegatedResultGate.dispatch(
                 context.request,
                 stale,
                 kind,
                 %{candidate: kind},
                 at: @now,
                 sink: fn receipt ->
                   send(self(), {:late_sink, receipt})
                   :ok
                 end
               )

      refute_received {:late_sink, _receipt}
    end

    expired = %{current | lease_expires_at: @now}

    assert {:error, %{kind: :unauthorized}} =
             DelegatedResultGate.dispatch(
               context.request,
               expired,
               :result,
               %{state: :completed},
               at: @now,
               sink: fn _receipt ->
                 send(self(), :expired_sink)
                 :ok
               end
             )

    refute_received :expired_sink
  end

  test "dispatches only a bounded digest receipt after the current-fence check", context do
    payload = %{workspace_digest: String.duplicate("c", 64), candidate: "bounded"}

    assert {:ok, receipt} =
             DelegatedResultGate.dispatch(
               context.request,
               current(context.request),
               :diff,
               payload,
               at: @now,
               sink: fn value ->
                 send(self(), {:accepted_sink, value})
                 :ok
               end
             )

    assert_receive {:accepted_sink, ^receipt}
    assert receipt.kind == :diff
    assert Regex.match?(~r/^[a-f0-9]{64}$/, receipt.payload_digest)
    refute Map.has_key?(receipt, :payload)
  end

  test "readiness discovery is non-billable and reports no actor identity", _context do
    assert {:ok, receipt} =
             Readiness.discover(:pi_rpc_deny_all,
               probe: FakeJidoHarnessReadinessProbe,
               probe_options: [owner: self()]
             )

    assert_receive {:jido_harness_readiness, :discover, :pi_rpc_deny_all}
    refute_received {:jido_harness_readiness, :live_smoke, _profile}
    assert receipt.probe == :non_billable_discovery
    refute receipt.prompt_sent
    assert receipt.authentication.actor_identity == :not_claimed
    assert receipt.authentication.evidence == :not_proven_without_live_request
    refute inspect(receipt) =~ "/sensitive/developer/path"
    refute inspect(receipt) =~ "must-not-be-reported"
  end

  test "live readiness remains blocked without explicit unexpired billing consent", context do
    invalid = %{
      granted: false,
      billing_acknowledged: true,
      profile: :pi_rpc_deny_all,
      actor_iri: context.request.actor_iri,
      expires_at: DateTime.add(@now, 60, :second)
    }

    assert {:error, %{operation: :jido_harness_live_consent}} =
             Readiness.live_smoke(:pi_rpc_deny_all, invalid,
               at: @now,
               probe: FakeJidoHarnessReadinessProbe,
               probe_options: [owner: self()]
             )

    refute_received {:jido_harness_readiness, :live_smoke, _profile}

    consent = %{invalid | granted: true}

    assert {:ok, receipt} =
             Readiness.live_smoke(:pi_rpc_deny_all, consent,
               at: @now,
               probe: FakeJidoHarnessReadinessProbe,
               probe_options: [owner: self()]
             )

    assert_receive {:jido_harness_readiness, :live_smoke, :pi_rpc_deny_all}
    assert receipt.probe == :consented_live_smoke
    assert receipt.result == :passed
    assert receipt.authentication.actor_identity == :not_claimed
  end

  test "the process runner proves bounded graceful and forced group-stop paths" do
    handle = %{run_id: "run_fixture", runtime_ref: "proc_fixture", event_cursor: 0}

    base_options = [
      process_api: JidoCode.TestSupport.FakeJidoHarnessProcessAPI,
      process_api_options: [owner: self()],
      cancellation_bound_ms: 25,
      kill_bound_ms: 25
    ]

    assert {:ok, graceful} = ProcessRunner.cancel(handle, %{}, base_options)
    assert graceful.usage.cancellation == :graceful_process_group
    assert graceful.usage.cancellation_bound_ms == 25
    assert_received {:jido_harness_process_api, :cancel, "proc_fixture"}
    assert_received {:jido_harness_process_api, :await, "proc_fixture", 25}

    counter = start_supervised!({Agent, fn -> 0 end})

    await_fun = fn process_id, _timeout ->
      case Agent.get_and_update(counter, fn count -> {count, count + 1} end) do
        0 -> {:error, :timeout}
        _later -> {:ok, %{process_id: process_id, state: :cancelled}}
      end
    end

    forced_options =
      put_in(base_options, [:process_api_options, :await_fun], await_fun)

    assert {:ok, forced} = ProcessRunner.cancel(handle, %{}, forced_options)
    assert forced.usage.cancellation == :forced_process_group
    assert_received {:jido_harness_process_api, :kill, "proc_fixture"}
  end

  test "the pinned process manager terminates a resistant descendant process group" do
    shell = System.find_executable("sh") || flunk("the process-group proof requires sh")
    kill = System.find_executable("kill") || flunk("the process-group proof requires kill")
    original_config = Application.get_env(:jido_harness, :process_manager, %{})

    Application.put_env(
      :jido_harness,
      :process_manager,
      Map.merge(original_config, %{cancel_grace_ms: 25, term_grace_ms: 25})
    )

    on_exit(fn ->
      Application.put_env(:jido_harness, :process_manager, original_config)
    end)

    assert {:ok, process_id} =
             Jido.Harness.Process.start(%{
               executable: shell,
               argv: [
                 "-c",
                 "trap '' INT TERM; sh -c 'trap \"\" INT TERM; sleep 30' & printf '%s\\n' $!; wait"
               ],
               stdin: false,
               runtime_timeout_ms: 5_000,
               idle_timeout_ms: 5_000
             })

    on_exit(fn ->
      _ = Jido.Harness.Process.kill(process_id)
      _ = Jido.Harness.Process.prune(process_id)
    end)

    child_pid = await_stdout_integer(process_id)
    handle = %{run_id: "process-group-proof", runtime_ref: process_id, event_cursor: 0}

    assert {:ok, proof} =
             ProcessRunner.cancel(handle, %{},
               cancellation_bound_ms: 2_000,
               kill_bound_ms: 2_000
             )

    assert proof.usage.cancellation in [:graceful_process_group, :forced_process_group]
    assert eventually(fn -> not os_process_alive?(kill, child_pid) end)
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

  defp await_stdout_integer(process_id, attempts \\ 100)

  defp await_stdout_integer(_process_id, 0),
    do: flunk("managed process did not emit its descendant pid")

  defp await_stdout_integer(process_id, attempts) do
    case Jido.Harness.Process.replay(process_id, limit: 20) do
      {:ok, events} ->
        case Enum.find(events, &(&1.type == :stdout)) do
          nil ->
            Process.sleep(10)
            await_stdout_integer(process_id, attempts - 1)

          event ->
            event.data |> String.trim() |> String.to_integer()
        end

      _error ->
        Process.sleep(10)
        await_stdout_integer(process_id, attempts - 1)
    end
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

  defp os_process_alive?(kill, pid) do
    {_output, status} =
      System.cmd(kill, ["-0", Integer.to_string(pid)], stderr_to_stdout: true)

    status == 0
  end

  defp request!(seed) do
    safe_seed = seed |> String.replace(~r/[^a-zA-Z0-9-]/, "-") |> String.slice(0, 80)

    assert {:ok, request} =
             Request.new(%{
               attempt_iri: resource!("attempt-cancel-#{safe_seed}"),
               lease_iri: resource!("lease-cancel-#{safe_seed}"),
               task_iri: resource!("task-cancel-#{safe_seed}"),
               goal_iri: resource!("goal-cancel-#{safe_seed}"),
               plan_iri: resource!("plan-cancel-#{safe_seed}"),
               repository_iri: resource!("repository-cancel-#{safe_seed}"),
               snapshot_iri: resource!("snapshot-cancel-#{safe_seed}"),
               actor_iri: resource!("actor-cancel-#{safe_seed}"),
               agent_iri: resource!("agent-cancel-#{safe_seed}"),
               capability_iri: resource!("capability-cancel-#{safe_seed}"),
               fencing_token: 503,
               context_digest: String.duplicate("a", 64),
               runtime_version: "jido-harness:e41fc165/runtime-contract:1.0.0",
               constraints: %{deployment_class: :developer_local_cli}
             })

    request
  end

  defp resource!(seed), do: Phase04Fixture.resource!(seed)
end

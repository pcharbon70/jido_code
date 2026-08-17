defmodule JidoCode.Factory.Harness.PhaseH05AdapterRegistryTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Runtime.JidoHarness.Recovery
  alias JidoCode.Runtime.JidoHarness.RunRegistry
  alias JidoCode.Runtime.JidoHarnessAdapter
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeJidoHarnessRunner
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-17 15:00:00Z]

  setup context do
    registry_name = Module.concat(__MODULE__, "Registry#{System.unique_integer([:positive])}")
    registry = start_supervised!({RunRegistry, name: registry_name})
    request = request!(Atom.to_string(context.test))

    options = [
      authority: AllowExecutionAuthority,
      registry: registry,
      runner: FakeJidoHarnessRunner,
      runner_options: [owner: self()],
      profile: :pi_rpc_deny_all,
      clock: fn -> @now end
    ]

    {:ok, registry: registry, request: request, options: options}
  end

  test "maps one authorized delegated activity through the existing runtime port", context do
    prompt = "protected prompt " <> String.duplicate("p", 32)
    options = Keyword.put(context.options, :prompt, prompt)

    assert {:ok, %{type: :prepared, sequence: 0}} =
             ExecutionRuntime.prepare(JidoHarnessAdapter, context.request, options)

    assert {:ok, %{type: :started, sequence: 1, outcome_class: :pending}} =
             ExecutionRuntime.start(JidoHarnessAdapter, context.request, options)

    assert_received {:jido_harness_runner, :start, profile, launch}
    assert profile.prompt_transport == :stdin_jsonl
    assert launch.prompt == prompt
    refute Enum.any?(profile.argv, &String.contains?(&1, prompt))

    assert {:ok, record} = RunRegistry.fetch(context.registry, context.request)
    refute inspect(record, limit: :infinity) =~ prompt
    assert record.state == :running
    assert record.runtime_ref == "proc_fake"
    assert record.session_ref == "session_fake"
    assert record.provider_session_ref == "provider_session_fake"
    assert record.versions.cli == "pi-fixture/1.0.0"
  end

  test "retains bounded normalized observations and terminal candidate metadata", context do
    options = Keyword.put(context.options, :prompt, "bounded delegated work")
    assert {:ok, _event} = ExecutionRuntime.start(JidoHarnessAdapter, context.request, options)

    status_receipt = %{
      state: :completed,
      observations: [
        %{
          sequence: 2,
          type: :progress,
          occurred_at: @now,
          payload_digest: String.duplicate("b", 64),
          tool_ref: nil
        }
      ],
      workspace_digest: String.duplicate("c", 64),
      candidate_diff_digest: String.duplicate("d", 64),
      artifact_iris: [resource!("artifact")],
      usage: %{turns: 1, enforcement: :observed_only},
      provider_internal_context: %{memory: "must-not-be-adopted"}
    }

    options = put_in(options, [:runner_options, :status_receipt], status_receipt)

    assert {:ok, event} = ExecutionRuntime.status(JidoHarnessAdapter, context.request, options)
    assert event.type == :completed
    assert event.outcome_class == :success
    assert event.sequence == 3
    assert event.usage == %{turns: 1, enforcement: :observed_only}

    assert {:ok, record} = RunRegistry.fetch(context.registry, context.request)
    assert record.state == :completed
    assert [%{type: :progress, sequence: 2}] = record.observations
    assert record.final.workspace_digest == String.duplicate("c", 64)
    assert record.final.candidate_diff_digest == String.duplicate("d", 64)
    refute inspect(record, limit: :infinity) =~ "must-not-be-adopted"
  end

  test "classifies missing ephemeral state without emitting a crashed state", context do
    for {recovery_context, expected} <- [
          {%{terminal_callback_proven: true}, :recover},
          {%{runtime_compatible: false}, :supersede},
          {%{cancellation_committed: true}, :propagated_cancellation},
          {%{lease_state: :expired}, :abandon},
          {%{lease_state: :active}, :retry_later}
        ] do
      options = Keyword.put(context.options, :recovery_context, recovery_context)
      assert {:ok, event} = ExecutionRuntime.status(JidoHarnessAdapter, context.request, options)
      assert event.type == :heartbeat
      assert event.outcome_class == :unknown
      assert event.diagnostic == "runtime_missing:#{expected}"
      refute event.type == :crashed
    end

    assert Recovery.classes() == [
             :recover,
             :supersede,
             :propagated_cancellation,
             :abandon,
             :retry_later
           ]
  end

  test "supports protected follow-up turns and deletes disposable references on terminate",
       context do
    options = Keyword.put(context.options, :prompt, "first turn")
    assert {:ok, _event} = ExecutionRuntime.start(JidoHarnessAdapter, context.request, options)

    assert {:ok, incoming} =
             RuntimeEvent.new(%{
               attempt_iri: context.request.attempt_iri,
               sequence: 2,
               type: :progress,
               occurred_at: @now,
               outcome_class: :pending,
               usage: %{}
             })

    follow_up = Keyword.put(options, :prompt, "follow-up through stdin")

    assert {:ok, %{type: :progress}} =
             ExecutionRuntime.signal(JidoHarnessAdapter, context.request, incoming, follow_up)

    assert_received {:jido_harness_runner, :signal, _handle,
                     %{prompt: "follow-up through stdin", sequence: 2}}

    assert {:ok, %{type: :cancelled}} =
             ExecutionRuntime.terminate(
               JidoHarnessAdapter,
               context.request,
               %{reason: :test},
               options
             )

    assert :error = RunRegistry.fetch(context.registry, context.request)
  end

  test "rejects oversized or secret-bearing normalized runtime records", context do
    options = Keyword.put(context.options, :prompt, "bounded work")
    assert {:ok, _event} = ExecutionRuntime.start(JidoHarnessAdapter, context.request, options)

    secret_status = %{
      state: :completed,
      observations: [],
      usage: %{token: "secret=sk-abcdefghijklmnopqrstuvwxyz123456"}
    }

    options = put_in(options, [:runner_options, :status_receipt], secret_status)

    assert {:error, %{operation: :jido_harness_terminal_result}} =
             ExecutionRuntime.status(JidoHarnessAdapter, context.request, options)
  end

  defp request!(seed) do
    safe_seed = seed |> String.replace(~r/[^a-zA-Z0-9-]/, "-") |> String.slice(0, 80)

    assert {:ok, request} =
             Request.new(%{
               attempt_iri: resource!("attempt-#{safe_seed}"),
               lease_iri: resource!("lease-#{safe_seed}"),
               task_iri: resource!("task-#{safe_seed}"),
               goal_iri: resource!("goal-#{safe_seed}"),
               plan_iri: resource!("plan-#{safe_seed}"),
               repository_iri: resource!("repository-#{safe_seed}"),
               snapshot_iri: resource!("snapshot-#{safe_seed}"),
               actor_iri: resource!("actor-#{safe_seed}"),
               agent_iri: resource!("agent-#{safe_seed}"),
               capability_iri: resource!("capability-#{safe_seed}"),
               fencing_token: 501,
               context_digest: String.duplicate("a", 64),
               runtime_version: "jido-harness:e41fc165/runtime-contract:1.0.0",
               constraints: %{delegated_profile: :pi_rpc_deny_all}
             })

    request
  end

  defp resource!(seed), do: Phase04Fixture.resource!(seed)
end

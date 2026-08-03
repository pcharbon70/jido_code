defmodule JidoCode.Factory.Phase08RuntimeBoundariesTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Execution.ContextPackage
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Runtime.AttemptSupervisor
  alias JidoCode.Runtime.AttemptWorker
  alias JidoCode.Runtime.JidoAdapter
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeExecutionRuntime
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    suffix = context.test |> Atom.to_string() |> String.replace(" ", "-")
    request = request!(suffix)
    on_exit(fn -> cleanup_runtime(request) end)
    {:ok, request: request, context_attributes: context_attributes(suffix, request)}
  end

  test "assembles deterministic least-privilege context with explicit omissions", %{
    context_attributes: attributes
  } do
    assert {:ok, first} = ContextPackage.build(attributes)

    assert {:ok, second} =
             attributes
             |> Map.update!(:source_items, &Enum.reverse/1)
             |> ContextPackage.build()

    assert first.digest == second.digest
    assert Enum.map(first.source_items, & &1.iri) == Enum.map(second.source_items, & &1.iri)
    assert [%{kind: :knowledge, reason: :visibility}] = first.omissions
    assert first.source_graph_revisions == attributes.current_graph_revisions
    refute inspect(first) =~ "PRIVATE KEY"
  end

  test "fails closed for stale, secret-bearing, incomplete, and authority-widening context", %{
    context_attributes: attributes
  } do
    assert {:error, %{operation: :execution_context_revisions}} =
             attributes
             |> put_in([:current_graph_revisions, attributes.control_graph], 99)
             |> ContextPackage.build()

    assert {:error, %{operation: :execution_context_completeness}} =
             attributes |> Map.put(:strict_complete?, false) |> ContextPackage.build()

    assert {:error, %{operation: :execution_context_authority}} =
             attributes |> Map.put(:allowed_effects, ["network.write"]) |> ContextPackage.build()

    assert {:error, %{operation: :execution_context_item}} =
             attributes
             |> Map.update!(:source_items, fn [item | rest] ->
               [%{item | classification: :secret} | rest]
             end)
             |> ContextPackage.build()
  end

  test "re-authorizes every runtime operation and provides deterministic failure scenarios", %{
    request: request
  } do
    assert {:error, %{kind: :unavailable}} =
             ExecutionRuntime.prepare(FakeExecutionRuntime, request)

    assert {:error, %{kind: :unauthorized}} =
             ExecutionRuntime.prepare(FakeExecutionRuntime, request,
               authority: AllowExecutionAuthority,
               authorized?: false
             )

    expected = %{
      success: {:ok, :started},
      tool_use: {:ok, :waiting_tool},
      timeout: {:ok, :timed_out},
      cancellation: {:ok, :cancelling},
      crash: {:error, :unavailable},
      lost_response: {:error, :timeout},
      duplicate_event: {:ok, :started},
      stale_lease: {:ok, :stale_lease}
    }

    Enum.each(expected, fn {scenario, outcome} ->
      result =
        ExecutionRuntime.start(FakeExecutionRuntime, request,
          authority: AllowExecutionAuthority,
          scenario: scenario
        )

      actual =
        case result do
          {:ok, event} -> {:ok, event.type}
          {:error, error} -> {:error, error.kind}
        end

      assert actual == outcome
    end)
  end

  test "runs Jido behind the port and recreates disposable attempt workers", %{request: request} do
    options = [authority: AllowExecutionAuthority, clock: fn -> ~U[2026-08-03 14:00:00Z] end]

    assert {:ok, %{type: :prepared}} = ExecutionRuntime.prepare(JidoAdapter, request, options)
    assert {:ok, %{type: :started}} = ExecutionRuntime.start(JidoAdapter, request, options)
    assert {:ok, %{type: :progress}} = ExecutionRuntime.status(JidoAdapter, request, options)

    worker_options = [
      adapter: FakeExecutionRuntime,
      runtime_options: [authority: AllowExecutionAuthority]
    ]

    assert {:ok, first_pid} = AttemptSupervisor.start_attempt(request, worker_options)

    assert {:error, {:already_started, ^first_pid}} =
             AttemptSupervisor.start_attempt(request, worker_options)

    assert {:ok, %{type: :prepared}} = AttemptWorker.operation(first_pid, :prepare)
    assert :ok = AttemptSupervisor.stop_attempt(request)
    refute Process.alive?(first_pid)

    assert {:ok, second_pid} = AttemptSupervisor.start_attempt(request, worker_options)
    refute second_pid == first_pid
    assert {:ok, %{type: :started}} = AttemptWorker.operation(second_pid, :start)
    assert :ok = AttemptSupervisor.stop_attempt(request)

    assert {:ok, %{type: :cancelled}} =
             ExecutionRuntime.cancel(JidoAdapter, request, %{reason: :test}, options)
  end

  defp request!(suffix) do
    {:ok, request} =
      Request.new(%{
        attempt_iri: resource!("attempt-#{suffix}"),
        lease_iri: resource!("lease-#{suffix}"),
        task_iri: resource!("task-#{suffix}"),
        goal_iri: resource!("goal-#{suffix}"),
        plan_iri: resource!("plan-#{suffix}"),
        repository_iri: resource!("repository-#{suffix}"),
        snapshot_iri: resource!("snapshot-#{suffix}"),
        actor_iri: resource!("actor-#{suffix}"),
        agent_iri: resource!("agent-#{suffix}"),
        capability_iri: resource!("capability-#{suffix}"),
        fencing_token: 1,
        context_digest: String.duplicate("a", 64),
        runtime_version: "jido:2.3.2/runtime-contract:1.0.0",
        constraints: %{network: :deny, paths: ["lib/"]}
      })

    request
  end

  defp context_attributes(suffix, request) do
    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: request.repository_iri})

    {:ok, source_graph} =
      GraphRegistry.graph_iri(:source_revision, %{
        repository: request.repository_iri,
        revision: request.snapshot_iri
      })

    %{
      enrollment_iri: resource!("enrollment-#{suffix}"),
      repository_iri: request.repository_iri,
      goal_iri: request.goal_iri,
      task_iri: request.task_iri,
      plan_iri: request.plan_iri,
      lease_iri: request.lease_iri,
      snapshot_iri: request.snapshot_iri,
      task_snapshot_iri: request.snapshot_iri,
      actor_iri: request.actor_iri,
      agent_iri: request.agent_iri,
      capability_iri: request.capability_iri,
      fencing_token: 1,
      runtime_version: "jido:2.3.2/runtime-contract:1.0.0",
      instruction: "Apply the accepted plan within the declared effects.",
      source_graph_revisions: %{control_graph => 7, source_graph => 1},
      current_graph_revisions: %{control_graph => 7, source_graph => 1},
      control_graph: control_graph,
      constraints: %{network: :deny, paths: ["lib/"]},
      allowed_effects: ["source.read"],
      task_allowed_effects: ["source.read", "git.write"],
      expected_artifacts: ["patch"],
      expected_evidence: ["tests"],
      source_items: [
        item("source-b-#{suffix}", "second source", :internal, :source),
        item("source-a-#{suffix}", "first source", :public, :source)
      ],
      knowledge_items: [
        item("knowledge-#{suffix}", "restricted convention", :confidential, :knowledge)
      ],
      visible_classifications: [:public, :internal],
      budget: %{max_items: 10, max_bytes: 8_192, max_tokens: 2_048},
      assembled_at: ~U[2026-08-03 14:00:00Z],
      lease_expires_at: ~U[2026-08-03 14:10:00Z],
      lease_state: :active,
      plan_state: :approved,
      strict_complete?: true
    }
  end

  defp item(seed, content, classification, kind) do
    %{
      iri: resource!(seed),
      content: content,
      classification: classification,
      fresh?: true,
      contradictory?: false,
      accepted?: kind == :knowledge,
      required?: false
    }
  end

  defp cleanup_runtime(request) do
    _ = AttemptSupervisor.stop_attempt(request)

    _ =
      ExecutionRuntime.terminate(JidoAdapter, request, %{reason: :cleanup},
        authority: AllowExecutionAuthority
      )

    :ok
  end

  defp resource!(seed), do: Phase04Fixture.resource!(seed)
end

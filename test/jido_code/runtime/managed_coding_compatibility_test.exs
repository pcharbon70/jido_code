defmodule JidoCode.Runtime.ManagedCodingCompatibilityTest do
  use ExUnit.Case, async: false

  alias Jido.Agent.InstanceManager
  alias Jido.Agent.Strategy.Snapshot
  alias Jido.Signal
  alias JidoCode.Runtime.ExecutionAgent
  alias JidoCode.Runtime.JidoInstance
  alias JidoCode.Runtime.ManagedCodingCompatibility, as: Compatibility
  alias JidoCode.TestSupport.JidoDirectiveAction

  test "pins the exact Jido API surface and exposes bounded strategy snapshots" do
    assert {:ok, evidence} = Compatibility.verify()
    assert evidence.jido_version == "2.3.2"
    assert evidence.storage == Jido.Storage.ETS
    assert evidence.persistence == :ephemeral_only

    agent =
      ExecutionAgent.new(
        id: "compatibility-agent",
        state: %{attempt_iri: "https://jido.run/id/attempt/compatibility", fencing_token: 1}
      )

    assert ExecutionAgent.strategy() == Jido.Agent.Strategy.Direct

    assert [{"jido_code.runtime.transition", JidoCode.Runtime.ExecutionTransitionAction}] =
             ExecutionAgent.signal_routes()

    assert %Snapshot{} = snapshot = ExecutionAgent.strategy_snapshot(agent)
    assert {:ok, public} = Compatibility.snapshot(snapshot)
    assert Map.keys(public) |> Enum.sort() == [:details, :done?, :result, :status]
  end

  test "agent commands are immutable values and directives carry no state mutation" do
    agent =
      ExecutionAgent.new(
        id: "immutable-agent",
        state: %{attempt_iri: "https://jido.run/id/attempt/immutable", fencing_token: 1}
      )

    original_state = agent.state

    {updated, []} =
      ExecutionAgent.cmd(
        agent,
        {JidoCode.Runtime.ExecutionTransitionAction, %{execution_status: :running, sequence: 1}}
      )

    assert agent.state == original_state
    assert updated.state.execution_status == :running

    {unchanged, [%Jido.Agent.Directive.Emit{}]} =
      ExecutionAgent.cmd(updated, JidoDirectiveAction)

    assert unchanged.state == updated.state
  end

  test "AgentServer routing and sequence classification detect replay hazards" do
    id = "managed-compatibility-#{System.unique_integer([:positive])}"

    assert {:ok, pid} =
             JidoInstance.start_agent(ExecutionAgent,
               id: id,
               state: %{
                 attempt_iri: "https://jido.run/id/attempt/#{id}",
                 fencing_token: 1
               }
             )

    on_exit(fn -> if Process.alive?(pid), do: JidoInstance.stop_agent(pid) end)

    assert {:ok, signal} =
             Signal.new("jido_code.runtime.transition", %{
               execution_status: :running,
               sequence: 1
             })

    assert {:ok, _agent} = Jido.AgentServer.call(pid, signal)
    assert {:ok, state} = Jido.AgentServer.state(pid)
    assert state.agent.state.last_sequence == 1

    assert Compatibility.signal_sequence(0, 1) == :next
    assert Compatibility.signal_sequence(1, 1) == :duplicate
    assert Compatibility.signal_sequence(2, 1) == :stale
    assert Compatibility.signal_sequence(1, 3) == :gap
  end

  test "InstanceManager provides partitioned supervision without persistence" do
    manager = :managed_coding_compatibility_manager

    start_supervised!(
      InstanceManager.child_spec(
        name: manager,
        agent: ExecutionAgent,
        storage: nil,
        partition: :compatibility,
        registry_partitions: 2,
        idle_timeout: :infinity
      )
    )

    initial_state = %{
      attempt_iri: "https://jido.run/id/attempt/partitioned",
      fencing_token: 1
    }

    assert {:ok, pid} = InstanceManager.get(manager, "partitioned", initial_state: initial_state)
    assert {:ok, ^pid} = InstanceManager.lookup(manager, "partitioned")
    assert {:ok, state} = Jido.AgentServer.state(pid)
    assert state.agent.state.__partition__ == :compatibility
  end
end

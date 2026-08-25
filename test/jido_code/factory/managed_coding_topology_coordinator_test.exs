defmodule JidoCode.Factory.ManagedCodingTopologyCoordinatorTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.TopologyContract
  alias JidoCode.Factory.ManagedCoding.TopologyCoordinator
  alias JidoCode.Runtime.ManagedCoding.SpecialistAgent
  alias JidoCode.Runtime.ManagedCoding.SpecialistManager
  alias JidoCode.Runtime.ManagedCoding.TopologyAdapter

  @digest String.duplicate("a", 64)
  @watermark String.duplicate("b", 64)

  setup do
    {:ok, contract} = TopologyContract.new(contract_attributes())
    on_exit(fn -> TopologyCoordinator.stop(contract, runtime: TopologyAdapter) end)
    %{contract: contract}
  end

  test "reconciles fixed supervised roles solely from the exact graph projection", %{
    contract: contract
  } do
    assert {:ok, runtime} =
             TopologyCoordinator.reconcile(contract, projection(), runtime: TopologyAdapter)

    assert runtime.authority == :graph_projection
    assert runtime.persistence == :none
    assert runtime.watermark == @watermark
    assert Enum.sort(Map.keys(runtime.roles)) == ~w[coder investigator reviewer]
    assert Enum.all?(runtime.roles, fn {_role, pid} -> Process.alive?(pid) end)

    assert Enum.all?(runtime.roles, fn {role, pid} ->
             {:ok, state} = Jido.AgentServer.state(pid)

             state.agent.name == SpecialistAgent.name() and state.agent.state.role == role and
               state.agent.state.reconstruction_watermark == @watermark
           end)

    assert {:ok, same_runtime} =
             TopologyCoordinator.reconcile(contract, projection(), runtime: TopologyAdapter)

    assert same_runtime.pod_pid == runtime.pod_pid
    assert same_runtime.roles == runtime.roles

    assert :ok = TopologyCoordinator.stop(contract, runtime: TopologyAdapter)
    refute Process.alive?(runtime.pod_pid)

    assert {:ok, rebuilt} =
             TopologyCoordinator.reconcile(contract, projection(), runtime: TopologyAdapter)

    assert rebuilt.pod_pid != runtime.pod_pid
    assert rebuilt.watermark == runtime.watermark
  end

  test "admits bounded delegation and routes every effect through existing host gateways", %{
    contract: contract
  } do
    {:ok, runtime} =
      TopologyCoordinator.reconcile(contract, projection(), runtime: TopologyAdapter)

    request = request()

    assert {:ok, admission} = TopologyCoordinator.admit_delegation(contract, runtime, request)
    assert admission.remaining.shared.messages == 3
    assert admission.remaining.role.messages == 3
    assert :merge in admission.unavailable_authorities
    assert :topology in admission.unavailable_authorities

    for {kind, route} <- %{
          "context" => :managed_coding_context,
          "model" => :managed_coding_model,
          "tool" => :managed_coding_tool,
          "memory" => :managed_coding_memory
        } do
      assert {:ok, effect} = TopologyCoordinator.route_effect(admission, kind)
      assert effect.route == route
      refute effect.direct_credentials
      refute effect.direct_graph_access
    end

    assert {:error, error} = TopologyCoordinator.route_effect(admission, "publication")
    assert error.operation == :managed_coding_specialist_effect_route
  end

  test "rejects recursion, fan-out, stale authority, role expansion, and forged signals", %{
    contract: contract
  } do
    {:ok, runtime} =
      TopologyCoordinator.reconcile(contract, projection(), runtime: TopologyAdapter)

    invalid = [
      %{request() | parent_role: "coder"},
      %{request() | concurrent: 3},
      %{request() | policy_current: false},
      %{request() | role: "publisher"},
      %{request() | active_roles: ["coder"]},
      %{request() | fence: 0},
      %{request() | profile_digest: String.duplicate("f", 64)}
    ]

    for request <- invalid do
      assert {:error, error} = TopologyCoordinator.admit_delegation(contract, runtime, request)
      assert error.operation == :managed_coding_delegation_admission
    end

    assert TopologyCoordinator.classify_signal(1, 2, "coder", "reviewer", 4, 4) == :forged
    assert TopologyCoordinator.classify_signal(1, 2, "coder", "coder", 4, 3) == :superseded
    assert TopologyCoordinator.classify_signal(1, 1, "coder", "coder", 4, 4) == :duplicate
    assert TopologyCoordinator.classify_signal(1, 3, "coder", "coder", 4, 4) == :gap
  end

  defp contract_attributes do
    %{
      topology_iri: "https://jido.run/id/topology/coordinator-test",
      revision: 1,
      profile_digest: @digest,
      jido_version: "2.3.2",
      pod_revision: "jido-pod/2.3.2",
      roles: Enum.map(~w[investigator coder reviewer], &role/1),
      max_fan_out: 3,
      max_depth: 1,
      max_message_bytes: 8_192,
      restart_limit: 2,
      timeout_ms: 30_000,
      state: :evaluation
    }
  end

  defp role(name) do
    %{
      name: name,
      module: SpecialistAgent,
      manager: SpecialistManager,
      activation: "lazy",
      capability_refs: [@digest],
      budget: %{
        max_messages: 4,
        max_input_bytes: 8_192,
        max_output_bytes: 8_192,
        max_tokens: 2_000,
        max_cost_microunits: 10_000,
        timeout_ms: 30_000
      }
    }
  end

  defp projection do
    %{
      topology_iri: "https://jido.run/id/topology/coordinator-test",
      revision: 1,
      profile_digest: @digest,
      watermark: @watermark,
      state: :active
    }
  end

  defp request do
    remaining = %{
      messages: 4,
      input_bytes: 8_192,
      output_bytes: 8_192,
      tokens: 2_000,
      cost_microunits: 10_000,
      timeout_ms: 30_000
    }

    %{
      delegation_iri: "https://jido.run/id/delegation/coordinator-test",
      task_iri: "https://jido.run/id/task/coordinator-test",
      attempt_iri: "https://jido.run/id/attempt/coordinator-test",
      role: "coder",
      fence: 4,
      depth: 1,
      parent_role: "host",
      policy_current: true,
      capability_ref: @digest,
      context_digest: @digest,
      profile_digest: @digest,
      shared_remaining: remaining,
      role_remaining: remaining,
      concurrent: 0,
      active_roles: []
    }
  end
end

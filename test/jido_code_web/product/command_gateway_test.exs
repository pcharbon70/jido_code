defmodule JidoCode.Product.CommandGatewayTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Product.CommandGateway
  alias JidoCode.Product.CommandOutcome

  test "constructs enrollment command identity, graph, revisions, and actor on the server" do
    test_pid = self()

    execute = fn %CommandEnvelope{} = command ->
      send(test_pid, {:execute, command})
      {:ok, receipt(command)}
    end

    assert {:ok, %CommandOutcome{outcome: :committed}} =
             CommandGateway.enroll_repository(authority(), identity(), params(),
               clock: fn -> ~U[2026-08-04 11:00:00Z] end,
               summary: fn -> %{dataset_revision: 22} end,
               metadata: fn "https://jido.run/graph/factory/catalog" ->
                 {:ok, %{graph_revision: 8}}
               end,
               execute: execute
             )

    assert_receive {:execute, command}
    assert command.command_type == "EnrollRepository"
    assert command.command_version == "1.1.0"
    assert command.actor_iri == authority().actor_iri
    assert command.principal_iri == authority().principal_iri
    assert command.scope_iri == identity().factory_scope_iri
    assert command.expected_dataset_revision == 22
    assert command.idempotency_key == params()["idempotency_key"]

    assert command.expected_graph_revisions == %{
             "https://jido.run/graph/factory/catalog" => 8
           }

    assert [%{family: :factory_catalog, graph_iri: graph}] = command.payload.changes
    assert graph == "https://jido.run/graph/factory/catalog"
  end

  test "rejects unconfirmed and oversized input before graph access" do
    params = Map.put(params(), "confirmed", "false")

    assert {:error, error} =
             CommandGateway.enroll_repository(authority(), identity(), params,
               summary: fn -> flunk("graph must not be read") end
             )

    assert error.kind == :invalid_input

    params = Map.put(params(), "owner", String.duplicate("a", 161))

    assert {:error, error} =
             CommandGateway.enroll_repository(authority(), identity(), params,
               summary: fn -> flunk("graph must not be read") end
             )

    assert error.kind == :invalid_input

    params = Map.put(params(), "reason", "Authorization: Bearer abcdefghijklmnopqrst")

    assert {:error, error} =
             CommandGateway.enroll_repository(authority(), identity(), params,
               summary: fn -> flunk("graph must not be read") end
             )

    assert error.operation == :sensitive_input
  end

  test "ignores browser attempts to select commands, graphs, revisions, or actors" do
    test_pid = self()

    params =
      params()
      |> Map.put("command_type", "RawSparql")
      |> Map.put("graph", "https://attacker.invalid/graph")
      |> Map.put("dataset_revision", "999")
      |> Map.put("actor_iri", "https://attacker.invalid/actor")

    execute = fn command ->
      send(test_pid, {:execute, command})
      {:ok, receipt(command)}
    end

    assert {:ok, _receipt} =
             CommandGateway.enroll_repository(authority(), identity(), params,
               clock: fn -> ~U[2026-08-04 11:00:00Z] end,
               summary: fn -> %{dataset_revision: 4} end,
               metadata: fn _graph -> {:ok, %{graph_revision: 2}} end,
               execute: execute
             )

    assert_receive {:execute, command}
    assert command.command_type == "EnrollRepository"
    assert command.actor_iri == authority().actor_iri
    assert command.expected_dataset_revision == 4
    refute Map.has_key?(command.payload, :sparql)
  end

  defp receipt(command) do
    CommandReceipt.success(:committed, %{
      command_iri: command.command_iri,
      receipt_iri: "https://jido.run/id/receipt/1",
      change_set_iri: "https://jido.run/id/change-set/1",
      dataset_revision: command.expected_dataset_revision + 1,
      graph_revisions: %{"https://jido.run/graph/factory/catalog" => 9},
      affected_graphs: ["https://jido.run/graph/factory/catalog"],
      assertion_count: 20,
      supersession_count: 0,
      actor_iri: command.actor_iri,
      committed_at: ~U[2026-08-04 11:00:01Z]
    })
  end

  defp params do
    %{
      "conceptual_key" => "managed-repository-alpha",
      "provider" => "https://github.com",
      "external_id" => "R_alpha",
      "owner" => "agentjido",
      "name" => "alpha",
      "reason" => "Enroll the managed repository",
      "confirmed" => "true",
      "idempotency_key" => "phase10enrollment0001"
    }
  end

  defp identity do
    %{
      factory_iri: "https://jido.run/id/repository-factory/default",
      factory_scope_iri: "https://jido.run/id/scope/factory/default",
      policy_boundary_iri: "https://jido.run/id/policy-boundary/default",
      policy_iris: ["https://jido.run/id/policy/default"]
    }
  end

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: "https://jido.run/id/principal/operator",
        actor_iri: "https://jido.run/id/actor/operator",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end
end

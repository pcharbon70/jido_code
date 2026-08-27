defmodule JidoCode.Product.CommandGatewayTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile
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

  test "constructs a revision-fenced deterministic wiki policy transition from reviewed state" do
    test_pid = self()
    approved_at = ~U[2026-08-01 00:00:00Z]
    {:ok, profile} = GenerationProfile.new(:manual_deterministic, %{approved_at: approved_at})

    query = fn
      :repository_wiki_enrollment_detail,
      "2.10.0",
      %{graph: _, resource: repository},
      _authority,
      scope,
      [] ->
        assert scope == repository
        {:ok, query_result(:repository_wiki_enrollment_detail, [])}

      :repository_wiki_generation_profiles,
      "2.10.0",
      %{graph: _graph},
      _authority,
      factory_scope,
      [] ->
        assert factory_scope == identity().factory_scope_iri

        {:ok,
         query_result(:repository_wiki_generation_profiles, [
           %{
             "profile" => term(profile.iri),
             "profileKey" => term("manual_deterministic"),
             "compilerProfile" => term(profile.compiler_profile),
             "compilerDigest" => term(profile.compiler_digest),
             "approved" => term(DateTime.to_iso8601(approved_at))
           }
         ])}
    end

    execute = fn command ->
      send(test_pid, {:execute_wiki, command})
      {:ok, receipt(command)}
    end

    params = %{
      "mode" => "manual",
      "read_visibility" => "retained",
      "retention" => "standard",
      "confirmed" => "true",
      "graph" => "https://attacker.invalid/raw",
      "command_type" => "RawSparql"
    }

    repository = "https://jido.run/id/repository/alpha"

    assert {:ok, %CommandOutcome{outcome: :committed}} =
             CommandGateway.configure_repository_wiki(
               authority(),
               identity(),
               repository,
               params,
               clock: fn -> ~U[2026-08-04 11:00:00Z] end,
               summary: fn -> %{dataset_revision: 22} end,
               metadata: fn _graph -> {:ok, %{graph_revision: 8}} end,
               query: query,
               execute: execute
             )

    assert_receive {:execute_wiki, command}
    assert command.command_type == "TransitionRepositoryWikiEnrollment"
    assert command.command_version == "2.10.0"
    assert command.scope_iri == repository
    assert command.actor_iri == authority().actor_iri
    assert command.expected_dataset_revision == 22
    assert map_size(command.expected_graph_revisions) == 2
    refute Map.has_key?(command.payload, :sparql)
    assert command.payload.disable_effects == []
  end

  test "rejects unconfirmed or unregistered wiki settings before executing a write" do
    repository = "https://jido.run/id/repository/alpha"

    assert {:error, %{kind: :invalid_input}} =
             CommandGateway.configure_repository_wiki(
               authority(),
               identity(),
               repository,
               %{
                 "mode" => "automatic",
                 "read_visibility" => "retained",
                 "retention" => "standard",
                 "confirmed" => "false"
               },
               summary: fn -> flunk("graph state must not be read") end
             )

    assert {:error, %{kind: :invalid_input}} =
             CommandGateway.configure_repository_wiki(
               authority(),
               identity(),
               repository,
               %{
                 "mode" => "synthesis",
                 "read_visibility" => "retained",
                 "retention" => "forever",
                 "confirmed" => "true"
               },
               summary: fn -> flunk("graph state must not be read") end
             )
  end

  test "admits regeneration only through an installed finite deterministic requester" do
    repository = "https://jido.run/id/repository/alpha"

    assert {:error, %{kind: :unavailable}} =
             CommandGateway.regenerate_repository_wiki(authority(), identity(), repository)

    requester = fn received_authority, received_repository, profile ->
      assert received_authority.actor_iri == authority().actor_iri
      assert received_repository == repository
      assert profile == :manual_deterministic
      {:ok, %CommandOutcome{outcome: :committed, retry: :never, dataset_revision: 23}}
    end

    assert {:ok, %CommandOutcome{outcome: :committed}} =
             CommandGateway.regenerate_repository_wiki(authority(), identity(), repository,
               requester: requester
             )
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
      policy_iris: ["https://jido.run/id/policy/default"],
      actor_iri: authority().actor_iri
    }
  end

  defp query_result(name, data) do
    %QueryResult{
      query_name: name,
      query_version: "2.10.0",
      dataset_revision: 22,
      graph_revisions: %{},
      ontology_version: "1.5.0",
      completeness: %{complete?: true},
      freshness: %{state: :current},
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: :snapshot,
      evaluated_at: ~U[2026-08-04 11:00:00Z],
      data: data
    }
  end

  defp term(value), do: %{type: :literal, value: value}

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

defmodule JidoCode.Product.ReadProjectionQueryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.ReadProjectionQuery

  test "admits only closed protocol 2.11.0 bindings and exact parameters" do
    test_pid = self()

    query = fn name, version, parameters, authority, scope, options ->
      send(test_pid, {:query, name, version, parameters, authority, scope, options})
      {:ok, :bounded_result}
    end

    parameters = %{
      graph: "https://jido.run/graph/factory/catalog",
      resource: "https://jido.run/id/repository-factory/default"
    }

    assert {:ok, :bounded_result} =
             ReadProjectionQuery.execute(
               query,
               :factory_cohort,
               parameters,
               authority(),
               "https://jido.run/id/scope/factory/default"
             )

    assert_receive {:query, :factory_repository_cohort, "2.11.0", ^parameters, _authority,
                    "https://jido.run/id/scope/factory/default", []}

    assert {:error, error} =
             ReadProjectionQuery.execute(
               query,
               :factory_cohort,
               Map.put(parameters, :query, "SELECT *"),
               authority(),
               "https://jido.run/id/scope/factory/default"
             )

    assert error.kind == :invalid_input
    refute_receive {:query, _, _, _, _, _, _}
  end

  test "rejects raw graph, unknown query, and caller options without invoking the adapter" do
    query = fn _name, _version, _parameters, _authority, _scope, _options ->
      flunk("unreviewed query adapter invocation")
    end

    assert {:error, _error} =
             ReadProjectionQuery.execute(
               query,
               :unknown,
               %{},
               authority(),
               "https://jido.run/id/scope/factory/default"
             )

    assert {:error, _error} =
             ReadProjectionQuery.execute(
               query,
               :active_attempts,
               %{graph: "https://attacker.invalid/graph"},
               authority(),
               "https://jido.run/id/scope/factory/default"
             )
  end

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: "https://jido.run/id/human/query-reader",
        actor_iri: "https://jido.run/id/human/query-reader",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end
end

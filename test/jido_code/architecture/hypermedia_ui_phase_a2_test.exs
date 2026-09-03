defmodule JidoCode.Architecture.HypermediaUIPhaseA2Test do
  use ExUnit.Case, async: false

  alias JidoCode.Architecture.HypermediaUIPhaseA2
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.QueryCatalog

  test "identity, authorization, approval, revocation, threats, documents, and fixtures validate" do
    assert {:ok, []} = HypermediaUIPhaseA2.check()
  end

  test "every current operation binding matches the executable registries" do
    matrix = manifests!().matrix

    for operation <- matrix["operations"],
        operation["binding"]["status"] != "future_contract_only" do
      binding = operation["binding"]

      cond do
        query = binding["query"] ->
          name =
            Enum.find(
              QueryCatalog.names(query["version"]),
              &(Atom.to_string(&1) == query["name"])
            )

          assert {:ok, definition} = QueryCatalog.fetch(name, query["version"])
          assert Atom.to_string(definition.capability) == binding["capability"]

        command = binding["command"] ->
          assert {:ok, definition} = CommandRegistry.resolve(command["name"], command["version"])
          assert Atom.to_string(definition.capability) == binding["capability"]
      end
    end
  end

  test "hostile authority scenarios fail closed without role union or scope inference" do
    manifests = manifests!()
    defaults = manifests.scenarios["authorization_defaults"]

    for scenario <- manifests.scenarios["authorization_scenarios"] do
      assert HypermediaUIPhaseA2.evaluate_authorization(
               manifests.matrix,
               defaults,
               scenario
             ) == scenario["expected"],
             scenario["id"]
    end
  end

  test "two-human and concurrent approval scenarios are deterministic" do
    manifests = manifests!()

    for scenario <- manifests.scenarios["approval_scenarios"] do
      assert HypermediaUIPhaseA2.evaluate_approval(scenario) == scenario["expected"],
             scenario["id"]
    end

    outcomes = manifests.approval["commit_compare_and_set"]["outcomes"]
    assert Enum.sum(Enum.map(outcomes, & &1["effect_dispatch_count"])) == 1
    assert manifests.approval["commit_compare_and_set"]["maximum_conflicting_winners"] == 1
  end

  test "all revocation dimensions terminate delivery and invalidate retrieval deterministically" do
    manifests = manifests!()

    for scenario <- manifests.scenarios["revocation_scenarios"] do
      assert HypermediaUIPhaseA2.evaluate_revocation(manifests.approval, scenario) ==
               scenario["expected"],
             scenario["id"]
    end

    assert Enum.map(manifests.approval["revocation_dimensions"], & &1["id"]) |> Enum.sort() ==
             ~w[account delegation graph incident project role session tenant]
  end

  test "role grants and missing operation classes fail architecture validation" do
    manifests = manifests!()

    widened =
      update_in(manifests, [:matrix, "roles"], fn [first | rest] ->
        [%{first | "exact_grants" => ["administrative"]} | rest]
      end)

    assert Enum.any?(
             HypermediaUIPhaseA2.validate(widened, File.cwd!()),
             &String.contains?(&1, "must not contain grants")
           )

    missing_patch =
      update_in(manifests, [:matrix, "operations"], fn operations ->
        Enum.reject(operations, &(&1["surface"] == "patch"))
      end)

    errors = HypermediaUIPhaseA2.validate(missing_patch, File.cwd!())
    assert Enum.any?(errors, &String.contains?(&1, "authorization operation count"))
    assert Enum.any?(errors, &String.contains?(&1, "operation surfaces"))
  end

  test "widened registry bindings and falsified hostile outcomes fail validation" do
    manifests = manifests!()

    widened =
      update_in(manifests, [:matrix, "operations"], fn operations ->
        Enum.map(operations, fn
          %{"id" => "project_home_page", "binding" => binding} = operation ->
            %{operation | "binding" => %{binding | "capability" => "administrative"}}

          operation ->
            operation
        end)
      end)

    assert Enum.any?(
             HypermediaUIPhaseA2.validate(widened, File.cwd!()),
             &String.contains?(&1, "project_home_page query capability")
           )

    falsified =
      update_in(manifests, [:scenarios, "authorization_scenarios"], fn scenarios ->
        Enum.map(scenarios, fn
          %{"id" => "cross_tenant_probe"} = scenario ->
            %{scenario | "expected" => "allowed"}

          scenario ->
            scenario
        end)
      end)

    assert Enum.any?(
             HypermediaUIPhaseA2.validate(falsified, File.cwd!()),
             &String.contains?(&1, "cross_tenant_probe authorization outcome")
           )
  end

  defp manifests! do
    assert {:ok, manifests} = HypermediaUIPhaseA2.load()
    manifests
  end
end

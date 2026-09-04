defmodule JidoCode.Architecture.HypermediaUIPhaseA1Test do
  use ExUnit.Case, async: false

  alias JidoCode.Architecture.HypermediaUIPhaseA1
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog

  test "the baseline, inventories, vocabulary, supersession, links, and anchors validate" do
    assert {:ok, []} = HypermediaUIPhaseA1.check()
  end

  test "the route inventory matches generated product routes" do
    manifests = manifests!()

    expected =
      manifests.runtime["routes"]
      |> Enum.reject(&(&1["id"] == "development_dashboard"))
      |> Enum.map(&{&1["method"], &1["path"]})
      |> Enum.sort()

    actual =
      JidoCodeWeb.Router.__routes__()
      |> Enum.reject(&String.starts_with?(&1.path, "/__qualification/"))
      |> Enum.map(&{&1.verb |> Atom.to_string() |> String.upcase(), &1.path})
      |> Enum.sort()

    assert actual == expected
  end

  test "the supervision inventory matches live OTP child ids" do
    supervision = manifests!().runtime["supervision"]

    assert child_ids(JidoCode.Supervisor) == Enum.sort(supervision["application_child_ids"])

    assert child_ids(JidoCode.Knowledge.Supervisor) ==
             Enum.sort(supervision["knowledge_children"])

    assert child_ids(JidoCode.Runtime.Supervisor) == Enum.sort(supervision["runtime_children"])
  end

  test "the semantic registry inventory matches executable catalogs" do
    semantic = manifests!().runtime["semantic_surface"]

    assert GraphRegistry.revision() == semantic["graph_registry_revision"]
    assert GraphRegistry.families() |> Enum.map(&Atom.to_string/1) == semantic["graph_families"]

    assert CommandRegistry.repository_wiki_version() == semantic["latest_command_protocol"]

    assert length(CommandRegistry.names(CommandRegistry.repository_wiki_version())) ==
             semantic["semantic_command_count"]

    assert QueryCatalog.repository_wiki_runtime_version() == semantic["latest_query_protocol"]

    assert length(QueryCatalog.names(QueryCatalog.repository_wiki_runtime_version())) ==
             semantic["reviewed_query_count"]
  end

  test "duplicate vocabulary and orphaned supersession fail validation" do
    manifests = manifests!()
    first_term = hd(manifests.vocabulary["terms"])

    duplicate =
      put_in(manifests, [:vocabulary, "terms"], [first_term | manifests.vocabulary["terms"]])

    assert Enum.any?(
             HypermediaUIPhaseA1.validate(duplicate, File.cwd!()),
             &String.contains?(&1, "duplicate vocabulary term")
           )

    orphaned =
      update_in(
        manifests,
        [:vocabulary, "supersession_matrix"],
        fn [first | rest] -> [%{first | "source_path" => "docs/missing-owner.md"} | rest] end
      )

    errors = HypermediaUIPhaseA1.validate(orphaned, File.cwd!())
    assert Enum.any?(errors, &String.contains?(&1, "supersession source does not exist"))
    assert Enum.any?(errors, &String.contains?(&1, "required supersession source is missing"))
  end

  test "unowned gaps and missing route evidence fail validation" do
    manifests = manifests!()

    unowned =
      update_in(manifests, [:runtime, "gaps"], fn [first | rest] ->
        [%{first | "owner" => ""} | rest]
      end)

    assert Enum.any?(
             HypermediaUIPhaseA1.validate(unowned, File.cwd!()),
             &String.contains?(&1, "is missing owner")
           )

    missing_evidence =
      update_in(manifests, [:runtime, "routes"], fn [first | rest] ->
        [%{first | "tests" => ["test/missing_hui_a1_evidence.exs"]} | rest]
      end)

    assert Enum.any?(
             HypermediaUIPhaseA1.validate(missing_evidence, File.cwd!()),
             &String.contains?(&1, "route browser_sign_in_form test does not exist")
           )
  end

  defp manifests! do
    assert {:ok, manifests} = HypermediaUIPhaseA1.load()
    manifests
  end

  defp child_ids(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.map(fn {id, _pid, _type, _modules} -> inspect(id) end)
    |> Enum.sort()
  end
end

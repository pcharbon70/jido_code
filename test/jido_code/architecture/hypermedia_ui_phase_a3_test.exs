defmodule JidoCode.Architecture.HypermediaUIPhaseA3Test do
  use ExUnit.Case, async: false

  alias JidoCode.Architecture.HypermediaUIPhaseA3

  test "runtime authority, supersession, interfaces, evidence, traceability, and documents validate" do
    assert {:ok, []} = HypermediaUIPhaseA3.check()
  end

  test "every supersession row is owned, version-traced, testable, reversible, and removable only by evidence" do
    manifests = manifests!()
    interface_ids = MapSet.new(Enum.map(manifests.interfaces["interfaces"], & &1["id"]))

    for row <- manifests.supersession["rows"] do
      assert is_binary(row["target_owner"]) and row["target_owner"] != ""
      assert row["test_classes"] != []
      assert is_binary(row["rollback_dependency"]) and row["rollback_dependency"] != ""
      assert is_binary(row["removal_condition"]) and row["removal_condition"] != ""
      assert MapSet.subset?(MapSet.new(row["interfaces"]), interface_ids)
    end
  end

  test "routes, signal namespaces, compatibility, consumers, and removal gates fail closed" do
    manifests = manifests!()

    mutations = [
      {put_in(
         manifests,
         [:interfaces, "routes", Access.at(1), "id"],
         get_in(manifests, [:interfaces, "routes", Access.at(0), "id"])
       ), "duplicate route id"},
      {put_in(manifests, [:interfaces, "signal_namespaces", Access.at(0), "authority"], true),
       "signal authority"},
      {put_in(manifests, [:interfaces, "compatibility", "dual_write"], "allowed"),
       "dual write compatibility"},
      {put_in(
         manifests,
         [:interfaces, "removal_gate", "milestone_label_alone_sufficient"],
         true
       ), "milestone label removal"}
    ]

    for {mutated, expected} <- mutations do
      assert has_error?(HypermediaUIPhaseA3.validate(mutated, File.cwd!()), expected)
    end
  end

  test "unowned supersession and unversioned interfaces fail trace validation" do
    manifests = manifests!()

    unowned =
      update_in(manifests, [:supersession, "rows"], fn [first | rest] ->
        [Map.delete(first, "target_owner") | rest]
      end)

    unversioned =
      update_in(manifests, [:interfaces, "interfaces"], fn [first | rest] ->
        [Map.delete(first, "version") | rest]
      end)

    assert has_error?(HypermediaUIPhaseA3.validate(unowned, File.cwd!()), "target_owner")
    assert has_error?(HypermediaUIPhaseA3.validate(unversioned, File.cwd!()), "interface version")
  end

  test "real seam and real-adapter evidence cannot be replaced by mocks" do
    manifests = manifests!()

    missing_proxy =
      update_in(manifests, [:evidence, "real_seams"], fn seams ->
        Enum.reject(seams, &(&1["id"] == "proxy"))
      end)

    fake_adapter =
      update_in(manifests, [:evidence, "evidence_classes"], fn classes ->
        Enum.map(classes, fn
          %{"id" => "real_adapter"} = class ->
            %{class | "real_required" => false, "mock_limit" => "fake_allowed"}

          class ->
            class
        end)
      end)

    assert has_error?(HypermediaUIPhaseA3.validate(missing_proxy, File.cwd!()), "real seams")

    assert has_error?(
             HypermediaUIPhaseA3.validate(fake_adapter, File.cwd!()),
             "real adapter evidence"
           )
  end

  test "merge-pending and accepted receipt states are coherent while mixed closure fails" do
    plan =
      File.read!(
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/phase-03-runtime-contract-supersession-and-interface-freeze.md"
      )

    receipt = File.read!("docs/architecture/hypermedia-ui-milestone-a-phase-03-receipt.md")

    assert HypermediaUIPhaseA3.validate_closure(plan, receipt) == []

    mixed =
      String.replace(
        receipt,
        "Status: **merge-pending**",
        "Status: **accepted-at-merged-candidate**"
      )

    assert has_error?(HypermediaUIPhaseA3.validate_closure(plan, mixed), "closure")

    sha = "1234567890abcdef1234567890abcdef12345678"

    accepted_plan =
      plan
      |> String.replace("status: proposed", "status: completed")
      |> String.replace("- [ ] 3 Phase", "- [x] 3 Phase")
      |> String.replace("- [ ] 3.4 Section", "- [x] 3.4 Section")
      |> String.replace("- [ ] 3.4.2 Task", "- [x] 3.4.2 Task")
      |> String.replace("- [ ] 3.4.2.3 Subtask", "- [x] 3.4.2.3 Subtask")

    accepted_receipt = """
    Status: **accepted-at-merged-candidate**

    | Merged candidate | `#{sha}` |

    Merged candidate: `#{sha}`
    Merge date: `2026-09-03`

    Gate HUI-A3

    Status: **accepted-at-merged-candidate**
    """

    assert HypermediaUIPhaseA3.validate_closure(accepted_plan, accepted_receipt) == []
  end

  defp manifests! do
    assert {:ok, manifests} = HypermediaUIPhaseA3.load()
    manifests
  end

  defp has_error?(errors, fragment) do
    Enum.any?(errors, &String.contains?(&1, fragment))
  end
end

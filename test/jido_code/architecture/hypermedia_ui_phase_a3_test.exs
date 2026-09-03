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

    mixed = String.replace(plan, "- [x] 3.4.2.3 Subtask", "- [ ] 3.4.2.3 Subtask")

    assert has_error?(HypermediaUIPhaseA3.validate_closure(mixed, receipt), "closure")

    merge_pending_plan =
      plan
      |> String.replace("status: completed", "status: proposed")
      |> String.replace("- [x] 3 Phase", "- [ ] 3 Phase")
      |> String.replace("- [x] 3.4 Section", "- [ ] 3.4 Section")
      |> String.replace("- [x] 3.4.2 Task", "- [ ] 3.4.2 Task")
      |> String.replace("- [x] 3.4.2.3 Subtask", "- [ ] 3.4.2.3 Subtask")

    merge_pending_receipt =
      receipt
      |> String.replace("Status: **accepted-at-merged-candidate**", "Status: **merge-pending**")
      |> then(
        &Regex.replace(
          ~r/\| Merged candidate \| `[0-9a-f]{40}` \|/,
          &1,
          "| Merged candidate | `merge-pending` |"
        )
      )
      |> then(
        &Regex.replace(
          ~r/Merged candidate: `[0-9a-f]{40}`/,
          &1,
          "Merged candidate: `merge-pending`"
        )
      )
      |> then(
        &Regex.replace(~r/Merge date: `\d{4}-\d{2}-\d{2}`/, &1, "Merge date: `merge-pending`")
      )

    assert HypermediaUIPhaseA3.validate_closure(merge_pending_plan, merge_pending_receipt) == []
  end

  defp manifests! do
    assert {:ok, manifests} = HypermediaUIPhaseA3.load()
    manifests
  end

  defp has_error?(errors, fragment) do
    Enum.any?(errors, &String.contains?(&1, fragment))
  end
end

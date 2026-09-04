defmodule JidoCode.Architecture.HypermediaUIPhaseB3Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseB3

  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-03-datastar-dstar-consumer-spike.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-03-receipt.md"

  test "tracked consumer, protocol, browser, proxy, and closure evidence passes" do
    assert {:ok, []} = HypermediaUIPhaseB3.check()
    assert {:ok, evidence} = HypermediaUIPhaseB3.load()

    assert evidence["status"] == "accepted_at_merged_candidate"

    assert evidence["implementation_pr_head"] ==
             "29e662f1afa5e8671e69632468d2a34ece1adcdb"

    assert evidence["merged_candidate"] == "e055ce51d880aa167c033a2e1f59ba4d7f8d1e81"
    assert evidence["baseline_commit"] == "21e659819f4ccce7a4ba5fb1a9d858183fb65564"
    assert get_in(evidence, ["browser_toolchain", "version"]) == "1.62.0"
    assert get_in(evidence, ["stream_limits", "max_queue"]) == 0
    assert map_size(evidence["source_digests"]) == 24
  end

  test "stream limits, signal schema, toolchain, and evidence drift fail closed" do
    assert {:ok, evidence} = HypermediaUIPhaseB3.load()

    assert has_error?(
             evidence
             |> put_in(["stream_limits", "max_connections"], 5)
             |> HypermediaUIPhaseB3.validate(File.cwd!()),
             "connection ceiling"
           )

    assert has_error?(
             evidence
             |> update_in(["signal_keys"], &tl/1)
             |> HypermediaUIPhaseB3.validate(File.cwd!()),
             "signal schema"
           )

    assert has_error?(
             evidence
             |> put_in(["browser_toolchain", "version"], "latest")
             |> HypermediaUIPhaseB3.validate(File.cwd!()),
             "browser package version"
           )

    {path, _digest} = Enum.at(evidence["source_digests"], 0)

    assert has_error?(
             evidence
             |> put_in(["source_digests", path], String.duplicate("0", 64))
             |> HypermediaUIPhaseB3.validate(File.cwd!()),
             "source digest"
           )
  end

  test "qualification source boundary rejects product consumers and inline scripts" do
    errors =
      HypermediaUIPhaseB3.check_qualification_sources([
        {"qualification/live.ex", "use JidoCodeWeb, :live_view"},
        {"qualification/store.ex", "JidoCode.Knowledge.StoreServer.read()"},
        {"qualification/effect.ex", "JidoCode.Runtime.run()"},
        {"qualification/bad.html.heex", "<script>alert('no')</script>"}
      ])

    assert has_error?(errors, "LiveView consumer")
    assert has_error?(errors, "product persistence")
    assert has_error?(errors, "runtime effects")
    assert has_error?(errors, "inline scripts")

    assert [] ==
             HypermediaUIPhaseB3.check_qualification_sources([
               {"qualification/controller.ex", "Dstar.patch_signals(conn, %{fixture: true})"}
             ])
  end

  test "closure accepts only coherent merge-pending or accepted states" do
    plan = File.read!(@plan_path)
    receipt = File.read!(@receipt_path)

    assert HypermediaUIPhaseB3.validate_closure(plan, receipt) == []

    pending_plan =
      plan
      |> String.replace("status: completed", "status: proposed", global: false)
      |> set_closure_checkboxes(false)

    pending_receipt =
      receipt
      |> String.replace("Status: **accepted-at-merged-candidate**", "Status: **merge-pending**",
        global: false
      )
      |> String.replace(
        "Merged candidate: `e055ce51d880aa167c033a2e1f59ba4d7f8d1e81`",
        "Merged candidate: `merge-pending`"
      )
      |> String.replace("Merge date: `2026-09-04`", "Merge date: `merge-pending`")

    assert HypermediaUIPhaseB3.validate_closure(pending_plan, pending_receipt) == []

    assert has_error?(
             HypermediaUIPhaseB3.validate_closure(plan, pending_receipt),
             "status: proposed"
           )

    assert has_error?(
             HypermediaUIPhaseB3.validate_closure(plan, ""),
             "exactly one coherent"
           )
  end

  defp set_closure_checkboxes(plan, checked?) do
    mark = if checked?, do: "x", else: " "

    plan
    |> String.replace(~r/- \[[ x]\] 3 Phase/, "- [#{mark}] 3 Phase")
    |> String.replace(~r/- \[[ x]\] 3\.4 Section/, "- [#{mark}] 3.4 Section")
    |> String.replace(~r/- \[[ x]\] 3\.4\.2 Task/, "- [#{mark}] 3.4.2 Task")
    |> String.replace(~r/- \[[ x]\] 3\.4\.2\.3 Subtask/, "- [#{mark}] 3.4.2.3 Subtask")
  end

  defp has_error?(errors, fragment), do: Enum.any?(errors, &String.contains?(&1, fragment))
end

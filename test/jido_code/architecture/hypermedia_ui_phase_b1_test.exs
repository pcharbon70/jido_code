defmodule JidoCode.Architecture.HypermediaUIPhaseB1Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseB1

  @fixture_root "test/fixtures/architecture/hypermedia_ui_b1"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-01-source-license-version-and-risk-baseline.md"
  @milestone_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/README.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-01-receipt.md"

  test "tracked HUI-B1 provenance, pairing, BOM, ledger, evidence, and boundary pass" do
    assert {:ok, []} = HypermediaUIPhaseB1.check()
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    assert manifests.shadcn["status"] == "accepted_source_baseline_adoption_blocked"
    assert manifests.pairing["status"] == "accepted_protocol_baseline_adoption_blocked"
    assert manifests.bom["status"] == "immutable_candidate_graph_not_installed"
    assert manifests.ledger["status"] == "accepted_decision_ledger_adoption_blocked"
    assert length(manifests.bom["components"]) == 19
    assert length(manifests.pairing["compatibility_matrix"]) == 11
    assert length(manifests.evidence["negative_cases"]) == 10
  end

  test "changed source commit, tag, and checksum fail closed" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    changed_commit =
      put_in(manifests, [:shadcn, "candidate", "commit"], String.duplicate("0", 40))

    assert has_error?(
             HypermediaUIPhaseB1.validate(changed_commit, File.cwd!()),
             "candidate commit"
           )

    changed_tag = put_in(manifests, [:pairing, "dstar", "tag"], "v0.2.1")
    assert has_error?(HypermediaUIPhaseB1.validate(changed_tag, File.cwd!()), "Dstar tag")

    changed_checksum =
      put_in(
        manifests,
        [:pairing, "dstar", "hex_release", "checksum_sha256"],
        String.duplicate("f", 64)
      )

    assert has_error?(HypermediaUIPhaseB1.validate(changed_checksum, File.cwd!()), "Hex checksum")
    assert has_error?(HypermediaUIPhaseB1.validate(changed_checksum, File.cwd!()), "BOM checksum")
  end

  test "missing usage authority and namespace drift fail closed" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    missing_license = put_in(manifests, [:shadcn, "license_and_usage", "spdx"], nil)

    assert has_error?(
             HypermediaUIPhaseB1.validate(missing_license, File.cwd!()),
             "license and usage"
           )

    namespace_drift = put_in(manifests, [:shadcn, "candidate", "module_namespace"], "Shadcn")

    assert has_error?(
             HypermediaUIPhaseB1.validate(namespace_drift, File.cwd!()),
             "module namespace"
           )
  end

  test "advisory and failed upstream CI qualification claims fail closed" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    advisory =
      put_in(
        manifests,
        [:pairing, "datastar", "upstream_evidence", "repository_security_advisories_at_review"],
        [%{"severity" => "critical", "id" => "GHSA-test"}]
      )

    assert has_error?(HypermediaUIPhaseB1.validate(advisory, File.cwd!()), "Datastar advisory")

    false_credit = put_in(manifests, [:shadcn, "upstream_evidence", "candidate_qualified"], true)
    assert has_error?(HypermediaUIPhaseB1.validate(false_credit, File.cwd!()), "qualification")
  end

  test "protocol matrix cannot omit a selected-version behavior" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()
    missing_behavior = update_in(manifests, [:pairing, "compatibility_matrix"], &tl/1)

    assert has_error?(HypermediaUIPhaseB1.validate(missing_behavior, File.cwd!()), "behavior ids")

    versionless =
      put_in(
        manifests,
        [:pairing, "compatibility_matrix", Access.at(0), "datastar_1_0_3"],
        ""
      )

    assert has_error?(HypermediaUIPhaseB1.validate(versionless, File.cwd!()), "datastar_1_0_3")
  end

  test "BOM rejects unknown transitives, missing consumers, and mismatched asset identity" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    unknown_edge =
      update_in(
        manifests,
        [:bom, "dependency_edges", "pkg:hex/dstar@0.2.0"],
        &["pkg:hex/unreviewed@9.9.9" | &1]
      )

    assert has_error?(HypermediaUIPhaseB1.validate(unknown_edge, File.cwd!()), "edge target")

    missing_consumer = put_in(manifests, [:bom, "components", Access.at(0), "consumer"], "")
    assert has_error?(HypermediaUIPhaseB1.validate(missing_consumer, File.cwd!()), "consumer")

    changed_bundle =
      put_in(manifests, [:bom, "components", Access.at(3), "sha256"], String.duplicate("0", 64))

    assert has_error?(
             HypermediaUIPhaseB1.validate(changed_bundle, File.cwd!()),
             "Datastar BOM checksum"
           )
  end

  test "ledger rejects active exceptions, mutable baseline, and missing clean-checkout outputs" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    exception =
      put_in(manifests, [:ledger, "exceptions_and_controls", "active_adoption_exceptions"], [
        "allow"
      ])

    assert has_error?(HypermediaUIPhaseB1.validate(exception, File.cwd!()), "active adoption")

    changed_baseline = put_in(manifests, [:ledger, "baseline", "commit"], "main")
    assert has_error?(HypermediaUIPhaseB1.validate(changed_baseline, File.cwd!()), "baseline")

    missing_output = update_in(manifests, [:ledger, "expected_HUI_B2_outputs"], &tl/1)

    assert has_error?(
             HypermediaUIPhaseB1.validate(missing_output, File.cwd!()),
             "expected output"
           )
  end

  test "phase boundary rejects changed lock or newly claimed consumer" do
    assert {:ok, manifests} = HypermediaUIPhaseB1.load()

    changed_lock =
      put_in(manifests, [:ledger, "baseline", "mix_lock_sha256"], String.duplicate("0", 64))

    assert has_error?(HypermediaUIPhaseB1.validate(changed_lock, File.cwd!()), "mix_lock")

    consumer_claim =
      put_in(manifests, [:evidence, "phase_boundary", "product_consumers_added"], true)

    assert has_error?(
             HypermediaUIPhaseB1.validate(consumer_claim, File.cwd!()),
             "product_consumers_added"
           )
  end

  test "unavailable artifact fixture fails closed with actionable diagnostics" do
    assert {:error, errors} =
             HypermediaUIPhaseB1.check(Path.join(@fixture_root, "unavailable"))

    assert length(errors) == 5
    assert Enum.all?(errors, &String.contains?(&1, "unavailable manifest"))
  end

  test "negative fixture registry covers every required release-blocking case" do
    assert {:ok, %{evidence: evidence}} = HypermediaUIPhaseB1.load()

    assert MapSet.new(Enum.map(evidence["negative_cases"], & &1["id"])) ==
             MapSet.new(~w[
               changed_commit changed_tag checksum_mismatch missing_license_or_usage_grant
               namespace_drift advisory_present upstream_CI_failure_claimed_qualified
               unavailable_artifact versionless_protocol_claim product_consumer_added_in_phase_1
             ])
  end

  test "closure accepts only coherent merge-pending or accepted states" do
    plan = File.read!(@plan_path)
    milestone = File.read!(@milestone_path)
    receipt = File.read!(@receipt_path)

    assert HypermediaUIPhaseB1.validate_closure(plan, milestone, receipt) == []

    merge_pending_plan =
      plan
      |> String.replace("status: completed", "status: proposed", global: false)
      |> set_closure_checkboxes(false)

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

    assert HypermediaUIPhaseB1.validate_closure(
             merge_pending_plan,
             milestone,
             merge_pending_receipt
           ) == []

    assert has_error?(
             HypermediaUIPhaseB1.validate_closure(merge_pending_plan, milestone, receipt),
             "completed plan status"
           )

    assert has_error?(
             HypermediaUIPhaseB1.validate_closure(plan, milestone, ""),
             "exactly one coherent"
           )

    mixed_receipt = receipt <> "\nStatus: **merge-pending**\n"

    assert has_error?(
             HypermediaUIPhaseB1.validate_closure(plan, milestone, mixed_receipt),
             "exactly one coherent"
           )
  end

  defp set_closure_checkboxes(plan, checked?) do
    mark = if checked?, do: "x", else: " "

    plan
    |> String.replace(~r/- \[[ x]\] 1 Phase/, "- [#{mark}] 1 Phase")
    |> String.replace(~r/- \[[ x]\] 1\.4 Section/, "- [#{mark}] 1.4 Section")
    |> String.replace(~r/- \[[ x]\] 1\.4\.2 Task/, "- [#{mark}] 1.4.2 Task")
    |> String.replace(~r/- \[[ x]\] 1\.4\.2\.3 Subtask/, "- [#{mark}] 1.4.2.3 Subtask")
  end

  defp has_error?(errors, fragment), do: Enum.any?(errors, &String.contains?(&1, fragment))
end

defmodule JidoCode.Architecture.HypermediaUIPhaseA4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseA4

  @fixture_root "test/fixtures/architecture/hypermedia_ui"
  @plan_root "docs/planning/secure-hypermedia-control-plane-ui"

  test "tracked sources, exceptions, requirements, gaps, plans, and receipts satisfy HUI-A4" do
    assert {:ok, []} = HypermediaUIPhaseA4.check()

    assert {:ok,
            %{
              acceptance: acceptance,
              dossier: dossier,
              guardrails: guardrails,
              traceability: traceability
            }} =
             HypermediaUIPhaseA4.load()

    assert guardrails["phase"] == "HUI-A4"
    assert acceptance["status"] == "accepted_at_merged_candidate"
    assert dossier["status"] == "accepted_at_merged_candidate"

    assert get_in(acceptance, ["baseline", "merged_candidate"]) ==
             "59ffca10f3ac9f262a81ce46b9f9f0e61550697c"

    assert get_in(dossier, ["baseline", "merged_candidate"]) ==
             "59ffca10f3ac9f262a81ce46b9f9f0e61550697c"

    assert length(traceability["gap_mappings"]) == 24
    assert length(traceability["requirements"]) == 12
    assert length(dossier["consumer_reconciliation"]) == 13
    assert length(dossier["surface_authority_reconciliation"]) == 8
    assert length(dossier["residual_risks"]) == 10
    assert length(dossier["milestone_b_blockers"]) == 8
    assert length(acceptance["coverage"]) == 12
    assert length(acceptance["failure_scenarios"]) == 9
  end

  test "acceptance matrix rejects missing coverage and false milestone-a claims" do
    assert {:ok, manifests} = HypermediaUIPhaseA4.load()

    missing_coverage = update_in(manifests, [:acceptance, "coverage"], &tl/1)

    assert has_error?(
             HypermediaUIPhaseA4.validate(missing_coverage, File.cwd!()),
             "coverage classes"
           )

    leaked_implementation =
      put_in(manifests, [:acceptance, "reproduction", "target_implementation_added"], true)

    assert has_error?(
             HypermediaUIPhaseA4.validate(leaked_implementation, File.cwd!()),
             "target implementation"
           )

    unsupported_readiness =
      put_in(manifests, [:acceptance, "reproduction", "unsupported_readiness_claim"], true)

    assert has_error?(
             HypermediaUIPhaseA4.validate(unsupported_readiness, File.cwd!()),
             "readiness claim"
           )
  end

  test "dossier rejects missing consumers, incomplete surface authority, and released blockers" do
    assert {:ok, manifests} = HypermediaUIPhaseA4.load()

    missing_consumer = update_in(manifests, [:dossier, "consumer_reconciliation"], &tl/1)

    assert has_error?(
             HypermediaUIPhaseA4.validate(missing_consumer, File.cwd!()),
             "consumer reconciliation"
           )

    incomplete_surface =
      put_in(
        manifests,
        [:dossier, "surface_authority_reconciliation", Access.at(0), "authorization_points"],
        []
      )

    assert has_error?(
             HypermediaUIPhaseA4.validate(incomplete_surface, File.cwd!()),
             "authorization points"
           )

    released_blocker =
      put_in(
        manifests,
        [:dossier, "milestone_b_blockers", Access.at(0), "status"],
        "released"
      )

    assert has_error?(
             HypermediaUIPhaseA4.validate(released_blocker, File.cwd!()),
             "blocker status"
           )
  end

  test "allowed controller HEEx contract and native component fixture pass" do
    assert {:ok, []} =
             @fixture_root
             |> fixture_sources("permitted")
             |> HypermediaUIPhaseA4.check_sources()
  end

  test "every prohibited runtime, asset, authority, graph, effect, and contract fixture fails" do
    sources = fixture_sources(@fixture_root, "prohibited")
    assert {:error, errors} = HypermediaUIPhaseA4.check_sources(sources)

    rejected_paths =
      errors
      |> Enum.map(&String.split(&1, ":", parts: 2))
      |> Enum.map(&List.first/1)
      |> MapSet.new()

    assert rejected_paths == MapSet.new(sources, &elem(&1, 0))

    for rule <- ~w[
          product_liveview product_livecomponent liveview_event_or_stream livevue_bridge
          saladui_import unauthorized_dashboard inline_script remote_product_asset
          raw_knowledge_access direct_graph_write caller_selected_graph
          browser_derived_authority get_effect direct_runtime_effect target_surface_contract
        ] do
      assert Enum.any?(errors, &String.contains?(&1, "[#{rule}]")),
             "expected fixture coverage for #{rule}"
    end
  end

  test "compatibility exceptions are exact, digest-bound, and expiring" do
    assert {:ok, %{guardrails: guardrails}} = HypermediaUIPhaseA4.load()

    exception =
      Enum.find(guardrails["exceptions"], &(&1["path"] == "lib/jido_code_web/router.ex"))

    source = File.read!(exception["path"])

    assert {:ok, []} =
             HypermediaUIPhaseA4.check_sources(
               [{exception["path"], source}],
               exceptions: [exception],
               today: ~D[2026-09-03]
             )

    assert {:error, changed_errors} =
             HypermediaUIPhaseA4.check_sources(
               [{exception["path"], source <> "\n"}],
               exceptions: [exception],
               today: ~D[2026-09-03]
             )

    assert Enum.any?(changed_errors, &String.contains?(&1, "[product_liveview]"))

    assert {:error, expired_errors} =
             HypermediaUIPhaseA4.check_sources(
               [{exception["path"], source}],
               exceptions: [exception],
               today: ~D[2027-04-01]
             )

    assert Enum.any?(expired_errors, &String.contains?(&1, "[unauthorized_dashboard]"))
  end

  test "plan graph rejects duplicate anchors, broken dependencies, and missing integration sections" do
    bodies = plan_sources()
    assert HypermediaUIPhaseA4.validate_plan_sources(bodies, File.cwd!()) == []

    [{first_path, first_body} | rest] = bodies

    [existing_anchor] =
      Regex.run(~r/Task \{#([A-Za-z0-9_-]+)\}/, first_body, capture: :all_but_first)

    duplicate = [{first_path, first_body <> "\nTask {##{existing_anchor}}\n"} | rest]

    assert has_error?(
             HypermediaUIPhaseA4.validate_plan_sources(duplicate, File.cwd!()),
             "duplicate task anchor"
           )

    broken = [{first_path, first_body <> "\n[after: {#missing-plan-anchor}]\n"} | rest]

    assert has_error?(
             HypermediaUIPhaseA4.validate_plan_sources(broken, File.cwd!()),
             "unknown values"
           )

    without_integration =
      String.replace(
        first_body,
        "Section - Phase 1 Integration Tests",
        "Section - Acceptance Tests"
      )

    assert has_error?(
             HypermediaUIPhaseA4.validate_plan_sources(
               [{first_path, without_integration} | rest],
               File.cwd!()
             ),
             "final integration section"
           )
  end

  test "traceability rejects missing gaps, unowned requirements, and browser-selected race policy" do
    assert {:ok, %{traceability: traceability}} = HypermediaUIPhaseA4.load()
    assert HypermediaUIPhaseA4.validate_program(traceability) == []

    missing_gap = update_in(traceability["gap_mappings"], &tl/1)
    assert has_error?(HypermediaUIPhaseA4.validate_program(missing_gap), "HUI gap mapping")

    unowned = put_in(traceability, ["requirements", Access.at(0), "authority_owner"], "")
    assert has_error?(HypermediaUIPhaseA4.validate_program(unowned), "authority_owner")

    silent_supersession =
      put_in(traceability, ["requirements", Access.at(0), "owner_documents"], [])

    assert has_error?(
             HypermediaUIPhaseA4.validate_program(silent_supersession),
             "owner_documents"
           )

    browser_version =
      put_in(traceability, ["parallel_version_policy", "caller_selected_versions"], true)

    assert has_error?(HypermediaUIPhaseA4.validate_program(browser_version), "caller-selected")
  end

  test "closure accepts only coherent merge-pending or accepted states" do
    plan_path =
      Path.join(
        @plan_root,
        "milestone-a-architectural-authority/phase-04-governance-guardrails-and-authority-acceptance.md"
      )

    milestone_path = Path.join(@plan_root, "milestone-a-architectural-authority/README.md")
    plan = File.read!(plan_path)
    milestone = File.read!(milestone_path)
    receipt = File.read!("docs/architecture/hypermedia-ui-milestone-a-phase-04-receipt.md")

    assert HypermediaUIPhaseA4.validate_closure(plan, milestone, receipt) == []

    merge_pending_plan =
      plan
      |> String.replace("status: completed", "status: proposed")
      |> set_closure_checkboxes(false)

    merge_pending_milestone = String.replace(milestone, "status: completed", "status: proposed")

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

    assert HypermediaUIPhaseA4.validate_closure(
             merge_pending_plan,
             merge_pending_milestone,
             merge_pending_receipt
           ) == []

    assert has_error?(
             HypermediaUIPhaseA4.validate_closure(plan, milestone, ""),
             "exactly one coherent"
           )

    assert has_error?(
             HypermediaUIPhaseA4.validate_closure(
               merge_pending_plan,
               merge_pending_milestone,
               receipt
             ),
             "completed plan status"
           )

    mixed_receipt = receipt <> "\nStatus: **merge-pending**\n"

    assert has_error?(
             HypermediaUIPhaseA4.validate_closure(plan, milestone, mixed_receipt),
             "exactly one coherent"
           )
  end

  defp fixture_sources(root, group) do
    root
    |> Path.join(group)
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
    |> Enum.map(&{&1, File.read!(&1)})
  end

  defp plan_sources do
    @plan_root
    |> Path.join("milestone-*/phase-*.md")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&{Path.relative_to(&1, File.cwd!()), File.read!(&1)})
  end

  defp set_closure_checkboxes(plan, checked?) do
    mark = if checked?, do: "x", else: " "

    plan
    |> String.replace(~r/- \[[ x]\] 4 Phase/, "- [#{mark}] 4 Phase")
    |> String.replace(~r/- \[[ x]\] 4\.4 Section/, "- [#{mark}] 4.4 Section")
    |> String.replace(~r/- \[[ x]\] 4\.4\.2 Task/, "- [#{mark}] 4.4.2 Task")
    |> String.replace(~r/- \[[ x]\] 4\.4\.2\.3 Subtask/, "- [#{mark}] 4.4.2.3 Subtask")
  end

  defp has_error?(errors, fragment), do: Enum.any?(errors, &String.contains?(&1, fragment))
end

defmodule JidoCode.Architecture.HypermediaUIPhaseA4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseA4

  @fixture_root "test/fixtures/architecture/hypermedia_ui"
  @plan_root "docs/planning/secure-hypermedia-control-plane-ui"

  test "tracked sources, exceptions, requirements, gaps, plans, and receipts satisfy HUI-A4" do
    assert {:ok, []} = HypermediaUIPhaseA4.check()

    assert {:ok, %{guardrails: guardrails, traceability: traceability}} =
             HypermediaUIPhaseA4.load()

    assert guardrails["phase"] == "HUI-A4"
    assert length(traceability["gap_mappings"]) == 24
    assert length(traceability["requirements"]) == 12
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

    merge_pending_receipt = """
    Status: **merge-pending**
    | Merged candidate | `merge-pending` |
    Merged candidate: `merge-pending`
    Merge date: `merge-pending`
    """

    assert HypermediaUIPhaseA4.validate_closure(plan, milestone, merge_pending_receipt) == []

    accepted_plan =
      plan
      |> String.replace("status: proposed", "status: completed")
      |> set_closure_checkboxes(true)

    accepted_milestone = String.replace(milestone, "status: proposed", "status: completed")
    sha = String.duplicate("a", 40)

    accepted_receipt = """
    Status: **accepted-at-merged-candidate**
    | Merged candidate | `#{sha}` |
    Merged candidate: `#{sha}`
    Merge date: `2026-09-03`
    """

    assert HypermediaUIPhaseA4.validate_closure(
             accepted_plan,
             accepted_milestone,
             accepted_receipt
           ) == []

    mixed_receipt = accepted_receipt <> "\nStatus: **merge-pending**\n"

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

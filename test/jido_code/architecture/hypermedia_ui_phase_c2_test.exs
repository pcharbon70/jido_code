defmodule JidoCode.Architecture.HypermediaUIPhaseC2Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseC2

  @source_path "lib/jido_code_web/components/hui_c2_probe.ex"
  @source """
  defmodule JidoCodeWeb.Components.HUIC2Probe do
    use Phoenix.Component

    attr :id, :string, required: true
    slot :inner_block, required: true

    def probe(assigns) do
      ~H\"\"\"
      <section id={@id}>{render_slot(@inner_block)}</section>
      \"\"\"
    end
  end
  """

  @tag :tmp_dir
  test "accepts the complete merge-pending implementation candidate", %{tmp_dir: root} do
    write_fixture(root, pending_plan(), pending_receipt())

    assert HypermediaUIPhaseC2.validate(candidate_evidence(root), root) == []
  end

  @tag :tmp_dir
  test "tolerates ordered staged progress before the receipt is published", %{tmp_dir: root} do
    write_fixture(root, progress_plan(), nil)

    evidence =
      root
      |> candidate_evidence()
      |> Map.merge(%{
        "status" => "implementation_in_progress",
        "completed_sections" => ["2.1"],
        "section_commits" => %{"2.1" => sha40("1")},
        "receipt_status" => "not_published",
        "clean_checkout_ci" => "not_run",
        "integration" => %{}
      })

    assert HypermediaUIPhaseC2.validate(evidence, root) == []
  end

  @tag :tmp_dir
  test "accepts only coherent merged-candidate provenance and closure files", %{tmp_dir: root} do
    write_fixture(root, accepted_plan(), accepted_receipt())
    accepted = accepted_evidence(root)

    assert HypermediaUIPhaseC2.validate(accepted, root) == []

    false_acceptance = Map.put(accepted, "merged_candidate", nil)

    assert has_error?(
             HypermediaUIPhaseC2.validate(false_acceptance, root),
             "receipt lifecycle"
           )

    write_receipt(root, accepted_receipt() <> "\nStatus: **merge-pending**\n")

    assert has_error?(
             HypermediaUIPhaseC2.validate(accepted, root),
             "merge-pending status count"
           )
  end

  @tag :tmp_dir
  test "rejects primitive, projection, section, and source drift", %{tmp_dir: root} do
    write_fixture(root, pending_plan(), pending_receipt())
    evidence = candidate_evidence(root)

    primitive_drift = update_in(evidence, ["facade", "supported_primitives"], &tl/1)
    assert has_error?(HypermediaUIPhaseC2.validate(primitive_drift, root), "primitive catalog")

    state_drift = update_in(evidence, ["projection", "states"], &tl/1)
    assert has_error?(HypermediaUIPhaseC2.validate(state_drift, root), "projection states")

    reordered = Map.put(evidence, "completed_sections", ["2.2", "2.1"])
    assert has_error?(HypermediaUIPhaseC2.validate(reordered, root), "completed section order")

    missing_predecessor_commit =
      put_in(evidence, ["section_commits"], %{"2.2" => sha40("2")})

    assert has_error?(
             HypermediaUIPhaseC2.validate(missing_predecessor_commit, root),
             "section commit order"
           )

    digest_drift = put_in(evidence, ["source_digests", @source_path], String.duplicate("0", 64))
    assert has_error?(HypermediaUIPhaseC2.validate(digest_drift, root), "source digest")
  end

  @tag :tmp_dir
  test "reports malformed nested evidence without opening or crashing", %{tmp_dir: root} do
    write_fixture(root, pending_plan(), pending_receipt())

    malformed =
      root
      |> candidate_evidence()
      |> Map.put("completed_sections", %{"2.1" => true})
      |> Map.put("facade", "browser supplied")
      |> Map.put("integration", %{"results" => "pass"})

    errors = HypermediaUIPhaseC2.validate(malformed, root)

    assert has_error?(errors, "completed sections schema")
    assert has_error?(errors, "primitive catalog")
  end

  @tag :tmp_dir
  test "rejects weakened DOM, native, authority, asset, and integration evidence", %{
    tmp_dir: root
  } do
    write_fixture(root, pending_plan(), pending_receipt())
    evidence = candidate_evidence(root)

    mutations = [
      {put_in(evidence, ["dom_contract", "stable_unique_root_ids"], false), "stable unique DOM"},
      {put_in(evidence, ["native_contract", "native_forms"], false), "native forms"},
      {put_in(evidence, ["authority_boundary", "component_authority"], true),
       "component authority"},
      {put_in(evidence, ["asset_boundary", "remote_assets"], true), "remote assets"},
      {put_in(evidence, ["integration", "results", "browser_matrix"], "pending"),
       "integration results"}
    ]

    for {mutated, diagnostic} <- mutations do
      assert has_error?(HypermediaUIPhaseC2.validate(mutated, root), diagnostic)
    end
  end

  test "source inspection rejects upstream, authority, runtime, inline, and remote leakage" do
    sources = [
      {"lib/jido_code_web/components/shell.ex", "alias ShadcnUI.Components.Foundation.Button"},
      {"lib/jido_code_web/components/navigation.ex", "alias JidoCode.Identity.AuthorityBuilder"},
      {"lib/jido_code_web/components/projection.ex", "alias Phoenix.LiveView.JS"},
      {"lib/jido_code_web/components/fixture.html.heex", ~S|<script>alert("x")</script>|},
      {"lib/jido_code_web/components/remote.html.heex",
       ~s(<link rel="stylesheet" href="https://example.test/app.css" />)}
    ]

    errors = HypermediaUIPhaseC2.validate_product_sources(sources)

    for diagnostic <- [
          "upstream component imports",
          "cannot construct or query authority",
          "cannot depend on LiveView",
          "inline scripts",
          "remote product assets"
        ] do
      assert has_error?(errors, diagnostic)
    end
  end

  defp candidate_evidence(root) do
    %{
      "schema_version" => 1,
      "phase" => "HUI-C2",
      "status" => "integration_candidate_merge_pending",
      "recorded_on" => "2026-09-05",
      "baseline_commit" => "73326538cefcc6b136cc96c621062f44f2346c24",
      "predecessor_candidate" => "4a6fa78443463a8c8cd8ed039119cef8ba6e3b1b",
      "completed_sections" => ["2.1", "2.2", "2.3", "2.4"],
      "section_commits" => %{
        "2.1" => sha40("1"),
        "2.2" => sha40("2"),
        "2.3" => sha40("3")
      },
      "receipt_status" => "merge_pending",
      "clean_checkout_ci" => "pending",
      "implementation_pr" => nil,
      "implementation_pr_head" => nil,
      "merged_candidate" => nil,
      "merge_date" => nil,
      "clean_checkout_jobs" => nil,
      "facade" => %{
        "module" => "JidoCodeWeb.Components.UI",
        "supported_primitives" => ~w[
          badge button checkbox dialog disclosure field_input form input link menu radio_group
          select skeleton status table toast tooltip
        ],
        "shadcn_import_owner" => "JidoCodeWeb.Components.UI",
        "closed_variants" => true,
        "phoenix_form_contract" => true,
        "project_input_contract" => true,
        "escaped_content" => true
      },
      "projection" => %{
        "states" => ~w[
          ready empty stale incomplete contradicted truncated unauthorized unavailable maintenance
          recovery
        ],
        "unavailable_clears_rows" => true,
        "unauthorized_is_concealed" => true,
        "stale_rows_require_explicit_state" => true,
        "bounded_collections" => true
      },
      "dom_contract" => %{
        "stable_unique_root_ids" => true,
        "stable_focus_targets" => true,
        "deterministic_relationship_ids" => true
      },
      "native_contract" => %{
        "ordinary_links" => true,
        "native_forms" => true,
        "native_submit" => true,
        "javascript_disabled" => "supported"
      },
      "authority_boundary" => %{
        "component_authority" => false,
        "browser_authority" => false,
        "navigation_visibility_grants" => false,
        "server_authorized_inputs" => true
      },
      "asset_boundary" => %{
        "inline_scripts" => false,
        "inline_event_handlers" => false,
        "remote_assets" => false,
        "remote_fonts" => false,
        "remote_icons" => false,
        "application_bundles" => ["assets/js/app.js", "assets/css/app.css"]
      },
      "invariants" => ~w[
        stable_unique_dom_roots_and_focus_targets
        native_forms_and_navigation_work_without_javascript
        components_never_construct_or_grant_authority
        shadcn_ui_imports_are_confined_to_the_ui_facade
        inline_scripts_event_handlers_and_remote_assets_are_prohibited
        projection_states_preserve_truth_bounds_and_concealment
        unavailable_and_unauthorized_projections_clear_rows
        semantic_status_never_relies_on_color_alone
      ],
      "integration" => %{
        "focused_tests" => 40,
        "precommit_tests" => 1_300,
        "browser_profiles" => ~w[chromium firefox webkit chromium-no-js chromium-touch],
        "results" => %{
          "facade_render_and_hostile_content" => "pass",
          "native_forms_and_navigation" => "pass",
          "accessibility_semantics" => "pass",
          "browser_matrix" => "pass",
          "visual_regression" => "pass",
          "architecture_boundary" => "pass",
          "dependency_and_asset_diff" => "pass",
          "strict_production_compile" => "pass",
          "repository_precommit" => "pass"
        }
      },
      "limitations" => [
        %{
          "id" => "named-screen-reader-release-evidence",
          "detail" =>
            "Automated ARIA semantics do not claim named screen-reader release evidence."
        }
      ],
      "exceptions" => [],
      "source_digests" => %{@source_path => digest(File.read!(Path.join(root, @source_path)))}
    }
  end

  defp accepted_evidence(root) do
    root
    |> candidate_evidence()
    |> Map.merge(%{
      "status" => "accepted_at_merged_candidate",
      "receipt_status" => "accepted_at_merged_candidate",
      "clean_checkout_ci" => "pass",
      "implementation_pr" => 119,
      "implementation_pr_head" => sha40("a"),
      "merged_candidate" => sha40("b"),
      "merge_date" => "2026-09-05",
      "clean_checkout_jobs" => %{
        "verify" => %{"id" => 101, "duration" => "18m", "result" => "pass"},
        "dialyzer" => %{"id" => 102, "duration" => "2m", "result" => "pass"}
      }
    })
  end

  defp write_fixture(root, plan, receipt) do
    source = Path.join(root, @source_path)
    File.mkdir_p!(Path.dirname(source))
    File.write!(source, @source)

    plan_path =
      Path.join(
        root,
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-02-shadcnui-facade-theme-and-app-components.md"
      )

    File.mkdir_p!(Path.dirname(plan_path))
    File.write!(plan_path, plan)

    if receipt, do: write_receipt(root, receipt)
  end

  defp write_receipt(root, receipt) do
    path = Path.join(root, "docs/architecture/hypermedia-ui-milestone-c-phase-02-receipt.md")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, receipt)
  end

  defp progress_plan do
    """
    status: proposed
    - [ ] 2 Phase
    - [x] 2.1 Section
    - [ ] 2.2 Section
    - [ ] 2.3 Section
    - [ ] 2.4 Section
    - [ ] 2.4.1 Task
    - [ ] 2.4.2 Task
    - [ ] 2.4.2.1 Subtask
    - [ ] 2.4.2.2 Subtask
    - [ ] 2.4.2.3 Subtask
    """
  end

  defp pending_plan do
    """
    status: proposed
    - [ ] 2 Phase
    - [x] 2.1 Section
    - [x] 2.2 Section
    - [x] 2.3 Section
    - [ ] 2.4 Section
    - [x] 2.4.1 Task
    - [ ] 2.4.2 Task
    - [x] 2.4.2.1 Subtask
    - [x] 2.4.2.2 Subtask
    - [ ] 2.4.2.3 Subtask
    """
  end

  defp accepted_plan do
    """
    status: completed
    - [x] 2 Phase
    - [x] 2.1 Section
    - [x] 2.2 Section
    - [x] 2.3 Section
    - [x] 2.4 Section
    - [x] 2.4.1 Task
    - [x] 2.4.2 Task
    - [x] 2.4.2.1 Subtask
    - [x] 2.4.2.2 Subtask
    - [x] 2.4.2.3 Subtask
    """
  end

  defp pending_receipt do
    """
    Status: **merge-pending**
    Merged candidate: `merge-pending`
    Merge date: `merge-pending`
    ## Gate HUI-C2 Reopening Conditions
    """
  end

  defp accepted_receipt do
    """
    Status: **accepted-at-merged-candidate**
    Merged candidate: `#{sha40("b")}`
    Merge date: `2026-09-05`
    ## Gate HUI-C2 Reopening Conditions
    """
  end

  defp sha40(character), do: String.duplicate(character, 40)
  defp digest(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
  defp has_error?(errors, fragment), do: Enum.any?(errors, &String.contains?(&1, fragment))
end

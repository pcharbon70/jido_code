defmodule JidoCode.Architecture.HypermediaUIPhaseC5 do
  @moduledoc false

  @manifest_path "priv/architecture/hypermedia_ui/phase_c5_implementation_evidence.json"
  @accessibility_path "priv/architecture/hypermedia_ui/phase_c5_accessibility_evidence.json"
  @operations_path "priv/architecture/hypermedia_ui/phase_c5_operations_evidence.json"
  @baseline_path "priv/architecture/hypermedia_ui/phase_c5_product_baseline.json"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-05-read-only-shell-accessibility-and-acceptance.md"
  @milestone_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/README.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-c-phase-05-receipt.md"
  @authorized_baseline "2542e9ceed021d42dbbde6cdc9eb9e9613c8546f"
  @predecessor_candidate "4532ff304816ad0a229192f0e0bc0f9a3abb66da"
  @implementation_pr 125
  @implementation_head "c63e77b2c1b489c2427d1b67590439ce2f369d77"
  @merged_candidate "5987a7a4a43505b035f5a566588d5201e98686f7"
  @merge_date "2026-09-06"
  @clean_checkout_jobs %{
    "verify" => %{"id" => 101_476_448_118, "duration" => "22m29s", "result" => "pass"},
    "dialyzer" => %{"id" => 101_473_993_080, "duration" => "1m51s", "result" => "pass"}
  }
  @sections ~w[5.1 5.2 5.3 5.4]
  @section_commits %{
    "5.1" => "18d9c7f9dbcc6045ed3815fcc7a297960f21bbbd",
    "5.2" => "024de7793dbdbd5c4d9ec986ad958c72126a836b",
    "5.3" => "635bfb4f7454bdac284f7eb6320dc179de605680"
  }
  @profiles ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @states ~w[ready empty stale incomplete contradicted truncated unauthorized unavailable maintenance recovery]
  @surfaces ~w[factory fleet projects project project_attempts project_wiki project_dependencies attempt]
  @results ~w[
    identity_session_scope_and_revocation
    routes_navigation_and_projection_states
    cross_scope_idor_and_inference
    hostile_content_privacy_cache_and_telemetry
    large_fleet_parallel_users_and_tabs
    adapter_outage_restart_and_unconfigured_capabilities
    real_identity_store_and_triple_store
    production_assets_proxy_and_tls
    native_supported_browser_matrix
    named_assistive_technology
    accessibility_and_responsive_matrix
    semantic_effect_free_reads
    architecture_boundary
    strict_production_compile
    repository_precommit
  ]
  @invariants ~w[
    named_identity_and_exact_scope_are_server_constructed
    unknown_and_unauthorized_resources_are_indistinguishable
    route_query_row_field_and_destination_authorization_repeat
    projection_queries_are_reviewed_versioned_bounded_and_effect_free
    protected_states_clear_prior_rows_and_cache_entries
    protected_responses_are_private_no_store_and_safe_to_observe
    native_links_forms_filters_pagination_retry_and_sign_out_work_without_javascript
    stable_roots_focus_targets_states_and_identity_remain_frozen
    unsupported_capabilities_have_no_decorative_or_effectful_controls
    wcag_browser_touch_reflow_rtl_forced_color_motion_print_and_at_matrix_passes
    real_adapter_posture_and_operational_thresholds_are_reproducible
    milestone_d_may_enhance_only_the_accepted_fragment_candidates
  ]
  @required_sources ~w[
    docs/architecture/hypermedia-ui-milestone-c-native-shell-baseline.md
    docs/architecture/hypermedia-ui-milestone-c-phase-05-receipt.md
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    priv/architecture/hypermedia_ui/phase_c5_accessibility_evidence.json
    priv/architecture/hypermedia_ui/phase_c5_operations_evidence.json
    priv/architecture/hypermedia_ui/phase_c5_product_baseline.json
    scripts/qualify_hui_c5_orca.sh
    test/accessibility/hypermedia_ui_phase_c5_orca.mjs
    test/browser/hypermedia_ui_phase_c5.spec.mjs
    test/jido_code/product/read_only_shell_operations_phase_c5_test.exs
    test/jido_code_web/controllers/read_only_shell_privacy_phase_c5_test.exs
  ]
  @allowed_prefixes ~w[
    docs/architecture/hypermedia-ui-milestone-c-native-shell-baseline.md
    docs/architecture/hypermedia-ui-milestone-c-phase-05-receipt.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/README.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-05-
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/mix/tasks/architecture.check.ex
    priv/architecture/hypermedia_ui/phase_c5_
    scripts/qualify_hui_c5_orca.sh
    test/accessibility/hypermedia_ui_phase_c5_orca.mjs
    test/browser/hypermedia_ui_phase_c5.spec.mjs
    test/jido_code/architecture/hypermedia_ui_phase_c5_
    test/jido_code/product/read_only_shell_operations_phase_c5_test.exs
    test/jido_code_web/controllers/read_only_shell_privacy_phase_c5_test.exs
  ]

  def check(root \\ File.cwd!()) do
    with {:ok, evidence} <- load(root) do
      case validate(evidence, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  def load(root \\ File.cwd!()) do
    path = Path.join(root, @manifest_path)

    with {:ok, body} <- File.read(path), {:ok, evidence} <- Jason.decode(body) do
      {:ok, evidence}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable evidence: #{inspect(reason)}"]}
    end
  end

  def validate(evidence, root) when is_map(evidence) do
    accessibility = load_json(root, @accessibility_path)
    operations = load_json(root, @operations_path)
    baseline = load_json(root, @baseline_path)
    integration = evidence["integration"] || %{}

    []
    |> equal(evidence["schema_version"], 1, "schema version")
    |> equal(evidence["phase"], "HUI-C5", "phase")
    |> member(
      evidence["status"],
      ~w[integration_candidate_merge_pending accepted_at_merged_candidate],
      "lifecycle status"
    )
    |> equal(evidence["baseline_commit"], @authorized_baseline, "authorized baseline")
    |> equal(evidence["predecessor_candidate"], @predecessor_candidate, "HUI-C4 candidate")
    |> equal(evidence["completed_sections"], @sections, "completed section order")
    |> equal(evidence["section_commits"] || %{}, @section_commits, "section commits")
    |> equal(MapSet.new(evidence["invariants"] || []), MapSet.new(@invariants), "invariants")
    |> validate_accessibility(accessibility)
    |> validate_operations(operations)
    |> validate_baseline(baseline, evidence["status"])
    |> equal(
      MapSet.new(integration["browser_profiles"] || []),
      MapSet.new(@profiles),
      "browser profiles"
    )
    |> equal(
      MapSet.new(Map.keys(integration["results"] || %{})),
      MapSet.new(@results),
      "integration result catalog"
    )
    |> all_pass(integration["results"] || %{})
    |> positive(integration["focused_tests"], "focused test count")
    |> positive(integration["precommit_tests"], "precommit test count")
    |> equal(integration["browser_applicable_passes"], 84, "browser applicable passes")
    |> equal(integration["browser_deliberate_skips"], 91, "browser deliberate skips")
    |> equal(integration["browser_failures"], 0, "browser failures")
    |> lifecycle(evidence, root)
    |> validate_sources(evidence["source_digests"], root)
    |> validate_boundaries(root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["HUI-C5 evidence must be a map"]

  defp validate_accessibility(errors, accessibility) do
    coverage = accessibility["coverage"] || %{}
    at_profiles = accessibility["assistive_technology_profiles"] || []

    errors
    |> equal(accessibility["target"], "WCAG 2.2 AA", "accessibility target")
    |> equal(
      Enum.map(accessibility["browser_profiles"] || [], & &1["name"]),
      @profiles,
      "accessibility browser profiles"
    )
    |> equal(length(at_profiles), 1, "named assistive-technology profiles")
    |> equal(get_in(at_profiles, [Access.at(0), "name"]), "Orca", "named assistive technology")
    |> equal(get_in(at_profiles, [Access.at(0), "result"]), "pass", "assistive technology result")
    |> all_pass(coverage)
    |> positive(length(accessibility["reopening_conditions"] || []), "accessibility reopenings")
  end

  defp validate_operations(errors, operations) do
    thresholds = operations["thresholds"] || %{}

    errors
    |> equal(thresholds["candidate_limit"], 100, "candidate limit")
    |> equal(thresholds["scan_limit"], 24, "scan limit")
    |> equal(thresholds["page_rows"], 20, "page rows")
    |> equal(thresholds["queries_per_factory_surface"], 121, "factory query fanout")
    |> equal(thresholds["surface_timeout_ms"], 5_500, "surface timeout")
    |> equal(thresholds["parallel_users"], 8, "parallel users")
    |> equal(thresholds["tabs_per_user"], 4, "tabs per user")
    |> equal(thresholds["cache_entries"], 512, "cache entries")
    |> all_pass(operations["failure_matrix"] || %{})
    |> all_pass(operations["privacy_matrix"] || %{})
    |> equal(
      get_in(operations, ["adapter_posture", "graph_authority", "result"]),
      "pass_unavailable",
      "graph authority posture"
    )
    |> equal(
      get_in(operations, ["adapter_posture", "triple_store", "result"]),
      "pass",
      "TripleStore adapter"
    )
    |> positive(length(operations["reopening_conditions"] || []), "operations reopenings")
  end

  defp validate_baseline(errors, baseline, status) do
    expected_status =
      if status == "accepted_at_merged_candidate",
        do: "accepted_at_merged_candidate",
        else: "fragment_candidate_merge_pending"

    errors
    |> equal(baseline["gate"], "HUI3", "product baseline gate")
    |> equal(baseline["status"], expected_status, "product baseline lifecycle")
    |> equal(length(baseline["routes"] || []), 27, "accepted route count")
    |> equal(
      Enum.map(baseline["projection_candidates"] || [], & &1["surface"]),
      @surfaces,
      "projection candidate surfaces"
    )
    |> equal(baseline["state_envelope"], @states, "state envelope")
    |> equal(length(baseline["enhancement_prohibitions"] || []), 7, "enhancement prohibitions")
    |> equal(length(baseline["reopening_conditions"] || []), 5, "baseline reopenings")
  end

  defp lifecycle(errors, %{"status" => "integration_candidate_merge_pending"} = evidence, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)
    milestone = read(root, @milestone_path)

    errors
    |> equal(evidence["receipt_status"], "merge_pending", "receipt status")
    |> equal(evidence["clean_checkout_ci"], "pending", "clean-checkout CI")
    |> equal(evidence["implementation_pr"], nil, "implementation PR")
    |> equal(evidence["implementation_pr_head"], nil, "implementation PR head")
    |> equal(evidence["merged_candidate"], nil, "merged candidate")
    |> equal(evidence["merge_date"], nil, "merge date")
    |> equal(evidence["clean_checkout_jobs"], nil, "clean-checkout jobs")
    |> require_match(receipt, ~r/Status: \*\*merge-pending\*\*/, "pending receipt")
    |> require_contains(receipt, "Merged candidate: `merge-pending`", "pending candidate")
    |> require_contains(plan, "status: proposed", "pending phase status")
    |> require_match(plan, ~r/- \[ \] 5 Phase/, "pending phase checkbox")
    |> require_match(plan, ~r/- \[ \] 5\.4 Section/, "pending integration checkbox")
    |> require_contains(milestone, "status: proposed", "pending milestone status")
  end

  defp lifecycle(errors, %{"status" => "accepted_at_merged_candidate"} = evidence, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)
    milestone = read(root, @milestone_path)

    errors
    |> equal(evidence["receipt_status"], "accepted_at_merged_candidate", "receipt status")
    |> equal(evidence["clean_checkout_ci"], "pass", "clean-checkout CI")
    |> equal(evidence["implementation_pr"], @implementation_pr, "implementation PR")
    |> equal(evidence["implementation_pr_head"], @implementation_head, "implementation PR head")
    |> equal(evidence["merged_candidate"], @merged_candidate, "merged candidate")
    |> equal(evidence["merge_date"], @merge_date, "merge date")
    |> equal(evidence["clean_checkout_jobs"], @clean_checkout_jobs, "clean-checkout jobs")
    |> require_match(
      receipt,
      ~r/Status: \*\*accepted-at-merged-candidate\*\*/,
      "accepted receipt"
    )
    |> require_contains(receipt, evidence["merged_candidate"], "receipt candidate")
    |> forbid(
      String.contains?(receipt, "merge-pending"),
      "accepted receipt remains merge-pending"
    )
    |> require_contains(plan, "status: completed", "completed phase status")
    |> require_match(plan, ~r/- \[x\] 5 Phase/, "accepted phase checkbox")
    |> require_match(plan, ~r/- \[x\] 5\.4 Section/, "accepted integration checkbox")
    |> require_match(plan, ~r/- \[x\] 5\.4\.2 Task/, "accepted receipt task checkbox")
    |> require_match(plan, ~r/- \[x\] 5\.4\.2\.3 Subtask/, "accepted pin checkbox")
    |> require_contains(milestone, "status: completed", "completed milestone status")
  end

  defp lifecycle(errors, _evidence, _root), do: ["unsupported receipt lifecycle" | errors]

  defp validate_sources(errors, sources, root) when is_map(sources) and map_size(sources) > 0 do
    errors =
      Enum.reduce(@required_sources, errors, fn path, acc ->
        if Map.has_key?(sources, path),
          do: acc,
          else: ["required source digest missing for #{path}" | acc]
      end)

    Enum.reduce(sources, errors, fn {path, expected}, acc ->
      cond do
        not Enum.any?(@allowed_prefixes, &String.starts_with?(path, &1)) ->
          ["unauthorized HUI-C5 source path #{path}" | acc]

        not full_digest?(expected) ->
          ["invalid source digest for #{path}" | acc]

        true ->
          case File.read(Path.join(root, path)) do
            {:ok, body} ->
              current = sha256(body)
              successor = JidoCode.Architecture.HypermediaUISuccessorEvidence

              if (successor.phase_d1_mutable_path?(path) or successor.phase_d2_mutable_path?(path)) and
                   successor.digest(root, path) == current,
                 do: acc,
                 else: equal(acc, current, expected, "source digest #{path}")

            {:error, reason} ->
              ["#{path}: unavailable source: #{inspect(reason)}" | acc]
          end
      end
    end)
  end

  defp validate_sources(errors, _sources, _root), do: ["source digests are empty" | errors]

  defp validate_boundaries(errors, root) do
    router = read(root, "lib/jido_code_web/router.ex")
    controller = read(root, "lib/jido_code_web/product_controller.ex")

    templates =
      Path.wildcard(Path.join(root, "lib/jido_code_web/controllers/**/*.{ex,heex}"))
      |> Enum.map_join("\n", &read_absolute/1)

    errors
    |> forbid(
      Regex.match?(~r/\b(?:live|live_session)\s+"\/(?:factory|projects)/, router),
      "product LiveView route"
    )
    |> forbid(String.contains?(controller, "TripleStore"), "controller raw store access")
    |> forbid(String.contains?(controller, "CommandGateway"), "controller command access")
    |> forbid(String.contains?(templates, "<script"), "controller template inline script")
    |> forbid(
      Regex.match?(~r/\son[a-z]+\s*=/i, templates),
      "controller template event handler"
    )
    |> forbid(String.contains?(templates, "dstar-"), "controller template Datastar behavior")
  end

  defp load_json(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, value} when is_map(value) -> value
          _invalid -> %{}
        end

      _unavailable ->
        %{}
    end
  end

  defp all_pass(errors, results) when is_map(results) do
    if map_size(results) > 0 and Enum.all?(results, fn {_key, value} -> value == "pass" end),
      do: errors,
      else: ["evidence results are not all pass" | errors]
  end

  defp all_pass(errors, _results), do: ["evidence results are not a map" | errors]

  defp positive(errors, value, _label) when is_integer(value) and value > 0, do: errors

  defp positive(errors, value, label),
    do: ["#{label}: expected positive integer, got #{inspect(value)}" | errors]

  defp equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp member(errors, actual, values, label) do
    if actual in values, do: errors, else: ["#{label}: unexpected #{inspect(actual)}" | errors]
  end

  defp forbid(errors, condition, message) when is_boolean(condition) do
    if condition, do: [message | errors], else: errors
  end

  defp require_match(errors, body, pattern, label) do
    if Regex.match?(pattern, body), do: errors, else: ["#{label} is missing" | errors]
  end

  defp require_contains(errors, body, value, label) do
    if is_binary(value) and String.contains?(body, value),
      do: errors,
      else: ["#{label} is missing" | errors]
  end

  defp full_digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp sha256(body), do: body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, _reason} -> ""
    end
  end

  defp read_absolute(path) do
    case File.read(path) do
      {:ok, body} -> body
      {:error, _reason} -> ""
    end
  end
end

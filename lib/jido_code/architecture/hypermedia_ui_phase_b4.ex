defmodule JidoCode.Architecture.HypermediaUIPhaseB4 do
  @moduledoc false

  alias JidoCode.Architecture.HypermediaUIPhaseB1
  alias JidoCode.Architecture.HypermediaUIPhaseB2
  alias JidoCode.Architecture.HypermediaUIPhaseB3
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  @manifest_path "priv/architecture/hypermedia_ui/phase_b4_fitness_policy.json"
  @qualification_path "priv/architecture/hypermedia_ui/phase_b4_qualification_evidence.json"
  @consumption_path "priv/architecture/hypermedia_ui/phase_b4_consumption_baseline.json"
  @integration_path "priv/architecture/hypermedia_ui/phase_b4_integration_evidence.json"
  @baseline "e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2"
  @document_path "docs/architecture/hypermedia-ui-dependency-fitness-and-update-policy.md"
  @consumption_document "docs/architecture/hypermedia-ui-product-consumption-baseline.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-04-receipt.md"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-04-dependency-consumer-and-architecture-qualification.md"
  @milestone_plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/README.md"
  @implementation_pr_head "67292e3e82b695731bd80da9eab1891aa143697a"
  @merged_candidate "63d2689321121775a46bf531d004ac4de44b81f2"
  @manifest_digests %{
    "priv/architecture/hypermedia_ui/phase_b1_candidate_bom.json" =>
      "dbfb08bfa5a95d41a538dadbcd8f9605918761a565e82ae075854c969a6f7f12",
    "priv/architecture/hypermedia_ui/phase_b1_supply_chain_ledger.json" =>
      "7e8c4286ebd125f0c1b8a8997abba699c82f0f583b5f518d0b6a7eeba9d9cfe6",
    "priv/architecture/hypermedia_ui/phase_b2_dependency_graph.json" =>
      "e35613aa0d39af166aa4156e284a0eeab6a68c720b8d186198b5ed0472fe622a",
    "priv/architecture/hypermedia_ui/phase_b2_resolved_sbom.json" =>
      "7a0b9e4ed1b4e187d464dae39de8e593978d9fa81a8b396619d848e14c697f68",
    "priv/architecture/hypermedia_ui/phase_b2_asset_pipeline.json" =>
      "de73f1008e64693583201b02b3fae50fd2c563d2fe38d61941a4a4b49806007a",
    "priv/architecture/hypermedia_ui/phase_b2_component_theme_contract.json" =>
      "381aa3d8c2b36113c97abf3df192a1614c04e9b40dd7720ae3a8636f884b46d4",
    "priv/architecture/hypermedia_ui/phase_b3_verification_evidence.json" =>
      "9acba10084866ab7d800c02b9fded59406b0370bffdad83dc973416f2a656344"
  }
  @candidate_inputs %{
    "mix.exs" => "d66c00f068f43943ed9bd94b0a2c77db152a224ad3e1d6deefee4745df3ffab9",
    "mix.lock" => "98b302693e9dbf826129aec7bdb85740201fb076096d253d10e4f7ba1660e10b",
    "package.json" => "d41b1362235934cf2f37a87351f1610325e27945660b636619b3f49a2fdc51ba",
    "package-lock.json" => "8a4b2384bdaf539731dd7eefa169cacaea38bcf689c2a59108ff6de5456addda",
    "assets/vendor/datastar/datastar.js" =>
      "5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65",
    "deps/shadcn_ui/priv/static/shadcn_ui.css" =>
      "ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41"
  }
  @hex_pins %{
    "dstar" => "0.2.0",
    "phoenix" => "1.8.11",
    "phoenix_html" => "4.3.0",
    "phoenix_live_view" => "1.2.9",
    "salad_ui" => "1.0.0"
  }
  @source_pins %{
    "shadcn_ui" => "fe40eae63504adc4375aead4f0e741f158a4d86e",
    "datastar" => "73ab00e7c06d8c2bad030fdddafba800fcccbde2"
  }
  @npm_pins %{
    "@playwright/test" => "1.62.0",
    "@tailwindcss/vite" => "4.3.3",
    "tailwindcss" => "4.3.3",
    "vite" => "7.3.6"
  }
  @forbidden ~w[
    mutable_hui_source remote_or_cdn_product_asset unreviewed_hui_override_or_fork
    unexpected_hui_transitive_application shadcn_import_outside_facade
    new_liveview_product_runtime new_livevue_or_vue_consumer new_saladui_consumer
    dstar_scripts inline_or_eval_csp_weakening browser_authority
    unapproved_network_or_build_step
  ]
  @update_evidence ~w[
    immutable_provenance license_and_usage_authority advisory_scan
    dependency_and_consumer_diff browser_protocol_matrix manual_accessibility_review
    release_and_rollback_drill
  ]
  @evidence_classes ~w[
    unit integration browser accessibility security_privacy usability load_capacity
    fault_injection real_adapter install upgrade rollback observation
  ]
  @browser_profiles ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @primitives ~w[button field_input link badge table disclosure dialog status]
  @accessibility_checks ~w[
    landmarks_names_labels visible_keyboard_focus native_disclosure_semantics
    dialog_modal_tree_initial_focus_escape_and_return
    table_caption_headers_and_bounded_overflow status_live_region
    light_and_dark_visual_contrast 320px_reflow
    patch_focus_selection_and_overlay_continuity
    reduced_motion_forced_colors_rtl_zoom_touch
  ]
  @qualification_source_digests %{
    "playwright.config.mjs" => "2830390b5277b8893e37cb4edc3583bbd6be8bd38be31feefd99eac4256b54b9",
    "test/browser/hypermedia_ui_phase_b3.spec.mjs" =>
      "2689d7b6216ff27e370d0d2939ca3ae80f745096d8ee04cff47a3f98a6063769",
    "test/browser/support/streaming_proxy.mjs" =>
      "a50f24a27aafdcc48a0e26d8e7436003caf1c0081a57341bb0f3f839e9a3be12",
    "test/browser/support/http2_streaming_proxy.mjs" =>
      "78e56e333b5b82c360240dcb1c4d29e11f1842bc2a34ff231a3c5ad41d01038e",
    "test/browser/support/hui-b4-local.crt" =>
      "f0458f35e0e0538bcae12bf5031d2d011fa7398390bd128e6238abb89dc02967",
    "test/browser/support/hui-b4-local.key" =>
      "47dbe13e8f870b222b9f8f610a9e5ef9b6c00bb7277916e0a09d5fcfe66afb28"
  }
  @qualification_document "docs/architecture/hypermedia-ui-release-qualification-evidence.md"
  @approved_attributes [
    "data-signals:*",
    "data-bind:*",
    "data-on:click__prevent",
    "data-attr:*",
    "data-indicator:*",
    "data-text"
  ]
  @dstar_functions ["start/1", "patch_elements/3", "patch_signals/3", "SSE.send_event!/3"]
  @browsers ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @composite_gaps [
    "FactoryShell",
    "ProjectContextSwitcher",
    "AttentionQueue",
    "ProjectionStatusStrip",
    "AgentFleetTable",
    "AgentAttemptWorkspace",
    "StageRail",
    "AttemptTimeline",
    "CodeDiff",
    "artifact manifest",
    "EvidenceMatrix",
    "ScopedCommandDialog",
    "CommandReceipt",
    "GraphLens accessible table/outline",
    "ProvenancePanel",
    "CostBudgetMeter"
  ]
  @failure_modes ~w[
    missing_or_stale_client_asset_uses_native_recovery
    malformed_or_unsupported_signal_fails_closed
    missing_csrf_or_cross_origin_write_fails_closed
    duplicate_or_excess_stream_fails_without_queue
    offline_or_interrupted_stream_uses_bounded_retry_then_native_recovery
    terminal_close_suppresses_reconnect
    authority_or_revision_from_browser_is_rejected
  ]
  @production_source_digests %{
    "assets/js/app.js" => "5f3451073941a412f73af51f3808b9530cbed20e8b83776c05c99ab4a4f65d4d",
    "assets/css/app.css" => "3920d1b157fea16475fda56ca07d463e6238c26e8b987485b9460f261c68ef58",
    "config/config.exs" => "1594d1d5ea7d4e4ce4a3b0d59d7b5434341d366fb07eb5b1d4589b6ac07e6ec8",
    "config/test.exs" => "1c4b20594a89cefd1afe13c9794b07709ca3e5c8ba6bcccff0abe1cf6061ddcc",
    "lib/jido_code/application.ex" =>
      "a35d349d390a9141621dbb9870e2c4f51235851f917313e391fcd90cfd412732",
    "lib/jido_code_web/router.ex" =>
      "59fb75843158676505bb59270867d662ea232c5ce3450470c30e3c315ae6a83f",
    "lib/jido_code_web/controllers/qualification/hypermedia_controller.ex" =>
      "7cb2e7f09287ae566b247afb3beef286b17ab09febd6f6799fa98c40eab2b5a7",
    "lib/jido_code_web/controllers/qualification/hypermedia_html/index.html.heex" =>
      "327d388b227b523db327caa081bb1d982e6d0fe9b35bceb39941e6ab4d053de3",
    "lib/mix/tasks/hui.b4.production_boundary.ex" =>
      "661beca76f26491eee18ba8811d341336b438b8c7dce99fc8cadc68a3d95f4b0",
    "lib/jido_code_web/components/ui.ex" =>
      "c6a537da7828a9357e15c0e72a9ba3196429c7e23a31dd76ac303dc17b5528e5",
    "priv/architecture/hypermedia_ui/phase_a4_governance_guardrails.json" =>
      "7ba9c927f4e86aa411960cde57c8f5d5acaf23514139b96c5e1e1942a5e5095d"
  }
  @section_commits %{
    "4.1" => "ab2d29065259d4e9a2f720abeffc3672f235f3e3",
    "4.2" => "0ea83345a3be68993e640c7bfb6a5ab01ef30844",
    "4.3" => "96badb46f1d2f19a8443363980cc88615d8e78e5"
  }
  @integration_manifest_digests %{
    "priv/architecture/hypermedia_ui/phase_b4_fitness_policy.json" =>
      "41669e19b59e89d317a2e89afda755e8eb80cae8393a41f0c814605134f84282",
    "priv/architecture/hypermedia_ui/phase_b4_qualification_evidence.json" =>
      "546339e6a20ea6ddf5a36b1aed01d8fd410f4457e30da925a323548c7ef6e2d1",
    "priv/architecture/hypermedia_ui/phase_b4_consumption_baseline.json" =>
      "2600f2127e2dc730fff4f93642302a9e86b591d19dfd7542db69b16c71d288bd"
  }
  @accepted_manifest_digests %{
    "priv/architecture/hypermedia_ui/phase_b4_fitness_policy.json" =>
      "41669e19b59e89d317a2e89afda755e8eb80cae8393a41f0c814605134f84282",
    "priv/architecture/hypermedia_ui/phase_b4_qualification_evidence.json" =>
      "546339e6a20ea6ddf5a36b1aed01d8fd410f4457e30da925a323548c7ef6e2d1",
    "priv/architecture/hypermedia_ui/phase_b4_consumption_baseline.json" =>
      "68948117ff1a6b2008d95fc8ac13b272a98e97dc00a5408c760b8c1eb8fe4ce6"
  }
  @reproduction_ids ~w[
    locked_mix_acquisition locked_npm_acquisition predecessor_and_architecture
    strict_production_compile static_analysis production_assets sbom_license_advisory release_startup
    browser_proxy_accessibility production_fixture_exclusion rollback_identity full_precommit
  ]
  @mutation_ids ~w[
    hex_version source_version npm_version manifest_or_source_digest license shadcn_import
    datastar_asset dstar_scripts inline_or_eval_csp remote_product_asset browser_authority
    new_liveview_runtime new_livevue_runtime new_saladui_consumer production_qualification_route
    production_qualification_supervision operational_ceiling attribute_or_event browser_profile
    residual_risk receipt_lifecycle
  ]
  @rollback_paths ~w[
    mix.exs mix.lock package.json package-lock.json assets/vendor/datastar/datastar.js
    deps/shadcn_ui/priv/static/shadcn_ui.css lib/jido_code_web/components/ui.ex
    assets/js/app.js assets/css/app.css
  ]

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    predecessor_errors =
      [HypermediaUIPhaseB1, HypermediaUIPhaseB2, HypermediaUIPhaseB3]
      |> Enum.flat_map(fn module -> module.check(root) |> errors() end)

    with {:ok, policy} <- load(root),
         {:ok, qualification} <- load_qualification(root),
         {:ok, consumption} <- load_consumption(root),
         {:ok, integration} <- load_integration(root) do
      case predecessor_errors ++
             validate(policy, root) ++
             validate_qualification(qualification, root) ++
             validate_consumption(consumption, root) ++
             validate_integration(integration, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  @spec load_integration(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load_integration(root \\ File.cwd!()) do
    path = Path.join(root, @integration_path)

    with {:ok, body} <- File.read(path),
         {:ok, evidence} <- Jason.decode(body) do
      {:ok, evidence}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable integration evidence: #{inspect(reason)}"]}
    end
  end

  @spec load_consumption(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load_consumption(root \\ File.cwd!()) do
    path = Path.join(root, @consumption_path)

    with {:ok, body} <- File.read(path),
         {:ok, baseline} <- Jason.decode(body) do
      {:ok, baseline}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable baseline: #{inspect(reason)}"]}
    end
  end

  @spec load_qualification(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load_qualification(root \\ File.cwd!()) do
    path = Path.join(root, @qualification_path)

    with {:ok, body} <- File.read(path),
         {:ok, evidence} <- Jason.decode(body) do
      {:ok, evidence}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable evidence: #{inspect(reason)}"]}
    end
  end

  @spec load(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    path = Path.join(root, @manifest_path)

    with {:ok, body} <- File.read(path),
         {:ok, policy} <- Jason.decode(body) do
      {:ok, policy}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable policy: #{inspect(reason)}"]}
    end
  end

  @spec validate(map(), Path.t()) :: [String.t()]
  def validate(policy, root) when is_map(policy) do
    stack = policy["approved_stack"] || %{}
    consumers = policy["approved_consumers"] || %{}

    []
    |> require_equal(policy["schema_version"], 1, "schema_version")
    |> require_equal(policy["phase"], "HUI-B4", "phase")
    |> require_equal(policy["status"], "fitness_policy_installed", "policy status")
    |> require_equal(policy["baseline_commit"], @baseline, "baseline")
    |> require_equal(policy["input_manifest_digests"], @manifest_digests, "manifest pins")
    |> require_equal(policy["candidate_inputs"], @candidate_inputs, "candidate pins")
    |> require_equal(stack["hex"], @hex_pins, "Hex pins")
    |> require_equal(stack["source"], @source_pins, "source pins")
    |> require_equal(stack["npm"], @npm_pins, "npm pins")
    |> require_exact_set(stack["licenses"] || [], ~w[Apache-2.0 MIT], "license allowlist")
    |> require_equal(consumers["product_consumers"], [], "product consumer boundary")
    |> require_exact_set(policy["forbidden_capabilities"] || [], @forbidden, "forbidden rules")
    |> require_exact_set(policy["update_evidence"] || [], @update_evidence, "update evidence")
    |> require_equal(policy["exceptions"], [], "fitness exceptions")
    |> validate_digests(root, @manifest_digests)
    |> validate_digests(root, @candidate_inputs)
    |> validate_current_sources(root)
    |> validate_document(root)
    |> Enum.reverse()
  end

  def validate(_policy, _root), do: ["HUI-B4 fitness policy must be a map"]

  @spec validate_qualification(map(), Path.t()) :: [String.t()]
  def validate_qualification(evidence, root) when is_map(evidence) do
    classes = evidence["evidence_classes"] || []
    upstream = evidence["upstream"] || %{}
    application = evidence["application"] || %{}
    browser = evidence["browser"] || %{}
    accessibility = evidence["manual_accessibility"] || %{}
    build = evidence["reproducible_build"] || %{}
    release = evidence["release"] || %{}
    risks = evidence["residual_risks"] || []

    []
    |> require_equal(evidence["schema_version"], 1, "qualification schema_version")
    |> require_equal(evidence["phase"], "HUI-B4", "qualification phase")
    |> require_equal(
      evidence["status"],
      "qualification_evidence_complete",
      "qualification status"
    )
    |> require_equal(evidence["baseline_commit"], @baseline, "qualification baseline")
    |> require_exact_set(Enum.map(classes, & &1["id"]), @evidence_classes, "evidence classes")
    |> require_equal(
      Enum.all?(classes, &String.starts_with?(&1["status"], "pass")),
      true,
      "evidence class outcomes"
    )
    |> require_equal(
      get_in(upstream, ["shadcn_ui", "result"]),
      "420 tests, 0 failures",
      "ShadcnUI upstream suite"
    )
    |> require_contains(
      get_in(upstream, ["dstar", "result"]),
      "no tests to run",
      "Dstar upstream limitation"
    )
    |> require_equal(application["strict_compile"], "pass", "strict compile")
    |> require_contains(application["static_analysis"], "0 unignored errors", "Dialyzer result")
    |> require_equal(application["hex_advisories"], "0", "Hex advisory result")
    |> require_equal(application["npm_production_advisories"], "0", "npm advisory result")
    |> require_exact_set(browser["profiles"] || [], @browser_profiles, "browser profiles")
    |> require_equal(browser["applicable_passed"], 21, "browser passed count")
    |> require_equal(browser["profile_skips"], 39, "browser skip count")
    |> require_equal(browser["production_assets"], true, "production browser assets")
    |> require_equal(browser["csp_enforcing"], true, "browser CSP")
    |> require_equal(
      browser["http2_tls_reverse_proxy_unbuffered_sse"],
      "pass",
      "HTTP/2 proxy"
    )
    |> require_exact_set(accessibility["primitives"] || [], @primitives, "reviewed primitives")
    |> require_exact_set(
      Enum.map(accessibility["checks"] || [], & &1["id"]),
      @accessibility_checks,
      "accessibility checks"
    )
    |> require_equal(
      Enum.all?(accessibility["checks"] || [], &String.starts_with?(&1["status"], "pass")),
      true,
      "accessibility outcomes"
    )
    |> require_contains(
      accessibility["named_screen_reader_speech_output"],
      "not_claimed",
      "screen-reader residual risk"
    )
    |> require_equal(build["runs"], 2, "reproducible build runs")
    |> require_equal(build["equal"], true, "reproducible build equality")
    |> require_equal(
      build["static_tree_sha256"],
      "2f360d1cd037f8c86ef38bf484da68e4c29d2d59b24672d85ca997d4110f6347",
      "static tree digest"
    )
    |> require_equal(release["assembly"], "pass", "release assembly")
    |> require_equal(release["clean_store_startup_runs"], 2, "release startup runs")
    |> require_equal(release["graceful_stop"], "pass", "release stop")
    |> require_equal(release["qualification_route_release_credit"], false, "route release credit")
    |> require_equal(evidence["source_digests"], @qualification_source_digests, "source digests")
    |> require_equal(evidence["patches_or_forks"], [], "patch and fork record")
    |> require_equal(evidence["upstream_reports"], [], "upstream report record")
    |> require_equal(length(risks), 5, "residual risk count")
    |> validate_residual_risks(risks)
    |> require_equal(evidence["exceptions"], [], "qualification exceptions")
    |> validate_digests(root, @qualification_source_digests)
    |> validate_browser_sources(root)
    |> validate_qualification_document(root)
    |> Enum.reverse()
  end

  def validate_qualification(_evidence, _root),
    do: ["HUI-B4 qualification evidence must be a map"]

  @spec validate_consumption(map(), Path.t()) :: [String.t()]
  def validate_consumption(baseline, root) when is_map(baseline) do
    imports = baseline["approved_imports"] || %{}
    assets = baseline["asset_contract"] || %{}
    production = baseline["production_boundary"] || %{}
    profiles = baseline["supported_profiles"] || %{}
    ceilings = baseline["operational_ceilings"] || %{}

    []
    |> require_equal(baseline["schema_version"], 1, "consumption schema_version")
    |> require_equal(baseline["phase"], "HUI-B4", "consumption phase")
    |> require_member(
      baseline["status"],
      ["merge_pending_consumption_baseline", "accepted_at_merged_candidate"],
      "consumption status"
    )
    |> require_equal(baseline["baseline_commit"], @baseline, "consumption baseline")
    |> validate_consumption_provenance(baseline)
    |> require_equal(imports["heex_facade"], "JidoCodeWeb.Components.UI", "HEEx facade")
    |> require_exact_set(
      imports["shadcn_ui"] || [],
      [
        "lib/jido_code_web/components/ui.ex",
        "assets/css/app.css"
      ],
      "ShadcnUI import boundary"
    )
    |> require_equal(imports["datastar"], ["assets/js/app.js"], "Datastar import boundary")
    |> require_exact_set(
      imports["dstar_product_boundary"] || [],
      ["explicit Phoenix controller", "application-owned bounded SSE adapter"],
      "Dstar product boundary"
    )
    |> require_exact_set(imports["dstar_functions"] || [], @dstar_functions, "Dstar functions")
    |> require_exact_set(
      baseline["approved_primitives"] || [],
      @primitives,
      "approved primitives"
    )
    |> require_exact_set(
      baseline["approved_datastar_attributes"] || [],
      @approved_attributes,
      "Datastar attributes"
    )
    |> require_exact_set(baseline["approved_events"] || [], ~w[get post], "approved events")
    |> require_equal(assets["datastar_version"], "1.0.3", "Datastar version")
    |> require_equal(
      assets["datastar_bundle_sha256"],
      @candidate_inputs["assets/vendor/datastar/datastar.js"],
      "Datastar asset"
    )
    |> require_equal(
      assets["shadcn_ui_source_commit"],
      @source_pins["shadcn_ui"],
      "ShadcnUI source"
    )
    |> require_equal(
      assets["shadcn_ui_css_sha256"],
      @candidate_inputs["deps/shadcn_ui/priv/static/shadcn_ui.css"],
      "ShadcnUI CSS"
    )
    |> require_equal(
      assets["app_js_sha256"],
      @production_source_digests["assets/js/app.js"],
      "application JS"
    )
    |> require_equal(
      assets["app_css_sha256"],
      @production_source_digests["assets/css/app.css"],
      "application CSS"
    )
    |> require_equal(
      assets["ui_facade_sha256"],
      @production_source_digests["lib/jido_code_web/components/ui.ex"],
      "UI facade"
    )
    |> require_equal(production["qualification_build_default"], false, "production build default")
    |> require_equal(production["qualification_build_test"], true, "test build setting")
    |> require_equal(production["production_route_count"], 0, "production route count")
    |> require_equal(
      production["production_supervision_children"],
      0,
      "production supervision children"
    )
    |> require_equal(production["fixture_source_retained"], true, "fixture retention")
    |> require_equal(
      production["verification_command"],
      "MIX_ENV=prod mix hui.b4.production_boundary",
      "production verification command"
    )
    |> require_exact_set(profiles["browsers"] || [], @browsers, "supported browsers")
    |> require_contains(profiles["csp"], "no unsafe-inline", "CSP unsafe-inline boundary")
    |> require_contains(profiles["csp"], "unsafe-eval", "CSP unsafe-eval boundary")
    |> require_equal(ceilings["max_connections"], 4, "connection ceiling")
    |> require_equal(ceilings["max_connections_per_tab"], 1, "per-tab ceiling")
    |> require_equal(ceilings["max_events"], 8, "event ceiling")
    |> require_equal(ceilings["max_bytes"], 12_288, "byte ceiling")
    |> require_equal(ceilings["max_queue"], 0, "queue ceiling")
    |> require_equal(ceilings["max_lifetime_ms"], 1_200, "lifetime ceiling")
    |> require_equal(ceilings["retry_max_count"], 2, "retry count")
    |> require_equal(ceilings["retry_max_wait_ms"], 3_000, "retry wait")
    |> require_exact_set(baseline["known_failure_modes"] || [], @failure_modes, "failure modes")
    |> require_exact_set(
      baseline["milestone_c_composite_gaps"] || [],
      @composite_gaps,
      "Milestone C composite gaps"
    )
    |> require_contains(baseline["rollback"], "complete prior Mix/npm locks", "rollback")
    |> require_contains(baseline["upgrade"], "deterministic HUI-B4", "upgrade")
    |> require_equal(
      baseline["source_digests"],
      @production_source_digests,
      "production source pins"
    )
    |> require_equal(baseline["exceptions"], [], "consumption exceptions")
    |> validate_digests(root, @production_source_digests)
    |> validate_production_boundary_sources(root)
    |> validate_consumption_document(root)
    |> validate_closure_files(baseline, root)
    |> Enum.reverse()
  end

  def validate_consumption(_baseline, _root),
    do: ["HUI-B4 consumption baseline must be a map"]

  defp validate_consumption_provenance(
         errors,
         %{"status" => "accepted_at_merged_candidate"} = baseline
       ) do
    candidate = baseline["accepted_candidate"] || %{}

    errors
    |> require_equal(candidate["implementation_pr"], 115, "consumption implementation PR")
    |> require_equal(
      candidate["implementation_pr_head"],
      @implementation_pr_head,
      "consumption implementation head"
    )
    |> require_equal(candidate["merged_candidate"], @merged_candidate, "consumption candidate")
    |> require_equal(candidate["merge_date"], "2026-09-04", "consumption merge date")
  end

  defp validate_consumption_provenance(errors, _baseline), do: errors

  @spec validate_integration(map(), Path.t()) :: [String.t()]
  def validate_integration(evidence, root) when is_map(evidence) do
    reproductions = evidence["reproduction"] || []
    mutations = evidence["mutation_cases"] || []
    production = evidence["production_boundary"] || %{}
    rollback = evidence["rollback"] || %{}

    []
    |> require_equal(evidence["schema_version"], 1, "integration schema_version")
    |> require_equal(evidence["phase"], "HUI-B4", "integration phase")
    |> require_member(
      evidence["status"],
      ["integration_candidate_merge_pending", "accepted_at_merged_candidate"],
      "integration status"
    )
    |> require_equal(evidence["baseline_commit"], @baseline, "integration baseline")
    |> require_equal(evidence["section_commits"], @section_commits, "section provenance")
    |> require_equal(
      evidence["manifest_digests"],
      @integration_manifest_digests,
      "implementation manifest pins"
    )
    |> require_equal(
      evidence["accepted_manifest_digests"],
      @accepted_manifest_digests,
      "accepted manifest pins"
    )
    |> require_exact_set(Enum.map(reproductions, & &1["id"]), @reproduction_ids, "reproductions")
    |> require_equal(
      Enum.all?(reproductions, &String.starts_with?(&1["result"], "pass")),
      true,
      "reproduction outcomes"
    )
    |> require_equal(
      Enum.all?(reproductions, &nonempty_evidence?/1),
      true,
      "reproduction evidence"
    )
    |> require_exact_set(Enum.map(mutations, & &1["id"]), @mutation_ids, "mutation cases")
    |> require_equal(
      Enum.all?(mutations, &(&1["expected"] == "rejected")),
      true,
      "mutation outcomes"
    )
    |> require_equal(Enum.all?(mutations, &nonempty_diagnostic?/1), true, "mutation diagnostics")
    |> require_equal(production["compile_build"], "prod", "production compile build")
    |> require_equal(production["qualification_routes"], 0, "production qualification routes")
    |> require_equal(
      production["qualification_supervision_children"],
      0,
      "production qualification supervision"
    )
    |> require_equal(
      production["runtime_enable_attempt"],
      "remains_absent",
      "runtime enable attempt"
    )
    |> require_equal(production["liveview_product_additions"], 0, "LiveView product additions")
    |> require_equal(rollback["baseline"], @baseline, "rollback baseline")
    |> require_equal(rollback["dependency_and_asset_diff"], "empty", "rollback identity")
    |> require_exact_set(rollback["restoration_set"] || [], @rollback_paths, "rollback set")
    |> require_equal(rollback["data_migration"], false, "rollback data migration")
    |> require_member("mix deps.get", evidence["commands"] || [], "Mix acquisition command")
    |> require_member("npm ci", evidence["commands"] || [], "npm acquisition command")
    |> require_member(
      "mix dialyzer --no-compile --format dialyxir --list-unused-filters",
      evidence["commands"] || [],
      "Dialyzer command"
    )
    |> require_member("npx playwright test", evidence["commands"] || [], "browser command")
    |> require_member("mix precommit", evidence["commands"] || [], "precommit command")
    |> require_equal(evidence["exceptions"], [], "integration exceptions")
    |> validate_digests(root, @accepted_manifest_digests)
    |> validate_integration_closure(evidence, root)
    |> Enum.reverse()
  end

  def validate_integration(_evidence, _root),
    do: ["HUI-B4 integration evidence must be a map"]

  @spec check_candidate_sources([{String.t(), String.t()}]) :: [String.t()]
  def check_candidate_sources(sources) when is_list(sources) do
    Enum.flat_map(sources, fn {path, source} ->
      [
        {Regex.match?(~r/\bDstar\.Scripts\b/, source), "#{path}: Dstar Scripts is prohibited"},
        {Path.extname(path) == ".heex" and Regex.match?(~r/<script(?:\s|>)/i, source),
         "#{path}: inline scripts are prohibited"},
        {Regex.match?(~r/(?:unsafe-eval|unsafe-inline)/, source),
         "#{path}: unsafe CSP evaluation is prohibited"},
        {Regex.match?(
           ~r/(?:<(?:script|link)[^>]+(?:src|href)=[\"']https?:\/\/|@import\s+(?:url\()?['\"]?https?:\/\/)/i,
           source
         ), "#{path}: remote or CDN product assets are prohibited"},
        {Regex.match?(
           ~r/(?:localStorage|sessionStorage|signals?)[^\n]{0,160}(?:grant|authority|assurance|delegation|policy_revision|expected_revision)/i,
           source
         ), "#{path}: browser state cannot supply authority"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp validate_current_sources(errors, root) do
    sources =
      ["lib/jido_code_web/**/*.ex", "lib/jido_code_web/**/*.heex", "assets/js/**/*.js"]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.uniq()
      |> Enum.filter(&File.regular?/1)
      |> Enum.reject(&(Path.relative_to(&1, root) == "assets/vendor/datastar/datastar.js"))
      |> Enum.map(&{Path.relative_to(&1, root), File.read!(&1)})

    Enum.reverse(check_candidate_sources(sources)) ++ errors
  end

  defp validate_document(errors, root) do
    body = read(root, @document_path)

    errors
    |> require_contains(body, "Deterministic Update Workflow", "update workflow")
    |> require_contains(body, "accessibility, release-startup", "accessibility renewal")
    |> require_contains(body, "release-startup", "release renewal")
    |> require_contains(body, "rollback", "rollback renewal")
    |> require_contains(body, "reopens HUI2", "drift reopening")
  end

  defp validate_browser_sources(errors, root) do
    config = read(root, "playwright.config.mjs")
    browser_test = read(root, "test/browser/hypermedia_ui_phase_b3.spec.mjs")
    http2_proxy = read(root, "test/browser/support/http2_streaming_proxy.mjs")

    errors
    |> require_contains(config, "http2_streaming_proxy.mjs", "HTTP/2 proxy server")
    |> require_contains(config, "ignoreHTTPSErrors: true", "loopback TLS policy")
    |> require_contains(browser_test, "nextHopProtocol", "HTTP/2 negotiation assertion")
    |> require_contains(browser_test, "setOffline(true)", "offline browser case")
    |> require_contains(http2_proxy, "http2.createSecureServer", "HTTP/2 TLS edge")
    |> require_contains(http2_proxy, "x-accel-buffering", "proxy buffering control")
  end

  defp validate_qualification_document(errors, root) do
    body = read(root, @qualification_document)

    errors
    |> require_contains(body, "Manual Accessibility Review", "manual accessibility record")
    |> require_contains(body, "HTTP/2", "HTTP/2 evidence")
    |> require_contains(body, "Residual Risks", "residual-risk record")
    |> require_contains(body, "does not authorize a product route", "product boundary")
  end

  defp validate_production_boundary_sources(errors, root) do
    config = read(root, "config/config.exs")
    test_config = read(root, "config/test.exs")
    application = read(root, "lib/jido_code/application.ex")
    router = read(root, "lib/jido_code_web/router.ex")
    task = read(root, "lib/mix/tasks/hui.b4.production_boundary.ex")

    errors
    |> require_contains(
      config,
      "config :jido_code, :hypermedia_qualification_build, false",
      "production build default"
    )
    |> require_contains(
      test_config,
      "config :jido_code, :hypermedia_qualification_build, true",
      "test build fixture"
    )
    |> require_contains(
      application,
      "Application.compile_env(\n                         :jido_code,\n                         :hypermedia_qualification_build,\n                         false",
      "compile-time supervision boundary"
    )
    |> require_contains(
      router,
      "if Application.compile_env(:jido_code, :hypermedia_qualification_build, false) do",
      "compile-time route boundary"
    )
    |> require_contains(task, "qualification_routes", "production route assertion")
    |> require_contains(task, "qualification_children", "production supervision assertion")
  end

  defp validate_consumption_document(errors, root) do
    body = read(root, @consumption_document)

    errors
    |> require_contains(body, "Accepted HUI-B4 product-consumption baseline", "accepted baseline")
    |> require_contains(body, "Authorized Consumption", "consumption authorization")
    |> require_contains(body, "Milestone C-Owned Composite Gaps", "composite ownership")
    |> require_contains(body, "zero `__qualification` routes", "production route exclusion")
    |> require_contains(body, "Rollback, Upgrade, And Reopening", "operations and reopening")
    |> require_contains(body, "HUI2 reopens", "HUI2 reopening")
  end

  defp validate_closure_files(errors, baseline, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)
    milestone_plan = read(root, @milestone_plan_path)

    {expected_status, milestone_status} =
      if String.contains?(receipt, "Status: **accepted-at-merged-candidate**") do
        {"accepted_at_merged_candidate", "status: completed"}
      else
        {"merge_pending_consumption_baseline", "status: proposed"}
      end

    errors
    |> require_equal(baseline["status"], expected_status, "HUI-B4 receipt lifecycle")
    |> require_contains(milestone_plan, milestone_status, "Milestone B lifecycle")
    |> then(&(Enum.reverse(validate_closure(plan, receipt)) ++ &1))
  end

  defp validate_integration_closure(errors, evidence, root) do
    receipt = read(root, @receipt_path)

    {expected_status, expected_ci} =
      if String.contains?(receipt, "Status: **accepted-at-merged-candidate**") do
        {"accepted_at_merged_candidate", "pass"}
      else
        {"integration_candidate_merge_pending", "merge_pending"}
      end

    errors
    |> require_equal(evidence["status"], expected_status, "integration receipt lifecycle")
    |> require_equal(evidence["clean_checkout_ci"], expected_ci, "clean-checkout CI lifecycle")
    |> validate_accepted_provenance(evidence, expected_status)
  end

  defp validate_accepted_provenance(errors, _evidence, "integration_candidate_merge_pending"),
    do: errors

  defp validate_accepted_provenance(errors, evidence, "accepted_at_merged_candidate") do
    jobs = evidence["clean_checkout_jobs"] || %{}

    errors
    |> require_equal(evidence["implementation_pr"], 115, "implementation PR")
    |> require_equal(
      evidence["implementation_pr_head"],
      @implementation_pr_head,
      "implementation PR head"
    )
    |> require_equal(evidence["merged_candidate"], @merged_candidate, "merged candidate")
    |> require_equal(evidence["merge_date"], "2026-09-04", "merge date")
    |> require_equal(
      jobs,
      %{
        "verify" => %{"id" => 101_115_796_930, "duration" => "18m33s", "result" => "pass"},
        "dialyzer" => %{"id" => 101_115_797_017, "duration" => "1m28s", "result" => "pass"}
      },
      "clean-checkout jobs"
    )
  end

  @spec validate_closure(String.t(), String.t()) :: [String.t()]
  def validate_closure(plan, receipt) do
    accepted? = String.contains?(receipt, "Status: **accepted-at-merged-candidate**")
    pending? = String.contains?(receipt, "Status: **merge-pending**")

    cond do
      accepted? and not pending? ->
        []
        |> require_contains(plan, "status: completed", "completed plan status")
        |> require_checkbox(plan, "4", "Phase", true)
        |> require_checkbox(plan, "4.4", "Section", true)
        |> require_checkbox(plan, "4.4.2", "Task", true)
        |> require_checkbox(plan, "4.4.2.3", "Subtask", true)
        |> require_match(receipt, ~r/Merged candidate: `[0-9a-f]{40}`/, "merged candidate")
        |> require_match(receipt, ~r/Merge date: `\d{4}-\d{2}-\d{2}`/, "merge date")

      pending? and not accepted? ->
        []
        |> require_contains(plan, "status: proposed", "proposed plan status")
        |> require_checkbox(plan, "4", "Phase", false)
        |> require_checkbox(plan, "4.3", "Section", true)
        |> require_checkbox(plan, "4.4", "Section", false)
        |> require_checkbox(plan, "4.4.2", "Task", false)
        |> require_checkbox(plan, "4.4.2.3", "Subtask", false)
        |> require_contains(plan, "- [x] 4.4.1 Task", "integration task")
        |> require_contains(plan, "- [x] 4.4.2.1 Subtask", "pending rule")
        |> require_contains(plan, "- [x] 4.4.2.2 Subtask", "evidence task")
        |> require_contains(receipt, "Merged candidate: `merge-pending`", "pending candidate")
        |> require_contains(receipt, "Merge date: `merge-pending`", "pending merge date")

      true ->
        ["HUI-B4 closure must have exactly one coherent receipt state"]
    end
  end

  defp validate_residual_risks(errors, risks) do
    required = ~w[id severity risk control owner expires_on update_trigger]

    Enum.reduce(risks, errors, fn risk, acc ->
      missing = Enum.reject(required, &(is_binary(risk[&1]) and String.trim(risk[&1]) != ""))

      if missing == [],
        do: acc,
        else: [
          "residual risk #{inspect(risk["id"])} is missing #{Enum.join(missing, ", ")}" | acc
        ]
    end)
  end

  defp nonempty_evidence?(record),
    do: is_binary(record["evidence"]) and String.trim(record["evidence"]) != ""

  defp nonempty_diagnostic?(record),
    do: is_binary(record["diagnostic"]) and String.trim(record["diagnostic"]) != ""

  defp validate_digests(errors, root, expected) do
    Enum.reduce(expected, errors, fn {path, digest}, acc ->
      digest = HypermediaUISuccessorEvidence.digest(root, path) || digest

      case File.read(Path.join(root, path)) do
        {:ok, body} -> require_equal(acc, sha256(body), digest, "digest #{path}")
        {:error, reason} -> ["#{path}: unavailable input: #{inspect(reason)}" | acc]
      end
    end)
  end

  defp require_checkbox(errors, plan, id, label, checked?) do
    require_contains(
      errors,
      plan,
      "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}",
      "#{id} closure checkbox"
    )
  end

  defp require_equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp require_equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp require_member(errors, value, values, label) do
    if value in values, do: errors, else: ["#{label}: unexpected #{inspect(value)}" | errors]
  end

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: ["#{label} is not exact" | errors]
  end

  defp require_contains(errors, body, fragment, label) do
    if String.contains?(body, fragment), do: errors, else: ["missing #{label}" | errors]
  end

  defp require_match(errors, body, pattern, label) do
    if Regex.match?(pattern, body), do: errors, else: ["missing #{label}" | errors]
  end

  defp errors({:ok, []}), do: []
  defp errors({:error, errors}), do: errors
  defp read(root, path), do: File.read!(Path.join(root, path))
  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end

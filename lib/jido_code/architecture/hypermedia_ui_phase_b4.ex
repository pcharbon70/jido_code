defmodule JidoCode.Architecture.HypermediaUIPhaseB4 do
  @moduledoc false

  alias JidoCode.Architecture.HypermediaUIPhaseB1
  alias JidoCode.Architecture.HypermediaUIPhaseB2
  alias JidoCode.Architecture.HypermediaUIPhaseB3

  @manifest_path "priv/architecture/hypermedia_ui/phase_b4_fitness_policy.json"
  @qualification_path "priv/architecture/hypermedia_ui/phase_b4_qualification_evidence.json"
  @baseline "e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2"
  @document_path "docs/architecture/hypermedia-ui-dependency-fitness-and-update-policy.md"
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

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    predecessor_errors =
      [HypermediaUIPhaseB1, HypermediaUIPhaseB2, HypermediaUIPhaseB3]
      |> Enum.flat_map(fn module -> module.check(root) |> errors() end)

    with {:ok, policy} <- load(root),
         {:ok, qualification} <- load_qualification(root) do
      case predecessor_errors ++
             validate(policy, root) ++ validate_qualification(qualification, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
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

  defp validate_digests(errors, root, expected) do
    Enum.reduce(expected, errors, fn {path, digest}, acc ->
      case File.read(Path.join(root, path)) do
        {:ok, body} -> require_equal(acc, sha256(body), digest, "digest #{path}")
        {:error, reason} -> ["#{path}: unavailable input: #{inspect(reason)}" | acc]
      end
    end)
  end

  defp require_equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp require_equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: ["#{label} is not exact" | errors]
  end

  defp require_contains(errors, body, fragment, label) do
    if String.contains?(body, fragment), do: errors, else: ["missing #{label}" | errors]
  end

  defp errors({:ok, []}), do: []
  defp errors({:error, errors}), do: errors
  defp read(root, path), do: File.read!(Path.join(root, path))
  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end

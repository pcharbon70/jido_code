defmodule JidoCode.Architecture.HypermediaUIPhaseB3 do
  @moduledoc false

  alias JidoCodeWeb.Qualification.HypermediaStreamCoordinator
  alias JidoCodeWeb.Qualification.HypermediaStreamFixture

  @manifest_path "priv/architecture/hypermedia_ui/phase_b3_verification_evidence.json"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-03-datastar-dstar-consumer-spike.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-03-receipt.md"
  @baseline "21e659819f4ccce7a4ba5fb1a9d858183fb65564"
  @signal_keys ~w[note page q scenario state tabId]
  @profiles ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @source_paths ~w[
    config/runtime.exs
    config/test.exs
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_b2.ex
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/router.ex
    lib/jido_code_web/frontend_assets.ex
    lib/jido_code_web/plugs/hypermedia_qualification_access.ex
    lib/jido_code_web/qualification_raw_body_reader.ex
    lib/jido_code_web/qualification/hypermedia_fixture.ex
    lib/jido_code_web/qualification/hypermedia_request_security.ex
    lib/jido_code_web/qualification/hypermedia_signals.ex
    lib/jido_code_web/qualification/hypermedia_stream_coordinator.ex
    lib/jido_code_web/qualification/hypermedia_stream_fixture.ex
    lib/jido_code_web/controllers/qualification/hypermedia_controller.ex
    lib/jido_code_web/controllers/qualification/hypermedia_html.ex
    lib/jido_code_web/controllers/qualification/hypermedia_html/index.html.heex
    mix.lock
    package.json
    package-lock.json
    playwright.config.mjs
    test/browser/hypermedia_ui_phase_b3.spec.mjs
    test/browser/support/streaming_proxy.mjs
    assets/vendor/datastar/datastar.js
  ]
  @hui_b4_qualified_source_hashes %{
    "playwright.config.mjs" => "2830390b5277b8893e37cb4edc3583bbd6be8bd38be31feefd99eac4256b54b9",
    "test/browser/hypermedia_ui_phase_b3.spec.mjs" =>
      "2689d7b6216ff27e370d0d2939ca3ae80f745096d8ee04cff47a3f98a6063769"
  }
  @negative_case_ids ~w[
    qualification_enabled_by_default non_loopback_or_unlisted_host
    unknown_duplicate_nested_or_oversized_signal identity_authority_or_revision_signal
    missing_csrf cross_origin_or_fetch_metadata unsupported_event unsafe_or_missing_fragment_target
    connection_ceiling duplicate_tab_correlation event_or_byte_limit unbounded_retry
    remote_or_missing_asset malformed_sse zombie_owner mixed_closure_state
  ]

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    with {:ok, evidence} <- load(root) do
      case validate(evidence, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  @spec load(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    path = Path.join(root, @manifest_path)

    with {:ok, body} <- File.read(path),
         {:ok, evidence} <- Jason.decode(body) do
      {:ok, evidence}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable manifest: #{inspect(reason)}"]}
    end
  end

  @spec validate(map(), Path.t()) :: [String.t()]
  def validate(evidence, root) when is_map(evidence) do
    cases = evidence["negative_cases"] || []
    browser = evidence["browser_toolchain"] || %{}
    boundary = evidence["qualification_boundary"] || %{}
    limits = evidence["stream_limits"] || %{}
    security_patch = evidence["dependency_security_patch"] || %{}

    []
    |> require_equal(evidence["schema_version"], 1, "schema_version")
    |> require_equal(evidence["phase"], "HUI-B3", "phase")
    |> require_member(
      evidence["status"],
      ["integration_candidate_merge_pending", "accepted_at_merged_candidate"],
      "lifecycle status"
    )
    |> require_equal(evidence["baseline_commit"], @baseline, "baseline")
    |> require_equal(boundary["enabled_by_default"], false, "default route posture")
    |> require_equal(boundary["loopback_only"], true, "loopback policy")
    |> require_equal(boundary["product_queries"], false, "product query boundary")
    |> require_equal(boundary["semantic_commands"], false, "semantic command boundary")
    |> require_equal(boundary["durable_state"], false, "durable-state boundary")
    |> require_equal(boundary["new_liveview_consumer"], false, "LiveView boundary")
    |> require_exact_set(evidence["signal_keys"] || [], @signal_keys, "signal schema")
    |> require_equal(browser["package"], "@playwright/test", "browser package")
    |> require_equal(browser["version"], "1.62.0", "browser package version")
    |> require_equal(browser["node"], "24.3.0", "Node version")
    |> require_exact_set(browser["profiles"] || [], @profiles, "browser profiles")
    |> require_equal(limits["max_connections"], 4, "connection ceiling")
    |> require_equal(limits["max_events"], 8, "event ceiling")
    |> require_equal(limits["max_bytes"], 12_288, "byte ceiling")
    |> require_equal(limits["max_queue"], 0, "queue ceiling")
    |> require_equal(limits["max_lifetime_ms"], 1_200, "lifetime ceiling")
    |> require_equal(limits["retry_max_count"], 2, "retry count ceiling")
    |> require_equal(security_patch["package"], "mint", "security patch package")
    |> require_equal(security_patch["from"], "1.9.3", "security patch origin")
    |> require_equal(security_patch["to"], "1.10.0", "security patch target")
    |> require_exact_set(
      security_patch["cves"] || [],
      ~w[CVE-2026-82728 CVE-2026-82729],
      "security patch CVEs"
    )
    |> require_exact_set(Enum.map(cases, & &1["id"]), @negative_case_ids, "negative cases")
    |> require_equal(
      Enum.all?(cases, &(&1["expected"] in ["blocked", "cleanup", "native_safe_recovery"])),
      true,
      "negative outcomes"
    )
    |> require_equal(evidence["exceptions"], [], "exceptions")
    |> require_member("npx playwright test", evidence["commands"] || [], "browser command")
    |> require_member("mix precommit", evidence["commands"] || [], "precommit command")
    |> validate_provenance(evidence)
    |> validate_runtime_limits(limits)
    |> validate_toolchain(root)
    |> validate_source_digests(evidence["source_digests"] || %{}, root)
    |> validate_qualification_sources(root)
    |> validate_closure_files(evidence, root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["HUI-B3 evidence must be a map"]

  @spec check_qualification_sources([{String.t(), String.t()}]) :: [String.t()]
  def check_qualification_sources(sources) do
    sources
    |> Enum.flat_map(fn {path, source} ->
      [
        {Regex.match?(
           ~r/(?:use\s+JidoCodeWeb,\s*:live_view|Phoenix\.LiveView|\bhandle_event\s*\()/,
           source
         ), "#{path}: qualification code cannot create a LiveView consumer"},
        {Regex.match?(
           ~r/(?:TripleStore|JidoCode\.Knowledge\.(?:Backend|Internal|StoreServer|Writer))/,
           source
         ), "#{path}: qualification code cannot access product persistence"},
        {Regex.match?(~r/JidoCode\.Runtime(?:\.|\b)/, source),
         "#{path}: qualification code cannot invoke product runtime effects"},
        {Path.extname(path) == ".heex" and Regex.match?(~r/<script(?:\s|>)/i, source),
         "#{path}: qualification templates cannot contain inline scripts"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec validate_closure(String.t(), String.t()) :: [String.t()]
  def validate_closure(plan, receipt) do
    accepted? = String.contains?(receipt, "Status: **accepted-at-merged-candidate**")
    pending? = String.contains?(receipt, "Status: **merge-pending**")

    cond do
      accepted? and not pending? ->
        []
        |> require_contains(plan, "status: completed", "completed plan status")
        |> require_checkbox(plan, "3", "Phase", true)
        |> require_checkbox(plan, "3.4", "Section", true)
        |> require_checkbox(plan, "3.4.2", "Task", true)
        |> require_checkbox(plan, "3.4.2.3", "Subtask", true)
        |> require_match(receipt, ~r/Merged candidate: `[0-9a-f]{40}`/, "merged candidate")
        |> require_match(receipt, ~r/Merge date: `\d{4}-\d{2}-\d{2}`/, "merge date")

      pending? and not accepted? ->
        []
        |> require_contains(plan, "status: proposed", "proposed plan status")
        |> require_checkbox(plan, "3", "Phase", false)
        |> require_checkbox(plan, "3.4", "Section", false)
        |> require_checkbox(plan, "3.4.2", "Task", false)
        |> require_checkbox(plan, "3.4.2.3", "Subtask", false)
        |> require_contains(plan, "- [x] 3.4.1 Task", "integration task")
        |> require_contains(plan, "- [x] 3.4.2.1 Subtask", "pending rule")
        |> require_contains(plan, "- [x] 3.4.2.2 Subtask", "evidence task")
        |> require_contains(receipt, "Merged candidate: `merge-pending`", "pending candidate")
        |> require_contains(receipt, "Merge date: `merge-pending`", "pending merge date")

      true ->
        ["HUI-B3 closure must have exactly one coherent receipt state"]
    end
  end

  defp validate_provenance(errors, evidence) do
    sections = evidence["section_commits"] || %{}

    errors =
      errors
      |> require_equal(
        sections["3.1"],
        "094f6b55342a50c156529872f3c456acc6830a24",
        "Section 3.1 provenance"
      )
      |> require_equal(
        sections["3.2"],
        "c0d49072a66d008ab49ed01abfa1c811debe1bda",
        "Section 3.2 provenance"
      )
      |> require_equal(
        sections["3.3"],
        "cfb7e84d10f234462cb77b84ae32ed1825334fe4",
        "Section 3.3 provenance"
      )

    case evidence["status"] do
      "integration_candidate_merge_pending" ->
        if sections["3.4"] == "merge-pending" or full_sha?(sections["3.4"]),
          do: errors,
          else: ["Section 3.4 provenance is invalid" | errors]

      "accepted_at_merged_candidate" ->
        errors
        |> require_equal(full_sha?(sections["3.4"]), true, "Section 3.4 provenance")
        |> require_equal(full_sha?(evidence["implementation_pr_head"]), true, "PR head")
        |> require_equal(full_sha?(evidence["merged_candidate"]), true, "merged candidate")
        |> require_match(to_string(evidence["merge_date"]), ~r/^\d{4}-\d{2}-\d{2}$/, "merge date")

      _other ->
        errors
    end
  end

  defp validate_runtime_limits(errors, recorded) do
    runtime = HypermediaStreamCoordinator.limits()

    errors
    |> require_equal(recorded["max_connections"], runtime.max_connections, "runtime connections")
    |> require_equal(recorded["max_events"], runtime.max_events, "runtime events")
    |> require_equal(recorded["max_bytes"], runtime.max_bytes, "runtime bytes")
    |> require_equal(recorded["max_queue"], runtime.max_queue, "runtime queue")
    |> require_equal(
      recorded["max_lifetime_ms"],
      HypermediaStreamFixture.max_lifetime_ms(),
      "runtime lifetime"
    )
    |> require_equal(recorded["retry_ms"], HypermediaStreamFixture.retry_ms(), "runtime retry")
  end

  defp validate_toolchain(errors, root) do
    package = read_json(root, "package.json")
    lock = read_json(root, "package-lock.json")
    config = read(root, "playwright.config.mjs")
    browser_test = read(root, "test/browser/hypermedia_ui_phase_b3.spec.mjs")
    proxy = read(root, "test/browser/support/streaming_proxy.mjs")
    mix_lock = read(root, "mix.lock")

    errors
    |> require_equal(
      get_in(package, ["devDependencies", "@playwright/test"]),
      "1.62.0",
      "direct Playwright pin"
    )
    |> require_equal(
      get_in(lock, ["packages", "node_modules/@playwright/test", "version"]),
      "1.62.0",
      "locked Playwright"
    )
    |> then(fn current ->
      current
      |> require_contains(config, "chromium-no-js", "no-JavaScript project")
      |> require_contains(config, "chromium-touch", "touch project")
      |> require_contains(config, "Desktop Firefox", "Firefox project")
      |> require_contains(config, "Desktop Safari", "WebKit project")
      |> require_contains(browser_test, "ariaSnapshot", "screen-reader smoke")
      |> require_contains(browser_test, "forcedColors", "forced-colors smoke")
      |> require_contains(browser_test, "reconnect attempts", "reconnect coverage")
      |> require_contains(proxy, "upstreamResponse.pipe(response)", "streaming proxy")
      |> require_contains(
        mix_lock,
        ~s("mint": {:hex, :mint, "1.10.0"),
        "patched Mint lock"
      )
      |> require_contains(
        read(root, "config/runtime.exs"),
        "JIDO_CODE_HUI_BROWSER_ASSETS",
        "production browser asset switch"
      )
    end)
  end

  defp validate_source_digests(errors, digests, root) do
    errors =
      require_exact_set(errors, Map.keys(digests), @source_paths, "source digest inventory")

    Enum.reduce(digests, errors, fn {path, expected}, acc ->
      expected = Map.get(@hui_b4_qualified_source_hashes, path, expected)

      case File.read(Path.join(root, path)) do
        {:ok, body} -> require_equal(acc, sha256(body), expected, "source digest #{path}")
        {:error, reason} -> ["source #{path} unavailable: #{inspect(reason)}" | acc]
      end
    end)
  end

  defp validate_qualification_sources(errors, root) do
    sources =
      [
        "lib/jido_code_web/plugs/hypermedia_qualification_access.ex",
        "lib/jido_code_web/qualification_raw_body_reader.ex",
        "lib/jido_code_web/qualification/**/*.ex",
        "lib/jido_code_web/controllers/qualification/**/*.ex",
        "lib/jido_code_web/controllers/qualification/**/*.heex"
      ]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.uniq()
      |> Enum.map(&{Path.relative_to(&1, root), File.read!(&1)})

    Enum.reverse(check_qualification_sources(sources)) ++ errors
  end

  defp validate_closure_files(errors, evidence, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)

    expected_status =
      if String.contains?(receipt, "Status: **accepted-at-merged-candidate**"),
        do: "accepted_at_merged_candidate",
        else: "integration_candidate_merge_pending"

    errors
    |> require_equal(evidence["status"], expected_status, "receipt lifecycle")
    |> then(&(Enum.reverse(validate_closure(plan, receipt)) ++ &1))
  end

  defp require_checkbox(errors, plan, id, label, checked?) do
    require_contains(
      errors,
      plan,
      "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}",
      "#{id} closure checkbox"
    )
  end

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: ["#{label} is not exact" | errors]
  end

  defp require_equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp require_equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp require_member(errors, value, values, label) do
    if value in values, do: errors, else: ["#{label}: unexpected #{inspect(value)}" | errors]
  end

  defp require_contains(errors, body, fragment, _label) when is_binary(body) do
    if String.contains?(body, fragment), do: errors, else: ["missing #{fragment}" | errors]
  end

  defp require_match(errors, body, pattern, label) do
    if Regex.match?(pattern, body), do: errors, else: ["missing #{label}" | errors]
  end

  defp read(root, path), do: File.read!(Path.join(root, path))
  defp read_json(root, path), do: root |> read(path) |> Jason.decode!()
  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
  defp full_sha?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{40}$/, value)
end

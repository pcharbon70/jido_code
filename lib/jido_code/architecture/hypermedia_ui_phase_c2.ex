defmodule JidoCode.Architecture.HypermediaUIPhaseC2 do
  @moduledoc false

  @manifest_path "priv/architecture/hypermedia_ui/phase_c2_implementation_evidence.json"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-02-shadcnui-facade-theme-and-app-components.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-c-phase-02-receipt.md"

  @baseline "73326538cefcc6b136cc96c621062f44f2346c24"
  @predecessor "4a6fa78443463a8c8cd8ed039119cef8ba6e3b1b"
  @sections ~w[2.1 2.2 2.3 2.4]
  @committable_sections ~w[2.1 2.2 2.3]
  @statuses ~w[
    implementation_in_progress
    integration_candidate_merge_pending
    accepted_at_merged_candidate
  ]
  @primitives ~w[
    badge button checkbox dialog disclosure field_input form input link menu radio_group select
    skeleton status table toast tooltip
  ]
  @projection_states ~w[
    ready empty stale incomplete contradicted truncated unauthorized unavailable maintenance recovery
  ]
  @browser_profiles ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @integration_results ~w[
    facade_render_and_hostile_content
    native_forms_and_navigation
    accessibility_semantics
    browser_matrix
    visual_regression
    architecture_boundary
    dependency_and_asset_diff
    strict_production_compile
    repository_precommit
  ]
  @invariants ~w[
    stable_unique_dom_roots_and_focus_targets
    native_forms_and_navigation_work_without_javascript
    components_never_construct_or_grant_authority
    shadcn_ui_imports_are_confined_to_the_ui_facade
    inline_scripts_event_handlers_and_remote_assets_are_prohibited
    projection_states_preserve_truth_bounds_and_concealment
    unavailable_and_unauthorized_projections_clear_rows
    semantic_status_never_relies_on_color_alone
  ]
  @source_prefixes ~w[
    lib/jido_code_web/components/
    lib/jido_code_web/qualification/
    lib/jido_code_web/controllers/qualification/
    test/jido_code_web/components/
    test/jido_code_web/controllers/qualification/
    test/support/hypermedia_ui_phase_c2
    test/browser/hypermedia_ui_phase_c2
  ]
  @source_paths MapSet.new(~w[
    assets/css/app.css
    assets/js/app.js
    assets/js/theme.js
    docs/architecture/hypermedia-ui-component-facade-and-theme.md
    docs/architecture/hypermedia-ui-milestone-c-phase-02-receipt.md
    docs/architecture/repository-wiki-inventory-capacity-successor.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-02-shadcnui-facade-theme-and-app-components.md
    lib/jido_code/architecture/checker.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c1.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c2.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code/knowledge/repository_wiki/compiler.ex
    lib/jido_code/knowledge/repository_wiki/pilot.ex
    lib/jido_code/knowledge/repository_wiki/qualification_corpus.ex
    lib/jido_code/knowledge/repository_wiki/source_inventory.ex
    lib/jido_code/knowledge/repository_wiki/source_inventory_helper_boundary.ex
    lib/jido_code/knowledge/repository_wiki/source_inventory_protocol.ex
    lib/mix/tasks/architecture.check.ex
    playwright.config.mjs
    test/jido_code/architecture/hypermedia_ui_phase_c2_test.exs
    test/jido_code/knowledge/repository_wiki/pilot_release_test.exs
    test/jido_code/knowledge/repository_wiki/qualification_corpus_test.exs
    test/jido_code/knowledge/repository_wiki/source_inventory_boundary_test.exs
    test/jido_code/knowledge/repository_wiki/source_inventory_capacity_successor_test.exs
    test/jido_code_web/plugs/content_security_policy_test.exs
  ])

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
        {:error, ["#{path}: unavailable evidence: #{inspect(reason)}"]}
    end
  end

  @spec validate(map(), Path.t()) :: [String.t()]
  def validate(evidence, root) when is_map(evidence) do
    recorded_completed = evidence["completed_sections"]
    completed = if is_list(recorded_completed), do: recorded_completed, else: []

    []
    |> require_equal(evidence["schema_version"], 1, "schema version")
    |> require_equal(evidence["phase"], "HUI-C2", "phase")
    |> require_member(evidence["status"], @statuses, "lifecycle status")
    |> require_equal(evidence["baseline_commit"], @baseline, "authorized HUI-C1 baseline")
    |> require_equal(evidence["predecessor_candidate"], @predecessor, "HUI-C1 candidate")
    |> require_iso_date(evidence["recorded_on"], "recorded date")
    |> require_equal(is_list(recorded_completed), true, "completed sections schema")
    |> require_equal(ordered_prefix?(completed), true, "completed section order")
    |> validate_section_commits(
      completed,
      evidence["section_commits"] || %{},
      evidence["status"]
    )
    |> validate_lifecycle(evidence, completed, root)
    |> validate_facade(map_or_empty(evidence["facade"]))
    |> maybe_validate("2.3" in completed, fn errors ->
      validate_projection(errors, map_or_empty(evidence["projection"]))
    end)
    |> validate_dom_contract(map_or_empty(evidence["dom_contract"]))
    |> validate_native_contract(map_or_empty(evidence["native_contract"]))
    |> validate_authority_boundary(map_or_empty(evidence["authority_boundary"]))
    |> validate_asset_boundary(map_or_empty(evidence["asset_boundary"]))
    |> require_exact_set(evidence["invariants"] || [], @invariants, "phase invariants")
    |> validate_integration(map_or_empty(evidence["integration"]), completed)
    |> validate_records(evidence["limitations"], "limitations", false)
    |> validate_records(evidence["exceptions"], "exceptions", true)
    |> validate_sources(evidence["source_digests"] || %{}, root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["HUI-C2 evidence must be a map"]

  @spec validate_product_sources([{String.t(), String.t()}]) :: [String.t()]
  def validate_product_sources(sources) when is_list(sources) do
    sources
    |> Enum.filter(fn {path, _source} ->
      String.starts_with?(path, "lib/jido_code_web/") or
        String.starts_with?(path, "assets/")
    end)
    |> Enum.flat_map(fn {path, source} ->
      component? = String.starts_with?(path, "lib/jido_code_web/components/")
      facade? = path == "lib/jido_code_web/components/ui.ex"

      c2_qualification? =
        path == "lib/jido_code_web/qualification/hypermedia_phase_c2_fixture.ex" or
          path ==
            "lib/jido_code_web/controllers/qualification/hypermedia_html/phase_c2.html.heex"

      c2_presentation? = component? or c2_qualification?
      presentation? = component? or Path.extname(path) in [".heex", ".js", ".css"]

      [
        {c2_presentation? and not facade? and upstream_component_import?(source),
         "#{path}: upstream component imports are confined to JidoCodeWeb.Components.UI"},
        {c2_presentation? and authority_dependency?(source),
         "#{path}: HUI-C2 presentation sources cannot construct or query authority"},
        {c2_presentation? and runtime_dependency?(source),
         "#{path}: HUI-C2 presentation sources cannot depend on LiveView, LiveVue, Dstar, or Datastar"},
        {presentation? and inline_script?(path, source),
         "#{path}: inline scripts and executable event-handler attributes are prohibited"},
        {presentation? and remote_asset?(path, source),
         "#{path}: remote product assets, fonts, and icons are prohibited"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp validate_facade(errors, facade) do
    errors
    |> require_equal(facade["module"], "JidoCodeWeb.Components.UI", "facade module")
    |> require_exact_set(facade["supported_primitives"] || [], @primitives, "primitive catalog")
    |> require_equal(
      facade["shadcn_import_owner"],
      "JidoCodeWeb.Components.UI",
      "ShadcnUI import owner"
    )
    |> require_equal(facade["closed_variants"], true, "closed facade variants")
    |> require_equal(facade["phoenix_form_contract"], true, "Phoenix form contract")
    |> require_equal(facade["project_input_contract"], true, "project input contract")
    |> require_equal(facade["escaped_content"], true, "escaped component content")
  end

  defp validate_projection(errors, projection) do
    errors
    |> require_exact_set(projection["states"] || [], @projection_states, "projection states")
    |> require_equal(projection["unavailable_clears_rows"], true, "unavailable projection rows")
    |> require_equal(projection["unauthorized_is_concealed"], true, "unauthorized concealment")
    |> require_equal(
      projection["stale_rows_require_explicit_state"],
      true,
      "stale row semantics"
    )
    |> require_equal(projection["bounded_collections"], true, "bounded projection collections")
  end

  defp validate_dom_contract(errors, contract) do
    errors
    |> require_equal(contract["stable_unique_root_ids"], true, "stable unique DOM roots")
    |> require_equal(contract["stable_focus_targets"], true, "stable focus targets")
    |> require_equal(
      contract["deterministic_relationship_ids"],
      true,
      "deterministic relationship IDs"
    )
  end

  defp validate_native_contract(errors, contract) do
    errors
    |> require_equal(contract["ordinary_links"], true, "ordinary navigation links")
    |> require_equal(contract["native_forms"], true, "native forms")
    |> require_equal(contract["native_submit"], true, "native submit")
    |> require_equal(contract["javascript_disabled"], "supported", "JavaScript-disabled posture")
  end

  defp validate_authority_boundary(errors, boundary) do
    errors
    |> require_equal(boundary["component_authority"], false, "component authority")
    |> require_equal(boundary["browser_authority"], false, "browser authority")
    |> require_equal(
      boundary["navigation_visibility_grants"],
      false,
      "navigation visibility authority"
    )
    |> require_equal(boundary["server_authorized_inputs"], true, "server-authorized inputs")
  end

  defp validate_asset_boundary(errors, boundary) do
    errors
    |> require_equal(boundary["inline_scripts"], false, "inline scripts")
    |> require_equal(boundary["inline_event_handlers"], false, "inline event handlers")
    |> require_equal(boundary["remote_assets"], false, "remote assets")
    |> require_equal(boundary["remote_fonts"], false, "remote fonts")
    |> require_equal(boundary["remote_icons"], false, "remote icons")
    |> require_exact_set(
      boundary["application_bundles"] || [],
      ["assets/js/app.js", "assets/css/app.css"],
      "application bundles"
    )
  end

  defp validate_integration(errors, integration, completed) do
    if "2.4" in completed do
      results = map_or_empty(integration["results"])

      errors
      |> require_positive(integration["focused_tests"], "focused test count")
      |> require_positive(integration["precommit_tests"], "precommit test count")
      |> require_exact_set(
        integration["browser_profiles"] || [],
        @browser_profiles,
        "browser profiles"
      )
      |> require_exact_set(Map.keys(results), @integration_results, "integration result keys")
      |> require_equal(
        Enum.all?(results, fn {_key, value} -> value == "pass" end),
        true,
        "integration results"
      )
    else
      errors
    end
  end

  defp validate_section_commits(errors, completed, commits, status) when is_map(commits) do
    keys = Enum.filter(@committable_sections, &Map.has_key?(commits, &1))
    values = Enum.map(keys, &commits[&1])

    errors =
      errors
      |> require_equal(
        Map.keys(commits) |> Enum.sort(),
        keys |> Enum.sort(),
        "section commit keys"
      )
      |> require_equal(ordered_prefix?(keys, @committable_sections), true, "section commit order")
      |> require_equal(Enum.all?(keys, &(&1 in completed)), true, "section commits completed")
      |> require_equal(Enum.all?(values, &full_sha?/1), true, "section commit SHA")
      |> require_equal(length(Enum.uniq(values)), length(values), "unique section commits")

    if status in ~w[integration_candidate_merge_pending accepted_at_merged_candidate] do
      require_equal(errors, keys, @committable_sections, "final section commit inventory")
    else
      errors
    end
  end

  defp validate_section_commits(errors, _completed, commits, _status),
    do: ["section commits must be a map, got #{inspect(commits)}" | errors]

  defp validate_lifecycle(errors, evidence, completed, root) do
    plan = read(root, @plan_path)
    receipt = read_optional(root, @receipt_path)

    errors
    |> require_equal(lifecycle_valid?(evidence, completed), true, "receipt lifecycle")
    |> validate_plan(evidence["status"], completed, plan)
    |> validate_receipt(evidence["status"], receipt)
  end

  defp lifecycle_valid?(%{"status" => "implementation_in_progress"} = evidence, completed) do
    ordered_prefix?(completed) and
      evidence["receipt_status"] in ["not_published", "merge_pending"] and
      evidence["clean_checkout_ci"] in ["not_run", "pending"] and nil_provenance?(evidence)
  end

  defp lifecycle_valid?(
         %{"status" => "integration_candidate_merge_pending"} = evidence,
         completed
       ) do
    completed == @sections and evidence["receipt_status"] == "merge_pending" and
      evidence["clean_checkout_ci"] == "pending" and nil_provenance?(evidence)
  end

  defp lifecycle_valid?(%{"status" => "accepted_at_merged_candidate"} = evidence, completed) do
    completed == @sections and evidence["receipt_status"] == "accepted_at_merged_candidate" and
      evidence["clean_checkout_ci"] == "pass" and is_integer(evidence["implementation_pr"]) and
      evidence["implementation_pr"] > 0 and full_sha?(evidence["implementation_pr_head"]) and
      full_sha?(evidence["merged_candidate"]) and iso_date?(evidence["merge_date"]) and
      valid_ci_jobs?(evidence["clean_checkout_jobs"])
  end

  defp lifecycle_valid?(_evidence, _completed), do: false

  defp nil_provenance?(evidence) do
    Enum.all?(
      ~w[implementation_pr implementation_pr_head merged_candidate merge_date clean_checkout_jobs],
      &is_nil(evidence[&1])
    )
  end

  defp valid_ci_jobs?(%{"verify" => verify, "dialyzer" => dialyzer} = jobs)
       when map_size(jobs) == 2 do
    Enum.all?([verify, dialyzer], fn job ->
      is_map(job) and is_integer(job["id"]) and job["id"] > 0 and job["result"] == "pass" and
        is_binary(job["duration"]) and String.trim(job["duration"]) != ""
    end)
  end

  defp valid_ci_jobs?(_jobs), do: false

  defp validate_plan(errors, "accepted_at_merged_candidate", _completed, plan) do
    errors
    |> require_contains(plan, "status: completed", "completed plan status")
    |> require_checkbox(plan, "2", "Phase", true)
    |> require_checkbox(plan, "2.1", "Section", true)
    |> require_checkbox(plan, "2.2", "Section", true)
    |> require_checkbox(plan, "2.3", "Section", true)
    |> require_checkbox(plan, "2.4", "Section", true)
    |> require_checkbox(plan, "2.4.2", "Task", true)
    |> require_checkbox(plan, "2.4.2.3", "Subtask", true)
  end

  defp validate_plan(errors, status, completed, plan)
       when status in ~w[implementation_in_progress integration_candidate_merge_pending] do
    errors =
      errors
      |> require_contains(plan, "status: proposed", "proposed plan status")
      |> require_checkbox(plan, "2", "Phase", false)
      |> require_checkbox(plan, "2.4", "Section", false)
      |> require_checkbox(plan, "2.4.2", "Task", false)
      |> require_checkbox(plan, "2.4.2.3", "Subtask", false)

    errors =
      Enum.reduce(~w[2.1 2.2 2.3], errors, fn section, acc ->
        require_checkbox(acc, plan, section, "Section", section in completed)
      end)

    if status == "integration_candidate_merge_pending" do
      errors
      |> require_checkbox(plan, "2.4.1", "Task", true)
      |> require_checkbox(plan, "2.4.2.1", "Subtask", true)
      |> require_checkbox(plan, "2.4.2.2", "Subtask", true)
    else
      errors
    end
  end

  defp validate_plan(errors, _status, _completed, _plan), do: errors

  defp validate_receipt(errors, "implementation_in_progress", ""), do: errors

  defp validate_receipt(errors, "implementation_in_progress", receipt),
    do: pending_receipt(errors, receipt)

  defp validate_receipt(errors, "integration_candidate_merge_pending", receipt),
    do: pending_receipt(errors, receipt)

  defp validate_receipt(errors, "accepted_at_merged_candidate", receipt) do
    errors
    |> require_positive(
      status_count(receipt, "accepted-at-merged-candidate"),
      "accepted status count"
    )
    |> require_equal(status_count(receipt, "merge-pending"), 0, "merge-pending status count")
    |> require_match(receipt, ~r/Merged candidate: `[0-9a-f]{40}`/, "merged candidate")
    |> require_match(receipt, ~r/Merge date: `\d{4}-\d{2}-\d{2}`/, "merge date")
    |> require_contains(receipt, "Gate HUI-C2 Reopening Conditions", "reopening conditions")
  end

  defp validate_receipt(errors, _status, _receipt), do: errors

  defp pending_receipt(errors, receipt) do
    errors
    |> require_positive(status_count(receipt, "merge-pending"), "merge-pending status count")
    |> require_equal(
      status_count(receipt, "accepted-at-merged-candidate"),
      0,
      "accepted status count"
    )
    |> require_match(receipt, ~r/Merged candidate: `?merge-pending`?/, "pending candidate")
    |> require_match(receipt, ~r/Merge date: `?merge-pending`?/, "pending merge date")
    |> require_contains(receipt, "Gate HUI-C2 Reopening Conditions", "reopening conditions")
  end

  defp validate_sources(errors, sources, root) when is_map(sources) and map_size(sources) > 0 do
    {errors, bodies} =
      Enum.reduce(sources, {errors, []}, fn {path, expected}, {acc, bodies} ->
        cond do
          not allowed_source?(path) ->
            {["unauthorized HUI-C2 source path #{inspect(path)}" | acc], bodies}

          not full_digest?(expected) ->
            {["invalid source digest for #{path}" | acc], bodies}

          true ->
            case File.read(Path.join(root, path)) do
              {:ok, body} ->
                {require_equal(acc, sha256(body), expected, "source digest #{path}"),
                 [{path, body} | bodies]}

              {:error, reason} ->
                {["#{path}: unavailable source: #{inspect(reason)}" | acc], bodies}
            end
        end
      end)

    Enum.reverse(validate_product_sources(bodies)) ++ errors
  end

  defp validate_sources(errors, _sources, _root), do: ["source digests are empty" | errors]

  defp validate_records(errors, values, label, empty_allowed?) when is_list(values) do
    cond do
      values == [] and empty_allowed? ->
        errors

      values == [] ->
        ["#{label} must record at least one explicit limitation" | errors]

      Enum.all?(values, &record?/1) ->
        errors

      true ->
        ["#{label} contain an incomplete record" | errors]
    end
  end

  defp validate_records(errors, values, label, _empty_allowed?),
    do: ["#{label} must be a list, got #{inspect(values)}" | errors]

  defp record?(value) when is_binary(value), do: String.trim(value) != ""

  defp record?(value) when is_map(value) do
    is_binary(value["id"]) and String.trim(value["id"]) != "" and
      is_binary(value["detail"]) and String.trim(value["detail"]) != ""
  end

  defp record?(_value), do: false

  defp allowed_source?(path) when is_binary(path) do
    Path.type(path) == :relative and Path.expand(path, "/") == "/" <> path and
      not String.contains?(path, ["\\", "\0"]) and
      (MapSet.member?(@source_paths, path) or
         Enum.any?(@source_prefixes, &String.starts_with?(path, &1)))
  end

  defp allowed_source?(_path), do: false

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}

  defp maybe_validate(errors, true, validator), do: validator.(errors)
  defp maybe_validate(errors, false, _validator), do: errors

  defp upstream_component_import?(source) do
    Regex.match?(~r/(?:use|import|alias)\s+(?:ShadcnUI|SaladUI)|(?:ShadcnUI|SaladUI)\./, source)
  end

  defp authority_dependency?(source) do
    Regex.match?(
      ~r/(?:alias|import|use)\s+JidoCode\.(?:Identity|Knowledge)|JidoCodeWeb\.ProductAuth|AuthorityBuilder|Identity\.Store/,
      source
    )
  end

  defp runtime_dependency?(source) do
    Regex.match?(~r/Phoenix\.LiveView|LiveVue|\bDstar\.|\bDatastar\b|data-on:/, source)
  end

  defp inline_script?(path, source) do
    Path.extname(path) == ".heex" and
      Regex.match?(~r/<script\b|\son[a-z]+\s*=/, source)
  end

  defp remote_asset?(path, source) do
    case Path.extname(path) do
      ".heex" -> Regex.match?(~r/(?:src|href)\s*=\s*["']https?:\/\//, source)
      ".css" -> Regex.match?(~r/(?:@import|url\()\s*["']?https?:\/\//, source)
      ".js" -> Regex.match?(~r/(?:import|from)\s+["']https?:\/\//, source)
      _extension -> false
    end
  end

  defp ordered_prefix?(sections), do: ordered_prefix?(sections, @sections)
  defp ordered_prefix?(sections, allowed), do: sections == Enum.take(allowed, length(sections))

  defp status_count(body, value),
    do: length(Regex.scan(~r/Status: \*\*#{Regex.escape(value)}\*\*/, body))

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, reason} -> "unavailable #{path}: #{inspect(reason)}"
    end
  end

  defp read_optional(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, :enoent} -> ""
      {:error, reason} -> "unavailable #{path}: #{inspect(reason)}"
    end
  end

  defp require_checkbox(errors, plan, id, label, checked?) do
    require_contains(
      errors,
      plan,
      "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}",
      "HUI-C2 #{id} closure checkbox"
    )
  end

  defp require_equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp require_equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp require_member(errors, value, allowed, label) do
    if value in allowed, do: errors, else: ["#{label}: unexpected #{inspect(value)}" | errors]
  end

  defp require_exact_set(errors, actual, expected, label) when is_list(actual) do
    if length(actual) == length(Enum.uniq(actual)) and MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: ["#{label} is not exact" | errors]
  end

  defp require_exact_set(errors, actual, _expected, label),
    do: ["#{label}: expected a list, got #{inspect(actual)}" | errors]

  defp require_positive(errors, value, _label) when is_integer(value) and value > 0, do: errors

  defp require_positive(errors, value, label),
    do: ["#{label}: expected a positive integer, got #{inspect(value)}" | errors]

  defp require_contains(errors, body, fragment, _label) when is_binary(body) do
    if String.contains?(body, fragment), do: errors, else: ["missing #{fragment}" | errors]
  end

  defp require_match(errors, body, pattern, label) when is_binary(body) do
    if Regex.match?(pattern, body), do: errors, else: ["#{label}: missing or invalid" | errors]
  end

  defp require_iso_date(errors, value, label) do
    if iso_date?(value), do: errors, else: ["#{label}: invalid #{inspect(value)}" | errors]
  end

  defp iso_date?(value) when is_binary(value),
    do: match?({:ok, _date}, Date.from_iso8601(value))

  defp iso_date?(_value), do: false

  defp full_sha?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{40}$/, value)
  defp full_digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end

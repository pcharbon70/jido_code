defmodule JidoCode.Architecture.HypermediaUIPhaseC3 do
  @moduledoc false

  @manifest_path "priv/architecture/hypermedia_ui/phase_c3_implementation_evidence.json"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-03-authenticated-shell-routes-and-native-navigation.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-c-phase-03-receipt.md"
  @baseline "7c77e2270cf754b6a04d5f95e12ca070083902ae"
  @predecessor "da7ab6a4478bb278aa31a7636fa92135843249ff"
  @implementation_head "306405e0e01d76a856b4c33639bd3b79744e02c2"
  @merged_candidate "fa5203a9aefe08d741b2898a01299c7d960c80d9"
  @merge_date "2026-09-05"
  @clean_checkout_jobs %{
    "verify" => %{"id" => 101_385_012_698, "duration" => "20m10s", "result" => "pass"},
    "dialyzer" => %{"id" => 101_382_702_919, "duration" => "2m30s", "result" => "pass"}
  }
  @sections ~w[3.1 3.2 3.3 3.4]
  @profiles ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @route_paths [
    "/factory",
    "/factory/fleet",
    "/projects",
    "/projects/switch",
    "/projects/:project_ref",
    "/projects/:project_ref/attempts",
    "/projects/:project_ref/wiki",
    "/projects/:project_ref/dependencies",
    "/projects/:project_ref/attempts/:attempt_ref",
    "/projects/:project_ref/knowledge/:lens",
    "/reviews/:candidate_ref",
    "/operations",
    "/operations/costs",
    "/security",
    "/security/incidents",
    "/governance",
    "/account",
    "/account/sessions",
    "/sign-in",
    "/sign-out",
    "/step-up",
    "/recovery",
    "/sessions",
    "/account/sessions/:management_ref"
  ]
  @new_routes [
    {"DELETE", "/account/sessions/:management_ref"},
    {"GET", "/account"},
    {"GET", "/account/sessions"},
    {"GET", "/factory"},
    {"GET", "/factory/fleet"},
    {"GET", "/governance"},
    {"GET", "/operations"},
    {"GET", "/operations/costs"},
    {"GET", "/projects"},
    {"GET", "/projects/:project_ref"},
    {"GET", "/projects/:project_ref/attempts"},
    {"GET", "/projects/:project_ref/attempts/:attempt_ref"},
    {"GET", "/projects/:project_ref/dependencies"},
    {"GET", "/projects/:project_ref/knowledge/:lens"},
    {"GET", "/projects/:project_ref/wiki"},
    {"GET", "/projects/switch"},
    {"GET", "/recovery"},
    {"GET", "/reviews/:candidate_ref"},
    {"GET", "/security"},
    {"GET", "/security/incidents"},
    {"GET", "/step-up"},
    {"POST", "/recovery"},
    {"POST", "/step-up"}
  ]
  @invariants ~w[
    explicit_new_controller_routes_without_new_product_liveview
    legacy_home_live_remains_a_compatibility_route
    exact_resource_authorization_precedes_rendering
    opaque_refs_preserve_resource_kind_and_containment
    unknown_and_unauthorized_resources_share_concealed_exterior
    navigation_is_independently_authorized_server_side
    native_forms_work_without_javascript
    scope_switch_clears_nested_selection
    session_management_never_exposes_bearer_session_refs
    unavailable_step_up_and_recovery_never_claim_readiness
    protected_pages_use_no_store_and_origin_only_referrers
  ]
  @results ~w[
    route_controller_matrix
    scope_and_concealment_matrix
    shell_navigation_and_forms
    session_and_recovery_workflows
    accessibility_and_responsive_matrix
    browser_matrix
    architecture_boundary
    strict_production_compile
    repository_precommit
  ]
  @allowed_prefixes ~w[
    lib/jido_code_web/controllers/
    test/jido_code_web/controllers/
    test/browser/hypermedia_ui_phase_c3
  ]
  @allowed_paths MapSet.new([
                   "config/config.exs",
                   "config/test.exs",
                   @plan_path,
                   @receipt_path,
                   "lib/jido_code/architecture/hypermedia_ui_phase_c1.ex",
                   "lib/jido_code/architecture/hypermedia_ui_phase_c2.ex",
                   "lib/jido_code/architecture/hypermedia_ui_phase_c3.ex",
                   "lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex",
                   "lib/jido_code/identity/sessions.ex",
                   "lib/jido_code/identity/store.ex",
                   "lib/jido_code_web/components/layouts/root.html.heex",
                   "lib/jido_code_web/components/product_page.ex",
                   "lib/jido_code_web/endpoint.ex",
                   "lib/jido_code_web/plugs/product_canonical_path.ex",
                   "lib/jido_code_web/product_auth.ex",
                   "lib/jido_code_web/product_controller.ex",
                   "lib/jido_code_web/product_page_view_model.ex",
                   "lib/jido_code_web/product_request.ex",
                   "lib/jido_code_web/router.ex",
                   "lib/mix/tasks/architecture.check.ex",
                   "test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs",
                   "test/jido_code/architecture/hypermedia_ui_phase_c3_test.exs"
                 ])

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
    completed =
      if(is_list(evidence["completed_sections"]), do: evidence["completed_sections"], else: [])

    routes = evidence["routes"] || %{}
    successor = evidence["runtime_successor"] || %{}
    session = evidence["session_workflows"] || %{}
    integration = evidence["integration"] || %{}

    []
    |> equal(evidence["schema_version"], 1, "schema version")
    |> equal(evidence["phase"], "HUI-C3", "phase")
    |> member(
      evidence["status"],
      ~w[implementation_in_progress integration_candidate_merge_pending accepted_at_merged_candidate],
      "lifecycle status"
    )
    |> equal(evidence["baseline_commit"], @baseline, "authorized baseline")
    |> equal(evidence["predecessor_candidate"], @predecessor, "HUI-C2 candidate")
    |> equal(completed, @sections, "completed section order")
    |> equal(
      evidence["section_commits"] || %{},
      %{
        "3.1" => "4720fb46145e9d46d1c856b8516a8d946bbbb03b",
        "3.2" => "26360a536c5082477235f08c31cb425b5653473f",
        "3.3" => "c7d4621ba666b6e180c3f6b6afd5d617d9b9159e"
      },
      "section commits"
    )
    |> equal(
      MapSet.new(evidence["invariants"] || []),
      MapSet.new(@invariants),
      "phase invariants"
    )
    |> equal(MapSet.new(routes["paths"] || []), MapSet.new(@route_paths), "route vocabulary")
    |> equal(
      successor["routes"]
      |> List.wrap()
      |> Enum.map(&{&1["method"], &1["path"]})
      |> MapSet.new(),
      MapSet.new(@new_routes),
      "runtime successor routes"
    )
    |> equal(routes["new_product_live_routes"], 0, "new product LiveView routes")
    |> equal(routes["retained_compatibility_live_routes"], 3, "compatibility LiveView routes")
    |> equal(routes["catch_all_actions"], 0, "catch-all actions")
    |> equal(routes["resource_refs"], "bounded_opaque_registry_refs", "resource refs")
    |> equal(
      routes["canonicalization"],
      "absolute_canonical_and_trailing_slash_redirect",
      "canonicalization"
    )
    |> equal(routes["query_schema"], "closed_bounded_get_intent", "query schema")
    |> equal(routes["concealment"], "unknown_equals_unauthorized", "concealment")
    |> equal(session["cookie_bearer_refs_in_html"], 0, "bearer session refs")
    |> equal(session["management_refs"], "non_bearer_sha256_preimage_refs", "management refs")
    |> equal(session["current_other_all_revocation"], true, "session revocation")
    |> equal(session["step_up"], "unavailable_until_configured", "step-up posture")
    |> equal(session["recovery"], "generic_unavailable_until_configured", "recovery posture")
    |> equal(session["secret_parameter_filtering"], true, "secret parameter filtering")
    |> equal(session["native_csrf_and_origin"], true, "native CSRF and Origin")
    |> equal(
      evidence["response_security"],
      %{
        "cache_control" => "no-store, private",
        "referrer_policy" => "origin",
        "origin_path_or_query_leak" => false
      },
      "response security"
    )
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
    |> lifecycle(evidence, root)
    |> validate_sources(evidence["source_digests"], root)
    |> validate_router(root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["HUI-C3 evidence must be a map"]

  def validate_product_sources(sources) do
    Enum.flat_map(sources, fn {path, body} ->
      []
      |> forbid(
        body =~
          ~r/\b(?:live|live_session)\s+"\/(?:factory|projects|reviews|operations|security|governance|account)/,
        "#{path}: product LiveView route"
      )
      |> forbid(
        body =~ ~r/\b(?:SELECT|ASK|CONSTRUCT)\s+|\b(?:INSERT|DELETE)\s+(?:DATA|WHERE|\{)/i,
        "#{path}: raw graph query"
      )
      |> forbid(String.contains?(body, "TripleStore"), "#{path}: raw store access")
      |> forbid(String.contains?(body, "<script"), "#{path}: inline script")
      |> forbid(Regex.match?(~r/\son[a-z]+\s*=/i, body), "#{path}: inline event handler")
      |> forbid(String.contains?(body, "dstar-"), "#{path}: Datastar product behavior")
    end)
  end

  defp lifecycle(errors, %{"status" => "integration_candidate_merge_pending"} = evidence, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)

    errors
    |> equal(evidence["receipt_status"], "merge_pending", "receipt status")
    |> equal(evidence["clean_checkout_ci"], "pending", "clean-checkout CI")
    |> equal(evidence["implementation_pr"], nil, "implementation PR")
    |> equal(evidence["implementation_pr_head"], nil, "implementation PR head")
    |> equal(evidence["merged_candidate"], nil, "merged candidate")
    |> equal(evidence["merge_date"], nil, "merge date")
    |> equal(evidence["clean_checkout_jobs"], nil, "clean-checkout jobs")
    |> require_match(receipt, ~r/Status: \*\*merge-pending\*\*/, "pending receipt")
    |> require_match(receipt, ~r/Merged candidate: `merge-pending`/, "pending candidate")
    |> require_contains(plan, "status: proposed", "pending plan status")
    |> require_match(plan, ~r/- \[ \] 3 Phase/, "pending phase checkbox")
    |> require_match(plan, ~r/- \[ \] 3\.4 Section/, "pending integration checkbox")
  end

  defp lifecycle(errors, %{"status" => "accepted_at_merged_candidate"} = evidence, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)

    errors
    |> equal(evidence["receipt_status"], "accepted_at_merged_candidate", "receipt status")
    |> equal(evidence["clean_checkout_ci"], "pass", "clean-checkout CI")
    |> equal(evidence["implementation_pr"], 121, "implementation PR")
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
    |> require_contains(plan, "status: completed", "completed plan status")
    |> require_match(plan, ~r/- \[x\] 3 Phase/, "accepted phase checkbox")
    |> require_match(plan, ~r/- \[x\] 3\.4 Section/, "accepted integration checkbox")
    |> require_match(plan, ~r/- \[x\] 3\.4\.2 Task/, "accepted receipt task checkbox")
    |> require_match(plan, ~r/- \[x\] 3\.4\.2\.3 Subtask/, "accepted pin checkbox")
  end

  defp lifecycle(errors, _evidence, _root), do: ["unsupported receipt lifecycle" | errors]

  defp validate_sources(errors, sources, root) when is_map(sources) and map_size(sources) > 0 do
    {errors, product_sources} =
      Enum.reduce(sources, {errors, []}, fn {path, expected}, {acc, inspected} ->
        case {allowed_source?(path), full_digest?(expected)} do
          {false, _digest?} ->
            {["unauthorized HUI-C3 source path #{path}" | acc], inspected}

          {true, false} ->
            {["invalid source digest for #{path}" | acc], inspected}

          {true, true} ->
            case File.read(Path.join(root, path)) do
              {:ok, body} ->
                next = equal(acc, sha256(body), expected, "source digest #{path}")

                inspected =
                  if product_source?(path), do: [{path, body} | inspected], else: inspected

                {next, inspected}

              {:error, reason} ->
                {["#{path}: unavailable source: #{inspect(reason)}" | acc], inspected}
            end
        end
      end)

    Enum.reverse(validate_product_sources(product_sources)) ++ errors
  end

  defp validate_sources(errors, _sources, _root), do: ["source digests are empty" | errors]

  defp validate_router(errors, root) do
    router = read(root, "lib/jido_code_web/router.ex")

    errors =
      errors
      |> forbid(String.contains?(router, ~s(live "/factory)), "router contains product LiveView")
      |> forbid(String.contains?(router, ~s(get "/*)), "router contains catch-all GET")
      |> forbid(
        not String.contains?(router, ~s(live "/", HomeLive)),
        "router removed the compatibility HomeLive route before HUI-H"
      )

    Enum.reduce(@route_paths, errors, fn path, acc ->
      if String.contains?(router, ~s("#{path}")),
        do: acc,
        else: ["router is missing explicit route #{path}" | acc]
    end)
  end

  defp allowed_source?(path),
    do:
      MapSet.member?(@allowed_paths, path) or
        Enum.any?(@allowed_prefixes, &String.starts_with?(path, &1))

  defp product_source?(path),
    do: String.starts_with?(path, "lib/jido_code_web/") and Path.extname(path) in [".ex", ".heex"]

  defp equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp member(errors, actual, values, label) do
    if actual in values,
      do: errors,
      else: ["#{label}: unexpected #{inspect(actual)}" | errors]
  end

  defp positive(errors, value, _label) when is_integer(value) and value > 0, do: errors

  defp positive(errors, value, label),
    do: ["#{label}: expected positive integer, got #{inspect(value)}" | errors]

  defp all_pass(errors, results) do
    if Enum.all?(results, fn {_key, value} -> value == "pass" end),
      do: errors,
      else: ["integration results are not all pass" | errors]
  end

  defp forbid(errors, condition, message) when is_boolean(condition) do
    Enum.filter([message], fn _message -> condition end) ++ errors
  end

  defp require_match(errors, body, pattern, label) do
    if Regex.match?(pattern, body),
      do: errors,
      else: ["#{label} is missing" | errors]
  end

  defp require_contains(errors, body, value, label) do
    if is_binary(value) and String.contains?(body, value),
      do: errors,
      else: ["#{label} is missing" | errors]
  end

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, _reason} -> ""
    end
  end

  defp full_digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end

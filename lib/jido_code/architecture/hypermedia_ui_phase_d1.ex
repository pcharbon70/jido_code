defmodule JidoCode.Architecture.HypermediaUIPhaseD1 do
  @moduledoc "Executable evidence for the closed, finite HUI-D1 read boundary."
  @manifest "priv/architecture/hypermedia_ui/phase_d1_implementation_evidence.json"
  @plan "docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-01-closed-request-signal-and-fragment-contracts.md"
  @receipt "docs/architecture/hypermedia-ui-milestone-d-phase-01-receipt.md"
  @merged_candidate "7118bf337639c5ecdd5f2567dafbc761a5e09165"
  @baseline "4d0e3918d732d87ebaad36e56ef90cc781e51d62"
  @predecessor "5987a7a4a43505b035f5a566588d5201e98686f7"
  @section_commits %{
    "1.1" => "5f2c2de7b86469af615da93e99bdd7516aff076f",
    "1.2" => "9a7228a9e04e14fed0dc6c4becbb2abfd15f3fc0",
    "1.3" => "23a153e703108a972377f76fcddee946bd50ae1b"
  }
  @paths ~w[
    /ui/reads/factory /ui/reads/fleet /ui/reads/projects
    /ui/reads/projects/:project_ref/overview /ui/reads/projects/:project_ref/attempts
    /ui/reads/projects/:project_ref/wiki /ui/reads/projects/:project_ref/dependencies
    /ui/reads/projects/:project_ref/attempts/:attempt_ref /ui/reads/account /ui/reads/sessions
  ]
  @invariants ~w[
    closed_namespaces_and_bounded_duplicate_preserving_parser
    browser_intent_never_carries_authority
    explicit_post_routes_share_native_queries
    fresh_exact_authority_after_field_shaping
    csrf_origin_fetch_metadata_json_and_private_logging
    principal_and_global_admission_are_bounded
    one_coherent_escaped_heex_root_with_a_byte_cap
    protected_and_failed_reads_clear_prior_content
    focus_selection_overlay_scroll_and_native_history_survive
    static_nonce_csp_local_bundle_no_scripts_or_streams
    native_workflows_and_all_predecessor_reopenings_remain_binding
    clean_checkout_ci_and_merged_candidate_are_required_for_closure
  ]
  @required_sources ~w[
    assets/js/app.js
    assets/js/read_projection.js
    assets/vite.config.mjs
    assets/vue_csp_compatibility.mjs
    docs/architecture/hypermedia-ui-compatibility-csp-repair.md
    docs/architecture/hypermedia-ui-read-request-and-fragment-implementation.md
    docs/architecture/hypermedia-ui-milestone-d-phase-01-receipt.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-01-closed-request-signal-and-fragment-contracts.md
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_b2.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c3.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d1.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code/product/read_request_limiter.ex
    lib/jido_code_web/components/product_page.ex
    lib/jido_code_web/controllers/account_controller.ex
    lib/jido_code_web/controllers/account_html/show.html.heex
    lib/jido_code_web/controllers/account_html/sessions.html.heex
    lib/jido_code_web/controllers/attempt_html/show.html.heex
    lib/jido_code_web/controllers/factory_html/attention.html.heex
    lib/jido_code_web/controllers/factory_html/fleet.html.heex
    lib/jido_code_web/controllers/project_html/index.html.heex
    lib/jido_code_web/controllers/project_html/overview.html.heex
    lib/jido_code_web/controllers/project_html/attempts.html.heex
    lib/jido_code_web/controllers/project_html/wiki.html.heex
    lib/jido_code_web/controllers/project_html/dependencies.html.heex
    lib/jido_code_web/controllers/read_controller.ex
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/plugs/read_body.ex
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/product_request.ex
    lib/jido_code_web/read_enhancement.ex
    lib/jido_code_web/read_response.ex
    lib/jido_code_web/read_security.ex
    lib/jido_code_web/read_signals.ex
    lib/jido_code_web/router.ex
    lib/mix/tasks/architecture.check.ex
    scripts/qualify_hui_d1_orca.sh
    test/accessibility/hypermedia_ui_phase_d1_orca.mjs
    test/browser/hypermedia_ui_phase_d1.spec.mjs
    test/assets/vue_csp_compatibility_test.mjs
    test/jido_code/architecture/vue_csp_compatibility_test.exs
    test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs
    test/jido_code/architecture/hypermedia_ui_phase_d1_test.exs
    test/jido_code/product/read_request_limiter_test.exs
    test/jido_code_web/controllers/read_controller_test.exs
    test/jido_code_web/read_signals_test.exs
  ]

  def load(root \\ File.cwd!()) do
    with {:ok, body} <- File.read(Path.join(root, @manifest)),
         {:ok, evidence} when is_map(evidence) <- Jason.decode(body) do
      {:ok, evidence}
    else
      _ -> {:error, ["HUI-D1 evidence unavailable or invalid"]}
    end
  end

  def check(root \\ File.cwd!()) do
    with {:ok, evidence} <- load(root) do
      case validate(evidence, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  def validate(evidence, root) when is_map(evidence) do
    []
    |> equal(evidence["schema_version"], 1, "schema version")
    |> equal(evidence["phase"], "HUI-D1", "phase")
    |> equal(evidence["baseline_commit"], @baseline, "authorized baseline")
    |> equal(evidence["predecessor_candidate"], @predecessor, "predecessor candidate")
    |> equal(evidence["section_commits"], @section_commits, "section commits")
    |> equal(evidence["completed_sections"], ~w[1.1 1.2 1.3 1.4], "section order")
    |> equal(evidence["invariants"], @invariants, "reopening invariants")
    |> equal(
      evidence["limits"],
      %{
        "request_bytes" => 2048,
        "namespace_count" => 1,
        "fields" => 5,
        "depth" => 2,
        "list_items" => 0,
        "search_bytes" => 128,
        "maximum_page" => 100,
        "patch_bytes" => 131_072,
        "patch_roots" => 1,
        "reads_per_minute" => 30,
        "per_principal_concurrency" => 2,
        "global_concurrency" => 16,
        "rate_window_keys" => 256,
        "client_deadline_ms" => 20_000
      },
      "limits"
    )
    |> equal(
      evidence["runtime_successor"],
      %{
        "routes" => Enum.map(@paths, &%{"method" => "POST", "path" => &1}),
        "application_child_ids" => ["JidoCode.Product.ReadRequestLimiter"]
      },
      "explicit runtime successor"
    )
    |> equal(
      evidence["browser_profiles"],
      ~w[chromium firefox webkit chromium-no-js chromium-touch],
      "browser profiles"
    )
    |> equal(evidence["exceptions"], [], "exceptions")
    |> sources(evidence["source_digests"], root)
    |> lifecycle(evidence, root)
    |> boundaries(root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["invalid HUI-D1 evidence"]

  defp sources(errors, sources, root) when is_map(sources) do
    errors =
      equal(
        errors,
        Enum.sort(Map.keys(sources)),
        Enum.sort(@required_sources),
        "exact source inventory"
      )

    Enum.reduce(sources, errors, fn {path, digest}, acc ->
      case File.read(Path.join(root, path)) do
        {:ok, body} ->
          current = Base.encode16(:crypto.hash(:sha256, body), case: :lower)
          successor = JidoCode.Architecture.HypermediaUISuccessorEvidence

          if successor.d4_override?(root, path, digest) or
               (successor.phase_d2_mutable_path?(path) and successor.digest(root, path) == current and
                  successor.d2_predecessor_digest(root, path) == digest),
             do: acc,
             else: equal(acc, current, digest, "source digest #{path}")

        _ ->
          ["source unavailable #{path}" | acc]
      end
    end)
  end

  defp sources(errors, _, _), do: ["missing source digests" | errors]

  defp lifecycle(errors, %{"status" => "integration_candidate_merge_pending"} = evidence, root) do
    errors
    |> equal(evidence["merged_candidate"], nil, "pending merged candidate")
    |> equal(evidence["clean_checkout_ci"], "pending", "pending clean checkout CI")
    |> contains(read(root, @receipt), "Status: **merge-pending**", "pending receipt")
    |> contains(read(root, @plan), "- [ ] 1 Phase", "pending phase checkbox")
    |> contains(read(root, @plan), "- [ ] 1.4 Section", "pending integration checkbox")
  end

  defp lifecycle(errors, %{"status" => "accepted_at_merged_candidate"} = evidence, root) do
    errors
    |> equal(evidence["merged_candidate"], @merged_candidate, "pinned merged candidate")
    |> equal(full_sha?(evidence["merged_candidate"]), true, "full merged SHA")
    |> equal(evidence["local_verification"], "pass", "local verification")
    |> equal(evidence["clean_checkout_ci"], "pass", "clean checkout CI")
    |> equal(is_integer(evidence["implementation_pr"]), true, "implementation PR")
    |> equal(valid_jobs?(evidence["clean_checkout_jobs"]), true, "clean checkout jobs")
    |> contains(
      read(root, @receipt),
      "Status: **accepted-at-merged-candidate**",
      "accepted receipt"
    )
    |> contains(read(root, @receipt), evidence["merged_candidate"], "receipt merged SHA")
    |> contains(
      read(root, @receipt),
      "Merge date: `#{evidence["merge_date"]}`",
      "receipt merge date"
    )
    |> contains(read(root, @plan), "- [x] 1 Phase", "accepted phase checkbox")
    |> contains(read(root, @plan), "- [x] 1.4 Section", "accepted integration checkbox")
    |> contains(read(root, @plan), "- [x] 1.4.2 Task", "accepted receipt checkbox")
    |> contains(read(root, @plan), "- [x] 1.4.2.3 Subtask", "accepted pin checkbox")
  end

  defp lifecycle(errors, _, _), do: ["unsupported lifecycle" | errors]

  defp boundaries(errors, root) do
    controller = read(root, "lib/jido_code_web/controllers/read_controller.ex")
    adapter = read(root, "assets/js/read_projection.js")
    enhancement = read(root, "lib/jido_code_web/read_enhancement.ex")
    response = read(root, "lib/jido_code_web/read_response.ex")

    errors
    |> equal(
      Regex.match?(
        ~r/TripleStore|CommandGateway|String\.to_atom|conn\.params\["action"\]/,
        controller
      ),
      false,
      "controller authority boundary"
    )
    |> equal(
      Regex.match?(~r/localStorage|sessionStorage|eval\(|new Function|innerHTML\s*=/, adapter),
      false,
      "local adapter boundary"
    )
    |> equal(
      Regex.match?(~r/Dstar\.(Scripts|script|start)|text\/event-stream/, response),
      false,
      "finite response boundary"
    )
    |> contains(enhancement, "@readProjection(evt)", "static expression")
    |> contains(response, ":before_each_protected_patch", "final authority check")
    |> contains(adapter, "retryMaxCount: 0", "no retry")
    |> contains(adapter, "root.replaceChildren", "terminal row clearing")
  end

  defp valid_jobs?(jobs) when is_map(jobs) do
    Enum.all?(~w[verify dialyzer], fn name ->
      case jobs[name] do
        %{"id" => id, "result" => "pass"} when is_integer(id) and id > 0 -> true
        _ -> false
      end
    end)
  end

  defp valid_jobs?(_), do: false
  defp full_sha?(value), do: is_binary(value) and Regex.match?(~r/\A[0-9a-f]{40}\z/, value)

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      _ -> ""
    end
  end

  defp contains(errors, text, value, label) do
    if is_binary(value) and value != "" and String.contains?(text, value),
      do: errors,
      else: ["missing #{label}" | errors]
  end

  defp equal(errors, value, value, _label), do: errors
  defp equal(errors, _actual, _expected, label), do: ["invalid #{label}" | errors]
end

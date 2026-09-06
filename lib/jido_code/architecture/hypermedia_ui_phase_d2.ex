defmodule JidoCode.Architecture.HypermediaUIPhaseD2 do
  @moduledoc "Executable provenance and fail-closed invariants for the product stream coordinator."
  @manifest "priv/architecture/hypermedia_ui/phase_d2_implementation_evidence.json"
  @plan "docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-02-authorized-page-tab-stream-coordinator.md"
  @receipt "docs/architecture/hypermedia-ui-milestone-d-phase-02-receipt.md"
  @baseline "852215a71fae707bd7bd89ea822e2963b695ec5b"
  @predecessor "7118bf337639c5ecdd5f2567dafbc761a5e09165"
  @merged_candidate "1d55390108763052998cc6f6e6dfc4ce319998c0"
  @sections ~w[2.1 2.2 2.3 2.4]
  @paths ~w[
    /ui/streams/factory /ui/streams/fleet /ui/streams/projects
    /ui/streams/projects/:project_ref/overview /ui/streams/projects/:project_ref/attempts
    /ui/streams/projects/:project_ref/wiki /ui/streams/projects/:project_ref/dependencies
    /ui/streams/projects/:project_ref/attempts/:attempt_ref /ui/streams/account /ui/streams/sessions
  ]
  @invariants ~w[
    authentication_csrf_origin_metadata_and_negotiation_precede_response_start
    exact_stream_resource_query_and_field_authority_is_server_owned
    bounded_correlation_and_signed_cursors_never_restore_authority
    trusted_session_tab_takeover_invalidates_the_old_lease
    principal_session_tenant_factory_rate_and_memory_caps_are_hard
    one_supervised_coordinator_owns_lifecycle_and_cleanup
    bounded_encoded_events_and_coalesced_control_credit_prevent_protected_replay
    hard_session_connection_idle_and_slow_owner_deadlines_ignore_traffic
    all_eight_revocation_generations_and_periodic_fresh_checks_are_binding
    terminal_authority_change_clears_protected_content_and_suppresses_reconnect
    native_fallback_focus_csp_and_predecessor_reopenings_remain_binding
    real_http_browser_proxy_failure_and_clean_checkout_tests_precede_merge_acceptance
  ]
  @required_sources ~w[
    assets/js/app.js
    assets/js/read_projection.js
    assets/js/stream_connection.js
    docs/architecture/hypermedia-ui-milestone-d-phase-02-receipt.md
    docs/architecture/hypermedia-ui-stream-coordinator-implementation.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-02-authorized-page-tab-stream-coordinator.md
    lib/jido_code/application.ex
    lib/jido_code/identity/store.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c3.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d1.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d2.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code/product/stream_coordinator.ex
    lib/jido_code/product/stream_owner_guard.ex
    lib/jido_code_web/components/product_page.ex
    lib/jido_code_web/components/layouts/root.html.heex
    lib/jido_code_web/controllers/stream_controller.ex
    lib/jido_code_web/controllers/stream_html.ex
    lib/jido_code_web/plugs/read_body.ex
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/product_request.ex
    lib/jido_code_web/read_response.ex
    lib/jido_code_web/read_enhancement.ex
    lib/jido_code_web/read_signals.ex
    lib/jido_code_web/router.ex
    lib/jido_code_web/stream_admission.ex
    lib/jido_code_web/stream_context.ex
    lib/jido_code_web/stream_delivery.ex
    lib/jido_code_web/stream_intent.ex
    lib/jido_code_web/stream_security.ex
    lib/mix/tasks/architecture.check.ex
    test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs
    test/jido_code/architecture/hypermedia_ui_phase_d2_test.exs
    test/jido_code/product/stream_coordinator_test.exs
    test/jido_code/product/stream_lifecycle_test.exs
    test/jido_code/product/stream_revocation_test.exs
    test/jido_code/identity/session_lifecycle_test.exs
    test/jido_code_web/controllers/stream_controller_test.exs
    test/jido_code_web/stream_intent_test.exs
    test/jido_code_web/stream_reauthorization_test.exs
    test/jido_code_web/stream_http_test.exs
    test/browser/hypermedia_ui_phase_d2.spec.mjs
    test/accessibility/hypermedia_ui_phase_d2_orca.mjs
    scripts/qualify_hui_d2_orca.sh
    test/support/deny_stream_authority_adapter.ex
  ]

  def load(root \\ File.cwd!()) do
    with {:ok, body} <- File.read(Path.join(root, @manifest)),
         {:ok, evidence} when is_map(evidence) <- Jason.decode(body),
         do: {:ok, evidence}
  end

  def check(root \\ File.cwd!()) do
    case load(root) do
      {:ok, evidence} ->
        case validate(evidence, root) do
          [] -> {:ok, []}
          errors -> {:error, errors}
        end

      _ ->
        {:error, ["HUI-D2 evidence unavailable"]}
    end
  end

  def validate(evidence, root) do
    []
    |> equal(evidence["schema_version"], 1, "schema")
    |> equal(evidence["phase"], "HUI-D2", "phase")
    |> equal(evidence["baseline_commit"], @baseline, "authorized baseline")
    |> equal(evidence["predecessor_candidate"], @predecessor, "predecessor candidate")
    |> equal(evidence["invariants"], @invariants, "reopening invariants")
    |> equal(
      evidence["runtime_successor"],
      %{
        "routes" => Enum.map(@paths, &%{"method" => "POST", "path" => &1}),
        "application_child_ids" => [
          "JidoCode.Product.StreamOwnerSupervisor",
          "JidoCode.Product.StreamCoordinator"
        ]
      },
      "runtime inventory"
    )
    |> equal(evidence["exceptions"], [], "exceptions")
    |> equal(
      evidence["limits"],
      Map.new(JidoCode.Product.StreamCoordinator.limits(), fn {key, value} ->
        {Atom.to_string(key), value}
      end),
      "fixed runtime limits"
    )
    |> equal(
      evidence["states"],
      ~w[admitted connected idle retrying revoked expired closing closed],
      "lifecycle states"
    )
    |> equal(
      evidence["predecessor_source_digests"],
      predecessor_digests(root),
      "preserved D1 source digests"
    )
    |> sources(evidence["source_digests"], root)
    |> lifecycle(evidence, root)
    |> boundaries(root)
  end

  defp sources(errors, sources, root) when is_map(sources) do
    errors =
      equal(
        errors,
        Enum.sort(Map.keys(sources)),
        Enum.sort(@required_sources),
        "exact source inventory"
      )

    Enum.reduce(sources, errors, fn {path, expected}, acc ->
      case File.read(Path.join(root, path)) do
        {:ok, body} ->
          equal(
            acc,
            Base.encode16(:crypto.hash(:sha256, body), case: :lower),
            expected,
            "source digest #{path}"
          )

        _ ->
          ["source unavailable #{path}" | acc]
      end
    end)
  end

  defp sources(errors, _, _), do: ["missing source digests" | errors]

  defp boundaries(errors, root) do
    adapter = File.read!(Path.join(root, "assets/js/stream_connection.js"))
    delivery = File.read!(Path.join(root, "lib/jido_code_web/stream_delivery.ex"))

    errors
    |> equal(
      Regex.match?(
        ~r/localStorage|sessionStorage|eval\(|new Function|innerHTML\s*=|https?:\/\//,
        adapter
      ),
      false,
      "local stream adapter boundary"
    )
    |> equal(
      Regex.match?(
        ~r/Dstar\.(Scripts|SSE|start)|TripleStore|CommandGateway|String\.to_atom/,
        delivery
      ),
      false,
      "shared transport boundary"
    )
    |> contains(root, "assets/js/stream_connection.js", "retryMaxCount: 0")
    |> contains(root, "assets/js/stream_connection.js", "retry <= 2")
    |> contains(root, "assets/js/stream_connection.js", "event.stopImmediatePropagation()")
    |> contains(root, "lib/jido_code_web/read_enhancement.ex", "@openStream(evt)")
    |> contains(
      root,
      "lib/jido_code_web/components/layouts/root.html.heex",
      "static_path(@conn, path)"
    )
  end

  defp predecessor_digests(root) do
    {:ok, predecessor} = JidoCode.Architecture.HypermediaUIPhaseD1.load(root)

    Map.filter(predecessor["source_digests"], fn {path, _} ->
      JidoCode.Architecture.HypermediaUISuccessorEvidence.phase_d2_mutable_path?(path)
    end)
  end

  defp lifecycle(errors, %{"status" => "implementation_in_progress"} = evidence, root) do
    sections = evidence["completed_sections"] || []

    errors
    |> equal(
      sections != [] and sections == Enum.take(@sections, length(sections)),
      true,
      "section order"
    )
    |> pending(evidence, root)
  end

  defp lifecycle(errors, %{"status" => "integration_candidate_merge_pending"} = evidence, root),
    do:
      errors
      |> equal(evidence["completed_sections"], @sections, "completed sections")
      |> local_verification(evidence)
      |> pending(evidence, root)

  defp lifecycle(errors, %{"status" => "accepted_at_merged_candidate"} = evidence, root) do
    errors
    |> equal(evidence["completed_sections"], @sections, "completed sections")
    |> equal(evidence["merged_candidate"], @merged_candidate, "merged candidate")
    |> equal(full_sha?(@merged_candidate), true, "full candidate SHA")
    |> local_verification(evidence)
    |> equal(evidence["clean_checkout_ci"], "pass", "clean checkout CI")
    |> equal(valid_jobs?(evidence["clean_checkout_jobs"]), true, "clean checkout jobs")
    |> equal(
      is_integer(evidence["implementation_pr"]) and evidence["implementation_pr"] > 0,
      true,
      "implementation PR"
    )
    |> equal(
      match?({:ok, _}, Date.from_iso8601(evidence["merge_date"] || "")),
      true,
      "merge date"
    )
    |> equal(
      Enum.all?(@sections, &full_sha?(get_in(evidence, ["section_commits", &1]))),
      true,
      "section commit provenance"
    )
    |> contains(root, @receipt, "Status: **accepted-at-merged-candidate**")
    |> contains(root, @receipt, "Merged candidate: `#{evidence["merged_candidate"]}`")
    |> contains(root, @receipt, "Merge date: `#{evidence["merge_date"]}`")
    |> contains(root, @plan, "- [x] 2 Phase")
    |> contains(root, @plan, "- [x] 2.4 Section")
    |> contains(root, @plan, "- [x] 2.4.2 Task")
    |> contains(root, @plan, "- [x] 2.4.2.3 Subtask")
  end

  defp lifecycle(errors, _, _), do: ["unsupported lifecycle" | errors]

  defp local_verification(errors, evidence) do
    errors
    |> equal(evidence["local_verification"], "pass", "local verification")
    |> equal(
      evidence["qualification"],
      %{
        "real_http_production_supervision" => "pass",
        "count_rate_event_queue_and_deadline_limits" => "pass",
        "slow_reader_process_node_restart_and_drain" => "pass",
        "all_eight_generations_query_idle_and_stale_reconnect" => "pass",
        "private_audit_and_telemetry" => "pass",
        "browser_native_keyboard_focus_sleep_retry_takeover_and_csp" => "pass",
        "http1_and_http2_proxy" => "pass",
        "named_orca" => "pass",
        "precommit" => "pass"
      },
      "integration qualification matrix"
    )
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

  defp pending(errors, evidence, root) do
    errors
    |> equal(evidence["merged_candidate"], nil, "pending candidate")
    |> equal(evidence["clean_checkout_ci"], "pending", "pending clean checkout CI")
    |> contains(root, @receipt, "Status: **merge-pending**")
    |> contains(root, @plan, "- [ ] 2 Phase")
    |> contains(root, @plan, "- [ ] 2.4 Section")
  end

  defp contains(errors, root, path, text),
    do:
      equal(
        errors,
        String.contains?(File.read!(Path.join(root, path)), text),
        true,
        "#{path}: #{text}"
      )

  defp equal(errors, value, value, _), do: errors
  defp equal(errors, _, _, label), do: ["invalid #{label}" | errors]
end

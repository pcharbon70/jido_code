defmodule JidoCode.Architecture.HypermediaUIPhaseC4 do
  @moduledoc false

  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  @manifest_path "priv/architecture/hypermedia_ui/phase_c4_implementation_evidence.json"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-04-attention-fleet-project-and-attempt-projections.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-c-phase-04-receipt.md"
  @baseline "3515b1f3ba0c2e8dfdde0c77a2782a2873f3ee42"
  @predecessor "fa5203a9aefe08d741b2898a01299c7d960c80d9"
  @implementation_pr 123
  @implementation_head "2deba683754c28b7a3343d22fd74addc49d9e9d0"
  @merged_candidate "4532ff304816ad0a229192f0e0bc0f9a3abb66da"
  @merge_date "2026-09-06"
  @clean_checkout_jobs %{
    "verify" => %{"id" => 101_436_837_030, "duration" => "22m27s", "result" => "pass"},
    "dialyzer" => %{"id" => 101_434_959_747, "duration" => "1m50s", "result" => "pass"}
  }
  @sections ~w[4.1 4.2 4.3 4.4]
  @profiles ~w[chromium firefox webkit chromium-no-js chromium-touch]
  @surfaces ~w[factory fleet projects project project_attempts project_wiki project_dependencies attempt]
  @states ~w[ready empty stale incomplete contradicted truncated unauthorized unavailable maintenance recovery]
  @invariants ~w[
    reviewed_versioned_queries_only
    bounded_candidates_scans_rows_pages_and_timeout
    exact_route_row_and_field_authorization
    opaque_links_without_raw_iris
    read_paths_are_semantic_effect_free
    unsupported_capabilities_never_become_controls
    protected_outcomes_clear_previously_visible_rows
    cache_keys_bind_exact_authority_scope_revision_and_query
    cache_hits_reauthorize_and_revocation_invalidates
    telemetry_contains_only_closed_safe_dimensions
    protected_responses_remain_private_no_store
    controller_heex_pages_work_without_javascript
  ]
  @results ~w[
    query_and_state_matrix
    authorization_and_concealment_matrix
    cache_and_revocation_matrix
    real_triple_store_projection
    controller_and_component_matrix
    accessibility_and_responsive_matrix
    browser_matrix
    architecture_boundary
    strict_production_compile
    repository_precommit
  ]
  @required_sources ~w[
    lib/jido_code/product/graph_read_projection_provider.ex
    lib/jido_code/product/read_projection.ex
    lib/jido_code/product/read_projection_cache.ex
    lib/jido_code/product/read_projection_query.ex
    lib/jido_code/product/read_projection_telemetry.ex
    lib/jido_code_web/components/read_workspace.ex
    lib/jido_code_web/product_controller.ex
    test/browser/hypermedia_ui_phase_c4.spec.mjs
    test/jido_code/product/read_projection_real_store_phase_c4_test.exs
  ]
  @allowed_prefixes ~w[
    docs/architecture/hypermedia-ui-milestone-c-phase-04-receipt.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-c-read-only-hypermedia-shell/phase-04-
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c3.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code/product.ex
    lib/jido_code/product/
    lib/jido_code_web/components/read_workspace.ex
    lib/jido_code_web/controllers/account_controller.ex
    lib/jido_code_web/controllers/attempt_html.ex
    lib/jido_code_web/controllers/attempt_html/
    lib/jido_code_web/controllers/factory_controller.ex
    lib/jido_code_web/controllers/factory_html.ex
    lib/jido_code_web/controllers/factory_html/
    lib/jido_code_web/controllers/project_controller.ex
    lib/jido_code_web/controllers/project_html.ex
    lib/jido_code_web/controllers/project_html/
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/product_page_view_model.ex
    lib/jido_code_web/product_request.ex
    lib/jido_code_web/read_projection_view.ex
    lib/mix/tasks/architecture.check.ex
    test/browser/hypermedia_ui_phase_c4.spec.mjs
    test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs
    test/jido_code/architecture/hypermedia_ui_phase_c4_test.exs
    test/jido_code/product/
    test/jido_code_web/controllers/factory_projection_phase_c4_test.exs
    test/jido_code_web/controllers/workspace_projection_phase_c4_test.exs
    test/support/fake_read_projection_provider.ex
    test/support/hypermedia_ui_phase_c4_fixture.ex
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
    query = evidence["query_contract"] || %{}
    cache = evidence["cache_security"] || %{}
    integration = evidence["integration"] || %{}
    successor = evidence["runtime_successor"] || %{}

    []
    |> equal(evidence["schema_version"], 1, "schema version")
    |> equal(evidence["phase"], "HUI-C4", "phase")
    |> member(
      evidence["status"],
      ~w[integration_candidate_merge_pending accepted_at_merged_candidate],
      "lifecycle status"
    )
    |> equal(evidence["baseline_commit"], @baseline, "authorized baseline")
    |> equal(evidence["predecessor_candidate"], @predecessor, "HUI-C3 candidate")
    |> equal(evidence["completed_sections"], @sections, "completed section order")
    |> equal(
      evidence["section_commits"] || %{},
      %{
        "4.1" => "56fbb5b2c6f439f8fd9124b74d186b5bfc480169",
        "4.2" => "528e9b975bb98ea15680a9a944503e26eb4e5a30",
        "4.3" => "5ef1935338473a2c8aa891e0af0d0a2f7c568189"
      },
      "section commits"
    )
    |> equal(
      MapSet.new(evidence["invariants"] || []),
      MapSet.new(@invariants),
      "phase invariants"
    )
    |> equal(query["version"], "2.11.0", "query version")
    |> equal(MapSet.new(query["surfaces"] || []), MapSet.new(@surfaces), "projection surfaces")
    |> equal(MapSet.new(query["states"] || []), MapSet.new(@states), "projection states")
    |> equal(query["candidate_limit"], 100, "candidate limit")
    |> equal(query["scan_limit"], 24, "scan limit")
    |> equal(query["page_size"], 20, "page size")
    |> equal(query["surface_timeout_ms"], 5_500, "surface timeout")
    |> equal(query["semantic_writes"], 0, "semantic writes")
    |> equal(query["raw_iris_in_view_models"], 0, "raw IRIs")
    |> equal(cache["fresh_ttl_ms"], 5_000, "fresh cache TTL")
    |> equal(cache["retention_ms"], 30_000, "stale retention")
    |> equal(cache["max_entries"], 512, "cache capacity")
    |> equal(cache["reauthorize_on_hit"], true, "cache-hit authorization")
    |> equal(cache["clear_on_protected_failure"], true, "protected cache clearing")
    |> equal(
      successor["application_child_ids"],
      ["JidoCode.Product.ReadProjectionCache"],
      "runtime successor children"
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
    |> validate_contract_sources(root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["HUI-C4 evidence must be a map"]

  def validate_product_sources(sources) do
    Enum.flat_map(sources, fn {path, body} ->
      []
      |> forbid(
        body =~ ~r/\b(?:live|live_session)\s+"\/(?:factory|projects)/,
        "#{path}: product LiveView route"
      )
      |> forbid(
        body =~ ~r/\b(?:SELECT|ASK|CONSTRUCT)\s+|\b(?:INSERT|DELETE)\s+(?:DATA|WHERE|\{)/i,
        "#{path}: raw graph query"
      )
      |> forbid(String.contains?(body, "TripleStore"), "#{path}: raw store access")
      |> forbid(
        Regex.match?(~r/\b(?:SemanticCommand|CommandGateway|execute_command)\b/, body),
        "#{path}: semantic command access"
      )
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
    |> require_match(plan, ~r/- \[ \] 4 Phase/, "pending phase checkbox")
    |> require_match(plan, ~r/- \[ \] 4\.4 Section/, "pending integration checkbox")
  end

  defp lifecycle(errors, %{"status" => "accepted_at_merged_candidate"} = evidence, root) do
    receipt = read(root, @receipt_path)
    plan = read(root, @plan_path)

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
    |> require_contains(plan, "status: completed", "completed plan status")
    |> require_match(plan, ~r/- \[x\] 4 Phase/, "accepted phase checkbox")
    |> require_match(plan, ~r/- \[x\] 4\.4 Section/, "accepted integration checkbox")
    |> require_match(plan, ~r/- \[x\] 4\.4\.2 Task/, "accepted receipt task checkbox")
    |> require_match(plan, ~r/- \[x\] 4\.4\.2\.3 Subtask/, "accepted pin checkbox")
  end

  defp lifecycle(errors, _evidence, _root), do: ["unsupported receipt lifecycle" | errors]

  defp validate_sources(errors, sources, root) when is_map(sources) and map_size(sources) > 0 do
    errors =
      Enum.reduce(@required_sources, errors, fn path, acc ->
        if Map.has_key?(sources, path),
          do: acc,
          else: ["required source digest missing for #{path}" | acc]
      end)

    {errors, product_sources} =
      Enum.reduce(sources, {errors, []}, fn {path, expected}, {acc, inspected} ->
        cond do
          not allowed_source?(path) ->
            {["unauthorized HUI-C4 source path #{path}" | acc], inspected}

          not full_digest?(expected) ->
            {["invalid source digest for #{path}" | acc], inspected}

          true ->
            case File.read(Path.join(root, path)) do
              {:ok, body} ->
                current = sha256(body)
                successor = HypermediaUISuccessorEvidence.digest(root, path)

                next =
                  if current == expected or
                       (HypermediaUISuccessorEvidence.phase_c5_mutable_path?(path) and
                          successor == current),
                     do: acc,
                     else: [
                       "source digest #{path}: expected #{inspect(expected)}, got #{inspect(current)}"
                       | acc
                     ]

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

  defp validate_contract_sources(errors, root) do
    provider = read(root, "lib/jido_code/product/graph_read_projection_provider.ex")
    query = read(root, "lib/jido_code/product/read_projection_query.ex")
    cache = read(root, "lib/jido_code/product/read_projection_cache.ex")
    telemetry = read(root, "lib/jido_code/product/read_projection_telemetry.ex")

    errors
    |> require_contains(query, ~s(@version "2.11.0"), "reviewed query version")
    |> require_contains(provider, "@candidate_limit 100", "candidate bound")
    |> require_contains(provider, "@scan_limit 24", "scan bound")
    |> require_contains(provider, "@page_size 20", "page bound")
    |> require_contains(provider, "@surface_timeout_ms 5_500", "surface timeout")
    |> require_contains(cache, "@fresh_ttl_ms 5_000", "fresh cache TTL")
    |> require_contains(cache, "@retention_ms 30_000", "cache retention")
    |> require_contains(cache, "@max_entries 512", "cache capacity")
    |> require_contains(telemetry, "@measurement_keys", "closed telemetry measurements")
    |> require_contains(telemetry, "@metadata_keys", "closed telemetry metadata")
  end

  defp allowed_source?(path), do: Enum.any?(@allowed_prefixes, &String.starts_with?(path, &1))

  defp product_source?(path),
    do:
      (String.starts_with?(path, "lib/jido_code/product") or
         String.starts_with?(path, "lib/jido_code_web/")) and
        Path.extname(path) in [".ex", ".heex"]

  defp equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp member(errors, actual, values, label) do
    if actual in values, do: errors, else: ["#{label}: unexpected #{inspect(actual)}" | errors]
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
    if Regex.match?(pattern, body), do: errors, else: ["#{label} is missing" | errors]
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

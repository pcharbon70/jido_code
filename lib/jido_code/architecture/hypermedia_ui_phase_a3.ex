defmodule JidoCode.Architecture.HypermediaUIPhaseA3 do
  @moduledoc false

  @manifest_directory "priv/architecture/hypermedia_ui"
  @manifest_files %{
    authority: "phase_a3_runtime_and_product_authority.json",
    supersession: "phase_a3_supersession_matrix.json",
    interfaces: "phase_a3_interface_registry.json",
    evidence: "phase_a3_evidence_contract.json",
    scenarios: "phase_a3_traceability_scenarios.json"
  }

  @baseline "02e16cbb6cd4c56fb93c19db8c9f4a535e580dcb"
  @projection_states ~w[
    ready empty stale incomplete contradicted truncated unauthorized unavailable maintenance recovery
  ]
  @target_prohibitions ~w[
    liveview_product_routes liveview_product_processes liveview_product_events
    liveview_product_streams liveview_product_state livevue_islands saladui_product_components
    remote_or_cdn_assets client_authoritative_revisions browser_granted_authority
  ]
  @lens_groups ~w[
    factory_and_capacity source project_domain work_and_execution evidence_and_decision
    memory_and_experience wiki_guides_and_dependencies cross_project_datasets
    security_and_audit derived_diagnostics
  ]
  @knowledge_prohibitions ~w[
    raw_sparql unrestricted_graph_browsing universal_node_link_hairball
    chat_as_record_of_truth process_heartbeat_as_semantic_progress
  ]
  @preserved_invariants ~w[
    graph_only_durable_authority reviewed_bounded_authorized_queries
    semantic_commands_and_immutable_receipts ten_projection_states
    lossy_hints_require_fresh_authorized_requery concealed_unknown_and_unauthorized_exterior
    unavailable_clears_rows named_identity_and_exact_grants_without_role_union
    separation_of_duty_and_compare_and_set bounded_accessible_native_fallback
    current_capability_honesty all_prior_gate_reopening_conditions
  ]
  @wiki_invariants ~w[
    explicit_default_off_enrollment repository_tenant_and_same_repository_session_isolation
    one_logical_maintainer_profile_per_enabled_repository
    deterministic_only_zero_model_call_capability
    immutable_edition_and_exact_source_candidate_identity
    token_reservation_usage_cost_attribution_and_reconciliation
    hard_aggregate_budget_and_opt_out_semantics
    review_activation_and_deterministic_release_separation
  ]
  @reauthorization_points ~w[
    before_response_start before_query_execution before_field_shaping
    before_stream_subscription before_each_protected_patch before_command_construction
    inside_command_gateway before_approval_commit before_export_creation
    before_each_export_or_download_retrieval
  ]
  @revocation_sources ~w[account session role delegation project tenant graph incident]
  @closure_checkboxes ~w[3 3.4 3.4.2 3.4.2.3]

  @accepted_documents %{
    "docs/adr/0008-server-rendered-heex-and-datastar-product-runtime.md" =>
      "Status: Accepted for architecture authority; dependency, migration, and release gated",
    "docs/adr/0010-shadcnui-as-product-component-primitive-layer.md" =>
      "Status: Accepted for architecture authority; dependency adoption and release gated",
    "docs/adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md" =>
      "Status: Accepted for architecture authority; projection, interaction, and release gated",
    "docs/architecture/hypermedia-product-governance-baseline.md" =>
      "Status: Accepted for architecture authority; implementation and release gated",
    "docs/architecture/hypermedia-ui-runtime-contract-supersession.md" =>
      "Status: Accepted architecture contract under ADRs 0008–0011; implementation",
    "docs/architecture/hypermedia-ui-validation-and-release-evidence-contract.md" =>
      "Status: Accepted architecture contract; evidence execution remains gated",
    "docs/architecture/shadcn-ui-adoption-and-component-contract.md" =>
      "Status: Accepted architecture contract under ADR 0010; dependency adoption gated",
    "docs/architecture/datastar-dstar-dependency-and-consumer-qualification.md" =>
      "Status: Accepted qualification contract under ADR 0008; dependencies remain unqualified",
    "docs/architecture/datastar-request-signal-fragment-and-stream-contract.md" =>
      "Status: Accepted architecture contract under ADR 0008; implementation gated",
    "docs/architecture/hypermedia-runtime-migration-and-rollback.md" =>
      "Status: Accepted architecture contract under ADRs 0008 and 0010; removal gated",
    "docs/architecture/secure-product-shell-and-information-architecture.md" =>
      "Status: Accepted architecture contract under ADRs 0009 and 0011; implementation gated",
    "docs/architecture/agent-attempt-workspace-and-command-contract.md" =>
      "Status: Accepted architecture contract under ADR 0011; implementation gated",
    "docs/architecture/graph-lens-and-visualization-contract.md" =>
      "Status: Accepted architecture contract under ADR 0011; implementation gated",
    "docs/architecture/ui-security-privacy-and-threat-model.md" =>
      "Status: Accepted architecture contract under ADRs 0008, 0009, and 0011; release gated",
    "docs/architecture/incident-control-plane-contract.md" =>
      "Status: Accepted architecture contract under ADRs 0009 and 0011; controls remain unavailable"
  }

  @type manifests :: %{
          authority: map(),
          supersession: map(),
          interfaces: map(),
          evidence: map(),
          scenarios: map()
        }

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    case load(root) do
      {:ok, manifests} ->
        case validate(manifests, root) do
          [] -> {:ok, []}
          errors -> {:error, errors}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  @spec load(Path.t()) :: {:ok, manifests()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    {manifests, errors} =
      Enum.reduce(@manifest_files, {%{}, []}, fn {key, file}, {loaded, errors} ->
        path = Path.join([root, @manifest_directory, file])

        case File.read(path) do
          {:ok, body} ->
            case Jason.decode(body) do
              {:ok, manifest} -> {Map.put(loaded, key, manifest), errors}
              {:error, reason} -> {loaded, ["#{path}: invalid JSON: #{inspect(reason)}" | errors]}
            end

          {:error, reason} ->
            {loaded, ["#{path}: cannot read manifest: #{inspect(reason)}" | errors]}
        end
      end)

    if errors == [], do: {:ok, manifests}, else: {:error, Enum.reverse(errors)}
  end

  @spec validate(manifests(), Path.t()) :: [String.t()]
  def validate(
        %{
          authority: authority,
          supersession: supersession,
          interfaces: interfaces,
          evidence: evidence,
          scenarios: scenarios
        },
        root
      ) do
    []
    |> validate_scenarios(scenarios, root)
    |> validate_authority(authority)
    |> validate_supersession(supersession, interfaces, scenarios, root)
    |> validate_interfaces(interfaces, scenarios, root)
    |> validate_evidence(evidence, scenarios)
    |> validate_documents(scenarios, root)
    |> Enum.reverse()
  end

  def validate(_incomplete, _root), do: ["HUI-A3 manifest set is incomplete"]

  @spec validate_closure(String.t(), String.t()) :: [String.t()]
  def validate_closure(plan, receipt) do
    accepted? = String.contains?(receipt, "Status: **accepted-at-merged-candidate**")
    merge_pending? = String.contains?(receipt, "Status: **merge-pending**")

    cond do
      accepted? and not merge_pending? ->
        []
        |> require_contains(plan, "status: completed", "HUI-A3 completed plan status")
        |> validate_closure_checkboxes(plan, true)
        |> validate_accepted_candidate(receipt)

      merge_pending? and not accepted? ->
        []
        |> require_contains(plan, "status: proposed", "HUI-A3 proposed plan status")
        |> validate_closure_checkboxes(plan, false)
        |> require_contains(
          receipt,
          "| Merged candidate | `merge-pending` |",
          "HUI-A3 merge-pending candidate table"
        )
        |> require_contains(
          receipt,
          "Merged candidate: `merge-pending`",
          "HUI-A3 merge-pending candidate metadata"
        )
        |> require_contains(
          receipt,
          "Merge date: `merge-pending`",
          "HUI-A3 merge-pending date metadata"
        )

      true ->
        ["HUI-A3 closure must have exactly one coherent receipt state"]
    end
  end

  defp validate_scenarios(errors, scenarios, root) do
    errors =
      errors
      |> require_equal(scenarios["schema_version"], 1, "traceability schema_version")
      |> require_equal(scenarios["phase"], "HUI-A3", "traceability phase")
      |> require_nonempty(scenarios["required_supersession_ids"], "supersession trace is empty")
      |> require_nonempty(scenarios["required_interface_ids"], "interface trace is empty")
      |> require_nonempty(scenarios["required_documents"], "document trace is empty")
      |> require_unique(
        Enum.map(scenarios["hostile_mutations"] || [], & &1["id"]),
        "hostile mutation id"
      )
      |> require_equal(
        length(scenarios["hostile_mutations"] || []),
        9,
        "hostile mutation count"
      )

    Enum.reduce(scenarios["historical_or_current_state_exclusions"] || [], errors, fn path, acc ->
      acc
      |> require_path(root, path, "historical/current-state exclusion")
      |> require_absent(
        scenarios["normative_presentation_documents"] || [],
        path,
        "historical/current-state exclusion must not be scanned as normative"
      )
    end)
  end

  defp validate_authority(errors, authority) do
    target = authority["target_ownership"] || %{}
    component = authority["component_boundary"] || %{}
    migration = authority["migration"] || %{}

    errors
    |> require_equal(authority["schema_version"], 1, "authority schema_version")
    |> require_equal(authority["phase"], "HUI-A3", "authority phase")
    |> require_equal(
      get_in(authority, ["baseline", "closure_commit"]),
      @baseline,
      "authority HUI-A2 closure baseline"
    )
    |> require_equal(
      authority["status"],
      "accepted_architecture_authority",
      "authority status"
    )
    |> require_equal(
      authority["runtime_status"],
      "current_compatibility_runtime_until_milestone_h",
      "authority runtime status"
    )
    |> require_exact_ids(authority["decisions"], ~w[ADR-0008 ADR-0010 ADR-0011], "decision")
    |> require_fields(
      target,
      ~w[full_page fragment action stream browser_state durability asset_build native_fallback],
      "target ownership"
    )
    |> require_exact_set(
      authority["prohibited_target_runtime"] || [],
      @target_prohibitions,
      "target runtime prohibitions"
    )
    |> require_exact_ids(
      authority["narrow_exceptions"],
      ~w[phoenix_live_view_package live_dashboard],
      "narrow exception"
    )
    |> require_equal(
      component["facade_owner"],
      "JidoCodeWeb.Components.UI",
      "component facade owner"
    )
    |> require_equal(component["dependency_adoption_gate"], "HUI-B", "component adoption gate")
    |> require_exact_set(authority["lens_groups"] || [], @lens_groups, "lens groups")
    |> require_exact_set(
      get_in(authority, ["knowledge_rules", "prohibited"]) || [],
      @knowledge_prohibitions,
      "knowledge prohibitions"
    )
    |> require_fields(
      migration,
      ~w[order coexistence rollback dependency_removal],
      "migration authority"
    )
  end

  defp validate_supersession(errors, supersession, interfaces, scenarios, root) do
    rows = supersession["rows"] || []
    interface_ids = Enum.map(interfaces["interfaces"] || [], & &1["id"])

    errors =
      errors
      |> require_equal(supersession["schema_version"], 1, "supersession schema_version")
      |> require_equal(supersession["phase"], "HUI-A3", "supersession phase")
      |> require_equal(supersession["baseline"], @baseline, "supersession baseline")
      |> require_exact_set(
        Enum.map(rows, & &1["id"]),
        scenarios["required_supersession_ids"] || [],
        "supersession trace"
      )
      |> require_unique(Enum.map(rows, & &1["id"]), "supersession row id")
      |> require_exact_set(
        supersession["preserved_invariants"] || [],
        @preserved_invariants,
        "preserved invariants"
      )
      |> require_exact_set(
        supersession["wiki_invariants"] || [],
        @wiki_invariants,
        "wiki invariants"
      )

    Enum.reduce(rows, errors, fn row, acc ->
      acc =
        acc
        |> require_fields(
          row,
          ~w[id source clause_scope disposition target_owner implementation_phase test_classes rollback_dependency removal_condition],
          "supersession #{row["id"]}"
        )
        |> require_nonempty(row["test_classes"], "#{row["id"]} test classes are empty")
        |> require_subset(row["interfaces"] || [], interface_ids, "#{row["id"]} interface trace")

      require_source_pattern(acc, root, row["source"], "#{row["id"]} source")
    end)
  end

  defp validate_interfaces(errors, interfaces, scenarios, root) do
    records = interfaces["interfaces"] || []
    routes = interfaces["routes"] || []
    interface_ids = Enum.map(records, & &1["id"])
    route_ids = Enum.map(routes, & &1["id"])
    route_signatures = Enum.map(routes, &"#{&1["method"]} #{&1["path"]}")
    request_ids = Enum.map(interfaces["request_classes"] || [], & &1["id"])
    signal_namespaces = interfaces["signal_namespaces"] || []

    errors =
      errors
      |> require_equal(interfaces["schema_version"], 1, "interface schema_version")
      |> require_equal(interfaces["phase"], "HUI-A3", "interface phase")
      |> require_exact_set(
        interface_ids,
        scenarios["required_interface_ids"] || [],
        "interface registry"
      )
      |> require_unique(interface_ids, "interface id")
      |> require_exact_set(
        request_ids,
        scenarios["required_request_classes"] || [],
        "request classes"
      )
      |> require_exact_set(
        interfaces["projection_states"] || [],
        @projection_states,
        "projection states"
      )
      |> require_unique(route_ids, "route id")
      |> require_unique(route_signatures, "route method and path")
      |> require_equal(length(routes), 41, "target route count")
      |> require_equal(length(signal_namespaces), 6, "signal namespace count")
      |> require_unique(Enum.map(signal_namespaces, & &1["prefix"]), "signal namespace prefix")
      |> require_exact_set(
        interfaces["reauthorization_points"] || [],
        @reauthorization_points,
        "reauthorization points"
      )
      |> validate_stream_contract(interfaces["stream_contract"] || %{})
      |> validate_command_contract(interfaces["command_contract"] || %{})
      |> validate_compatibility(interfaces)

    errors =
      Enum.reduce(records, errors, fn interface, acc ->
        acc
        |> require_fields(interface, ~w[id version owner milestone status consumers], "interface")
        |> require_semver(interface["version"], "#{interface["id"]} interface version")
        |> require_nonempty(interface["consumers"], "#{interface["id"]} consumers are empty")
      end)

    errors =
      Enum.reduce(routes, errors, fn route, acc ->
        acc
        |> require_fields(route, ~w[id class method path interface status], "route")
        |> require_member(route["class"], request_ids, "#{route["id"]} request class")
        |> require_member(route["interface"], interface_ids, "#{route["id"]} interface")
        |> validate_route_method(route, interfaces["request_classes"] || [])
      end)

    errors =
      Enum.reduce(signal_namespaces, errors, fn namespace, acc ->
        acc
        |> require_equal(namespace["authority"], false, "#{namespace["id"]} signal authority")
        |> require_nonempty(namespace["allowed"], "#{namespace["id"]} allowed signals are empty")
      end)

    consumers = interfaces["current_consumer_manifest"] || []

    errors =
      errors
      |> require_equal(length(consumers), 13, "current consumer count")
      |> require_unique(Enum.map(consumers, & &1["path"]), "current consumer path")
      |> require_equal(
        get_in(interfaces, ["removal_gate", "milestone_label_alone_sufficient"]),
        false,
        "milestone label removal"
      )
      |> require_nonempty(
        get_in(interfaces, ["removal_gate", "requires"]),
        "removal requirements are empty"
      )
      |> require_equal(
        length(interfaces["shared_file_ownership"] || []),
        10,
        "shared file ownership count"
      )

    Enum.reduce(consumers, errors, fn consumer, acc ->
      require_path(acc, root, consumer["path"], "current runtime consumer")
    end)
  end

  defp validate_stream_contract(errors, stream) do
    errors
    |> require_equal(stream["interface"], "hui.stream.v1", "stream interface")
    |> require_equal(stream["maximum_lifetime_seconds"], 900, "stream maximum lifetime")
    |> require_equal(
      stream["maximum_reauthorization_interval_seconds"],
      60,
      "stream reauthorization interval"
    )
    |> require_equal(
      stream["initial_state"],
      "current_authorized_snapshot",
      "stream initial state"
    )
    |> require_exact_set(
      stream["revocation_sources"] || [],
      @revocation_sources,
      "stream revocation"
    )
    |> require_equal(stream["before_patch"], "reauthorize_and_requery", "stream patch authority")
    |> require_nonempty(stream["terminal_actions"], "stream terminal actions are empty")
  end

  defp validate_command_contract(errors, command) do
    errors
    |> require_equal(command["interface"], "hui.command_adapter.v1", "command interface")
    |> require_nonempty(command["preview_fields"], "command preview fields are empty")
    |> require_nonempty(command["receipt_outcomes"], "command receipt outcomes are empty")
    |> require_nonempty(command["recovery_states"], "command recovery states are empty")
    |> require_equal(command["optimistic_success"], false, "command optimistic success")
  end

  defp validate_compatibility(errors, interfaces) do
    compatibility = interfaces["compatibility"] || %{}

    errors
    |> require_equal(compatibility["dual_write"], "prohibited", "dual write compatibility")
    |> require_contains(
      compatibility["dual_read"],
      "prohibited_for_browser_authority",
      "dual read compatibility"
    )
    |> require_contains(
      compatibility["feature_flags"],
      "selects_one_owner",
      "feature flag ownership"
    )
    |> require_text(compatibility["old_reader"], "old reader behavior")
    |> require_text(compatibility["deprecation_window"], "deprecation window")
  end

  defp validate_route_method(errors, route, request_classes) do
    methods =
      request_classes
      |> Enum.find(%{}, &(&1["id"] == route["class"]))
      |> Map.get("methods", [])

    require_member(errors, route["method"], methods, "#{route["id"]} method")
  end

  defp validate_evidence(errors, evidence, scenarios) do
    classes = evidence["evidence_classes"] || []
    seams = evidence["real_seams"] || []
    class_ids = Enum.map(classes, & &1["id"])
    seam_ids = Enum.map(seams, & &1["id"])

    errors =
      errors
      |> require_equal(evidence["schema_version"], 1, "evidence schema_version")
      |> require_equal(evidence["phase"], "HUI-A3", "evidence phase")
      |> require_exact_set(
        class_ids,
        scenarios["required_evidence_classes"] || [],
        "evidence classes"
      )
      |> require_unique(class_ids, "evidence class id")
      |> require_exact_set(
        seam_ids,
        scenarios["required_real_seams"] || [],
        "real seams"
      )
      |> require_unique(seam_ids, "real seam id")
      |> require_equal(
        get_in(evidence, ["qualification_identity", "digest_algorithm"]),
        "sha256",
        "evidence digest algorithm"
      )
      |> require_equal(
        get_in(evidence, ["qualification_identity", "nontransferable_on_change"]),
        true,
        "evidence qualification transfer"
      )
      |> require_equal(
        get_in(evidence, ["determinism", "timezone"]),
        "Etc/UTC",
        "evidence timezone"
      )
      |> require_equal(
        get_in(evidence, ["determinism", "secret_values_in_artifacts"]),
        false,
        "evidence secret retention"
      )
      |> require_exact_set(
        get_in(evidence, ["receipt_state_machine", "phase_a3_closure_checkboxes"]) || [],
        @closure_checkboxes,
        "closure checkboxes"
      )
      |> require_equal(
        get_in(evidence, ["receipt_state_machine", "mixed_state"]),
        "invalid",
        "mixed closure state"
      )
      |> require_equal(
        get_in(evidence, ["reopening_rules", "preserve_verbatim_at_closure"]),
        true,
        "reopening condition preservation"
      )

    errors =
      Enum.reduce(classes, errors, fn class, acc ->
        acc
        |> require_text(class["owner"], "#{class["id"]} evidence owner")
        |> require_text(class["independent_reviewer"], "#{class["id"]} reviewer")
        |> require_nonempty(class["required_artifacts"], "#{class["id"]} artifacts are empty")
        |> require_text(class["mock_limit"], "#{class["id"]} mock limit")
      end)

    errors =
      case Enum.find(classes, &(&1["id"] == "real_adapter")) do
        %{"real_required" => true, "mock_limit" => "no_fake_may_satisfy_this_class"} ->
          errors

        _other ->
          ["real adapter evidence must require a real seam and reject fake replacement" | errors]
      end

    Enum.reduce(seams, errors, fn seam, acc ->
      acc
      |> require_text(seam["requires"], "#{seam["id"]} real seam requirement")
      |> require_equal(
        seam["fake_replacement"],
        false,
        "#{seam["id"]} real seam fake replacement"
      )
    end)
  end

  defp validate_documents(errors, scenarios, root) do
    required = scenarios["required_documents"] || []

    errors = Enum.reduce(required, errors, &require_path(&2, root, &1, "HUI-A3 document"))

    errors =
      Enum.reduce(required, errors, fn path, acc ->
        case File.read(Path.join(root, path)) do
          {:ok, body} -> validate_markdown_links(acc, root, path, body)
          {:error, _reason} -> acc
        end
      end)

    errors =
      Enum.reduce(@accepted_documents, errors, fn {path, accepted_status}, acc ->
        require_contains(acc, read(root, path), accepted_status, "#{path} accepted status")
      end)

    errors =
      Enum.reduce(scenarios["normative_presentation_documents"] || [], errors, fn path, acc ->
        body = read(root, path)

        Enum.reduce(scenarios["prohibited_normative_phrases"] || [], acc, fn phrase,
                                                                             phrase_errors ->
          require_not_contains(
            phrase_errors,
            body,
            phrase,
            "#{path} retains prohibited target ownership phrase #{inspect(phrase)}"
          )
        end)
      end)

    plan =
      read(
        root,
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/phase-03-runtime-contract-supersession-and-interface-freeze.md"
      )

    receipt = read(root, "docs/architecture/hypermedia-ui-milestone-a-phase-03-receipt.md")

    errors
    |> require_contains(plan, "- [x] 3.1 Section", "Phase 3 Section 3.1 checkbox")
    |> require_contains(plan, "- [x] 3.2 Section", "Phase 3 Section 3.2 checkbox")
    |> require_contains(plan, "- [x] 3.3 Section", "Phase 3 Section 3.3 checkbox")
    |> require_contains(plan, "- [x] 3.4.1 Task", "Phase 3 integration task checkbox")
    |> require_contains(plan, "- [x] 3.4.2.1 Subtask", "Phase 3 receipt invariant checkbox")
    |> require_contains(plan, "- [x] 3.4.2.2 Subtask", "Phase 3 receipt evidence checkbox")
    |> then(&(&1 ++ validate_closure(plan, receipt)))
  end

  defp validate_closure_checkboxes(errors, plan, checked?) do
    Enum.reduce(@closure_checkboxes, errors, fn id, acc ->
      label = closure_label(id)
      wanted = "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}"
      unwanted = "- [#{if(checked?, do: " ", else: "x")}] #{id} #{label}"

      acc
      |> require_contains(plan, wanted, "HUI-A3 #{id} closure checkbox")
      |> require_not_contains(plan, unwanted, "HUI-A3 #{id} mixed closure checkbox")
    end)
  end

  defp closure_label("3"), do: "Phase"
  defp closure_label("3.4"), do: "Section"
  defp closure_label("3.4.2"), do: "Task"
  defp closure_label("3.4.2.3"), do: "Subtask"

  defp validate_accepted_candidate(errors, receipt) do
    table_sha = capture(receipt, ~r/\| Merged candidate \| `([0-9a-f]{40})` \|/)
    metadata_sha = capture(receipt, ~r/Merged candidate: `([0-9a-f]{40})`/)
    merge_date = capture(receipt, ~r/Merge date: `(\d{4}-\d{2}-\d{2})`/)

    errors
    |> require_sha(table_sha, "HUI-A3 merged candidate table")
    |> require_sha(metadata_sha, "HUI-A3 merged candidate metadata")
    |> require_equal(metadata_sha, table_sha, "HUI-A3 merged candidate consistency")
    |> require_date(merge_date, "HUI-A3 merge date")
    |> require_contains(
      receipt,
      "Gate HUI-A3\n\nStatus: **accepted-at-merged-candidate**",
      "HUI-A3 accepted gate"
    )
  end

  defp validate_markdown_links(errors, root, source_path, body) do
    Regex.scan(~r/\[[^\]]+\]\(([^)]+)\)/, body, capture: :all_but_first)
    |> Enum.reduce(errors, fn [target], acc ->
      target = target |> String.split("#", parts: 2) |> hd()

      cond do
        target == "" ->
          acc

        String.starts_with?(target, ["http://", "https://", "mailto:"]) ->
          acc

        true ->
          resolved = Path.expand(target, Path.dirname(Path.join(root, source_path)))

          if File.exists?(resolved),
            do: acc,
            else: ["#{source_path} link target does not exist: #{target}" | acc]
      end
    end)
  end

  defp require_source_pattern(errors, root, path, label) when is_binary(path) do
    if String.contains?(path, "*") do
      matches = Path.wildcard(Path.join(root, path))
      if matches == [], do: ["#{label} does not match any files: #{path}" | errors], else: errors
    else
      require_path(errors, root, path, label)
    end
  end

  defp require_source_pattern(errors, _root, path, label),
    do: ["#{label} is invalid: #{inspect(path)}" | errors]

  defp require_path(errors, root, path, label) do
    if is_binary(path) and File.exists?(Path.join(root, path)),
      do: errors,
      else: ["#{label} does not exist: #{inspect(path)}" | errors]
  end

  defp require_fields(errors, map, fields, label) do
    Enum.reduce(fields, errors, fn field, acc ->
      require_present(acc, map[field], "#{label} is missing #{field}")
    end)
  end

  defp require_present(errors, value, message) do
    if present?(value), do: errors, else: [message | errors]
  end

  defp require_text(errors, value, label),
    do: require_present(errors, value, "#{label} must be non-empty text")

  defp require_nonempty(errors, value, message) when is_list(value) do
    if value == [], do: [message | errors], else: errors
  end

  defp require_nonempty(errors, _value, message), do: [message | errors]

  defp require_unique(errors, values, label) do
    duplicates = values -- Enum.uniq(values)

    Enum.reduce(Enum.uniq(duplicates), errors, fn value, acc ->
      ["duplicate #{label}: #{inspect(value)}" | acc]
    end)
  end

  defp require_exact_ids(errors, values, expected, label) when is_list(values) do
    require_exact_set(errors, Enum.map(values, & &1["id"]), expected, "#{label} ids")
  end

  defp require_exact_ids(errors, _values, _expected, label),
    do: ["#{label} records are missing" | errors]

  defp require_exact_set(errors, actual, expected, label) do
    actual_set = MapSet.new(actual)
    expected_set = MapSet.new(expected)

    if actual_set == expected_set and length(actual) == length(expected),
      do: errors,
      else: [
        "#{label}; expected #{inspect(Enum.sort(expected))}, got #{inspect(Enum.sort(actual))}"
        | errors
      ]
  end

  defp require_subset(errors, values, allowed, label) do
    unexpected = MapSet.difference(MapSet.new(values), MapSet.new(allowed)) |> MapSet.to_list()

    if unexpected == [],
      do: errors,
      else: ["#{label} has unknown values: #{inspect(unexpected)}" | errors]
  end

  defp require_member(errors, value, allowed, label) do
    if value in allowed, do: errors, else: ["#{label} is invalid: #{inspect(value)}" | errors]
  end

  defp require_absent(errors, values, value, message) do
    if value in values, do: [message | errors], else: errors
  end

  defp require_equal(errors, actual, expected, message) do
    if actual == expected,
      do: errors,
      else: ["#{message}; expected #{inspect(expected)}, got #{inspect(actual)}" | errors]
  end

  defp require_contains(errors, value, substring, message) do
    if is_binary(value) and String.contains?(value, substring),
      do: errors,
      else: [message | errors]
  end

  defp require_not_contains(errors, value, substring, message) do
    if is_binary(value) and not String.contains?(value, substring),
      do: errors,
      else: [message | errors]
  end

  defp require_semver(errors, value, label) do
    if is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value),
      do: errors,
      else: ["#{label} must be semantic version text" | errors]
  end

  defp require_sha(errors, value, label) do
    if is_binary(value) and Regex.match?(~r/^[0-9a-f]{40}$/, value),
      do: errors,
      else: ["#{label} must be a full lowercase Git SHA" | errors]
  end

  defp require_date(errors, value, label) do
    case is_binary(value) && Date.from_iso8601(value) do
      {:ok, _date} -> errors
      _other -> ["#{label} must be an ISO date" | errors]
    end
  end

  defp capture(body, regex) do
    case Regex.run(regex, body, capture: :all_but_first) do
      [value] -> value
      _other -> nil
    end
  end

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, _reason} -> ""
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)
end

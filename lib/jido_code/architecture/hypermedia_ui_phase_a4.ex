defmodule JidoCode.Architecture.HypermediaUIPhaseA4 do
  @moduledoc false

  @manifest_directory "priv/architecture/hypermedia_ui"
  @manifest_files %{
    acceptance: "phase_a4_acceptance_matrix.json",
    dossier: "phase_a4_authority_dossier.json",
    guardrails: "phase_a4_governance_guardrails.json",
    traceability: "phase_a4_program_traceability.json"
  }
  @program_directory "docs/planning/secure-hypermedia-control-plane-ui"
  @source_globs [
    "mix.exs",
    "lib/jido_code_web/**/*.ex",
    "lib/jido_code_web/**/*.heex",
    "assets/**/*.css",
    "assets/**/*.js",
    "assets/**/*.mjs",
    "assets/**/*.ts",
    "assets/**/*.vue"
  ]
  @exception_fields ~w[id owner reason path symbol rules expires_on evidence reopening_condition sha256]
  @mapping_fields ~w[id authority_owner owner_documents milestone phase_task test_evidence_class reopening_condition]
  @consumer_fields ~w[path current_kind target_disposition replacement_owner removal_owner evidence reopening_condition]
  @surface_fields ~w[id interface authority_builder authorization_points safe_outcomes implementation_owner evidence reopening_condition]
  @coverage_classes ~w[
    runtime dependency asset identity authority query command stream export documentation
    receipt concurrency
  ]
  @contract_fields ~w[
    kind interface authority_builder exact_resource_action query_catalog concealment redaction
    stable_dom csrf_origin command_gateway receipt native_fallback availability
  ]
  @closure_checkboxes ~w[4 4.4 4.4.2 4.4.2.3]
  @hui_b2_manifest "priv/architecture/hypermedia_ui/phase_b2_dependency_graph.json"
  @hui_b2_baseline "da9776d49d9e2f9d487294292e7643355576902d"
  @hui_b2_legacy_paths ~w[
    mix.exs
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/components/ui.ex
    lib/jido_code_web/components/layouts.ex
    assets/js/app.js
    assets/css/app.css
  ]

  @source_rules [
    {:product_liveview, [".ex", ".exs"],
     ~r/(?:use\s+(?:JidoCodeWeb,\s*:live_view|Phoenix\.LiveView)|defmodule\s+\S+Live\b|\blive_session\b|\blive\s+"|Phoenix\.LiveView\.Socket|\blive_render\b)/,
     "target product code cannot add a LiveView route, module, session, socket, or render"},
    {:product_livecomponent, [".ex", ".exs"],
     ~r/(?:JidoCodeWeb,\s*:live_component|Phoenix\.LiveComponent)/,
     "target product code cannot add a LiveComponent"},
    {:liveview_event_or_stream, [".ex", ".exs", ".heex"],
     ~r/(?:\bhandle_event\s*\(|\bstream\s*\(|phx-(?:click|submit|change|update|hook)\s*=)/,
     "target product code cannot add LiveView events, streams, or hooks"},
    {:livevue_bridge, [".ex", ".exs", ".js", ".mjs", ".ts", ".vue"], ~r/(?:LiveVue|live_vue)/,
     "target product code cannot add a LiveVue bridge"},
    {:saladui_import, [".ex", ".exs", ".js", ".mjs", ".ts", ".vue", ".css"],
     ~r/(?:SaladUI|salad_ui)/, "target product code cannot add a SaladUI consumer"},
    {:unauthorized_dashboard, [".ex", ".exs"], ~r/\blive_dashboard\b/,
     "LiveDashboard requires the recorded development-only exception"},
    {:inline_script, [".heex"], ~r/<script(?:\s|>)/i,
     "HEEx templates cannot contain inline scripts"},
    {:remote_product_asset, [".heex", ".css", ".js", ".mjs", ".ts"],
     ~r/(?:<(?:script|link)[^>]+(?:src|href)=["']https?:\/\/|@import\s+(?:url\()?['"]?https?:\/\/)/i,
     "product assets must be pinned and served from local bundles"},
    {:raw_knowledge_access, [".ex", ".exs", ".heex", ".js", ".mjs", ".ts", ".vue"],
     ~r/(?:JidoCode\.Knowledge\.(?:Backend|Internal|StoreServer)|\b(?:SELECT\s+.+\s+WHERE|ASK|CONSTRUCT|INSERT\s+DATA|DELETE\s+(?:DATA|WHERE))\s*\{)/is,
     "product code must use a reviewed projection or command contract"},
    {:direct_graph_write, [".ex", ".exs"],
     ~r/(?:TripleStore|JidoCode\.Knowledge\.(?:Writer|WriteBatch)|\bWriter\.commit\s*\(|\bWriteBatch\.new\s*\()/,
     "product code cannot access TripleStore or graph write primitives directly"},
    {:caller_selected_graph, [".ex", ".exs", ".js", ".mjs", ".ts", ".vue"],
     ~r/(?:params|signals?|body|query)[^\n]{0,120}(?:graph_(?:iri|grant)|graphs?\[|expected_revision|policy_revision)/i,
     "graph grants, graph targets, and authoritative revisions must be server-owned"},
    {:browser_derived_authority, [".js", ".mjs", ".ts", ".vue"],
     ~r/(?:localStorage|sessionStorage|signals?)[^\n]{0,160}(?:grant|authority|assurance|delegation|policy_revision|expected_revision)/i,
     "browser state cannot create grants, authority, assurance, delegation, or revisions"},
    {:get_effect, [".ex", ".exs"],
     ~r/\bget\s*\(?\s*"[^"]+"\s*,[^\n]+:(?:create|update|delete|apply|execute|control|approve|reject|cancel|retry|regenerate|save|start|stop|resume)\b/,
     "GET routes cannot perform semantic effects"},
    {:direct_runtime_effect, [".ex", ".exs"], ~r/JidoCode\.Runtime(?:\.|\b)/,
     "web product code must reach runtime effects only through the governed command gateway"}
  ]

  @type manifests :: %{acceptance: map(), dossier: map(), guardrails: map(), traceability: map()}

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

        with {:ok, body} <- File.read(path),
             {:ok, manifest} <- Jason.decode(body) do
          {Map.put(loaded, key, manifest), errors}
        else
          {:error, %Jason.DecodeError{} = reason} ->
            {loaded, ["#{path}: invalid JSON: #{Exception.message(reason)}" | errors]}

          {:error, reason} ->
            {loaded, ["#{path}: cannot read manifest: #{inspect(reason)}" | errors]}
        end
      end)

    if errors == [], do: {:ok, manifests}, else: {:error, Enum.reverse(errors)}
  end

  @spec validate(manifests(), Path.t()) :: [String.t()]
  def validate(
        %{
          acceptance: acceptance,
          dossier: dossier,
          guardrails: guardrails,
          traceability: traceability
        },
        root
      ) do
    []
    |> validate_guardrails(guardrails, root)
    |> validate_program_traceability(traceability, root)
    |> validate_dossier(dossier, guardrails, root)
    |> validate_acceptance(acceptance, root)
    |> validate_product_sources(guardrails, root)
    |> Enum.reverse()
  end

  def validate(_incomplete, _root), do: ["HUI-A4 manifest set is incomplete"]

  defp validate_acceptance(errors, acceptance, root) do
    coverage = acceptance["coverage"] || []
    failures = acceptance["failure_scenarios"] || []
    failure_ids = Enum.map(failures, & &1["id"])

    errors =
      errors
      |> require_equal(acceptance["schema_version"], 1, "acceptance matrix schema_version")
      |> require_equal(acceptance["phase"], "HUI-A4", "acceptance matrix phase")
      |> require_equal(
        get_in(acceptance, ["baseline", "closure_commit"]),
        "e9da1fe3a9f0a1017f35fcb29136f390e2da954f",
        "acceptance matrix baseline"
      )
      |> require_exact_set(
        Enum.map(coverage, & &1["class"]),
        @coverage_classes,
        "acceptance coverage classes"
      )
      |> require_unique(Enum.map(coverage, & &1["class"]), "acceptance coverage class")
      |> require_exact_set(
        failure_ids,
        ~w[stale_receipt missing_receipt duplicate_anchor broken_dependency missing_integration_section unowned_requirement silent_supersession expired_exception parallel_version_race],
        "acceptance failure scenarios"
      )
      |> require_unique(failure_ids, "acceptance failure scenario")
      |> require_equal(
        get_in(acceptance, ["reproduction", "target_implementation_added"]),
        false,
        "Milestone A target implementation"
      )
      |> require_equal(
        get_in(acceptance, ["reproduction", "unsupported_readiness_claim"]),
        false,
        "Milestone A readiness claim"
      )
      |> require_member(
        "mix architecture.check",
        get_in(acceptance, ["reproduction", "commands"]) || [],
        "architecture reproduction command"
      )
      |> require_member(
        "mix precommit",
        get_in(acceptance, ["reproduction", "commands"]) || [],
        "precommit reproduction command"
      )

    errors =
      Enum.reduce(coverage, errors, fn record, acc ->
        acc
        |> require_nonempty(record["allowed"], "#{record["class"]} allowed coverage is empty")
        |> require_nonempty(
          record["prohibited"],
          "#{record["class"]} prohibited coverage is empty"
        )
        |> require_nonempty(record["evidence"], "#{record["class"]} evidence is empty")
      end)

    Enum.reduce(acceptance["source_documents"] || [], errors, fn path, acc ->
      require_path(acc, root, path, "acceptance source document")
    end)
  end

  defp validate_dossier(errors, dossier, guardrails, root) do
    consumers = dossier["consumer_reconciliation"] || []
    surfaces = dossier["surface_authority_reconciliation"] || []
    proposals = dossier["proposal_dispositions"] || []
    risks = dossier["residual_risks"] || []
    blockers = dossier["milestone_b_blockers"] || []

    interface_registry =
      read_json!(root, "priv/architecture/hypermedia_ui/phase_a3_interface_registry.json")

    expected_consumers =
      Enum.map(interface_registry["current_consumer_manifest"] || [], & &1["path"])

    exception_ids = Enum.map(guardrails["exceptions"] || [], & &1["id"])

    errors =
      errors
      |> require_equal(dossier["schema_version"], 1, "authority dossier schema_version")
      |> require_equal(dossier["phase"], "HUI-A4", "authority dossier phase")
      |> require_equal(
        get_in(dossier, ["baseline", "closure_commit"]),
        "e9da1fe3a9f0a1017f35fcb29136f390e2da954f",
        "authority dossier baseline"
      )
      |> require_exact_set(
        Enum.map(consumers, & &1["path"]),
        expected_consumers,
        "current consumer reconciliation"
      )
      |> require_unique(Enum.map(consumers, & &1["path"]), "consumer reconciliation path")
      |> require_exact_set(
        Enum.map(surfaces, & &1["id"]),
        ~w[page fragment stream command approval export incident revocation],
        "surface authority reconciliation"
      )
      |> require_exact_set(
        get_in(dossier, ["exception_register", "ids"]) || [],
        exception_ids,
        "dossier exception register"
      )
      |> require_equal(
        get_in(dossier, ["exception_register", "count"]),
        length(exception_ids),
        "dossier exception count"
      )
      |> require_nonempty(proposals, "proposal disposition register is missing")
      |> require_nonempty(risks, "residual risk register is missing")
      |> require_nonempty(blockers, "Milestone B blocker register is missing")
      |> require_exact_set(
        Enum.map(proposals, & &1["disposition"]),
        ~w[accepted deferred rejected],
        "proposal disposition classes"
      )

    errors =
      Enum.reduce(consumers, errors, fn consumer, acc ->
        require_fields(acc, consumer, @consumer_fields, "consumer #{consumer["path"]}")
      end)

    errors =
      Enum.reduce(surfaces, errors, fn surface, acc ->
        acc
        |> require_fields(surface, @surface_fields, "surface #{surface["id"]}")
        |> require_nonempty(
          surface["authorization_points"],
          "#{surface["id"]} authorization points are empty"
        )
        |> require_nonempty(surface["safe_outcomes"], "#{surface["id"]} safe outcomes are empty")
      end)

    errors =
      Enum.reduce(proposals, errors, fn proposal, acc ->
        acc
        |> require_fields(
          proposal,
          ~w[id item disposition owner evidence reopening_condition],
          "proposal #{proposal["id"]}"
        )
        |> require_member(
          proposal["disposition"],
          ~w[accepted deferred rejected],
          "#{proposal["id"]} disposition"
        )
      end)

    errors =
      Enum.reduce(risks, errors, fn risk, acc ->
        require_fields(
          acc,
          risk,
          ~w[id severity owner status mitigation expiry reopening_condition],
          "risk #{risk["id"]}"
        )
      end)

    errors =
      Enum.reduce(blockers, errors, fn blocker, acc ->
        acc
        |> require_fields(
          blocker,
          ~w[id owner required_evidence status reopening_condition],
          "Milestone B blocker #{blocker["id"]}"
        )
        |> require_equal(blocker["status"], "blocking", "#{blocker["id"]} blocker status")
      end)

    plan =
      read(
        root,
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/phase-04-governance-guardrails-and-authority-acceptance.md"
      )

    milestone_plan =
      read(
        root,
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/README.md"
      )

    receipt =
      read(root, "docs/architecture/hypermedia-ui-milestone-a-phase-04-receipt.md")

    errors
    |> require_path(
      root,
      "docs/architecture/hypermedia-ui-milestone-a-authority-dossier.md",
      "Milestone A authority dossier"
    )
    |> then(&(&1 ++ validate_closure(plan, milestone_plan, receipt)))
  end

  @spec check_sources([{String.t(), String.t()}], keyword()) ::
          {:ok, []} | {:error, [String.t()]}
  def check_sources(sources, opts \\ []) when is_list(sources) do
    exceptions = Keyword.get(opts, :exceptions, [])
    today = Keyword.get(opts, :today, Date.utc_today())

    exception_by_path = Map.new(exceptions, &{&1["path"], &1})

    errors =
      sources
      |> Enum.flat_map(fn {path, source} ->
        case exception_by_path[path] do
          nil ->
            analyze_source(path, source)

          exception ->
            if exception_applies?(exception, source, today),
              do: [],
              else: analyze_source(path, source)
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    if errors == [], do: {:ok, []}, else: {:error, errors}
  end

  @spec validate_closure(String.t(), String.t(), String.t()) :: [String.t()]
  def validate_closure(plan, milestone_plan, receipt) do
    accepted? = String.contains?(receipt, "Status: **accepted-at-merged-candidate**")
    merge_pending? = String.contains?(receipt, "Status: **merge-pending**")

    cond do
      accepted? and not merge_pending? ->
        []
        |> require_contains(plan, "status: completed", "HUI-A4 completed plan status")
        |> require_contains(milestone_plan, "status: completed", "Milestone A completed status")
        |> validate_closure_checkboxes(plan, true)
        |> require_merged_candidate(receipt)

      merge_pending? and not accepted? ->
        []
        |> require_contains(plan, "status: proposed", "HUI-A4 proposed plan status")
        |> require_contains(milestone_plan, "status: proposed", "Milestone A proposed status")
        |> validate_closure_checkboxes(plan, false)
        |> require_contains(
          receipt,
          "| Merged candidate | `merge-pending` |",
          "HUI-A4 merge-pending candidate table"
        )
        |> require_contains(
          receipt,
          "Merged candidate: `merge-pending`",
          "HUI-A4 merge-pending metadata"
        )
        |> require_contains(receipt, "Merge date: `merge-pending`", "HUI-A4 merge-pending date")

      true ->
        ["HUI-A4 closure must have exactly one coherent receipt state"]
    end
  end

  @spec validate_plan_sources([{String.t(), String.t()}], Path.t()) :: [String.t()]
  def validate_plan_sources(bodies, root) when is_list(bodies) do
    task_anchors = Enum.flat_map(bodies, fn {_path, body} -> task_anchors(body) end)
    dependencies = Enum.flat_map(bodies, fn {_path, body} -> dependency_anchors(body) end)

    []
    |> validate_plan_source_set(bodies, task_anchors, dependencies, root)
    |> Enum.reverse()
  end

  @spec validate_program(map(), Path.t()) :: [String.t()]
  def validate_program(traceability, root \\ File.cwd!()) do
    []
    |> validate_program_traceability(traceability, root)
    |> Enum.reverse()
  end

  defp validate_guardrails(errors, guardrails, root) do
    exceptions = guardrails["exceptions"] || []
    rule_ids = Enum.map(guardrails["rules"] || [], & &1["id"])
    authorized_paths = authorized_hui_b2_legacy_paths(root)

    implemented_rules =
      Enum.map(@source_rules, &(&1 |> elem(0) |> Atom.to_string())) ++
        ["target_surface_contract"]

    errors =
      errors
      |> require_equal(guardrails["schema_version"], 1, "guardrail schema_version")
      |> require_equal(guardrails["phase"], "HUI-A4", "guardrail phase")
      |> require_equal(
        get_in(guardrails, ["baseline", "closure_commit"]),
        "e9da1fe3a9f0a1017f35fcb29136f390e2da954f",
        "HUI-A4 closure baseline"
      )
      |> require_exact_set(rule_ids, implemented_rules, "guardrail rule registry")
      |> require_unique(rule_ids, "guardrail rule id")
      |> require_unique(Enum.map(exceptions, & &1["id"]), "exception id")
      |> require_unique(Enum.map(exceptions, & &1["path"]), "exception path")
      |> require_equal(
        get_in(guardrails, ["exception_policy", "broad_paths_allowed"]),
        false,
        "broad exception paths"
      )
      |> require_equal(
        get_in(guardrails, ["target_surface_contract", "required_fields"]),
        @contract_fields,
        "target surface contract fields"
      )

    Enum.reduce(exceptions, errors, fn exception, acc ->
      acc
      |> require_fields(exception, @exception_fields, "exception #{exception["id"]}")
      |> require_regular_file(root, exception["path"], "exception path")
      |> require_digest(root, exception, authorized_paths)
      |> require_future_date(exception["expires_on"], "exception #{exception["id"]} expiry")
      |> require_subset(exception["rules"] || [], rule_ids, "exception #{exception["id"]} rules")
    end)
  end

  defp validate_program_traceability(errors, traceability, root) do
    program_root = Path.join(root, @program_directory)
    expected_milestones = traceability["milestones"] || []
    expected_names = Enum.map(expected_milestones, & &1["directory"])

    actual_names =
      program_root
      |> Path.join("milestone-*")
      |> Path.wildcard()
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(&Path.basename/1)
      |> Enum.sort()

    phase_files =
      program_root
      |> Path.join("milestone-*/phase-*.md")
      |> Path.wildcard()
      |> Enum.sort()

    bodies = Enum.map(phase_files, &{Path.relative_to(&1, root), File.read!(&1)})
    task_anchors = Enum.flat_map(bodies, fn {_path, body} -> task_anchors(body) end)
    dependencies = Enum.flat_map(bodies, fn {_path, body} -> dependency_anchors(body) end)

    errors =
      errors
      |> require_equal(traceability["schema_version"], 1, "program traceability schema_version")
      |> require_equal(traceability["phase"], "HUI-A4", "program traceability phase")
      |> require_equal(actual_names, Enum.sort(expected_names), "milestone directory inventory")
      |> require_equal(length(phase_files), 37, "program phase-file count")
      |> require_equal(
        Enum.sum(Enum.map(expected_milestones, & &1["phase_count"])),
        37,
        "declared phase-file count"
      )
      |> require_equal(
        get_in(traceability, ["parallel_version_policy", "caller_selected_versions"]),
        false,
        "caller-selected interface versions"
      )
      |> require_equal(
        get_in(traceability, ["parallel_version_policy", "shared_mutable_browser_authority"]),
        false,
        "shared mutable browser authority"
      )
      |> require_equal(
        get_in(traceability, ["parallel_version_policy", "conflict_outcome"]),
        "explicit_conflict_receipt",
        "parallel version conflict outcome"
      )
      |> validate_plan_source_set(bodies, task_anchors, dependencies, root)
      |> validate_milestone_phase_counts(program_root, expected_milestones)
      |> validate_requirement_mappings(traceability, task_anchors, root)
      |> validate_completed_receipts(bodies, root)

    validate_milestone_sources(errors, expected_milestones, program_root, root)
  end

  defp validate_plan_source_set(errors, bodies, task_anchors, dependencies, root) do
    errors
    |> require_unique(task_anchors, "task anchor")
    |> require_subset(dependencies, task_anchors, "plan dependency anchors")
    |> require_equal(
      Enum.count(task_anchors, &String.ends_with?(&1, "phase-receipt")),
      length(bodies),
      "unique phase receipt anchors"
    )
    |> validate_phase_files(bodies, root)
  end

  defp validate_milestone_phase_counts(errors, program_root, milestones) do
    Enum.reduce(milestones, errors, fn milestone, acc ->
      count =
        program_root
        |> Path.join(milestone["directory"])
        |> Path.join("phase-*.md")
        |> Path.wildcard()
        |> length()

      require_equal(acc, count, milestone["phase_count"], "#{milestone["directory"]} phase count")
    end)
  end

  defp validate_phase_files(errors, bodies, root) do
    Enum.reduce(bodies, errors, fn {path, body}, acc ->
      receipt_count =
        body |> task_anchors() |> Enum.count(&String.ends_with?(&1, "phase-receipt"))

      acc
      |> require_match(
        body,
        ~r/^id: plan\.jido_code_hypermedia_ui_milestone_[a-h]_phase_\d{2}$/m,
        "#{path} stable plan id"
      )
      |> require_match(
        body,
        ~r/^parent_plan: plan\.jido_code_hypermedia_ui_milestone_[a-h]$/m,
        "#{path} parent plan"
      )
      |> require_match(body, ~r/^status: (?:proposed|completed)$/m, "#{path} status")
      |> require_match(
        body,
        ~r/\d+\.\d+ Section - Phase \d+ Integration Tests/,
        "#{path} final integration section"
      )
      |> require_equal(receipt_count, 1, "#{path} receipt task count")
      |> validate_markdown_links(root, path, body)
    end)
  end

  defp validate_requirement_mappings(errors, traceability, task_anchors, root) do
    requirements = traceability["requirements"] || []
    gaps = traceability["gap_mappings"] || []

    baseline_gaps =
      read_json!(root, "priv/architecture/hypermedia_ui/phase_a1_runtime_inventory.json")["gaps"] ||
        []

    baseline_gap_ids = Enum.map(baseline_gaps, & &1["id"])

    errors =
      errors
      |> require_nonempty(requirements, "program requirements are missing")
      |> require_exact_set(Enum.map(gaps, & &1["id"]), baseline_gap_ids, "HUI gap mapping")
      |> require_unique(Enum.map(requirements ++ gaps, & &1["id"]), "requirement or gap id")

    Enum.reduce(requirements ++ gaps, errors, fn mapping, acc ->
      acc =
        acc
        |> require_fields(mapping, @mapping_fields, "traceability #{mapping["id"]}")
        |> require_member(mapping["phase_task"], task_anchors, "#{mapping["id"]} phase task")
        |> require_match(
          mapping["milestone"],
          ~r/^HUI-[A-H](?:,HUI-[A-H])*$/,
          "#{mapping["id"]} milestone owner"
        )

      Enum.reduce(mapping["owner_documents"] || [], acc, fn path, doc_errors ->
        require_path(doc_errors, root, path, "#{mapping["id"]} owner document")
      end)
    end)
  end

  defp validate_completed_receipts(errors, bodies, root) do
    Enum.reduce(bodies, errors, fn {path, body}, acc ->
      if frontmatter_value(body, "status") == "completed" do
        receipt_path = receipt_path_for_plan(path)
        receipt = read(root, receipt_path)

        acc
        |> require_contains(
          receipt,
          "Status: **accepted-at-merged-candidate**",
          "#{path} accepted receipt"
        )
        |> require_match(
          receipt,
          ~r/Merged candidate[^\n]*[0-9a-f]{40}/,
          "#{path} pinned merged candidate"
        )
        |> require_match(
          receipt,
          ~r/(?:merged(?: on)?|Merge date:)[^\n]*\d{4}-\d{2}-\d{2}/,
          "#{path} pinned merge date"
        )
      else
        acc
      end
    end)
  end

  defp validate_milestone_sources(errors, milestones, program_root, root) do
    Enum.reduce(milestones, errors, fn milestone, acc ->
      path = Path.join([program_root, milestone["directory"], "README.md"])
      relative = Path.relative_to(path, root)
      body = read(root, relative)

      acc
      |> require_match(
        body,
        ~r/^id: plan\.jido_code_hypermedia_ui_milestone_[a-h]$/m,
        "#{relative} milestone id"
      )
      |> validate_markdown_links(root, relative, body)
    end)
  end

  defp validate_product_sources(errors, guardrails, root) do
    sources =
      @source_globs
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.uniq()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&{Path.relative_to(&1, root), File.read!(&1)})

    authorized_paths = authorized_hui_b2_legacy_paths(root)

    exceptions =
      Enum.map(guardrails["exceptions"] || [], fn exception ->
        if exception["path"] in authorized_paths do
          source = read(root, exception["path"])
          Map.put(exception, "sha256", sha256(source))
        else
          exception
        end
      end)

    case check_sources(sources, exceptions: exceptions) do
      {:ok, []} -> errors
      {:error, source_errors} -> Enum.reverse(source_errors) ++ errors
    end
  end

  defp analyze_source(path, source) do
    extension = Path.extname(path)

    pattern_errors =
      Enum.flat_map(@source_rules, fn {rule, extensions, regex, message} ->
        if extension in extensions and Regex.match?(regex, source) do
          [format_error(path, matching_line(source, regex), rule, message)]
        else
          []
        end
      end)

    path_errors =
      if String.starts_with?(path, "assets/vue/") do
        [format_error(path, 1, :livevue_bridge, "target product code cannot add Vue sources")]
      else
        []
      end

    contract_errors =
      if target_surface?(path, source) do
        missing =
          Enum.reject(@contract_fields, &Regex.match?(~r/\b#{Regex.escape(&1)}\s*:/, source))

        Enum.map(missing, fn field ->
          format_error(
            path,
            1,
            :target_surface_contract,
            "hypermedia contract is missing #{field}"
          )
        end)
      else
        []
      end

    pattern_errors ++ path_errors ++ contract_errors
  end

  defp target_surface?(path, source) do
    String.contains?(path, "/hypermedia/") or String.contains?(source, "@hypermedia_contract")
  end

  defp exception_applies?(exception, source, today) do
    with {:ok, expiry} <- Date.from_iso8601(exception["expires_on"] || ""),
         true <- Date.compare(expiry, today) in [:gt, :eq],
         true <- sha256(source) == exception["sha256"] do
      true
    else
      _other -> false
    end
  end

  defp validate_closure_checkboxes(errors, plan, checked?) do
    Enum.reduce(@closure_checkboxes, errors, fn id, acc ->
      label = closure_label(id)
      wanted = "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}"
      unwanted = "- [#{if(checked?, do: " ", else: "x")}] #{id} #{label}"

      acc
      |> require_contains(plan, wanted, "HUI-A4 #{id} closure checkbox")
      |> require_not_contains(plan, unwanted, "HUI-A4 #{id} mixed closure checkbox")
    end)
  end

  defp closure_label("4"), do: "Phase"
  defp closure_label("4.4"), do: "Section"
  defp closure_label("4.4.2"), do: "Task"
  defp closure_label("4.4.2.3"), do: "Subtask"

  defp require_merged_candidate(errors, receipt) do
    errors
    |> require_match(
      receipt,
      ~r/\| Merged candidate \| `[0-9a-f]{40}` \|/,
      "HUI-A4 accepted candidate table"
    )
    |> require_match(
      receipt,
      ~r/Merged candidate: `[0-9a-f]{40}`/,
      "HUI-A4 accepted candidate metadata"
    )
    |> require_match(receipt, ~r/Merge date: `\d{4}-\d{2}-\d{2}`/, "HUI-A4 accepted merge date")
  end

  defp task_anchors(body) do
    ~r/Task \{#([A-Za-z0-9_-]+)\}/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(&List.first/1)
  end

  defp dependency_anchors(body) do
    ~r/\[after: ([^\]]+)\]/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.flat_map(fn [contents] ->
      ~r/\{#([A-Za-z0-9_-]+)\}/
      |> Regex.scan(contents, capture: :all_but_first)
      |> Enum.map(&List.first/1)
    end)
  end

  defp receipt_path_for_plan(path) do
    [_, letter] = Regex.run(~r/milestone-([a-h])-/, path)
    [_, phase] = Regex.run(~r/phase-(\d{2})-/, path)
    "docs/architecture/hypermedia-ui-milestone-#{letter}-phase-#{phase}-receipt.md"
  end

  defp frontmatter_value(body, key) do
    case Regex.run(~r/^#{Regex.escape(key)}:\s*(.+)$/m, body, capture: :all_but_first) do
      [value] -> String.trim(value)
      _other -> nil
    end
  end

  defp validate_markdown_links(errors, root, source, body) do
    ~r/\[[^\]]*\]\(([^)]+)\)/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(&List.first/1)
    |> Enum.reject(&external_link?/1)
    |> Enum.reduce(errors, fn target, acc ->
      path_part = target |> String.split("#", parts: 2) |> List.first()

      if path_part == "" do
        acc
      else
        resolved =
          source
          |> Path.dirname()
          |> Path.join(path_part)
          |> Path.expand(root)

        if File.exists?(resolved),
          do: acc,
          else: ["#{source}: Markdown target does not exist: #{target}" | acc]
      end
    end)
  end

  defp external_link?(target) do
    String.starts_with?(target, ["http://", "https://", "mailto:"])
  end

  defp require_digest(errors, root, exception, authorized_paths) do
    path = exception["path"]

    if path in authorized_paths do
      errors
    else
      require_original_digest(errors, root, exception)
    end
  end

  defp require_original_digest(errors, root, exception) do
    path = exception["path"]

    if is_binary(path) and File.regular?(Path.join(root, path)) do
      actual = root |> Path.join(path) |> File.read!() |> sha256()
      require_equal(errors, actual, exception["sha256"], "#{exception["id"]} exception digest")
    else
      errors
    end
  end

  defp authorized_hui_b2_legacy_paths(root) do
    path = Path.join(root, @hui_b2_manifest)

    with {:ok, body} <- File.read(path),
         {:ok, manifest} <- Jason.decode(body),
         "HUI-B2" <- manifest["phase"],
         @hui_b2_baseline <- manifest["baseline_commit"],
         status
         when status in [
                "resolved_exact_graph",
                "integration_candidate_merge_pending",
                "accepted_at_merged_candidate"
              ] <-
           manifest["status"] do
      manifest["authorized_legacy_exception_paths"]
      |> List.wrap()
      |> Enum.filter(&(&1 in @hui_b2_legacy_paths))
    else
      _other -> []
    end
  end

  defp require_future_date(errors, value, label) do
    case Date.from_iso8601(value || "") do
      {:ok, date} ->
        if Date.compare(date, Date.utc_today()) == :lt,
          do: ["#{label} is expired" | errors],
          else: errors

      {:error, _reason} ->
        ["#{label} must be an ISO date" | errors]
    end
  end

  defp require_regular_file(errors, root, path, label) do
    if is_binary(path) and File.regular?(Path.join(root, path)),
      do: errors,
      else: ["#{label} must be one exact regular file: #{inspect(path)}" | errors]
  end

  defp require_path(errors, root, path, label) do
    if is_binary(path) and File.exists?(Path.join(root, path)),
      do: errors,
      else: ["#{label} does not exist: #{inspect(path)}" | errors]
  end

  defp require_fields(errors, map, fields, label) do
    Enum.reduce(fields, errors, fn field, acc ->
      if present?(map[field]), do: acc, else: ["#{label} is missing #{field}" | acc]
    end)
  end

  defp require_nonempty(errors, value, message) do
    if present?(value), do: errors, else: [message | errors]
  end

  defp require_unique(errors, values, label) do
    duplicates = values -- Enum.uniq(values)

    Enum.reduce(Enum.uniq(duplicates), errors, fn value, acc ->
      ["duplicate #{label}: #{inspect(value)}" | acc]
    end)
  end

  defp require_equal(errors, actual, expected, label) do
    if actual == expected,
      do: errors,
      else: ["#{label}; expected #{inspect(expected)}, got #{inspect(actual)}" | errors]
  end

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: [
        "#{label}; expected #{inspect(Enum.sort(expected))}, got #{inspect(Enum.sort(actual))}"
        | errors
      ]
  end

  defp require_subset(errors, actual, allowed, label) do
    unknown = MapSet.difference(MapSet.new(actual), MapSet.new(allowed)) |> MapSet.to_list()

    if unknown == [],
      do: errors,
      else: ["#{label} contains unknown values: #{inspect(Enum.sort(unknown))}" | errors]
  end

  defp require_member(errors, actual, allowed, label) do
    if actual in allowed,
      do: errors,
      else: ["#{label} is not registered: #{inspect(actual)}" | errors]
  end

  defp require_contains(errors, body, expected, label) do
    if is_binary(body) and String.contains?(body, expected),
      do: errors,
      else: ["#{label} is missing" | errors]
  end

  defp require_not_contains(errors, body, forbidden, label) do
    if is_binary(body) and String.contains?(body, forbidden),
      do: ["#{label} is present" | errors],
      else: errors
  end

  defp require_match(errors, body, regex, label) do
    if is_binary(body) and Regex.match?(regex, body),
      do: errors,
      else: ["#{label} does not match" | errors]
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, reason} -> "missing #{path}: #{inspect(reason)}"
    end
  end

  defp read_json!(root, path), do: root |> Path.join(path) |> File.read!() |> Jason.decode!()

  defp matching_line(source, regex) do
    case Regex.run(regex, source, return: :index) do
      [{offset, _length} | _rest] ->
        source |> binary_part(0, offset) |> String.split("\n") |> length()

      _other ->
        1
    end
  end

  defp format_error(path, line, rule, message), do: "#{path}:#{line} [#{rule}] #{message}"
  defp sha256(body), do: body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end

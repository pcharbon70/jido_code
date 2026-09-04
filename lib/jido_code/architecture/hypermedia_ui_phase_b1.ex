defmodule JidoCode.Architecture.HypermediaUIPhaseB1 do
  @moduledoc false

  @manifest_directory "priv/architecture/hypermedia_ui"
  @manifest_files %{
    shadcn: "phase_b1_shadcn_source.json",
    pairing: "phase_b1_datastar_dstar_pairing.json",
    bom: "phase_b1_candidate_bom.json",
    ledger: "phase_b1_supply_chain_ledger.json",
    evidence: "phase_b1_verification_evidence.json"
  }
  @baseline "1e4073bb6968924abb2345e49453f980ae7eee92"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-01-source-license-version-and-risk-baseline.md"
  @milestone_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/README.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-01-receipt.md"
  @closure_checkboxes ~w[1 1.4 1.4.2 1.4.2.3]
  @baseline_files %{
    "mix.exs" => "ac3ee46af4eb10360bead10c6875f286e6d6308920e17624f98ae88247ead3f1",
    "mix.lock" => "db12394fa532dfcf3468249f30732204c278afde74fb48cc9c630b4e2b409402",
    "package.json" => "7f591835bbd701538c7352dcbc54b7f6e9f8930b94ded856bb67128023b48da3",
    "package-lock.json" => "597085163703c02ba831aec86e335ada9f577021da748fa6225f29f718a9868f",
    "assets/js/app.js" => "9b412cc6aed09720186d85fd901a9569ab6fe68a15ee538a6fd746c881c1f283",
    "assets/css/app.css" => "9a2d120a389d8c686cfbde58c0dc2d954a22325b404d5258a356b2e8ea92d4e8"
  }
  @baseline_manifest_hashes %{
    "mix_exs_sha256" => @baseline_files["mix.exs"],
    "mix_lock_sha256" => @baseline_files["mix.lock"],
    "package_json_sha256" => @baseline_files["package.json"],
    "package_lock_sha256" => @baseline_files["package-lock.json"],
    "app_js_sha256" => @baseline_files["assets/js/app.js"],
    "app_css_sha256" => @baseline_files["assets/css/app.css"]
  }
  @shadcn_risks ~w[
    HUI-B1-SHADCN-R01 HUI-B1-SHADCN-R02 HUI-B1-SHADCN-R03
    HUI-B1-SHADCN-R04 HUI-B1-SHADCN-R05
  ]
  @pair_risks ~w[
    HUI-B1-PAIR-R01 HUI-B1-PAIR-R02 HUI-B1-PAIR-R03 HUI-B1-PAIR-R04
    HUI-B1-PAIR-R05 HUI-B1-PAIR-R06 HUI-B1-PAIR-R07
  ]
  @behavior_ids ~w[
    request_headers json_signal_transport form_transport csrf element_event signal_event
    sse_framing non_sse_response retries errors csp
  ]
  @component_refs ~w[
    source:shadcn_ui@fe40eae63504adc4375aead4f0e741f158a4d86e
    asset:shadcn_ui.css@ed0768e9582e
    pkg:hex/dstar@0.2.0
    asset:datastar@1.0.3
    pkg:hex/phoenix_live_view@1.2.9
    pkg:hex/phoenix@1.8.11
    pkg:hex/phoenix_html@4.3.0
    pkg:hex/phoenix_pubsub@2.2.0
    pkg:hex/phoenix_template@1.0.4
    pkg:hex/plug@1.20.3
    pkg:hex/plug_crypto@2.2.0
    pkg:hex/telemetry@1.4.2
    pkg:hex/jason@1.4.5
    pkg:hex/mime@2.0.7
    pkg:hex/websock_adapter@0.6.0
    pkg:hex/websock@0.5.3
    pkg:npm/%40tailwindcss/vite@4.3.3
    pkg:npm/tailwindcss@4.3.3
    pkg:npm/vite@7.3.6
  ]
  @negative_cases ~w[
    changed_commit changed_tag checksum_mismatch missing_license_or_usage_grant
    namespace_drift advisory_present upstream_CI_failure_claimed_qualified
    unavailable_artifact versionless_protocol_claim product_consumer_added_in_phase_1
  ]
  @expected_outputs ~w[
    mix.exs mix.lock package.json package-lock.json assets/vendor/datastar/datastar.js
    assets/css/app.css priv/static/.vite/manifest.json priv/static/cache_manifest.json
    priv/architecture/hypermedia_ui/phase_b2_resolved_sbom.json
    docs/architecture/hypermedia-ui-milestone-b-phase-02-receipt.md
  ]

  @type manifests :: %{
          shadcn: map(),
          pairing: map(),
          bom: map(),
          ledger: map(),
          evidence: map()
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

        with {:ok, body} <- File.read(path),
             {:ok, manifest} <- Jason.decode(body) do
          {Map.put(loaded, key, manifest), errors}
        else
          {:error, %Jason.DecodeError{} = reason} ->
            {loaded, ["#{path}: invalid JSON: #{Exception.message(reason)}" | errors]}

          {:error, reason} ->
            {loaded, ["#{path}: unavailable manifest: #{inspect(reason)}" | errors]}
        end
      end)

    if errors == [], do: {:ok, manifests}, else: {:error, Enum.reverse(errors)}
  end

  @spec validate(manifests(), Path.t()) :: [String.t()]
  def validate(
        %{shadcn: shadcn, pairing: pairing, bom: bom, ledger: ledger, evidence: evidence},
        root
      ) do
    []
    |> validate_shadcn(shadcn)
    |> validate_pairing(pairing)
    |> validate_bom(bom, shadcn, pairing)
    |> validate_ledger(ledger)
    |> validate_evidence(evidence)
    |> validate_phase_boundary(root, evidence)
    |> validate_documents_and_closure(root)
    |> Enum.reverse()
  end

  def validate(_incomplete, _root), do: ["HUI-B1 manifest set is incomplete"]

  @spec validate_closure(String.t(), String.t(), String.t()) :: [String.t()]
  def validate_closure(plan, milestone, receipt) do
    accepted? = String.contains?(receipt, "Status: **accepted-at-merged-candidate**")
    merge_pending? = String.contains?(receipt, "Status: **merge-pending**")

    cond do
      accepted? and not merge_pending? ->
        []
        |> require_contains(plan, "status: completed", "HUI-B1 completed plan status")
        |> require_contains(milestone, "status: completed", "Milestone B completed status")
        |> validate_closure_checkboxes(plan, true)
        |> require_match(
          receipt,
          ~r/\| Merged candidate \| `[0-9a-f]{40}` \|/,
          "HUI-B1 accepted candidate table"
        )
        |> require_match(
          receipt,
          ~r/Merged candidate: `[0-9a-f]{40}`/,
          "HUI-B1 accepted candidate metadata"
        )
        |> require_match(
          receipt,
          ~r/Merge date: `\d{4}-\d{2}-\d{2}`/,
          "HUI-B1 accepted merge date"
        )

      merge_pending? and not accepted? ->
        []
        |> require_contains(plan, "status: proposed", "HUI-B1 proposed plan status")
        |> require_contains(milestone, "status: proposed", "Milestone B proposed status")
        |> validate_closure_checkboxes(plan, false)
        |> require_contains(
          receipt,
          "| Merged candidate | `merge-pending` |",
          "HUI-B1 merge-pending candidate table"
        )
        |> require_contains(
          receipt,
          "Merged candidate: `merge-pending`",
          "HUI-B1 merge-pending metadata"
        )
        |> require_contains(receipt, "Merge date: `merge-pending`", "HUI-B1 merge-pending date")

      true ->
        ["HUI-B1 closure must have exactly one coherent receipt state"]
    end
  end

  defp validate_shadcn(errors, manifest) do
    risks = manifest["risk_register"] || []

    errors =
      errors
      |> require_equal(manifest["schema_version"], 1, "Shadcn source schema_version")
      |> require_equal(manifest["phase"], "HUI-B1", "Shadcn source phase")
      |> require_equal(
        manifest["status"],
        "accepted_source_baseline_adoption_blocked",
        "Shadcn source status"
      )
      |> require_equal(
        get_in(manifest, ["candidate", "commit"]),
        "fe40eae63504adc4375aead4f0e741f158a4d86e",
        "Shadcn exact candidate commit"
      )
      |> require_equal(
        get_in(manifest, ["candidate", "tree"]),
        "75980039b06222dcba51ba642ef06fb596aa8cfa",
        "Shadcn exact tree"
      )
      |> require_equal(
        get_in(manifest, ["candidate", "module_namespace"]),
        "ShadcnUI",
        "Shadcn module namespace"
      )
      |> require_equal(
        get_in(manifest, ["integrity", "archive_sha256"]),
        "a71b35c1102102ee38935d80b1d21e41c68aa3966bca4fb77e8d816383831a1c",
        "Shadcn archive checksum"
      )
      |> require_equal(
        get_in(manifest, ["license_and_usage", "spdx"]),
        "MIT",
        "Shadcn license and usage grant"
      )
      |> require_equal(
        get_in(manifest, ["upstream_evidence", "repository_security_advisories_at_review"]),
        [],
        "Shadcn advisory snapshot"
      )
      |> require_equal(
        get_in(manifest, ["upstream_evidence", "ci_conclusion"]),
        "failure",
        "Shadcn exact upstream CI result"
      )
      |> require_equal(
        get_in(manifest, ["upstream_evidence", "candidate_qualified"]),
        false,
        "failed Shadcn candidate qualification"
      )
      |> require_equal(
        get_in(manifest, ["update_policy", "adoption_decision"]),
        "blocked_until_Phases_2_through_4_close",
        "Shadcn adoption decision"
      )
      |> require_exact_set(Enum.map(risks, & &1["id"]), @shadcn_risks, "Shadcn risk ids")

    Enum.reduce(risks, errors, fn risk, acc ->
      require_fields(
        acc,
        risk,
        ~w[id severity owner status risk mitigation expires_on reopening_condition],
        "Shadcn risk #{risk["id"]}"
      )
    end)
  end

  defp validate_pairing(errors, manifest) do
    matrix = manifest["compatibility_matrix"] || []
    risks = manifest["risk_register"] || []
    incompatible = manifest["incompatible_combinations"] || []

    errors =
      errors
      |> require_equal(manifest["schema_version"], 1, "pairing schema_version")
      |> require_equal(manifest["phase"], "HUI-B1", "pairing phase")
      |> require_equal(
        manifest["status"],
        "accepted_protocol_baseline_adoption_blocked",
        "pairing status"
      )
      |> require_equal(get_in(manifest, ["dstar", "version"]), "0.2.0", "Dstar version")
      |> require_equal(get_in(manifest, ["dstar", "tag"]), "v0.2.0", "Dstar tag")
      |> require_equal(
        get_in(manifest, ["dstar", "commit"]),
        "4bfb9110645f3831cd350f25434493c76a42bfae",
        "Dstar commit"
      )
      |> require_equal(
        get_in(manifest, ["dstar", "hex_release", "checksum_sha256"]),
        "4766c1f3da802aa7e842aa78cbb778c8d764599e18fc67bbe32fbe25ac2c6460",
        "Dstar Hex checksum"
      )
      |> require_equal(get_in(manifest, ["dstar", "license", "spdx"]), "MIT", "Dstar license")
      |> require_equal(
        get_in(manifest, [
          "dstar",
          "upstream_evidence",
          "repository_security_advisories_at_review"
        ]),
        [],
        "Dstar repository advisory snapshot"
      )
      |> require_all_equal(
        Enum.map(
          get_in(manifest, ["dstar", "upstream_evidence", "exact_commit_checks"]) || [],
          & &1["conclusion"]
        ),
        "success",
        "Dstar exact commit CI conclusions"
      )
      |> require_equal(get_in(manifest, ["datastar", "version"]), "1.0.3", "Datastar version")
      |> require_equal(get_in(manifest, ["datastar", "tag"]), "v1.0.3", "Datastar tag")
      |> require_equal(
        get_in(manifest, ["datastar", "commit"]),
        "73ab00e7c06d8c2bad030fdddafba800fcccbde2",
        "Datastar commit"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "tag_signature", "status"]),
        "verified_by_GitHub",
        "Datastar tag signature"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "selected_bundle", "sha256"]),
        "5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65",
        "Datastar bundle checksum"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "selected_bundle", "unminified_bundle_sha256"]),
        nil,
        "Datastar absent unminified bundle"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "license", "spdx"]),
        "MIT",
        "Datastar license"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "csp", "mode"]),
        "opt_in_nonce_mode",
        "Datastar CSP mode"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "csp", "unsafe_eval_required"]),
        false,
        "Datastar unsafe-eval requirement"
      )
      |> require_equal(
        get_in(manifest, ["datastar", "build_record", "rebuild_status"]),
        "not_reproducible_from_release_tree_alone",
        "Datastar release-tree rebuild status"
      )
      |> require_equal(
        get_in(manifest, [
          "datastar",
          "upstream_evidence",
          "repository_security_advisories_at_review"
        ]),
        [],
        "Datastar advisory snapshot"
      )
      |> require_exact_set(Enum.map(matrix, & &1["id"]), @behavior_ids, "protocol behavior ids")
      |> require_exact_set(Enum.map(risks, & &1["id"]), @pair_risks, "pair risk ids")
      |> require_equal(length(incompatible), 5, "incompatible pairing count")
      |> require_all_equal(
        Enum.map(incompatible, & &1["status"]),
        "rejected",
        "incompatible pairing status"
      )

    errors =
      Enum.reduce(matrix, errors, fn behavior, acc ->
        require_fields(
          acc,
          behavior,
          ~w[id dstar_or_application datastar_1_0_3 jido_code_disposition],
          "protocol behavior #{behavior["id"]}"
        )
      end)

    Enum.reduce(risks, errors, fn risk, acc ->
      require_fields(
        acc,
        risk,
        ~w[id severity owner status risk mitigation expires_on reopening_condition],
        "pair risk #{risk["id"]}"
      )
    end)
  end

  defp validate_bom(errors, bom, shadcn, pairing) do
    components = bom["components"] || []
    refs = Enum.map(components, & &1["ref"])

    errors =
      errors
      |> require_equal(bom["schema_version"], 1, "candidate BOM schema_version")
      |> require_equal(bom["baseline_commit"], @baseline, "candidate BOM baseline")
      |> require_equal(
        bom["status"],
        "immutable_candidate_graph_not_installed",
        "candidate BOM status"
      )
      |> require_exact_set(refs, @component_refs, "candidate BOM component refs")
      |> require_unique(refs, "candidate BOM component ref")
      |> require_equal(
        component_value(
          components,
          "source:shadcn_ui@fe40eae63504adc4375aead4f0e741f158a4d86e",
          "sha256"
        ),
        get_in(shadcn, ["integrity", "archive_sha256"]),
        "Shadcn BOM archive checksum"
      )
      |> require_equal(
        component_value(components, "pkg:hex/dstar@0.2.0", "sha256"),
        get_in(pairing, ["dstar", "hex_release", "checksum_sha256"]),
        "Dstar BOM checksum"
      )
      |> require_equal(
        component_value(components, "asset:datastar@1.0.3", "sha256"),
        get_in(pairing, ["datastar", "selected_bundle", "sha256"]),
        "Datastar BOM checksum"
      )
      |> require_equal(
        get_in(bom, ["upstream_build_inputs", "shadcn_ui", "npm_locked_component_count"]),
        66,
        "Shadcn npm locked component count"
      )
      |> require_equal(
        get_in(bom, ["advisory_snapshot", "selected_source_repository_advisories"]),
        [],
        "candidate source advisories"
      )
      |> require_equal(
        get_in(bom, ["advisory_snapshot", "selected_Hex_release_retirements"]),
        [],
        "candidate Hex retirements"
      )
      |> require_equal(
        get_in(bom, ["advisory_snapshot", "shadcn_upstream_package_lock_npm_audit", "total"]),
        0,
        "Shadcn npm advisory total"
      )

    errors =
      Enum.reduce(components, errors, fn component, acc ->
        acc
        |> require_fields(
          component,
          ~w[ref name version ecosystem source license role consumer disposition],
          "BOM component #{component["ref"]}"
        )
        |> require_integrity(component)
      end)

    Enum.reduce(bom["dependency_edges"] || %{}, errors, fn {from, targets}, acc ->
      acc = require_member(acc, from, refs, "BOM dependency edge source")
      Enum.reduce(targets, acc, &require_member(&2, &1, refs, "BOM dependency edge target"))
    end)
  end

  defp validate_ledger(errors, ledger) do
    selected = ledger["selected_inputs"] || []
    alternatives = ledger["alternatives"] || []
    constraints = ledger["constraint_decisions"] || []
    temporary = get_in(ledger, ["exceptions_and_controls", "temporary_constraints"]) || []
    outputs = Enum.map(ledger["expected_HUI_B2_outputs"] || [], & &1["path"])

    errors =
      errors
      |> require_equal(ledger["schema_version"], 1, "supply-chain ledger schema_version")
      |> require_equal(ledger["phase"], "HUI-B1", "supply-chain ledger phase")
      |> require_equal(
        ledger["status"],
        "accepted_decision_ledger_adoption_blocked",
        "supply-chain ledger status"
      )
      |> require_equal(get_in(ledger, ["baseline", "commit"]), @baseline, "supply-chain baseline")
      |> require_equal(
        get_in(ledger, ["baseline", "new_dependencies_or_assets_in_HUI_B1"]),
        [],
        "HUI-B1 dependency and asset additions"
      )
      |> require_equal(length(selected), 4, "selected input count")
      |> require_equal(length(alternatives), 8, "alternative decision count")
      |> require_equal(length(constraints), 5, "constraint decision count")
      |> require_equal(
        get_in(ledger, ["exceptions_and_controls", "active_adoption_exceptions"]),
        [],
        "active adoption exceptions"
      )
      |> require_equal(length(temporary), 2, "temporary constraint count")
      |> require_exact_set(outputs, @expected_outputs, "HUI-B2 expected output paths")
      |> require_nonempty(
        ledger["reopening_conditions"],
        "supply-chain reopening conditions are missing"
      )
      |> require_nonempty(
        get_in(ledger, ["offline_and_cache_policy", "verify_before_use"]),
        "offline verification policy is missing"
      )
      |> require_nonempty(
        get_in(ledger, ["update_and_incident_policy", "emergency"]),
        "emergency advisory response is missing"
      )

    errors =
      Enum.reduce(@baseline_manifest_hashes, errors, fn {field, expected}, acc ->
        require_equal(
          acc,
          get_in(ledger, ["baseline", field]),
          expected,
          "supply-chain baseline #{field}"
        )
      end)

    errors =
      Enum.reduce(selected, errors, fn record, acc ->
        require_fields(
          acc,
          record,
          ~w[id input identity reason owner replacement_trigger],
          "selected input #{record["id"]}"
        )
      end)

    errors =
      Enum.reduce(alternatives, errors, fn record, acc ->
        acc
        |> require_fields(record, ~w[id candidate decision reason], "alternative #{record["id"]}")
        |> require_member(
          record["decision"],
          ~w[rejected rejected_for_phase_2 deferred],
          "alternative decision"
        )
      end)

    Enum.reduce(temporary, errors, fn record, acc ->
      require_fields(
        acc,
        record,
        ~w[id owner expires_on condition control],
        "temporary constraint #{record["id"]}"
      )
    end)
  end

  defp validate_evidence(errors, evidence) do
    sources = evidence["source_verification"] || []
    cases = evidence["negative_cases"] || []
    boundary = evidence["phase_boundary"] || %{}

    errors =
      errors
      |> require_equal(evidence["schema_version"], 1, "verification evidence schema_version")
      |> require_equal(evidence["phase"], "HUI-B1", "verification evidence phase")
      |> require_equal(
        evidence["status"],
        "accepted_at_merged_candidate",
        "verification evidence status"
      )
      |> require_equal(evidence["baseline_commit"], @baseline, "verification evidence baseline")
      |> require_equal(length(sources), 7, "source verification count")
      |> require_all_equal(
        Enum.map(sources, & &1["verified"]),
        true,
        "source verification results"
      )
      |> require_exact_set(Enum.map(cases, & &1["id"]), @negative_cases, "negative case ids")
      |> require_all_equal(Enum.map(cases, & &1["expected"]), "blocked", "negative case outcome")
      |> require_member(
        "mix precommit",
        evidence["commands"] || [],
        "HUI-B1 verification command"
      )

    Enum.reduce(
      ~w[product_consumers_added dependency_declarations_changed lockfiles_changed application_assets_changed routes_or_runtime_changed release_credit_granted],
      errors,
      fn field, acc ->
        require_equal(acc, boundary[field], false, "HUI-B1 phase boundary #{field}")
      end
    )
  end

  defp validate_phase_boundary(errors, _root, %{"status" => "accepted_at_merged_candidate"}),
    do: errors

  defp validate_phase_boundary(errors, root, %{
         "status" => "implementation_candidate_merge_pending"
       }) do
    errors =
      Enum.reduce(@baseline_files, errors, fn {path, expected}, acc ->
        case File.read(Path.join(root, path)) do
          {:ok, body} ->
            require_equal(acc, sha256(body), expected, "HUI-B1 preserved #{path}")

          {:error, reason} ->
            ["HUI-B1 preserved #{path} is unavailable: #{inspect(reason)}" | acc]
        end
      end)

    source =
      ["mix.exs", "package.json", "assets/js/app.js", "assets/css/app.css"]
      |> Enum.map(&read(root, &1))
      |> Enum.join("\n")

    errors
    |> require_not_match(source, ~r/\{:dstar\b/, "HUI-B1 Dstar dependency consumer")
    |> require_not_match(source, ~r/\{:shadcn_ui\b/, "HUI-B1 ShadcnUI dependency consumer")
    |> require_not_match(
      source,
      ~r/(?:from|import)\s+["'][^"']*datastar/i,
      "HUI-B1 Datastar asset consumer"
    )
    |> require_not_match(source, ~r/shadcn_ui\.css/, "HUI-B1 ShadcnUI asset consumer")
  end

  defp validate_phase_boundary(errors, _root, _evidence),
    do: ["HUI-B1 phase-boundary state is unsupported" | errors]

  defp validate_documents_and_closure(errors, root) do
    documents = [
      "docs/architecture/hypermedia-ui-shadcn-source-license-risk-baseline.md",
      "docs/architecture/hypermedia-ui-datastar-dstar-source-protocol-baseline.md",
      "docs/architecture/hypermedia-ui-dependency-supply-chain-ledger.md",
      @receipt_path
    ]

    errors =
      Enum.reduce(documents, errors, fn path, acc ->
        if File.regular?(Path.join(root, path)),
          do: acc,
          else: ["HUI-B1 document is unavailable: #{path}" | acc]
      end)

    plan = read(root, @plan_path)
    milestone = read(root, @milestone_path)
    receipt = read(root, @receipt_path)
    Enum.reverse(validate_closure(plan, milestone, receipt)) ++ errors
  end

  defp validate_closure_checkboxes(errors, plan, checked?) do
    Enum.reduce(@closure_checkboxes, errors, fn id, acc ->
      label = closure_label(id)
      wanted = "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}"
      unwanted = "- [#{if(checked?, do: " ", else: "x")}] #{id} #{label}"

      acc
      |> require_contains(plan, wanted, "HUI-B1 #{id} closure checkbox")
      |> require_not_contains(plan, unwanted, "HUI-B1 #{id} mixed closure checkbox")
    end)
  end

  defp closure_label("1"), do: "Phase"
  defp closure_label("1.4"), do: "Section"
  defp closure_label("1.4.2"), do: "Task"
  defp closure_label("1.4.2.3"), do: "Subtask"

  defp component_value(components, ref, field) do
    case Enum.find(components, &(&1["ref"] == ref)) do
      nil -> nil
      component -> component[field]
    end
  end

  defp require_integrity(errors, component) do
    cond do
      valid_sha256?(component["sha256"]) ->
        errors

      is_binary(component["integrity"]) and String.starts_with?(component["integrity"], "sha512-") ->
        errors

      true ->
        ["BOM component #{component["ref"]} has no valid integrity" | errors]
    end
  end

  defp valid_sha256?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{64}$/, value)

  defp require_fields(errors, map, fields, label) do
    Enum.reduce(fields, errors, fn field, acc ->
      if present?(map[field]), do: acc, else: ["#{label} is missing #{field}" | acc]
    end)
  end

  defp require_equal(errors, actual, expected, label) do
    if actual == expected,
      do: errors,
      else: ["#{label}; expected #{inspect(expected)}, got #{inspect(actual)}" | errors]
  end

  defp require_all_equal(errors, values, expected, label) do
    if values != [] and Enum.all?(values, &(&1 == expected)),
      do: errors,
      else: [
        "#{label}; expected every value to be #{inspect(expected)}, got #{inspect(values)}"
        | errors
      ]
  end

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: [
        "#{label}; expected #{inspect(Enum.sort(expected))}, got #{inspect(Enum.sort(actual))}"
        | errors
      ]
  end

  defp require_unique(errors, values, label) do
    duplicates = values -- Enum.uniq(values)
    Enum.reduce(Enum.uniq(duplicates), errors, &["duplicate #{label}: #{inspect(&1)}" | &2])
  end

  defp require_member(errors, actual, allowed, label) do
    if actual in allowed,
      do: errors,
      else: ["#{label} is not registered: #{inspect(actual)}" | errors]
  end

  defp require_nonempty(errors, value, label) do
    if present?(value), do: errors, else: [label | errors]
  end

  defp require_contains(errors, body, expected, label) do
    if is_binary(body) and String.contains?(body, expected),
      do: errors,
      else: ["#{label} is missing" | errors]
  end

  defp require_not_contains(errors, body, value, label) do
    if is_binary(body) and String.contains?(body, value),
      do: ["#{label} is present" | errors],
      else: errors
  end

  defp require_match(errors, body, regex, label) do
    if Regex.match?(regex, body),
      do: errors,
      else: ["#{label} does not match" | errors]
  end

  defp require_not_match(errors, body, regex, label) do
    if Regex.match?(regex, body),
      do: ["#{label} is present" | errors],
      else: errors
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, reason} -> "unavailable #{path}: #{inspect(reason)}"
    end
  end

  defp sha256(body), do: body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end

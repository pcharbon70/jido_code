defmodule JidoCode.Architecture.HypermediaUIPhaseB2Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseB2

  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-02-phoenix-component-and-asset-integration.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-02-receipt.md"

  test "tracked dependency, facade, asset, evidence, and closure records pass" do
    assert {:ok, []} = HypermediaUIPhaseB2.check()
    assert {:ok, manifests} = HypermediaUIPhaseB2.load()

    assert manifests.graph["status"] == "integration_candidate_merge_pending"
    assert length(manifests.sbom["components"]) == 19
    assert length(manifests.theme["facade"]["public_primitives"]) == 8
    assert manifests.assets["build"]["repeat_builds_equal"]
    assert length(manifests.evidence["negative_cases"]) == 14
  end

  test "dependency lifecycle and inventory drift fail closed" do
    assert {:ok, manifests} = HypermediaUIPhaseB2.load()

    changed_status = put_in(manifests, [:graph, "status"], "unreviewed")

    assert has_error?(
             HypermediaUIPhaseB2.validate(changed_status, File.cwd!()),
             "dependency graph status"
           )

    changed_constraint = put_in(manifests, [:graph, "direct_constraints", "dstar"], "~> 0.2")

    assert has_error?(
             HypermediaUIPhaseB2.validate(changed_constraint, File.cwd!()),
             "direct constraints"
           )

    missing_component = update_in(manifests, [:sbom, "components"], &tl/1)

    assert has_error?(
             HypermediaUIPhaseB2.validate(missing_component, File.cwd!()),
             "SBOM components"
           )

    missing_license = put_in(manifests, [:sbom, "components", Access.at(0), "license"], nil)

    assert has_error?(
             HypermediaUIPhaseB2.validate(missing_license, File.cwd!()),
             "phoenix license"
           )

    missing_integrity = put_in(manifests, [:sbom, "components", Access.at(0), "integrity"], nil)

    assert has_error?(
             HypermediaUIPhaseB2.validate(missing_integrity, File.cwd!()),
             "phoenix integrity"
           )

    changed_version = put_in(manifests, [:sbom, "components", Access.at(0), "version"], "latest")

    assert has_error?(
             HypermediaUIPhaseB2.validate(changed_version, File.cwd!()),
             "phoenix version"
           )
  end

  test "facade and deterministic asset drift fail closed" do
    assert {:ok, manifests} = HypermediaUIPhaseB2.load()

    missing_primitive =
      update_in(manifests, [:theme, "facade", "public_primitives"], &tl/1)

    assert has_error?(
             HypermediaUIPhaseB2.validate(missing_primitive, File.cwd!()),
             "facade primitive names"
           )

    broad_import = put_in(manifests, [:theme, "facade", "broad_upstream_imports_allowed"], true)

    assert has_error?(
             HypermediaUIPhaseB2.validate(broad_import, File.cwd!()),
             "broad ShadcnUI imports"
           )

    digest_drift = put_in(manifests, [:assets, "datastar", "sha256"], String.duplicate("0", 64))

    assert has_error?(
             HypermediaUIPhaseB2.validate(digest_drift, File.cwd!()),
             "Datastar bundle digest"
           )

    source_map = put_in(manifests, [:assets, "datastar", "source_map_shipped"], true)
    assert has_error?(HypermediaUIPhaseB2.validate(source_map, File.cwd!()), "source-map policy")

    nondeterministic = put_in(manifests, [:assets, "build", "repeat_builds_equal"], false)

    assert has_error?(
             HypermediaUIPhaseB2.validate(nondeterministic, File.cwd!()),
             "deterministic build result"
           )
  end

  test "product source boundary rejects unqualified or remote consumers" do
    sources = [
      {"lib/jido_code_web/controllers/bad_controller.ex", "alias ShadcnUI.Components.Button"},
      {"lib/jido_code_web/controllers/bad.html.heex", "<button data-on:click=\"doThing()\">"},
      {"lib/jido_code_web/controllers/dstar_controller.ex", "Dstar.Scripts.render(:datastar)"},
      {"assets/js/bad.js", "import runtime from \"https://cdn.example/runtime.js\""}
    ]

    assert {:error, errors} = HypermediaUIPhaseB2.check_product_sources(sources)
    assert has_error?(errors, "ShadcnUI is available only behind")
    assert has_error?(errors, "Datastar product expressions")
    assert has_error?(errors, "Dstar product consumption")
    assert has_error?(errors, "remote product asset import")
  end

  test "negative evidence registry is exact and all cases remain blocking" do
    assert {:ok, %{evidence: evidence}} = HypermediaUIPhaseB2.load()

    assert Enum.all?(evidence["negative_cases"], &(&1["expected"] == "blocked"))

    assert MapSet.new(Enum.map(evidence["negative_cases"], & &1["id"])) ==
             MapSet.new(~w[
               dependency_pin_drift lock_checksum_drift implicit_override missing_license
               shadcn_outside_facade datastar_product_consumer dstar_product_consumer
               bundle_digest_drift source_map_present csp_unsafe_eval csp_unsafe_inline
               missing_or_reused_nonce nondeterministic_build mixed_closure_state
             ])
  end

  test "closure accepts only coherent merge-pending or accepted states" do
    plan = File.read!(@plan_path)
    receipt = File.read!(@receipt_path)

    assert HypermediaUIPhaseB2.validate_closure(plan, receipt) == []

    accepted_plan =
      plan
      |> String.replace("status: proposed", "status: completed", global: false)
      |> set_closure_checkboxes(true)

    accepted_receipt =
      receipt
      |> String.replace("Status: **merge-pending**", "Status: **accepted-at-merged-candidate**")
      |> String.replace(
        "Merged candidate: `merge-pending`",
        "Merged candidate: `#{String.duplicate("a", 40)}`"
      )
      |> String.replace("Merge date: `merge-pending`", "Merge date: `2026-09-04`")

    assert HypermediaUIPhaseB2.validate_closure(accepted_plan, accepted_receipt) == []

    assert has_error?(
             HypermediaUIPhaseB2.validate_closure(accepted_plan, receipt),
             "proposed plan status"
           )

    assert has_error?(
             HypermediaUIPhaseB2.validate_closure(plan, ""),
             "exactly one coherent"
           )

    mixed_receipt = receipt <> "\nStatus: **accepted-at-merged-candidate**\n"

    assert has_error?(
             HypermediaUIPhaseB2.validate_closure(plan, mixed_receipt),
             "exactly one coherent"
           )
  end

  defp set_closure_checkboxes(plan, checked?) do
    mark = if checked?, do: "x", else: " "

    plan
    |> String.replace(~r/- \[[ x]\] 2 Phase/, "- [#{mark}] 2 Phase")
    |> String.replace(~r/- \[[ x]\] 2\.4 Section/, "- [#{mark}] 2.4 Section")
    |> String.replace(~r/- \[[ x]\] 2\.4\.2 Task/, "- [#{mark}] 2.4.2 Task")
    |> String.replace(~r/- \[[ x]\] 2\.4\.2\.3 Subtask/, "- [#{mark}] 2.4.2.3 Subtask")
  end

  defp has_error?(errors, fragment), do: Enum.any?(errors, &String.contains?(&1, fragment))
end

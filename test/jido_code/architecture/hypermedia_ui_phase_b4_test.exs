defmodule JidoCode.Architecture.HypermediaUIPhaseB4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseB4
  alias JidoCode.Architecture.HypermediaUIPhaseA4

  test "accepted manifests, locks, assets, licenses, consumers, and update policy pass" do
    assert {:ok, []} = HypermediaUIPhaseB4.check()
    assert {:ok, policy} = HypermediaUIPhaseB4.load()

    assert policy["baseline_commit"] == "e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2"

    assert get_in(policy, ["approved_stack", "source", "shadcn_ui"]) ==
             "fe40eae63504adc4375aead4f0e741f158a4d86e"

    assert get_in(policy, ["approved_consumers", "product_consumers"]) == []
    assert policy["exceptions"] == []
  end

  test "qualification evidence covers all release classes and residual risks" do
    assert {:ok, evidence} = HypermediaUIPhaseB4.load_qualification()
    assert HypermediaUIPhaseB4.validate_qualification(evidence, File.cwd!()) == []

    assert get_in(evidence, ["browser", "applicable_passed"]) == 21
    assert get_in(evidence, ["reproducible_build", "equal"]) == true
    assert length(evidence["evidence_classes"]) == 13
    assert length(evidence["residual_risks"]) == 5
  end

  test "qualification browser, accessibility, release, and risk drift fails closed" do
    assert {:ok, evidence} = HypermediaUIPhaseB4.load_qualification()

    mutations = [
      {put_in(evidence, ["browser", "applicable_passed"], 20), "browser passed count"},
      {put_in(evidence, ["reproducible_build", "equal"], false), "build equality"},
      {put_in(evidence, ["release", "qualification_route_release_credit"], true),
       "route release credit"},
      {update_in(evidence, ["evidence_classes"], &tl/1), "evidence classes"},
      {update_in(evidence, ["residual_risks"], &tl/1), "residual risk count"}
    ]

    Enum.each(mutations, fn {mutated, expected} ->
      assert Enum.any?(
               HypermediaUIPhaseB4.validate_qualification(mutated, File.cwd!()),
               &String.contains?(&1, expected)
             )
    end)
  end

  test "product consumption baseline pins the facade, protocol, profiles, and production exclusion" do
    assert {:ok, baseline} = HypermediaUIPhaseB4.load_consumption()
    assert HypermediaUIPhaseB4.validate_consumption(baseline, File.cwd!()) == []

    assert get_in(baseline, ["approved_imports", "heex_facade"]) ==
             "JidoCodeWeb.Components.UI"

    assert get_in(baseline, ["production_boundary", "production_route_count"]) == 0
    assert length(baseline["milestone_c_composite_gaps"]) == 16
    assert baseline["exceptions"] == []
  end

  test "product import, asset, ceiling, failure, composite, and route drift fails closed" do
    assert {:ok, baseline} = HypermediaUIPhaseB4.load_consumption()

    mutations = [
      {put_in(baseline, ["approved_imports", "heex_facade"], "ShadcnUI"), "HEEx facade"},
      {put_in(baseline, ["asset_contract", "app_js_sha256"], String.duplicate("0", 64)),
       "application JS"},
      {put_in(baseline, ["operational_ceilings", "max_queue"], 1), "queue ceiling"},
      {update_in(baseline, ["known_failure_modes"], &tl/1), "failure modes"},
      {update_in(baseline, ["milestone_c_composite_gaps"], &tl/1), "Milestone C composite gaps"},
      {put_in(baseline, ["production_boundary", "production_route_count"], 1),
       "production route count"}
    ]

    Enum.each(mutations, fn {mutated, expected} ->
      assert Enum.any?(
               HypermediaUIPhaseB4.validate_consumption(mutated, File.cwd!()),
               &String.contains?(&1, expected)
             )
    end)
  end

  test "merge-pending receipt keeps the final closure boxes open" do
    plan =
      File.read!(
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-04-dependency-consumer-and-architecture-qualification.md"
      )

    receipt = File.read!("docs/architecture/hypermedia-ui-milestone-b-phase-04-receipt.md")

    assert HypermediaUIPhaseB4.validate_closure(plan, receipt) == []
  end

  test "integration evidence pins reproduction, mutation, production, and rollback results" do
    assert {:ok, evidence} = HypermediaUIPhaseB4.load_integration()
    assert HypermediaUIPhaseB4.validate_integration(evidence, File.cwd!()) == []

    assert evidence["clean_checkout_ci"] == "merge_pending"
    assert length(evidence["reproduction"]) == 12
    assert length(evidence["mutation_cases"]) == 21
    assert get_in(evidence, ["production_boundary", "qualification_routes"]) == 0
    assert get_in(evidence, ["rollback", "dependency_and_asset_diff"]) == "empty"
  end

  test "every recorded mutation class is rejected with its actionable diagnostic" do
    assert {:ok, policy} = HypermediaUIPhaseB4.load()
    assert {:ok, qualification} = HypermediaUIPhaseB4.load_qualification()
    assert {:ok, consumption} = HypermediaUIPhaseB4.load_consumption()
    assert {:ok, integration} = HypermediaUIPhaseB4.load_integration()

    plan =
      File.read!(
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-04-dependency-consumer-and-architecture-qualification.md"
      )

    receipt = File.read!("docs/architecture/hypermedia-ui-milestone-b-phase-04-receipt.md")

    source_errors = fn path, source ->
      HypermediaUIPhaseB4.check_candidate_sources([{path, source}])
    end

    a4_errors = fn path, source ->
      {:error, errors} = HypermediaUIPhaseA4.check_sources([{path, source}])
      errors
    end

    diagnostics = %{
      "hex_version" =>
        HypermediaUIPhaseB4.validate(
          put_in(policy, ["approved_stack", "hex", "dstar"], "0.2.1"),
          File.cwd!()
        ),
      "source_version" =>
        HypermediaUIPhaseB4.validate(
          put_in(policy, ["approved_stack", "source", "datastar"], "main"),
          File.cwd!()
        ),
      "npm_version" =>
        HypermediaUIPhaseB4.validate(
          put_in(policy, ["approved_stack", "npm", "vite"], "latest"),
          File.cwd!()
        ),
      "manifest_or_source_digest" =>
        HypermediaUIPhaseB4.validate(
          put_in(policy, ["candidate_inputs", "mix.lock"], String.duplicate("0", 64)),
          File.cwd!()
        ),
      "license" =>
        HypermediaUIPhaseB4.validate(
          update_in(policy, ["approved_stack", "licenses"], &tl/1),
          File.cwd!()
        ),
      "shadcn_import" =>
        HypermediaUIPhaseB4.validate_consumption(
          update_in(consumption, ["approved_imports", "shadcn_ui"], &tl/1),
          File.cwd!()
        ),
      "datastar_asset" =>
        HypermediaUIPhaseB4.validate_consumption(
          put_in(
            consumption,
            ["asset_contract", "datastar_bundle_sha256"],
            String.duplicate("0", 64)
          ),
          File.cwd!()
        ),
      "dstar_scripts" => source_errors.("fixture.ex", "Dstar.Scripts.execute(conn, action)"),
      "inline_or_eval_csp" => source_errors.("fixture.ex", "script-src 'unsafe-eval'"),
      "remote_product_asset" =>
        source_errors.("fixture.heex", "<script src=\"https://cdn.invalid/app.js\">"),
      "browser_authority" =>
        source_errors.("fixture.js", "sessionStorage.getItem('policy_revision_authority')"),
      "new_liveview_runtime" => a4_errors.("fixture.ex", "live \"/new\", NewLive"),
      "new_livevue_runtime" => a4_errors.("fixture.ex", "use LiveVue"),
      "new_saladui_consumer" => a4_errors.("fixture.ex", "alias SaladUI.Button"),
      "production_qualification_route" =>
        HypermediaUIPhaseB4.validate_consumption(
          put_in(consumption, ["production_boundary", "production_route_count"], 1),
          File.cwd!()
        ),
      "production_qualification_supervision" =>
        HypermediaUIPhaseB4.validate_consumption(
          put_in(consumption, ["production_boundary", "production_supervision_children"], 1),
          File.cwd!()
        ),
      "operational_ceiling" =>
        HypermediaUIPhaseB4.validate_consumption(
          put_in(consumption, ["operational_ceilings", "max_queue"], 1),
          File.cwd!()
        ),
      "attribute_or_event" =>
        HypermediaUIPhaseB4.validate_consumption(
          update_in(consumption, ["approved_datastar_attributes"], &tl/1),
          File.cwd!()
        ),
      "browser_profile" =>
        HypermediaUIPhaseB4.validate_consumption(
          update_in(consumption, ["supported_profiles", "browsers"], &tl/1),
          File.cwd!()
        ),
      "residual_risk" =>
        HypermediaUIPhaseB4.validate_qualification(
          update_in(qualification, ["residual_risks"], &tl/1),
          File.cwd!()
        ),
      "receipt_lifecycle" =>
        HypermediaUIPhaseB4.validate_closure(
          plan,
          String.replace(receipt, "Status: **merge-pending**", "Status: **unknown**")
        )
    }

    assert Map.keys(diagnostics) |> Enum.sort() ==
             integration["mutation_cases"] |> Enum.map(& &1["id"]) |> Enum.sort()

    Enum.each(integration["mutation_cases"], fn mutation ->
      assert Enum.any?(
               Map.fetch!(diagnostics, mutation["id"]),
               &String.contains?(&1, mutation["diagnostic"])
             ),
             "#{mutation["id"]} did not produce #{mutation["diagnostic"]}"
    end)
  end

  test "version, digest, license, consumer, and update-evidence drift fails closed" do
    assert {:ok, policy} = HypermediaUIPhaseB4.load()

    mutations = [
      {put_in(policy, ["approved_stack", "hex", "dstar"], "latest"), "Hex pins"},
      {put_in(policy, ["candidate_inputs", "mix.lock"], String.duplicate("0", 64)),
       "candidate pins"},
      {update_in(policy, ["approved_stack", "licenses"], &tl/1), "license allowlist"},
      {put_in(policy, ["approved_consumers", "product_consumers"], ["lib/product.ex"]),
       "product consumer"},
      {update_in(policy, ["update_evidence"], &tl/1), "update evidence"}
    ]

    Enum.each(mutations, fn {mutated, expected} ->
      assert Enum.any?(
               HypermediaUIPhaseB4.validate(mutated, File.cwd!()),
               &String.contains?(&1, expected)
             )
    end)
  end

  test "forbidden runtime, asset, CSP, and authority patterns are rejected" do
    errors =
      HypermediaUIPhaseB4.check_candidate_sources([
        {"fixture/scripts.ex", "Dstar.Scripts.execute(conn, \"bad\")"},
        {"fixture/inline.html.heex", "<script>bad()</script>"},
        {"fixture/csp.ex", "script-src 'unsafe-eval'"},
        {"fixture/cdn.heex", "<script src=\"https://cdn.invalid/app.js\">"},
        {"fixture/auth.js", "localStorage.getItem('delegation_authority')"}
      ])

    assert Enum.any?(errors, &String.contains?(&1, "Dstar Scripts"))
    assert Enum.any?(errors, &String.contains?(&1, "inline scripts"))
    assert Enum.any?(errors, &String.contains?(&1, "unsafe CSP"))
    assert Enum.any?(errors, &String.contains?(&1, "remote or CDN"))
    assert Enum.any?(errors, &String.contains?(&1, "browser state"))
  end
end

defmodule JidoCode.Architecture.HypermediaUIPhaseB4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseB4

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

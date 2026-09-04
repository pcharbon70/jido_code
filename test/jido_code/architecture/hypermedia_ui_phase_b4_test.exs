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

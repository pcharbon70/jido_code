defmodule JidoCode.Architecture.HypermediaUIPhaseC3Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseC3
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  test "accepts the complete merge-pending route and native-browser candidate" do
    assert HypermediaUIPhaseC3.check() == {:ok, []}
  end

  test "rejects route, lifecycle, browser, session, and source drift" do
    {:ok, evidence} = HypermediaUIPhaseC3.load()

    mutations = [
      {update_in(evidence, ["routes", "paths"], &tl/1), "route vocabulary"},
      {put_in(evidence, ["routes", "new_product_live_routes"], 1), "new product LiveView routes"},
      {put_in(evidence, ["session_workflows", "cookie_bearer_refs_in_html"], 1),
       "bearer session refs"},
      {put_in(evidence, ["response_security", "referrer_policy"], "unsafe-url"),
       "response security"},
      {update_in(evidence, ["integration", "browser_profiles"], &tl/1), "browser profiles"},
      {put_in(evidence, ["integration", "results", "browser_matrix"], "pending"),
       "integration results"},
      {Map.put(evidence, "completed_sections", ["3.2", "3.1"]), "completed section order"}
    ]

    for {mutated, diagnostic} <- mutations do
      assert Enum.any?(
               HypermediaUIPhaseC3.validate(mutated, File.cwd!()),
               &String.contains?(&1, diagnostic)
             )
    end

    [path | _rest] = Map.keys(evidence["source_digests"])
    digest_drift = put_in(evidence, ["source_digests", path], String.duplicate("0", 64))

    assert Enum.any?(
             HypermediaUIPhaseC3.validate(digest_drift, File.cwd!()),
             &String.contains?(&1, "source digest")
           )
  end

  test "source inspection rejects product LiveView, graph access, scripts, handlers, and Datastar" do
    errors =
      HypermediaUIPhaseC3.validate_product_sources([
        {"lib/jido_code_web/router.ex", ~s(live "/factory", FactoryLive)},
        {"lib/jido_code_web/controllers/raw.ex",
         "alias TripleStore\nSELECT * WHERE { ?s ?p ?o }"},
        {"lib/jido_code_web/controllers/raw.html.heex", "<script>run()</script>"},
        {"lib/jido_code_web/controllers/handler.html.heex", "<button onclick=\"run()\">"},
        {"lib/jido_code_web/controllers/signal.html.heex", "<div dstar-signals=\"{}\">"}
      ])

    for diagnostic <- [
          "product LiveView route",
          "raw graph query",
          "raw store access",
          "inline script",
          "inline event handler",
          "Datastar product behavior"
        ] do
      assert Enum.any?(errors, &String.contains?(&1, diagnostic))
    end
  end

  test "successor evidence owns only explicit C3 changes to accepted predecessor paths" do
    for path <- [
          "config/config.exs",
          "config/test.exs",
          "lib/jido_code/identity/store.ex",
          "lib/jido_code_web/components/layouts/root.html.heex",
          "lib/jido_code_web/product_auth.ex",
          "lib/jido_code_web/router.ex"
        ] do
      assert HypermediaUISuccessorEvidence.phase_c3_mutable_path?(path)
    end

    refute HypermediaUISuccessorEvidence.phase_c3_mutable_path?("assets/js/app.js")
    refute HypermediaUISuccessorEvidence.phase_c3_mutable_path?("assets/vendor/datastar.js")
  end
end

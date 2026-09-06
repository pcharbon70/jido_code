defmodule JidoCode.Architecture.HypermediaUIPhaseC4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseC4
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  test "accepts the complete merge-pending read-projection candidate" do
    assert HypermediaUIPhaseC4.check() == {:ok, []}
  end

  test "rejects query, bound, cache, lifecycle, browser, and source drift" do
    {:ok, evidence} = HypermediaUIPhaseC4.load()

    mutations = [
      {put_in(evidence, ["query_contract", "version"], "unreviewed"), "query version"},
      {put_in(evidence, ["query_contract", "scan_limit"], 10_000), "scan limit"},
      {put_in(evidence, ["query_contract", "semantic_writes"], 1), "semantic writes"},
      {put_in(evidence, ["cache_security", "reauthorize_on_hit"], false),
       "cache-hit authorization"},
      {update_in(evidence, ["integration", "browser_profiles"], &tl/1), "browser profiles"},
      {put_in(evidence, ["integration", "results", "browser_matrix"], "pending"),
       "integration results"},
      {Map.put(evidence, "completed_sections", ["4.2", "4.1"]), "completed section order"}
    ]

    for {mutated, diagnostic} <- mutations do
      assert Enum.any?(
               HypermediaUIPhaseC4.validate(mutated, File.cwd!()),
               &String.contains?(&1, diagnostic)
             )
    end

    [path | _rest] = Map.keys(evidence["source_digests"])
    digest_drift = put_in(evidence, ["source_digests", path], String.duplicate("0", 64))

    assert Enum.any?(
             HypermediaUIPhaseC4.validate(digest_drift, File.cwd!()),
             &String.contains?(&1, "source digest")
           )
  end

  test "source inspection rejects raw graph/store/command access and active browser runtimes" do
    errors =
      HypermediaUIPhaseC4.validate_product_sources([
        {"lib/jido_code_web/router.ex", ~s(live "/factory", FactoryLive)},
        {"lib/jido_code/product/raw.ex", "SELECT * WHERE { ?s ?p ?o }\nalias TripleStore"},
        {"lib/jido_code/product/write.ex", "CommandGateway.execute_command(command)"},
        {"lib/jido_code_web/controllers/raw.html.heex", "<script>run()</script>"},
        {"lib/jido_code_web/controllers/handler.html.heex", "<button onclick=\"run()\">"},
        {"lib/jido_code_web/controllers/signal.html.heex", "<div dstar-signals=\"{}\">"}
      ])

    for diagnostic <- [
          "product LiveView route",
          "raw graph query",
          "raw store access",
          "semantic command access",
          "inline script",
          "inline event handler",
          "Datastar product behavior"
        ] do
      assert Enum.any?(errors, &String.contains?(&1, diagnostic))
    end
  end

  test "successor evidence owns only explicit C4 changes to accepted predecessor paths" do
    for path <- [
          "lib/jido_code/application.ex",
          "lib/jido_code_web/controllers/factory_html/attention.html.heex",
          "lib/jido_code_web/controllers/project_html/overview.html.heex",
          "lib/jido_code_web/product_controller.ex",
          "lib/mix/tasks/architecture.check.ex"
        ] do
      assert HypermediaUISuccessorEvidence.phase_c4_mutable_path?(path)
    end

    refute HypermediaUISuccessorEvidence.phase_c4_mutable_path?("assets/js/app.js")
    refute HypermediaUISuccessorEvidence.phase_c4_mutable_path?("lib/jido_code_web/router.ex")
  end
end

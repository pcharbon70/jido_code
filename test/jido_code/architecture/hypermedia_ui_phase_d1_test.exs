defmodule JidoCode.Architecture.HypermediaUIPhaseD1Test do
  use ExUnit.Case, async: true
  alias JidoCode.Architecture.{HypermediaUIPhaseD1, HypermediaUISuccessorEvidence}

  test "the exact D1 schema, route, root and evidence boundary passes" do
    assert HypermediaUIPhaseD1.check() == {:ok, []}
  end

  test "authority, bounds, runtime, source and lifecycle drift cannot close the gate" do
    {:ok, evidence} = HypermediaUIPhaseD1.load()

    for {mutated, diagnostic} <- [
          {put_in(evidence, ["limits", "request_bytes"], 1_000_000), "limits"},
          {put_in(evidence, ["limits", "patch_roots"], 2), "limits"},
          {put_in(evidence, ["runtime_successor", "routes"], []), "runtime successor"},
          {Map.put(evidence, "invariants", []), "reopening invariants"},
          {Map.put(evidence, "baseline_commit", String.duplicate("0", 40)),
           "authorized baseline"},
          {Map.put(evidence, "status", "accepted"), "lifecycle"},
          {Map.put(evidence, "source_digests", %{}), "source inventory"},
          {put_in(
             evidence,
             ["source_digests", "lib/jido_code_web/read_signals.ex"],
             String.duplicate("0", 64)
           ), "source digest"}
        ] do
      assert Enum.any?(
               HypermediaUIPhaseD1.validate(mutated, File.cwd!()),
               &String.contains?(&1, diagnostic)
             )
    end
  end

  test "successor ownership is narrow and never includes identity or query authority" do
    assert HypermediaUISuccessorEvidence.phase_d1_mutable_path?("lib/jido_code_web/router.ex")

    refute HypermediaUISuccessorEvidence.phase_d1_mutable_path?(
             "lib/jido_code/identity/authority_builder.ex"
           )

    refute HypermediaUISuccessorEvidence.phase_d1_mutable_path?(
             "lib/jido_code/product/graph_read_projection_provider.ex"
           )

    refute HypermediaUISuccessorEvidence.phase_d1_mutable_path?(
             "assets/vendor/datastar/datastar.js"
           )
  end

  test "the predecessor permits only the exact reviewed expression source" do
    path = "lib/jido_code_web/read_enhancement.ex"
    source = File.read!(path)
    checker = JidoCode.Architecture.HypermediaUIPhaseB2
    assert checker.check_product_sources([{path, source}]) == []
    assert checker.check_product_sources([{path, source <> "\n# altered expression"}]) != []
    assert checker.check_product_sources([{"lib/jido_code_web/other.ex", source}]) != []
  end
end

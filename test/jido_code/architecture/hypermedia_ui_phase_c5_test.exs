defmodule JidoCode.Architecture.HypermediaUIPhaseC5Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseC5
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  test "accepts the complete merge-pending HUI-C5 and HUI3 candidate" do
    assert HypermediaUIPhaseC5.check() == {:ok, []}
  end

  test "rejects integration, lifecycle, and source drift" do
    {:ok, evidence} = HypermediaUIPhaseC5.load()

    mutations = [
      {Map.put(evidence, "completed_sections", ["5.2", "5.1"]), "completed section order"},
      {put_in(evidence, ["integration", "browser_profiles"], ["chromium"]), "browser profiles"},
      {put_in(evidence, ["integration", "browser_failures"], 1), "browser failures"},
      {put_in(evidence, ["integration", "results", "architecture_boundary"], "pending"),
       "evidence results"},
      {Map.put(evidence, "baseline_commit", String.duplicate("0", 40)), "authorized baseline"}
    ]

    for {mutated, diagnostic} <- mutations do
      assert Enum.any?(
               HypermediaUIPhaseC5.validate(mutated, File.cwd!()),
               &String.contains?(&1, diagnostic)
             )
    end

    [path | _rest] = Map.keys(evidence["source_digests"])
    digest_drift = put_in(evidence, ["source_digests", path], String.duplicate("0", 64))

    assert Enum.any?(
             HypermediaUIPhaseC5.validate(digest_drift, File.cwd!()),
             &String.contains?(&1, "source digest")
           )
  end

  test "successor evidence owns only the C5 architecture closure paths" do
    for path <- [
          "lib/jido_code/architecture/hypermedia_ui_phase_c4.ex",
          "lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex",
          "lib/mix/tasks/architecture.check.ex"
        ] do
      assert HypermediaUISuccessorEvidence.phase_c5_mutable_path?(path)
    end

    refute HypermediaUISuccessorEvidence.phase_c5_mutable_path?("assets/css/app.css")
    refute HypermediaUISuccessorEvidence.phase_c5_mutable_path?("lib/jido_code_web/router.ex")
  end
end

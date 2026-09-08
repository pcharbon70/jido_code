defmodule JidoCode.Architecture.HypermediaUIPhaseD4Test do
  use ExUnit.Case, async: true
  alias JidoCode.Architecture.HypermediaUIPhaseD4, as: Phase

  test "candidate source inventory and predecessor evidence remain exact" do
    assert {:ok, []} = Phase.check()
    {:ok, evidence} = Phase.load()

    for {key, value} <- [
          {"source_digests", %{}},
          {"predecessor_source_digests", %{}},
          {"baseline_commit", "wrong"},
          {"status", "accepted_at_merged_candidate"},
          {"completed_sections", ["4.1"]},
          {"independent_reviews", "self-approved"},
          {"browser_toolchain", "1.62.0"},
          {"triple_store_candidate", "6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f"},
          {"merged_candidate", "invented"}
        ] do
      refute Phase.validate(Map.put(evidence, key, value), File.cwd!()) == []
    end
  end
end

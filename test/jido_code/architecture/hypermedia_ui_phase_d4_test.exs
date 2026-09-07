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
          {"merged_candidate", "invented"}
        ] do
      refute Phase.validate(Map.put(evidence, key, value), File.cwd!()) == []
    end
  end
end

defmodule JidoCode.Architecture.HypermediaUIPhaseD3Test do
  use ExUnit.Case, async: true
  alias JidoCode.Architecture.HypermediaUIPhaseD3, as: Phase

  test "D3 evidence preserves predecessor and source boundaries" do
    assert {:ok, []} = Phase.check()
    {:ok, e} = Phase.load()

    for {key, value} <- [
          {"source_digests", %{}},
          {"invariants", []},
          {"predecessor_source_digests", %{}},
          {"baseline_commit", "wrong"},
          {"status", "accepted_at_merged_candidate"}
        ] do
      refute Phase.validate(Map.put(e, key, value), File.cwd!()) == []
    end
  end
end

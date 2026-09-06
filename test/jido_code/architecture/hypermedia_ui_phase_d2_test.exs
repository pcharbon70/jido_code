defmodule JidoCode.Architecture.HypermediaUIPhaseD2Test do
  use ExUnit.Case, async: true
  alias JidoCode.Architecture.HypermediaUIPhaseD2, as: Phase

  test "D2 evidence and all reopening invariants validate" do
    assert {:ok, []} = Phase.check()
  end

  test "provenance, missing source, premature acceptance and weakened invariants fail" do
    assert {:ok, evidence} = Phase.load()

    for {key, value} <- [
          {"baseline_commit", "wrong"},
          {"source_digests", %{}},
          {"status", "accepted_at_merged_candidate"},
          {"invariants", []},
          {"runtime_successor", %{}}
        ] do
      refute Phase.validate(Map.put(evidence, key, value), File.cwd!()) == []
    end
  end
end

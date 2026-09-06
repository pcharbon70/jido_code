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
      mutated = Map.put(evidence, key, value)

      mutated =
        if key == "status",
          do: Map.put(mutated, "merged_candidate", String.duplicate("0", 40)),
          else: mutated

      refute Phase.validate(mutated, File.cwd!()) == []
    end
  end

  test "integration acceptance cannot omit real HTTP, browser, accessibility or precommit evidence" do
    assert {:ok, evidence} = Phase.load()
    candidate = Map.put(evidence, "status", "integration_candidate_merge_pending")

    for key <- ["local_verification", "qualification"] do
      refute Phase.validate(Map.put(candidate, key, nil), File.cwd!()) == []
    end
  end
end

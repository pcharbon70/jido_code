defmodule JidoCode.Architecture.HypermediaUIPhaseD3Test do
  use ExUnit.Case, async: true
  alias JidoCode.Architecture.HypermediaUIPhaseD3, as: Phase

  test "accepted closure requires completed frontmatter, not completed wording in the body" do
    assert Phase.completed_plan?("---\nid: phase\nstatus: completed\n---\n# Phase")
    refute Phase.completed_plan?("---\nstatus: proposed\n---\nstatus: completed")
    refute Phase.completed_plan?("---\nstatus: completed\nstatus: proposed\n---")
    refute Phase.completed_plan?("status: completed")
    refute Phase.completed_plan?("---\nstatus: completed-later\n---")
  end

  test "D3 evidence preserves predecessor and source boundaries" do
    assert {:ok, []} = Phase.check()
    {:ok, e} = Phase.load()

    for {key, value} <- [
          {"source_digests", %{}},
          {"invariants", []},
          {"predecessor_source_digests", %{}},
          {"baseline_commit", "wrong"},
          {"status", "unsupported"},
          {"merged_candidate", "wrong"}
        ] do
      refute Phase.validate(Map.put(e, key, value), File.cwd!()) == []
    end
  end
end

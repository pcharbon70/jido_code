defmodule JidoCode.Architecture.HypermediaUIPhaseC1Test do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.HypermediaUIPhaseC1
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  test "pins the authorized HUI-C1 baseline, invariants, and current sources" do
    assert {:ok, []} = HypermediaUIPhaseC1.check()
    assert {:ok, evidence} = HypermediaUIPhaseC1.load()
    assert evidence["completed_sections"] == ["1.1", "1.2", "1.3", "1.4"]
  end

  test "rejects reordered sections and source drift" do
    assert {:ok, evidence} = HypermediaUIPhaseC1.load()

    reordered = Map.put(evidence, "completed_sections", ["1.2", "1.1"])
    assert Enum.any?(HypermediaUIPhaseC1.validate(reordered, File.cwd!()), &(&1 =~ "order"))

    drifted = put_in(evidence, ["source_digests", "config/config.exs"], String.duplicate("0", 64))
    assert Enum.any?(HypermediaUIPhaseC1.validate(drifted, File.cwd!()), &(&1 =~ "source digest"))
  end

  test "rejects an accepted lifecycle without merged candidate provenance" do
    assert {:ok, evidence} = HypermediaUIPhaseC1.load()

    false_acceptance =
      evidence
      |> Map.put("status", "accepted_at_merged_candidate")
      |> Map.put("receipt_status", "accepted_at_merged_candidate")
      |> Map.put("clean_checkout_ci", "pass")

    assert Enum.any?(
             HypermediaUIPhaseC1.validate(false_acceptance, File.cwd!()),
             &(&1 =~ "receipt lifecycle")
           )
  end

  test "successor evidence cannot override dependency or asset pins" do
    refute HypermediaUISuccessorEvidence.mutable_path?("mix.lock")
    refute HypermediaUISuccessorEvidence.mutable_path?("assets/vendor/datastar/datastar.js")
    assert HypermediaUISuccessorEvidence.digest(File.cwd!(), "mix.lock") == nil
  end
end

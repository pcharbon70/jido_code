defmodule JidoCode.Factory.ManagedCodingPhase06IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.QualificationAudit
  alias JidoCode.TestSupport.ManagedCodingPhase06Fixture

  test "reconciles the exact profile from task admission through human outcome" do
    evidence = ManagedCodingPhase06Fixture.evidence()

    assert {:ok, audit} =
             QualificationAudit.verify(evidence, ManagedCodingPhase06Fixture.drills())

    assert audit.release_ready
    assert audit.profile_digest == ManagedCodingPhase06Fixture.digest()

    assert Enum.sort(audit.reconciled_links) ==
             Enum.sort([
               :task_iri,
               :attempt_iri,
               :effect_iri,
               :candidate_iri,
               :verification_iri,
               :publication_iri,
               :operator_decision_iri,
               :reviewer_actor_iri
             ])
  end

  test "material profile drift invalidates prior qualification" do
    evidence =
      ManagedCodingPhase06Fixture.evidence()
      |> Map.put(:candidate_digest, String.duplicate("b", 64))

    assert {:error, %AdapterError{kind: :corrupt}} =
             QualificationAudit.verify(evidence, ManagedCodingPhase06Fixture.drills())
  end

  test "requires every shadow, pilot, stop, disable, incident, rollback, and reenable drill" do
    evidence = ManagedCodingPhase06Fixture.evidence()
    incomplete = QualificationAudit.drills() -- [:shadow_non_interference, :human_merge, :disable]

    assert {:error, %AdapterError{kind: :corrupt}} =
             QualificationAudit.verify(evidence, incomplete)
  end

  test "fails closed when shadow interferes, human merge is bypassed, or findings remain" do
    base = ManagedCodingPhase06Fixture.evidence()

    for evidence <- [
          %{base | shadow_influenced_live_work: true},
          %{base | human_merged: false},
          %{base | runtime_merge_authority: true},
          %{base | unresolved_findings: ["pilot regression"]},
          %{base | evidence_complete: false}
        ] do
      assert {:error, %AdapterError{kind: :corrupt}} =
               QualificationAudit.verify(evidence, ManagedCodingPhase06Fixture.drills())
    end
  end
end

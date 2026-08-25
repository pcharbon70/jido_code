defmodule JidoCode.TestSupport.ManagedCodingPhase06Fixture do
  @moduledoc false

  alias JidoCode.Factory.ManagedCoding.QualificationAudit

  @digest String.duplicate("a", 64)

  def evidence do
    %{
      task_iri: iri("task"),
      attempt_iri: iri("attempt"),
      effect_iri: iri("effect"),
      candidate_iri: iri("candidate"),
      verification_iri: iri("verification"),
      publication_iri: iri("publication"),
      operator_decision_iri: iri("operator-decision"),
      reviewer_actor_iri: iri("human-reviewer"),
      profile_digest: @digest,
      effect_digest: @digest,
      candidate_digest: @digest,
      verification_digest: @digest,
      publication_digest: @digest,
      operator_decision_digest: @digest,
      evaluation_qualified: true,
      shadow_influenced_live_work: false,
      publication_mode: :draft,
      human_reviewed: true,
      human_approved: true,
      human_merged: true,
      runtime_approval_authority: false,
      runtime_merge_authority: false,
      evidence_complete: true,
      unresolved_findings: []
    }
  end

  def drills, do: QualificationAudit.drills()
  def digest, do: @digest
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

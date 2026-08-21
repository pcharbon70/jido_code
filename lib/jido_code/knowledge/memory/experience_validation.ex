defmodule JidoCode.Knowledge.Memory.ExperienceValidation do
  @moduledoc "Independent validation of a quarantined experience candidate."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CandidateFactOrSummary
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.ExperienceSourceManifest
  alias JidoCode.Knowledge.Memory.ExperienceTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec validate(
          ExperienceCase.t(),
          CandidateFactOrSummary.t(),
          ExperienceSourceManifest.t(),
          map(),
          map()
        ) :: {:ok, map()} | {:error, Error.t()}
  def validate(
        %ExperienceCase{} = experience,
        %CandidateFactOrSummary{} = summary,
        %ExperienceSourceManifest{} = manifest,
        quarantine_report,
        attributes
      )
      when is_map(quarantine_report) and is_map(attributes) do
    with true <- quarantine_report[:clear?] == true and quarantine_report[:reasons] == [],
         true <- quarantine_report[:case_iri] == experience.iri,
         true <- quarantine_report[:summary_iri] == summary.iri,
         true <- quarantine_report[:source_manifest_digest] == manifest.digest,
         true <- summary.author_iri != attributes[:validator_iri],
         :ok <- ResourceIdentity.validate(attributes[:validator_iri]),
         :ok <- ResourceIdentity.validate(attributes[:evidence_iri]),
         true <- attributes[:source_manifest_digest] == manifest.digest,
         true <- attributes[:expected_graph_revisions] == manifest.source_graph_revisions,
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- DateTime.compare(recorded_at, manifest.effective_at) in [:gt, :eq],
         {:ok, transition} <-
           ExperienceTransition.new(%{
             case_iri: experience.iri,
             prior_state: :candidate,
             next_state: :validated,
             revision: 1,
             expected_predecessor: experience.transition.iri,
             actor_iri: attributes.validator_iri,
             cause_iri: attributes.evidence_iri,
             reason: "independent evidence validated experience case",
             recorded_at: recorded_at
           }) do
      {:ok,
       %{
         revision: @revision,
         case: experience,
         summary: summary,
         manifest: manifest,
         quarantine_report: quarantine_report,
         validator_iri: attributes.validator_iri,
         validation_evidence_iri: attributes.evidence_iri,
         transition: transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def validate(_experience, _summary, _manifest, _report, _attributes), do: invalid()

  defp invalid, do: {:error, Error.new(:unauthorized, :experience_validation)}
end

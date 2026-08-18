defmodule JidoCode.Factory.Evaluation.AdjudicationResult do
  @moduledoc "Independent correctness decision with advisory-only judge provenance."

  @enforce_keys [
    :task_iri,
    :candidate_digest,
    :correct?,
    :human_verdict,
    :resolver_used?,
    :evidence_iris,
    :llm_judges_advisory_only?,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end

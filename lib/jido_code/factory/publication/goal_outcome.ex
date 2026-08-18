defmodule JidoCode.Factory.Publication.GoalOutcome do
  @moduledoc "Recorded external-observation, post-change-evidence, and FinalGoal result."

  @enforce_keys [
    :publication_attempt_iri,
    :external_revision,
    :confirmation_iri,
    :post_change_snapshot_iri,
    :evidence_iris,
    :disposition,
    :observation_receipt,
    :evidence_receipt,
    :decision_receipt,
    :goal_satisfied?,
    :terminal?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end

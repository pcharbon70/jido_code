defmodule JidoCode.Factory.Evaluation.RunPlan do
  @moduledoc "Frozen Phase 7 trial assignments for one pinned target and corpus."

  @enforce_keys [
    :profile_revision,
    :track,
    :corpus_revision,
    :corpus_digest,
    :target,
    :assignments,
    :provider_seed_control?,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end

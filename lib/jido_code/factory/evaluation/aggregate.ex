defmodule JidoCode.Factory.Evaluation.Aggregate do
  @moduledoc "Reproducible Phase 7 aggregate with explicit denominators and methods."

  @enforce_keys [
    :profile_revision,
    :track,
    :trial_count,
    :task_count,
    :counts,
    :binary_metrics,
    :continuous_metrics,
    :diagnostics,
    :analysis_revision,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end

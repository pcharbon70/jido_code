defmodule JidoCode.Factory.Evaluation.Adversarial.Report do
  @moduledoc "Complete release-suite outcome with utility and security kept distinct."

  @enforce_keys [
    :profile_revision,
    :scenario_count,
    :utility_counts,
    :security_counts,
    :safe_failures,
    :violating_successes,
    :critical_violations,
    :clean_control_failures,
    :release_eligible?,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end

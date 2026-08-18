defmodule JidoCode.Factory.Verification.Evidence do
  @moduledoc "Structured verifier output with no transition or acceptance authority."

  @enforce_keys [
    :admission_digest,
    :environment_digest,
    :base_workspace_digest,
    :candidate_workspace_digest,
    :checks,
    :findings,
    :evidence_command,
    :acceptance_authority?,
    :transition_authority?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{evidence_command: term()}
end

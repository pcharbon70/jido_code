defmodule JidoCode.Factory.Tool.Authorization do
  @moduledoc "Transient authorization explanation; never reusable effect authority."

  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Factory.Tool.Proposal

  @derive {Inspect,
           only: [:proposal_digest, :tool_name, :tool_version, :decision_digest, :authorized_at]}
  @enforce_keys [
    :proposal,
    :proposal_digest,
    :tool_name,
    :tool_version,
    :definition,
    :arguments,
    :capability,
    :decision_digest,
    :authorized_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          proposal: Proposal.t(),
          definition: Definition.t(),
          capability: Capability.t()
        }
end

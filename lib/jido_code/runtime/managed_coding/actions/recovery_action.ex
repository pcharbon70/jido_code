defmodule JidoCode.Runtime.ManagedCoding.Actions.RecoveryAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_recovery",
    description: "Advance a non-effecting graph reconstruction watermark",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      reconstruction_watermark: [type: :non_neg_integer, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:recovery, params, context)
end

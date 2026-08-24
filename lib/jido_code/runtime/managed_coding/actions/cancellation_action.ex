defmodule JidoCode.Runtime.ManagedCoding.Actions.CancellationAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_cancellation",
    description: "Advance one current cancellation request or completion",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:cancellation, params, context)
end

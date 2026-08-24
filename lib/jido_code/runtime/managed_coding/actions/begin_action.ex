defmodule JidoCode.Runtime.ManagedCoding.Actions.BeginAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_begin",
    description: "Begin one admitted managed coding attempt",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:begin, params, context)
end

defmodule JidoCode.Runtime.ManagedCoding.Actions.ModelResultAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_model_result",
    description: "Accept one correlated closed model result",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      invocation_iri: [type: :string, required: true],
      kind: [type: :atom, required: true],
      next_invocation_iri: [type: :string, required: false]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:model_result, params, context)
end

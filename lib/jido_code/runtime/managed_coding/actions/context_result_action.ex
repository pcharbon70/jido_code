defmodule JidoCode.Runtime.ManagedCoding.Actions.ContextResultAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_context_result",
    description: "Accept one exact compiled context result",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      context_digest: [type: :string, required: true],
      model_invocation_iri: [type: :string, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:context_result, params, context)
end

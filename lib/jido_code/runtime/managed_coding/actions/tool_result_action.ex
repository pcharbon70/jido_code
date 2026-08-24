defmodule JidoCode.Runtime.ManagedCoding.Actions.ToolResultAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_tool_result",
    description: "Accept one correlated governed tool result",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      invocation_iri: [type: :string, required: true],
      kind: [type: :atom, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:tool_result, params, context)
end

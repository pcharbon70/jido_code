defmodule JidoCode.Runtime.ManagedCoding.Actions.BudgetExhaustedAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_budget_exhausted",
    description: "Stop before a disallowed next managed coding effect",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      dimension: [type: :atom, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:budget_exhausted, params, context)
end

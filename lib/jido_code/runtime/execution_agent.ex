defmodule JidoCode.Runtime.ExecutionAgent do
  @moduledoc false

  use Jido.Agent,
    name: "jido_code_execution",
    description: "Ephemeral worker for one graph-authorized execution attempt",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      execution_status: [type: :atom, default: :prepared],
      last_sequence: [type: :non_neg_integer, default: 0]
    ],
    signal_routes: [
      {"jido_code.runtime.transition", JidoCode.Runtime.ExecutionTransitionAction}
    ]
end

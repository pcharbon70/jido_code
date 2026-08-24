defmodule JidoCode.Runtime.ManagedCoding.Actions.CandidateResultAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_candidate_result",
    description: "Accept one immutable local candidate capture result",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      invocation_iri: [type: :string, required: true],
      candidate_digest: [type: :string, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:candidate_result, params, context)
end

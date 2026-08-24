defmodule JidoCode.Runtime.ManagedCoding.Actions.ActorResponseAction do
  @moduledoc false

  use Jido.Action,
    name: "managed_coding_actor_response",
    description: "Accept one bounded authenticated actor response",
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      sequence: [type: :pos_integer, required: true],
      invocation_iri: [type: :string, required: true]
    ]

  @impl true
  def run(params, context),
    do: JidoCode.Runtime.ManagedCoding.ActionSupport.run(:actor_response, params, context)
end

defmodule JidoCode.Runtime.ExecutionTransitionAction do
  @moduledoc false

  use Jido.Action,
    name: "execution_transition",
    description: "Updates disposable execution worker status",
    schema: [
      execution_status: [type: :atom, required: true],
      sequence: [type: :non_neg_integer, required: true]
    ]

  @impl true
  def run(params, context) do
    current = Map.get(context.state, :last_sequence, 0)

    if params.sequence >= current do
      {:ok,
       %{
         execution_status: params.execution_status,
         last_sequence: params.sequence
       }}
    else
      {:error, :stale_runtime_sequence}
    end
  end
end

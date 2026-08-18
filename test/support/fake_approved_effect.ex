defmodule JidoCode.TestSupport.FakeApprovedEffect do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ApprovedEffect

  @impl true
  def execute(state, request, options) do
    case state do
      %{owner: owner} when is_pid(owner) ->
        send(owner, {:approved_effect, :execute, request.invocation_iri})

      _state ->
        :ok
    end

    Keyword.get(
      options,
      :result,
      {:ok,
       %{
         status: :succeeded,
         external_effect_id: "effect-#{request.action_digest}",
         result_digest: request.action_digest
       }}
    )
  end
end

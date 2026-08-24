defmodule JidoCode.Runtime.ManagedCoding.ActionSupport do
  @moduledoc false

  alias JidoCode.Runtime.ManagedCoding.Transition

  @spec run(atom(), map(), map()) :: {:ok, map()} | {:error, term()}
  def run(event, params, context) when is_atom(event) and is_map(params) and is_map(context) do
    Transition.apply(context.state, event, params)
  end
end

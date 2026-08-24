defmodule JidoCode.TestSupport.FakeManagedCodingDirective do
  @moduledoc false
  @behaviour JidoCode.Factory.Ports.ManagedCodingDirective

  alias JidoCode.Factory.AdapterError

  @impl true
  def execute(state, envelope, _options) do
    send(state.owner, {:directive_effect, self(), envelope})

    case Map.get(state, :mode, :success) do
      :success -> {:ok, Map.get(state, :result, %{outcome: :completed})}
      :wait -> receive(do: (:release -> {:ok, Map.get(state, :result, %{outcome: :completed})}))
      :crash -> raise "private backend crash"
      :corrupt -> {:ok, self()}
      :error -> {:error, AdapterError.new(:unavailable, :private_backend)}
    end
  end
end

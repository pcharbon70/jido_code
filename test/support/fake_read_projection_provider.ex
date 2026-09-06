defmodule JidoCode.TestSupport.FakeReadProjectionProvider do
  @moduledoc false

  @behaviour JidoCode.Product.ReadProjectionProvider

  @impl true
  def load(context, _options) do
    if test_pid = Application.get_env(:jido_code, :read_projection_test_pid) do
      send(test_pid, {:read_projection_load, context})
    end

    fixture = Application.fetch_env!(:jido_code, :read_projection_fixture)

    case fixture do
      fun when is_function(fun, 1) -> {:ok, fun.(context)}
      fixtures when is_map(fixtures) -> {:ok, Map.fetch!(fixtures, context.page.key)}
    end
  end
end

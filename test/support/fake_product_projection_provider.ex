defmodule JidoCode.TestSupport.FakeProductProjectionProvider do
  @moduledoc false

  @behaviour JidoCodeWeb.Product.ProjectionProvider

  @impl true
  def load(authority, identity, options) do
    if test_pid = Application.get_env(:jido_code, :product_projection_test_pid) do
      send(test_pid, {:product_projection_load, authority, identity, options})
    end

    {:ok, Application.fetch_env!(:jido_code, :product_projection_fixture)}
  end
end

defmodule JidoCodeWeb.StreamProjectionRegistryTest do
  use JidoCodeWeb.ConnCase, async: false
  alias JidoCode.Product.StreamProjectionRegistry, as: Registry

  test "only trusted route state selects the callback, scope, graph family and root", %{
    conn: conn
  } do
    conn = conn |> init_test_session(%{}) |> sign_in_named_human() |> get("/factory")
    page = conn.assigns.page
    assert {:ok, binding} = Registry.build(page)
    assert binding.root == "#product-owned-content"
    assert binding.scopes == [page.authorization.product_identity.factory_scope_iri]
    assert binding.families == Registry.entries().factory
    assert binding.refresh == (&JidoCode.Product.read_projection/2)

    assert {:ok, ^binding} =
             Registry.build(Map.merge(page, %{graph: "caller", root: "#other", refresh: :caller}))

    assert {:error, :unregistered_subscription} = Registry.build(%{page | key: :unregistered})

    assert {:error, :unregistered_subscription} =
             Registry.build(%{page | authorization: %{decision: :denied}})

    assert {:error, :unregistered_subscription} =
             Registry.build(%{page | key: :project, route_params: %{resource_ref: "unknown"}})

    assert Enum.sort(Map.keys(Registry.entries())) ==
             Enum.sort(JidoCodeWeb.ReadSignals.surfaces())

    assert Enum.all?(Registry.entries(), fn {_, families} ->
             Enum.all?(families, &(&1 in JidoCode.Knowledge.GraphRegistry.families()))
           end)
  end
end

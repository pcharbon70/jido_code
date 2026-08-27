defmodule JidoCodeWeb.Api.V1.AgentOfferingController do
  use JidoCodeWeb, :controller

  alias JidoCode.Product.AgentCatalogGateway
  alias JidoCode.Product.AgentOffering
  alias JidoCodeWeb.Api.V1.ProductResponse

  def index(conn, params) do
    gateway = Application.get_env(:jido_code, :agent_catalog_gateway, AgentCatalogGateway)

    case invoke(gateway, conn.assigns.authority, conn.assigns.product_identity, params) do
      {:ok, offerings} ->
        ProductResponse.ok(conn, %{offerings: Enum.map(offerings, &AgentOffering.safe_map/1)})

      {:error, error} ->
        ProductResponse.error(conn, error)
    end
  end

  defp invoke(gateway, authority, identity, params) when is_atom(gateway),
    do: gateway.list(authority, identity, params)

  defp invoke(gateway, authority, identity, params) when is_function(gateway, 3),
    do: gateway.(authority, identity, params)
end

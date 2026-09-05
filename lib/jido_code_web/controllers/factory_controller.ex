defmodule JidoCodeWeb.FactoryController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  @factory %{resource: :factory, operation: :factory_shell, area: :developer}

  def root(conn, params) do
    case JidoCodeWeb.ProductRequest.authorize(
           conn,
           spec(:factory, "Factory", "Factory home."),
           params
         ) do
      {:ok, conn, _page} -> redirect(conn, to: ~p"/factory")
      {:error, conn} -> conn
    end
  end

  def attention(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(:factory, "Needs attention", "Authorized factory attention and readiness."),
        :attention
      )

  def fleet(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(:fleet, "Fleet", "Authorized factory fleet and capacity."),
        :fleet
      )

  defp spec(key, title, summary),
    do:
      Map.merge(@factory, %{
        key: key,
        title: title,
        summary: summary,
        query: ["q", "state", "page"]
      })
end

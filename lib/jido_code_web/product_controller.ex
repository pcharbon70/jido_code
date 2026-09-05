defmodule JidoCodeWeb.ProductController do
  @moduledoc false

  import Phoenix.Controller

  alias JidoCodeWeb.ProductRequest

  def serve(conn, params, spec, template) do
    case ProductRequest.authorize(conn, spec, params) do
      {:ok, conn, page} ->
        render(conn, template,
          page: page,
          page_title: page.title,
          current_scope: conn.assigns[:current_scope]
        )

      {:error, conn} ->
        conn
    end
  end
end

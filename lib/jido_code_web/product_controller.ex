defmodule JidoCodeWeb.ProductController do
  @moduledoc false

  import Phoenix.Controller

  alias JidoCodeWeb.ProductRequest
  alias JidoCodeWeb.ProductPageViewModel

  def serve(conn, params, spec, template) do
    case prepare(conn, params, spec) do
      {:ok, conn, page, view_model} ->
        render(conn, template,
          page: page,
          view_model: view_model,
          page_title: page.title,
          canonical_url: page.canonical_url,
          current_scope: conn.assigns[:current_scope]
        )

      {:error, conn} ->
        conn
    end
  end

  def prepare(conn, params, spec) do
    case ProductRequest.authorize(conn, spec, params) do
      {:ok, conn, page} -> {:ok, conn, page, ProductPageViewModel.build(conn, page)}
      {:error, conn} -> {:error, conn}
    end
  end
end

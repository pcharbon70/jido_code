defmodule JidoCodeWeb.ProductController do
  @moduledoc false

  import Phoenix.Controller

  alias JidoCode.Product
  alias JidoCode.Product.ReadProjection
  alias JidoCodeWeb.ProductRequest
  alias JidoCodeWeb.ProductPageViewModel

  @read_surfaces [
    :factory,
    :fleet,
    :projects,
    :project,
    :project_attempts,
    :project_wiki,
    :project_dependencies,
    :attempt
  ]

  def serve(conn, params, spec, template) do
    case prepare(conn, params, spec) do
      {:ok, conn, page, projection, view_model} ->
        respond(conn, template,
          page: page,
          projection: projection,
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
      {:ok, conn, page} ->
        conn =
          Plug.Conn.put_private(conn, :read_authorization, {spec, params, page.authorization})

        projection = load_projection(conn, page)

        {:ok, conn, page, projection, ProductPageViewModel.build(conn, page, projection)}

      {:error, conn} ->
        {:error, conn}
    end
  end

  def respond(conn, template, assigns) do
    if conn.assigns[:enhanced_read] do
      JidoCodeWeb.ReadResponse.render(conn, template, assigns)
    else
      render(conn, template, assigns)
    end
  end

  defp load_projection(conn, %{key: key} = page) when key in @read_surfaces do
    context = %{
      session_ref: conn.assigns.authenticated_human.session_ref,
      current_scope: conn.assigns.current_scope,
      product_identity: conn.assigns.product_identity,
      authority: conn.assigns.authority,
      authorization: conn.assigns.authorization,
      page: page
    }

    case Product.read_projection(context) do
      {:ok, projection} -> projection
      {:error, _reason} -> ReadProjection.unavailable(key, :error)
    end
  end

  defp load_projection(_conn, _page), do: nil
end

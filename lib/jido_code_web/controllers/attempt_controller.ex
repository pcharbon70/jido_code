defmodule JidoCodeWeb.AttemptController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  def show(conn, params) do
    ProductController.serve(
      conn,
      params,
      %{
        key: :attempt,
        title: "Attempt workspace",
        summary: "Durable read-only attempt context and evidence.",
        resource: {:nested, "project_ref", :project, "attempt_ref", :attempt},
        operation: :attempt_page,
        area: :developer,
        query: ["q", "state", "page"]
      },
      :show
    )
  end
end

defmodule JidoCodeWeb.KnowledgeController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  def show(conn, params) do
    ProductController.serve(
      conn,
      params,
      %{
        key: :knowledge,
        title: "Knowledge lens",
        summary: "A closed, reviewed lens over authorized project knowledge.",
        resource: {:resource, "project_ref", :project},
        operation: :knowledge_page,
        area: :knowledge,
        lens: true,
        query: ["q", "page"]
      },
      :show
    )
  end
end

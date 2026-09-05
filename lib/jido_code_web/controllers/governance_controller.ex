defmodule JidoCodeWeb.GovernanceController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  def index(conn, params) do
    ProductController.serve(
      conn,
      params,
      %{
        key: :governance,
        title: "Governance",
        summary: "Separately authorized policy, identity, audit, and retention posture.",
        resource: :factory,
        operation: :administration_page,
        area: :administration,
        query: ["q", "page"]
      },
      :index
    )
  end
end

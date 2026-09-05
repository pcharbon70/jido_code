defmodule JidoCodeWeb.ReviewController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  def show(conn, params) do
    ProductController.serve(
      conn,
      params,
      %{
        key: :review,
        title: "Candidate review",
        summary: "Authorized evidence and disposition for one immutable candidate.",
        resource: {:resource, "candidate_ref", :candidate},
        operation: :evidence_page,
        area: :reviewer,
        query: ["page"]
      },
      :show
    )
  end
end

defmodule JidoCodeWeb.OperationsController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  @operations %{resource: :factory, operation: :operations_page, area: :operations}
  @costs %{resource: :factory, operation: :cost_page, area: :cost}

  def index(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(
          @operations,
          :operations,
          "Operations",
          "Capacity, providers, recovery, and service posture."
        ),
        :index
      )

  def costs(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(@costs, :costs, "Costs", "Authorized bounded cost and budget posture."),
        :costs
      )

  defp spec(base, key, title, summary),
    do:
      Map.merge(base, %{key: key, title: title, summary: summary, query: ["q", "state", "page"]})
end

defmodule JidoCodeWeb.SecurityController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  def index(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(:security, "Security", "Authorized security posture."),
        :index
      )

  def incidents(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(
          :incidents,
          "Security incidents",
          "Authorized incident posture without concealed details."
        ),
        :incidents
      )

  defp spec(key, title, summary),
    do: %{
      key: key,
      title: title,
      summary: summary,
      resource: :factory,
      operation: :security_page,
      area: :security,
      query: ["q", "state", "page"]
    }
end

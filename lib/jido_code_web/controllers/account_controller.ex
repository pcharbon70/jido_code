defmodule JidoCodeWeb.AccountController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController

  @session %{resource: :session, operation: :compatibility_product, area: :developer}

  def show(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(:account, "Account", "Current named-human account and assurance posture."),
        :show
      )

  def sessions(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(:sessions, "Sessions", "Current browser session and revocation controls."),
        :sessions
      )

  defp spec(key, title, summary),
    do: Map.merge(@session, %{key: key, title: title, summary: summary, query: []})
end

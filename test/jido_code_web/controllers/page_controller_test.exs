defmodule JidoCodeWeb.PageControllerTest do
  use JidoCodeWeb.ConnCase

  test "GET / redirects to setup when onboarding is incomplete", %{conn: conn} do
    conn = get(conn, ~p"/")

    redirect_to = redirected_to(conn)
    uri = URI.parse(redirect_to)

    assert uri.path == "/setup"
    assert URI.decode_query(uri.query || "")["step"] == "1"
  end
end

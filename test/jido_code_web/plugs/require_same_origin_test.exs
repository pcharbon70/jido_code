defmodule JidoCodeWeb.Plugs.RequireSameOriginTest do
  use JidoCodeWeb.ConnCase, async: true

  alias JidoCodeWeb.Plugs.RequireSameOrigin

  test "accepts an exact same origin and optional same-site fetch metadata", %{conn: conn} do
    conn =
      conn
      |> Map.put(:method, "POST")
      |> put_req_header("origin", "http://www.example.com")
      |> put_req_header("sec-fetch-site", "same-origin")
      |> RequireSameOrigin.call([])

    refute conn.halted
  end

  test "rejects missing, cross-origin, malformed, and cross-site browser writes", %{conn: conn} do
    candidates = [
      conn,
      put_req_header(conn, "origin", "https://attacker.invalid"),
      put_req_header(conn, "origin", "not-an-origin"),
      conn
      |> put_req_header("origin", "http://www.example.com")
      |> put_req_header("sec-fetch-site", "cross-site")
    ]

    for candidate <- candidates do
      rejected = candidate |> Map.put(:method, "POST") |> RequireSameOrigin.call([])
      assert rejected.halted
      assert rejected.status == 403
    end
  end

  test "does not apply an Origin requirement to safe methods", %{conn: conn} do
    refute conn |> Map.put(:method, "GET") |> RequireSameOrigin.call([]) |> Map.fetch!(:halted)
  end
end

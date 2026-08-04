defmodule JidoCodeWeb.AuthControllerTest do
  use JidoCodeWeb.ConnCase, async: true

  test "redirects an unauthenticated product request without disclosing state", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "renders the operator sign-in form", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")
    document = document(conn, 200)

    assert has_selector?(document, "#operator-sign-in-form")
    refute has_selector?(document, "input[value='test-operator-token']")
  end

  test "renews the session after valid authentication", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{"untrusted" => "old-session-value"})
      |> post(~p"/sign-in", operator: %{credential: "test-operator-token"})

    assert redirected_to(conn) == ~p"/"
    refute get_session(conn, "untrusted")
    assert is_integer(get_session(conn, "jido_code_authenticated_at"))
    assert get_session(conn, "jido_code_session_generation") == "test-1"
    assert is_binary(get_session(conn, "jido_code_session_nonce"))
  end

  test "rejects invalid or oversized credentials with the same safe response", %{conn: conn} do
    invalid = post(conn, ~p"/sign-in", operator: %{credential: "incorrect"})

    oversized =
      build_conn()
      |> post(~p"/sign-in", operator: %{credential: String.duplicate("x", 513)})

    assert invalid |> document(401) |> has_selector?("#operator-sign-in-error")
    assert oversized |> document(401) |> has_selector?("#operator-sign-in-error")
    refute get_session(invalid, "jido_code_authenticated_at")
    refute get_session(oversized, "jido_code_authenticated_at")
  end

  test "drops the authenticated session on sign out", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> JidoCodeWeb.ProductAuth.establish_session()
      |> delete(~p"/sign-out")

    assert redirected_to(conn) == ~p"/sign-in"
    refute get_session(conn, "jido_code_authenticated_at")
  end

  defp document(conn, status), do: conn |> html_response(status) |> LazyHTML.from_document()

  defp has_selector?(document, selector) do
    document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
  end
end

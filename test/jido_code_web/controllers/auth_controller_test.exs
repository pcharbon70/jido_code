defmodule JidoCodeWeb.AuthControllerTest do
  use JidoCodeWeb.ConnCase, async: false

  test "redirects an unauthenticated product request without disclosing state", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/sign-in?#{%{return_to: "/"}}"
  end

  test "renders the named-human sign-in form and a bounded return location", %{conn: conn} do
    conn = get(conn, ~p"/sign-in?#{%{return_to: "/coding-agents"}}")
    document = document(conn, 200)

    assert has_selector?(document, "#human-sign-in-form")
    assert has_selector?(document, "input[name='session[login]']")
    assert has_selector?(document, "input[name='session[credential]']")

    assert has_selector?(
             document,
             "input[name='session[return_to]'][value='/coding-agents']"
           )

    refute has_selector?(document, "input[value='test-named-human-credential']")
  end

  test "renews a server-side session after valid named-human authentication", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{"untrusted" => "old-session-value"})
      |> with_same_origin()
      |> post(~p"/sign-in",
        session: %{
          login: "operator@example.test",
          credential: "test-named-human-credential",
          return_to: "/coding-agents"
        }
      )

    assert redirected_to(conn) == ~p"/coding-agents"
    refute get_session(conn, "untrusted")
    assert is_binary(get_session(conn, "jido_code_human_session_ref"))
    refute get_session(conn, "jido_code_authenticated_at")
    refute get_session(conn, "jido_code_session_nonce")
  end

  test "rejects legacy, invalid, oversized, and cross-origin credentials with safe responses", %{
    conn: conn
  } do
    invalid =
      conn
      |> with_same_origin()
      |> post(~p"/sign-in",
        session: %{login: "operator@example.test", credential: "incorrect value"}
      )

    legacy =
      build_conn()
      |> with_same_origin()
      |> post(~p"/sign-in",
        session: %{login: "operator@example.test", credential: "test-operator-token"}
      )

    oversized =
      build_conn()
      |> with_same_origin()
      |> post(~p"/sign-in",
        session: %{
          login: "operator@example.test",
          credential: String.duplicate("x", 513)
        }
      )

    cross_origin =
      build_conn()
      |> put_req_header("origin", "https://attacker.invalid")
      |> post(~p"/sign-in",
        session: %{
          login: "operator@example.test",
          credential: "test-named-human-credential"
        }
      )

    for rejected <- [invalid, legacy, oversized] do
      assert rejected |> document(401) |> has_selector?("#human-sign-in-error")
      refute get_session(rejected, "jido_code_human_session_ref")
    end

    assert response(cross_origin, 403) == "Request origin was not accepted."
  end

  test "revokes the authenticated session on sign out", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> with_same_origin()
      |> delete(~p"/sign-out")

    assert redirected_to(conn) == ~p"/sign-in"
    refute get_session(conn, "jido_code_human_session_ref")
  end

  defp document(conn, status), do: conn |> html_response(status) |> LazyHTML.from_document()

  defp has_selector?(document, selector) do
    document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
  end
end

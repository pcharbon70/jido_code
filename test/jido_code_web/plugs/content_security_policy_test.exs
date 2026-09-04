defmodule JidoCodeWeb.Plugs.ContentSecurityPolicyTest do
  use JidoCodeWeb.ConnCase, async: true

  alias JidoCodeWeb.Plugs.ContentSecurityPolicy

  test "binds one response nonce to the CSP and root Datastar opt-in", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")
    [policy] = get_resp_header(conn, "content-security-policy")
    [_, nonce] = Regex.run(~r/'nonce-([A-Za-z0-9_-]+)'/, policy)
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query("html[data-nonce='#{nonce}'][data-shadcn-theme='light']")
           |> LazyHTML.to_html() != ""

    assert policy =~ "require-trusted-types-for 'script'"
    assert policy =~ "trusted-types datastar"
    refute policy =~ "unsafe-eval"
    refute policy =~ "unsafe-inline"
    refute policy =~ "https:"
  end

  test "creates a fresh nonce for every response", %{conn: conn} do
    [first] = conn |> get(~p"/sign-in") |> get_resp_header("content-security-policy")
    [second] = build_conn() |> get(~p"/sign-in") |> get_resp_header("content-security-policy")

    refute first == second
  end

  test "serves local static assets with immutable versioned caching and nosniff", %{conn: conn} do
    conn = get(conn, "/images/logo.svg?vsn=d")

    assert response(conn, 200) != ""
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(conn, "cross-origin-resource-policy") == ["same-origin"]
    assert get_resp_header(conn, "content-type") == ["image/svg+xml"]
  end

  test "policy rejects an empty nonce" do
    assert_raise FunctionClauseError, fn -> ContentSecurityPolicy.policy("") end
  end
end

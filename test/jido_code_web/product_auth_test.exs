defmodule JidoCodeWeb.ProductAuthTest do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCode.Identity
  alias JidoCodeWeb.ProductAuth

  test "keeps the configured operator credential isolated to the compatibility API" do
    assert ProductAuth.authenticate("test-operator-token") == :ok
    assert ProductAuth.authenticate("other-token") == :error
    assert ProductAuth.authenticate(String.duplicate("x", 513)) == :error

    assert {:error, :authentication_failed} =
             ProductAuth.authenticate_human("operator@example.test", "test-operator-token")

    assert {:ok, api_scope, _authority} = ProductAuth.api_scope("test-operator-token")
    assert api_scope.principal_class == :compatibility_operator
  end

  test "stores only an opaque named-human reference in the renewed browser session", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{"untrusted" => "old-session-value"})
      |> sign_in_named_human()

    refute get_session(conn, "untrusted")
    assert get_session(conn, "jido_code_human_session_ref") =~ ~r/^session_[A-Za-z0-9_-]+$/
    refute get_session(conn, "jido_code_authenticated_at")
    refute get_session(conn, "jido_code_session_generation")
    refute get_session(conn, "jido_code_session_nonce")
    refute get_session(conn, "actor_iri")
    refute get_session(conn, "assurance")
  end

  test "constructs named-human scope from current server records rather than cookie values", %{
    conn: conn
  } do
    conn =
      conn
      |> init_test_session(%{
        "actor_iri" => "https://attacker.invalid/actor",
        "principal_iri" => "https://attacker.invalid/principal",
        "assurance" => "action_bound_step_up"
      })
      |> sign_in_named_human()
      |> ProductAuth.fetch_current_scope([])

    scope = conn.assigns.current_scope
    assert scope.subject_ref == "human_test_operator"
    assert scope.principal_class == :human
    assert scope.assurance == :baseline
    assert scope.actor_iri == "https://jido.run/id/human/human_test_operator"
    assert scope.principal_iri == "https://jido.run/id/human/human_test_operator"
    assert conn.assigns.authority.actor_iri == scope.actor_iri
  end

  test "invalidates every current browser session after logout-all", %{conn: conn} do
    first = conn |> init_test_session(%{}) |> sign_in_named_human()
    second = build_conn() |> init_test_session(%{}) |> sign_in_named_human()

    first_scope = ProductAuth.fetch_current_scope(first, []).assigns.current_scope
    second_scope = ProductAuth.fetch_current_scope(second, []).assigns.current_scope
    assert first_scope
    assert second_scope

    assert :ok = ProductAuth.logout_all(first)
    refute ProductAuth.current_scope_valid?(first_scope)
    refute ProductAuth.current_scope_valid?(second_scope)
    assert ProductAuth.fetch_current_scope(second, []).assigns.current_scope == nil

    assert {:ok, _authentication} =
             Identity.authenticate("operator@example.test", "test-named-human-credential")
  end

  test "accepts only bounded local return locations" do
    assert ProductAuth.safe_return_path("/projects/example?tab=activity") ==
             "/projects/example?tab=activity"

    for hostile <- [
          "https://attacker.invalid/",
          "//attacker.invalid/",
          "javascript:alert(1)",
          "/sign-in",
          String.duplicate("/", 1_025),
          nil
        ] do
      assert ProductAuth.safe_return_path(hostile) == "/"
    end
  end
end

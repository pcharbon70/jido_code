defmodule JidoCodeWeb.ProductAuthTest do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCodeWeb.ProductAuth

  test "accepts only the configured credential digest" do
    assert ProductAuth.authenticate("test-operator-token") == :ok
    assert ProductAuth.authenticate("other-token") == :error
    assert ProductAuth.authenticate(String.duplicate("x", 513)) == :error
  end

  test "rejects expired and future sessions", %{conn: conn} do
    now = System.system_time(:second)

    expired =
      conn
      |> init_test_session(%{})
      |> ProductAuth.establish_session(authenticated_at: now - 3_601)
      |> ProductAuth.fetch_current_scope([])

    future =
      build_conn()
      |> init_test_session(%{})
      |> ProductAuth.establish_session(authenticated_at: now + 60)
      |> ProductAuth.fetch_current_scope([])

    assert expired.assigns.current_scope == nil
    assert future.assigns.current_scope == nil
  end

  test "invalidates every existing session when the trusted generation changes", %{conn: conn} do
    prior = Application.fetch_env!(:jido_code, :product_auth)

    conn =
      conn
      |> init_test_session(%{})
      |> ProductAuth.establish_session()

    Application.put_env(
      :jido_code,
      :product_auth,
      Keyword.put(prior, :session_generation, "test-2")
    )

    on_exit(fn -> Application.put_env(:jido_code, :product_auth, prior) end)

    conn = ProductAuth.fetch_current_scope(conn, [])
    assert conn.assigns.current_scope == nil
  end

  test "constructs authority from trusted product identity rather than session values", %{
    conn: conn
  } do
    conn =
      conn
      |> init_test_session(%{
        "actor_iri" => "https://attacker.invalid/actor",
        "principal_iri" => "https://attacker.invalid/principal"
      })
      |> ProductAuth.establish_session()
      |> ProductAuth.fetch_current_scope([])

    assert conn.assigns.current_scope.actor_iri ==
             "https://jido.run/id/actor/local-operator"

    assert conn.assigns.current_scope.principal_iri ==
             "https://jido.run/id/actor/local-operator"
  end
end

defmodule JidoCodeWeb.SessionWorkflowPhaseC3Test do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCodeWeb.ProductAuth

  test "renders configured sign-in posture with password-manager semantics and safe headers", %{
    conn: conn
  } do
    response = get(conn, ~p"/sign-in")
    document = response |> html_response(200) |> LazyHTML.from_document()

    assert has?(document, "#human-sign-in-form")
    assert has?(document, "input[autocomplete='username']")
    assert has?(document, "input[type='password'][autocomplete='current-password']")
    assert has?(document, "#human-recovery-link[href='/recovery']")
    assert get_resp_header(response, "cache-control") == ["no-store, private"]
    assert get_resp_header(response, "referrer-policy") == ["no-referrer"]
  end

  test "states unavailable step-up without soliciting or simulating elevated assurance", %{
    conn: conn
  } do
    current = conn |> init_test_session(%{}) |> sign_in_named_human()
    page = get(current, "/step-up?return_to=/security")
    document = page |> html_response(200) |> LazyHTML.from_document()

    assert has?(document, "#human-step-up-unavailable[role='status']")
    refute has?(document, "#human-step-up-form")
    refute has?(document, "input[type='password']")

    rejected =
      page
      |> recycle()
      |> with_same_origin()
      |> post(~p"/step-up", step_up: %{credential: "not-logged", return_to: "/security"})

    body = html_response(rejected, 503)
    assert body =~ "requested assurance could not be established"
    refute body =~ "not-logged"
  end

  test "returns generic recovery posture and response without account enumeration", %{conn: conn} do
    page = get(conn, ~p"/recovery")
    document = page |> html_response(200) |> LazyHTML.from_document()

    assert has?(document, "#human-recovery-unavailable[role='status']")
    assert has?(document, "#human-recovery-form")
    assert has?(document, "input[autocomplete='username']")

    known =
      conn
      |> recycle()
      |> with_same_origin()
      |> post(~p"/recovery", recovery: %{login: "operator@example.test"})

    unknown =
      build_conn()
      |> with_same_origin()
      |> post(~p"/recovery", recovery: %{login: "absent@example.test"})

    assert response_text(known, 202) == response_text(unknown, 202)
    refute html_response(known, 202) =~ "operator@example.test"
  end

  test "lists same-account sessions without exposing reusable browser session references", %{
    conn: conn
  } do
    first = conn |> init_test_session(%{}) |> sign_in_named_human()
    second = build_conn() |> init_test_session(%{}) |> sign_in_named_human()
    first_session_ref = get_session(first, "jido_code_human_session_ref")
    second_session_ref = get_session(second, "jido_code_human_session_ref")

    page = get(first, ~p"/account/sessions")
    body = html_response(page, 200)
    document = LazyHTML.from_document(body)

    assert has?(document, "#session-list")
    assert count(document, "#session-list > li") >= 2
    assert count(document, "#session-list > li[data-current-session='true']") == 1
    assert has?(document, "#session-logout-all-form")
    refute body =~ first_session_ref
    refute body =~ second_session_ref
  end

  test "revokes one other browser through a non-bearer management reference", %{conn: conn} do
    first = conn |> init_test_session(%{}) |> sign_in_named_human()
    second = build_conn() |> init_test_session(%{}) |> sign_in_named_human()

    authorized = ProductAuth.fetch_authenticated_session(first, [])
    {:ok, sessions} = ProductAuth.managed_sessions(authorized)
    target = Enum.find(sessions, &(not &1.current))

    ended =
      first
      |> with_same_origin()
      |> delete("/account/sessions/#{target.management_ref}")

    assert redirected_to(ended) == ~p"/account/sessions"
    assert get(ended |> recycle(), ~p"/factory").status == 200

    revoked = get(second |> recycle(), ~p"/factory")
    assert redirected_to(revoked) =~ "/sign-in?"
  end

  test "ending the current or all sessions rotates back to generic sign-in", %{conn: conn} do
    current = conn |> init_test_session(%{}) |> sign_in_named_human()
    authorized = ProductAuth.fetch_authenticated_session(current, [])
    {:ok, sessions} = ProductAuth.managed_sessions(authorized)
    target = Enum.find(sessions, & &1.current)

    ended =
      current
      |> with_same_origin()
      |> delete("/account/sessions/#{target.management_ref}")

    assert redirected_to(ended) == ~p"/sign-in?#{%{reason: "session-ended"}}"
    refute get_session(ended, "jido_code_human_session_ref")

    first = build_conn() |> init_test_session(%{}) |> sign_in_named_human()
    second = build_conn() |> init_test_session(%{}) |> sign_in_named_human()

    all_ended = first |> with_same_origin() |> delete(~p"/sessions")
    assert redirected_to(all_ended) == ~p"/sign-in"
    assert redirected_to(get(second |> recycle(), ~p"/factory")) =~ "/sign-in?"
  end

  defp response_text(conn, status) do
    conn
    |> html_response(status)
    |> LazyHTML.from_document()
    |> LazyHTML.query("#human-recovery")
    |> LazyHTML.text()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp has?(document, selector), do: count(document, selector) > 0
  defp count(document, selector), do: document |> LazyHTML.query(selector) |> Enum.count()
end

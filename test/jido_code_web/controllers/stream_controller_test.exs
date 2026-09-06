defmodule JidoCodeWeb.StreamControllerTest do
  use JidoCodeWeb.ConnCase, async: false
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture, as: Fixture
  alias JidoCode.Product.{ReadRequestLimiter, StreamCoordinator}

  @routes [
    {:factory, "/factory"},
    {:fleet, "/fleet"},
    {:projects, "/projects"},
    {:project, "/projects/project_browser_alpha/overview"},
    {:project_attempts, "/projects/project_browser_alpha/attempts"},
    {:project_wiki, "/projects/project_browser_alpha/wiki"},
    {:project_dependencies, "/projects/project_browser_alpha/dependencies"},
    {:attempt, "/projects/project_browser_alpha/attempts/attempt_browser_alpha"},
    {:account, "/account"},
    {:sessions, "/sessions"}
  ]

  setup %{conn: conn} do
    keys = [
      :product_read_projection_provider,
      :read_projection_fixture,
      :read_projection_test_pid
    ]

    prior = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    Application.put_env(:jido_code, :read_projection_test_pid, self())

    Application.put_env(:jido_code, :read_projection_fixture, fn context ->
      Fixture.projection(context.page.key)
    end)

    :sys.replace_state(ReadRequestLimiter, fn _ -> %{windows: %{}, leases: %{}} end)
    limits = :sys.get_state(StreamCoordinator).limits

    :sys.replace_state(StreamCoordinator, fn state ->
      %{state | windows: %{}, nonces: %{}, limits: %{limits | idle_ms: 1_000}}
    end)

    on_exit(fn ->
      :sys.replace_state(StreamCoordinator, &%{&1 | limits: limits})

      Enum.each(prior, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:jido_code, key),
          else: Application.put_env(:jido_code, key, value)
      end)
    end)

    page = conn |> init_test_session(%{}) |> sign_in_named_human() |> get("/factory")

    token =
      page
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("meta[name='csrf-token']")
      |> LazyHTML.attribute("content")
      |> hd()

    %{page: page, token: token}
  end

  test "all ten explicit routes start only an authorized bounded private snapshot", context do
    for {surface, route} <- @routes do
      response = request(context) |> post("/ui/streams" <> route, body(surface))
      assert response.status == 200, "surface #{surface} returned #{response.status}"
      assert get_resp_header(response, "content-type") == ["text/event-stream; charset=utf-8"]
      assert get_resp_header(response, "cache-control") == ["no-store, private"]
      assert get_resp_header(response, "x-accel-buffering") == ["no"]
      assert byte_size(response.resp_body) <= JidoCodeWeb.StreamDelivery.max_event_bytes()
      assert %{connections: 0} = StreamCoordinator.stats()
      document = response.resp_body |> elements() |> LazyHTML.from_fragment()
      assert length(Enum.to_list(LazyHTML.query(document, "#product-owned-content"))) == 1
      refute Enum.any?(LazyHTML.query(document, "script, #product-shell"))

      if surface not in [:account, :sessions] do
        assert_receive {:read_projection_load,
                        %{page: %{key: ^surface, authorization: authorization}}}

        assert authorization.decision == :allowed
        assert {%{action: :stream}, _, _} = response.private.read_authorization
      end
    end
  end

  test "negotiation, CSRF, origin, metadata and closed correlation fail before SSE", context do
    for {header, value, status} <- [
          {"accept", "text/html", 406},
          {"origin", "https://evil.test", 403},
          {"sec-fetch-site", "same-site", 403},
          {"datastar-request", "false", 403},
          {"content-type", "text/plain", 415}
        ] do
      response =
        request(context)
        |> put_req_header(header, value)
        |> post("/ui/streams/fleet", body(:fleet))

      assert response.status == status
      refute get_resp_header(response, "content-type") == ["text/event-stream; charset=utf-8"]
    end

    assert request(context) |> post("/ui/streams/fleet", "{}") |> response(422)

    assert request(context)
           |> post("/ui/streams/fleet", String.duplicate("x", 2049))
           |> response(413)

    assert request(context) |> post("/ui/streams/fleet?tab=copy", body(:fleet)) |> response(422)
    assert request(context) |> get("/ui/streams/fleet") |> response(405)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      request(context)
      |> put_private(:plug_skip_csrf_protection, false)
      |> delete_req_header("x-csrf-token")
      |> post("/ui/streams/fleet", body(:fleet))
    end

    refute_receive {:read_projection_load, %{page: %{key: :fleet}}}
    assert %{connections: 0} = StreamCoordinator.stats()
  end

  test "absent sessions, unknown resources, cross-scope references and replay are not grants",
       context do
    assert request(context)
           |> init_test_session(%{"jido_code_human_session_ref" => nil})
           |> post("/ui/streams/fleet", body(:fleet))
           |> response(401)

    for {surface, route} <- [
          {:project, "/ui/streams/projects/unknown/overview"},
          {:attempt, "/ui/streams/projects/project_browser_beta/attempts/attempt_browser_alpha"}
        ] do
      assert request(context) |> post(route, body(surface)) |> response(404)
    end

    raw = body(:fleet)
    assert request(context) |> post("/ui/streams/fleet", raw) |> response(200)
    assert request(context) |> post("/ui/streams/fleet", raw) |> response(409)

    assert request(context)
           |> put_req_header("last-event-id", "copied")
           |> post("/ui/streams/fleet", body(:fleet))
           |> response(422)

    assert %{connections: 0} = StreamCoordinator.stats()
  end

  test "revocation during query withholds every byte of the earlier snapshot", context do
    Application.put_env(:jido_code, :read_projection_fixture, fn query ->
      {:ok, sessions} = JidoCode.Identity.Sessions.managed(query.session_ref)
      current = Enum.find(sessions, & &1.current)

      {:ok, :current} =
        JidoCode.Identity.Sessions.revoke_managed(query.session_ref, current.management_ref)

      Fixture.projection(:fleet, %{
        fleet: [Fixture.fleet_row("WITHHELD", "/projects/project_browser_alpha")]
      })
    end)

    response = request(context) |> post("/ui/streams/fleet", body(:fleet))
    assert response.status == 401
    refute response.resp_body =~ "WITHHELD"
    assert %{connections: 0} = StreamCoordinator.stats()
  end

  test "a page grant is not a stream grant and denial precedes query or headers", context do
    store = JidoCode.Identity.Store
    original = :sys.get_state(store).config

    :sys.replace_state(store, fn state ->
      %{
        state
        | config: %{
            state.config
            | authority_adapter: JidoCode.TestSupport.DenyStreamAuthorityAdapter
          }
      }
    end)

    try do
      response = request(context) |> post("/ui/streams/fleet", body(:fleet))
      assert response.status == 403
      refute get_resp_header(response, "content-type") == ["text/event-stream; charset=utf-8"]
      refute_receive {:read_projection_load, %{page: %{key: :fleet}}}
      assert %{connections: 0} = StreamCoordinator.stats()
      assert context.page |> recycle() |> get("/factory/fleet") |> html_response(200)
    after
      :sys.replace_state(store, &%{&1 | config: original})
    end
  end

  defp request(context) do
    context.page
    |> recycle()
    |> put_req_header("accept", "text/event-stream")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("datastar-request", "true")
    |> put_req_header("sec-fetch-site", "same-origin")
    |> with_same_origin()
    |> put_req_header("x-csrf-token", context.token)
  end

  defp body(surface),
    do:
      Jason.encode!(%{"stream" => %{tab: random(), request: random()}, "read_#{surface}" => %{}})

  defp random, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

  defp elements(body),
    do:
      body
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "data: elements "))
      |> Enum.map_join("\n", &String.replace_prefix(&1, "data: elements ", ""))
end

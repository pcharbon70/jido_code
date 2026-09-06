defmodule JidoCodeWeb.ReadControllerTest do
  use JidoCodeWeb.ConnCase, async: false
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture, as: Fixture
  alias JidoCode.Product.ReadRequestLimiter

  @routes [
    {:factory, "/ui/reads/factory", "/factory", "factory-attention-trust"},
    {:fleet, "/ui/reads/fleet", "/factory/fleet", "factory-fleet-trust"},
    {:projects, "/ui/reads/projects", "/projects", "project-catalog-trust"},
    {:project, "/ui/reads/projects/project_browser_alpha/overview",
     "/projects/project_browser_alpha", "project-overview-trust"},
    {:project_attempts, "/ui/reads/projects/project_browser_alpha/attempts",
     "/projects/project_browser_alpha/attempts", "project-attempts-trust"},
    {:project_wiki, "/ui/reads/projects/project_browser_alpha/wiki",
     "/projects/project_browser_alpha/wiki", "project-wiki-trust"},
    {:project_dependencies, "/ui/reads/projects/project_browser_alpha/dependencies",
     "/projects/project_browser_alpha/dependencies", "project-dependencies-trust"},
    {:attempt, "/ui/reads/projects/project_browser_alpha/attempts/attempt_browser_alpha",
     "/projects/project_browser_alpha/attempts/attempt_browser_alpha", "attempt-workspace-trust"},
    {:account, "/ui/reads/account", "/account", "account-summary"},
    {:sessions, "/ui/reads/sessions", "/account/sessions", "session-list"}
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

    on_exit(fn ->
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

  test "all ten fixed routes retain native queries, exact resources and private headers",
       context do
    for {surface, route, native, root} <- @routes do
      response =
        request(context)
        |> post(route, Jason.encode!(%{JidoCodeWeb.ReadSignals.namespace(surface) => %{}}))

      document = response |> html_response(200) |> LazyHTML.from_document()
      assert Enum.any?(LazyHTML.query(document, "##{root}")), "missing #{root} on #{surface}"
      assert get_resp_header(response, "cache-control") == ["no-store, private"]
      assert get_resp_header(response, "referrer-policy") == ["no-referrer"]
      assert response.request_path == native

      if surface not in [:account, :sessions] do
        assert_receive {:read_projection_load, %{page: %{key: ^surface}}}
      end
    end
  end

  test "only normalized intent reaches the existing bounded provider", context do
    response =
      request(context)
      |> post(
        "/ui/reads/fleet",
        ~s({"read_fleet":{"q":"  beta  ","page":2,"state":"blocked","sort":"health","direction":"descending"}})
      )

    assert response.status == 200
    assert_receive {:read_projection_load, %{page: %{key: :fleet, query: query}}}

    assert query == %{
             "q" => "beta",
             "page" => 2,
             "state" => "blocked",
             "sort" => "health",
             "direction" => "descending"
           }
  end

  test "fragments contain one complete escaped projection and clear protected states", context do
    for state <- JidoCode.Product.ReadProjection.canonical_states() do
      projection =
        Fixture.projection(:fleet, %{
          state: state,
          fleet: [
            Fixture.fleet_row("<script>private</script>", "/projects/project_browser_alpha")
          ]
        })

      Application.put_env(:jido_code, :read_projection_fixture, %{fleet: projection})
      response = request(context) |> post("/ui/reads/fleet", ~s({"read_fleet":{}}))
      document = response |> html_response(200) |> LazyHTML.from_fragment()
      assert length(Enum.to_list(LazyHTML.query(document, "#product-owned-content"))) == 1

      assert Enum.any?(
               LazyHTML.query(document, "#factory-fleet-trust[data-projection-state='#{state}']")
             )

      assert Enum.any?(LazyHTML.query(document, "#product-read-errors"))
      refute Enum.any?(LazyHTML.query(document, "script, #product-shell, html, head"))
      assert byte_size(response.resp_body) <= JidoCodeWeb.ReadResponse.max_patch_bytes()

      if JidoCode.Product.ReadProjection.protected_state?(state) or state == :empty do
        refute LazyHTML.text(document) =~ "private"
      else
        assert LazyHTML.text(document) =~ "<script>private</script>"
      end
    end
  end

  test "the final patch limit is a byte bound, independent of provider truncation" do
    limit = JidoCodeWeb.ReadResponse.max_patch_bytes()
    assert JidoCodeWeb.ReadResponse.max_roots() == 1
    assert JidoCodeWeb.ReadResponse.within_limit?(String.duplicate("x", limit))
    refute JidoCodeWeb.ReadResponse.within_limit?(String.duplicate("x", limit + 1))
    refute JidoCodeWeb.ReadResponse.within_limit?(String.duplicate("é", limit))
  end

  test "closed transport rejects hostile bodies and non-read methods without querying", context do
    for {body, status} <- [
          {~s({"read_fleet":{"q":"a","q":"b"}}), 422},
          {~s({"read_fleet":{"grant":"secret"}}), 422},
          {~s({"read_fleet":{"q":{}}}), 422},
          {"{", 422},
          {String.duplicate("x", 2049), 413}
        ] do
      response = request(context) |> post("/ui/reads/fleet", body)
      assert response.status == status
      assert response.resp_body == "Read request was not accepted."
    end

    assert request(context) |> get("/ui/reads/fleet") |> response(405)
    assert request(context) |> post("/ui/reads/fleet?q=secret", "{}") |> response(422)

    assert request(context)
           |> put_req_header("content-type", "text/plain")
           |> post("/ui/reads/fleet", "{}")
           |> response(415)

    refute_receive {:read_projection_load, %{page: %{key: :fleet}}}
  end

  test "Origin, Fetch Metadata, enhancement header and real CSRF are mandatory", context do
    for {header, value} <- [
          {"origin", "https://evil.test"},
          {"sec-fetch-site", "same-site"},
          {"datastar-request", "false"}
        ] do
      assert request(context)
             |> put_req_header(header, value)
             |> post("/ui/reads/fleet", ~s({"read_fleet":{}}))
             |> response(403)
    end

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      request(context)
      |> put_private(:plug_skip_csrf_protection, false)
      |> delete_req_header("x-csrf-token")
      |> post("/ui/reads/fleet", ~s({"read_fleet":{}}))
    end

    assert request(context)
           |> put_private(:plug_skip_csrf_protection, false)
           |> post("/ui/reads/fleet", ~s({"read_fleet":{}}))
           |> response(200)
  end

  test "a revoked session during field shaping cannot release its earlier projection", context do
    Application.put_env(:jido_code, :read_projection_fixture, fn query ->
      {:ok, sessions} = JidoCode.Identity.Sessions.managed(query.session_ref)
      current = Enum.find(sessions, & &1.current)

      {:ok, :current} =
        JidoCode.Identity.Sessions.revoke_managed(query.session_ref, current.management_ref)

      Fixture.projection(:fleet, %{
        fleet: [Fixture.fleet_row("WITHHELD", "/projects/project_browser_alpha")]
      })
    end)

    response = request(context) |> post("/ui/reads/fleet", ~s({"read_fleet":{}}))
    assert response.status == 401
    refute response.resp_body =~ "WITHHELD"
  end

  test "nested scope mismatches and unknown references stay concealed", context do
    for route <- [
          "/ui/reads/projects/unknown/overview",
          "/ui/reads/projects/project_browser_beta/attempts/attempt_browser_alpha"
        ] do
      namespace =
        if String.ends_with?(route, "overview"), do: "read_project", else: "read_attempt"

      response = request(context) |> post(route, Jason.encode!(%{namespace => %{}}))
      assert response.status == 404
    end

    refute_receive {:read_projection_load, %{page: %{key: :attempt}}}
  end

  defp request(%{page: page, token: token}) do
    page
    |> recycle()
    |> with_same_origin()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("datastar-request", "true")
    |> put_req_header("sec-fetch-site", "same-origin")
    |> put_req_header("x-csrf-token", token)
  end
end

defmodule JidoCodeWeb.ReadOnlyShellPrivacyPhaseC5Test do
  use JidoCodeWeb.ConnCase, async: false

  test "authorized and concealed reads retain private headers and safe exterior detail", %{
    conn: conn
  } do
    authorized = conn |> init_test_session(%{}) |> sign_in_named_human() |> get(~p"/factory")
    html = html_response(authorized, 200)

    assert get_resp_header(authorized, "cache-control") == ["no-store, private"]
    assert get_resp_header(authorized, "referrer-policy") == ["origin"]
    assert get_resp_header(authorized, "x-robots-tag") == ["noindex, nofollow"]
    refute html =~ "https://jido.run/"
    refute html =~ "test-named-human-credential"
    refute html =~ "session_ref"
    refute html =~ "graph_scope_iri"

    concealed =
      conn
      |> recycle()
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> get("/projects/project_hidden_phase_c5")

    assert response(concealed, 404) == "Not found."
    assert get_resp_header(concealed, "cache-control") == ["no-store, private"]
    refute response(concealed, 404) =~ "project_hidden_phase_c5"
  end

  test "hostile filters remain bounded text and cannot create executable content", %{conn: conn} do
    response =
      conn
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> get("/factory/fleet?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")

    html = html_response(response, 200)
    document = LazyHTML.from_document(html)

    assert document
           |> LazyHTML.query("#product-filter-search-query")
           |> LazyHTML.attribute("value") == ["<script>alert(1)</script>"]

    refute document |> LazyHTML.query("#product-main script") |> Enum.any?()
    refute html =~ "<script>alert(1)</script>"
  end

  test "production and CI retain local assets, production builds, and proxy qualification" do
    workflow = File.read!(".github/workflows/ci.yml")
    playwright = File.read!("playwright.config.mjs")
    product_request = File.read!("lib/jido_code_web/product_request.ex")
    telemetry = File.read!("lib/jido_code/product/read_projection_telemetry.ex")

    assert workflow =~ "MIX_ENV=test mix assets.build"
    assert workflow =~ "npx playwright test"
    assert playwright =~ "http2_streaming_proxy.mjs"
    assert playwright =~ "https://127.0.0.1"
    assert product_request =~ ~s|put_resp_header("cache-control", "no-store, private")|
    assert product_request =~ ~s|put_resp_header("referrer-policy", "origin")|
    assert telemetry =~ "@measurement_keys"
    assert telemetry =~ "@metadata_keys"
    refute telemetry =~ "principal_iri"
    refute telemetry =~ "graph_scope_iri"
  end
end

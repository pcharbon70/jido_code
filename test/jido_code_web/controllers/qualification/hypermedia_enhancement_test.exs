defmodule JidoCodeWeb.Qualification.HypermediaEnhancementTest do
  use JidoCodeWeb.ConnCase, async: false

  setup do
    prior = Application.get_env(:jido_code, :hypermedia_qualification)

    Application.put_env(:jido_code, :hypermedia_qualification,
      enabled: true,
      allowed_hosts: ["www.example.com"]
    )

    on_exit(fn -> Application.put_env(:jido_code, :hypermedia_qualification, prior) end)
  end

  test "renders static enhancement expressions without putting CSRF in signals or URLs", %{
    conn: conn
  } do
    document = conn |> get(~p"/__qualification/hypermedia") |> document(200)
    filter = LazyHTML.query(document, "#hui-b3-filter-submit")
    note = LazyHTML.query(document, "#hui-b3-note-submit")

    csrf_token =
      document
      |> LazyHTML.query("meta[name='csrf-token']")
      |> LazyHTML.attribute("content")
      |> List.first()

    filter_expression = filter |> LazyHTML.attribute("data-on:click__prevent") |> List.first()
    note_expression = note |> LazyHTML.attribute("data-on:click__prevent") |> List.first()

    assert filter_expression =~ "/fragments/results"
    assert filter_expression =~ "/^(q|state|page)$/"
    assert note_expression =~ "/events/validate-note"
    assert note_expression =~ "x-csrf-token"
    assert note_expression =~ "/^note$/"
    refute note_expression =~ csrf_token
    refute LazyHTML.to_html(document) =~ "data-bind:csrf"
  end

  test "returns a coherent escaped Dstar results fragment for an admitted GET", %{conn: conn} do
    signals = URI.encode_www_form(~s({"q":"hostile","state":"ready","page":1}))

    conn =
      conn
      |> put_req_header("datastar-request", "true")
      |> put_req_header("sec-fetch-site", "same-origin")
      |> get("/__qualification/hypermedia/fragments/results?datastar=#{signals}")

    assert get_resp_header(conn, "content-type") == ["text/event-stream; charset=utf-8"]
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
    assert Dstar.Test.assert_patched_element(conn, "#hui-b3-results-region")
    assert Dstar.Test.patched_signals(conn)["_pending"] == false

    [element | _rest] =
      conn
      |> Dstar.Test.sse_events()
      |> Enum.filter(&(&1.type == "datastar-patch-elements"))

    {_metadata, ["elements " <> first_line | remaining_lines]} =
      Enum.split_while(element.data, &(not String.starts_with?(&1, "elements ")))

    html = Enum.join([first_line | remaining_lines], "\n")

    document = LazyHTML.from_fragment(html)

    assert present?(
             document,
             "#hui-b3-results-region[data-fixture-state='ready'][data-fixture-total='1']"
           )

    assert LazyHTML.text(LazyHTML.query(document, "#fixture-hostile td:first-child")) ==
             "<unsafe>& hostile label"

    refute present?(document, "script")
  end

  test "accepts a same-origin JSON action with header CSRF transport and escapes its patch", %{
    conn: conn
  } do
    page = get(conn, ~p"/__qualification/hypermedia")

    csrf_token =
      page
      |> document(200)
      |> LazyHTML.query("meta[name='csrf-token']")
      |> LazyHTML.attribute("content")
      |> List.first()

    conn =
      page
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("datastar-request", "true")
      |> put_req_header("origin", "http://www.example.com")
      |> put_req_header("sec-fetch-site", "same-origin")
      |> put_req_header("x-csrf-token", csrf_token)
      |> post(
        ~p"/__qualification/hypermedia/events/validate-note",
        Jason.encode!(%{"note" => "<unsafe>& note"})
      )

    assert get_resp_header(conn, "content-type") == ["text/event-stream; charset=utf-8"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    assert Dstar.Test.assert_patched_element(conn, "#hui-b3-enhanced-outcome")

    body = conn.resp_body
    assert body =~ "&lt;unsafe&gt;&amp; note"
    refute body =~ "<unsafe>"
  end

  test "fails closed for cross-site, malformed, duplicate, unknown, and unsupported requests", %{
    conn: conn
  } do
    request = fn conn, query ->
      conn
      |> put_req_header("datastar-request", "true")
      |> put_req_header("sec-fetch-site", "same-origin")
      |> get("/__qualification/hypermedia/fragments/results?#{query}")
    end

    assert request.(conn, "datastar=%7B") |> json_response(422) == %{"error" => "invalid_json"}

    duplicated =
      "datastar=#{URI.encode_www_form(~s({"q":"a"}))}&datastar=#{URI.encode_www_form(~s({"q":"b"}))}"

    assert request.(build_conn(), duplicated) |> json_response(422) ==
             %{"error" => "duplicate_transport"}

    unknown = "datastar=#{URI.encode_www_form(~s({"authority":"admin"}))}"
    assert request.(build_conn(), unknown) |> json_response(422) == %{"error" => "unknown_key"}

    cross_site =
      build_conn()
      |> put_req_header("datastar-request", "true")
      |> put_req_header("sec-fetch-site", "cross-site")
      |> get("/__qualification/hypermedia/fragments/results?datastar=%7B%7D")

    assert json_response(cross_site, 403) == %{"error" => "cross_site_request"}

    unsupported =
      build_conn()
      |> put_req_header("datastar-request", "true")
      |> put_req_header("sec-fetch-site", "same-origin")
      |> post(~p"/__qualification/hypermedia/events/not-registered", %{})

    assert json_response(unsupported, 404) == %{"error" => "unsupported_event"}
  end

  defp document(conn, status), do: conn |> html_response(status) |> LazyHTML.from_document()

  defp present?(document, selector) do
    document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
  end
end

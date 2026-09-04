defmodule JidoCodeWeb.Qualification.HypermediaStreamTest do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCodeWeb.Qualification.HypermediaStreamCoordinator, as: Coordinator

  setup do
    start_supervised!(Coordinator)
    prior = Application.get_env(:jido_code, :hypermedia_qualification)

    Application.put_env(:jido_code, :hypermedia_qualification,
      enabled: true,
      allowed_hosts: ["www.example.com"]
    )

    assert :ok = Coordinator.reset()

    on_exit(fn ->
      Application.put_env(:jido_code, :hypermedia_qualification, prior)
    end)
  end

  test "emits a fixed bounded lifecycle with retry, heartbeat, nudge, and terminal close", %{
    conn: conn
  } do
    conn = stream_request(conn, %{"tabId" => "tab_stream_001", "scenario" => "normal"})

    assert get_resp_header(conn, "content-type") == ["text/event-stream; charset=utf-8"]
    assert conn.resp_body =~ "retry: 1500"
    assert conn.resp_body =~ "event: hui-b3-heartbeat"
    assert conn.resp_body =~ "id: hui-b3-complete"
    assert Dstar.Test.assert_patched_element(conn, "#hui-b3-stream-state")

    signals = Dstar.Test.patched_signals(conn)
    assert signals["_connectionState"] == "closed"
    assert signals["_fixtureFreshness"] == "patched"
    assert signals["_fixtureTruth"] == "fixture-only"
    assert signals["_terminal"] == true
    assert signals["nudges"]["huiB3Results"] == 1

    events = Dstar.Test.sse_events(conn)
    limits = Coordinator.limits()
    assert length(events) <= limits.max_events
    assert Coordinator.snapshot().active == 0
    assert Coordinator.snapshot().counters.released_completed == 1
  end

  test "emits deterministic duplicate, reorder, and dropped fixture hints", %{conn: conn} do
    duplicate = stream_request(conn, %{"tabId" => "tab_duplicate_001", "scenario" => "duplicate"})
    assert occurrences(duplicate.resp_body, "id: hui-b3-hint-3") == 2

    reorder =
      conn
      |> recycle()
      |> stream_request(%{"tabId" => "tab_reorder_001", "scenario" => "reorder"})

    assert index_of(reorder.resp_body, "id: hui-b3-hint-4") <
             index_of(reorder.resp_body, "id: hui-b3-hint-3")

    dropped =
      reorder
      |> recycle()
      |> stream_request(%{"tabId" => "tab_dropped_001", "scenario" => "drop"})

    assert dropped.resp_body =~ "dropped-3-through-4"
    assert dropped.resp_body =~ "\"_sequence\":5"
  end

  test "fails fast at the connection ceiling and leaves native reload available", %{conn: conn} do
    tokens =
      for index <- 1..Coordinator.limits().max_connections do
        assert {:ok, token, :present} = Coordinator.acquire("tab_occupied_#{index}")
        token
      end

    response = stream_request(conn, %{"tabId" => "tab_overflow_001", "scenario" => "normal"})
    assert json_response(response, 429) == %{"error" => "connection_ceiling"}

    Enum.each(tokens, &Coordinator.release(&1, :cancelled))

    document = conn |> recycle() |> get(~p"/__qualification/hypermedia") |> document(200)
    assert present?(document, "#hui-b3-stream-reload[href='/__qualification/hypermedia']")
    assert present?(document, "#hui-b3-stream-state[data-connection-state='idle']")
    assert present?(document, "#hui-b3-stream-state[data-fixture-freshness='native']")
  end

  test "accepts a missing correlation hint but rejects invalid values and scenarios", %{
    conn: conn
  } do
    missing = stream_request(conn, %{"scenario" => "terminal"})
    assert Dstar.Test.patched_signals(missing)["_tabCorrelation"] == "missing"

    invalid_tab =
      missing
      |> recycle()
      |> stream_request(%{"tabId" => "<invalid>", "scenario" => "normal"})

    assert json_response(invalid_tab, 422) == %{"error" => "invalid_value"}

    invalid_scenario =
      invalid_tab
      |> recycle()
      |> stream_request(%{"tabId" => "tab_invalid_001", "scenario" => "unbounded"})

    assert json_response(invalid_scenario, 422) == %{"error" => "invalid_value"}
  end

  defp stream_request(conn, signals) do
    page = get(conn, ~p"/__qualification/hypermedia")

    csrf_token =
      page
      |> document(200)
      |> LazyHTML.query("meta[name='csrf-token']")
      |> LazyHTML.attribute("content")
      |> List.first()

    page
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("datastar-request", "true")
    |> put_req_header("origin", "http://www.example.com")
    |> put_req_header("sec-fetch-site", "same-origin")
    |> put_req_header("x-csrf-token", csrf_token)
    |> post(~p"/__qualification/hypermedia/stream", Jason.encode!(signals))
  end

  defp occurrences(body, pattern), do: length(String.split(body, pattern)) - 1

  defp index_of(body, pattern) do
    {index, _length} = :binary.match(body, pattern)
    index
  end

  defp document(conn, status), do: conn |> html_response(status) |> LazyHTML.from_document()

  defp present?(document, selector) do
    document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
  end
end

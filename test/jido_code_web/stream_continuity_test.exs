defmodule JidoCodeWeb.StreamContinuityTest do
  use JidoCodeWeb.ConnCase, async: false
  alias JidoCode.Product.{ReadRequestLimiter, StreamCoordinator}
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture, as: Fixture

  test "a verified reconnect floor rejects older query truth before SSE starts", %{conn: conn} do
    keys = [:product_read_projection_provider, :read_projection_fixture]
    old = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    original_limits = :sys.get_state(StreamCoordinator).limits

    :sys.replace_state(
      StreamCoordinator,
      &%{&1 | windows: %{}, nonces: %{}, limits: %{original_limits | idle_ms: 500}}
    )

    :sys.replace_state(ReadRequestLimiter, fn _ -> %{windows: %{}, leases: %{}} end)

    on_exit(fn ->
      :sys.replace_state(StreamCoordinator, &%{&1 | limits: original_limits})

      Enum.each(old, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:jido_code, key),
          else: Application.put_env(:jido_code, key, value)
      end)
    end)

    fixture(9)
    page = conn |> init_test_session(%{}) |> sign_in_named_human() |> get("/factory/fleet")

    token =
      page
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("meta[name='csrf-token']")
      |> LazyHTML.attribute("content")
      |> hd()

    tab = random()
    first = request(page, token) |> post("/ui/streams/fleet", payload(tab, nil))
    assert first.status == 200
    [_, cursor] = Regex.run(~r/^id: (.+)$/m, first.resp_body)
    fixture(8)

    behind =
      request(page, token)
      |> put_req_header("last-event-id", cursor)
      |> post("/ui/streams/fleet", payload(tab, cursor))

    assert behind.status == 503
    refute get_resp_header(behind, "content-type") == ["text/event-stream; charset=utf-8"]
    fixture(10)

    fresh =
      request(page, token)
      |> put_req_header("last-event-id", cursor)
      |> post("/ui/streams/fleet", payload(tab, cursor))

    assert fresh.status == 200
    [_, current] = Regex.run(~r/^id: (.+)$/m, fresh.resp_body)

    assert {:ok, 10} =
             JidoCodeWeb.StreamContext.cursor_revision(fresh.private.stream_context, current)

    assert StreamCoordinator.stats().connections == 0
  end

  defp fixture(revision),
    do:
      Application.put_env(:jido_code, :read_projection_fixture, fn context ->
        Fixture.projection(context.page.key, %{dataset_revision: revision})
      end)

  defp payload(tab, cursor) do
    correlation = %{tab: tab, request: random()}
    correlation = if cursor, do: Map.put(correlation, :cursor, cursor), else: correlation
    Jason.encode!(%{"stream" => correlation, "read_fleet" => %{}})
  end

  defp request(page, token),
    do:
      page
      |> recycle()
      |> put_req_header("accept", "text/event-stream")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("datastar-request", "true")
      |> put_req_header("sec-fetch-site", "same-origin")
      |> with_same_origin()
      |> put_req_header("x-csrf-token", token)

  defp random, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
end

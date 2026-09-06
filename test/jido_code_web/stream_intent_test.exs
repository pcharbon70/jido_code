defmodule JidoCodeWeb.StreamIntentTest do
  use ExUnit.Case, async: true
  alias JidoCodeWeb.{StreamContext, StreamIntent}
  @tab "AAAAAAAAAAAAAAAAAAAAAA"
  @request "BBBBBBBBBBBBBBBBBBBBBA"

  test "two closed namespaces normalize only existing page intent" do
    for surface <- JidoCodeWeb.ReadSignals.surfaces() do
      raw =
        Jason.encode!(%{"stream" => %{tab: @tab, request: @request}, "read_#{surface}" => %{}})

      assert {:ok, %{query: %{}, tab: @tab, request: @request}} =
               StreamIntent.decode(surface, raw)
    end

    assert {:ok, %{query: %{"q" => "beta"}}} = StreamIntent.decode(:fleet, raw(~s("q":" beta ")))
  end

  test "duplicate, unknown, deep, missing, reused keys and oversized inputs fail closed" do
    for input <- [
          "{}",
          raw("\"q\":[]"),
          raw("\"q\":{},\"q\":\"x\""),
          raw("\"grant\":\"admin\""),
          raw("\"q\":\"" <> String.duplicate("x", 2050) <> "\""),
          ~s({"stream":{"tab":"#{@tab}","tab":"#{@tab}","request":"#{@request}"},"read_fleet":{}}),
          ~s({"stream":{"tab":"#{@tab}"},"read_fleet":{}}),
          ~s({"stream":{"tab":"bad","request":"#{@request}"},"read_fleet":{}}),
          ~s({"stream":{"tab":"#{@tab}","request":"#{@request}","cursor":12},"read_fleet":{}}),
          raw("\"q\":\"x\",\"q\":\"y\"")
        ] do
      assert {:error, :invalid_stream_intent} = StreamIntent.decode(:fleet, input)
    end
  end

  test "cursor is bounded, signed, scoped and only transport correlation" do
    context = %{
      subject: "human",
      session: "session",
      session_generation: 1,
      account_generation: 1,
      tenant: "tenant",
      project: "project",
      resource: "attempt",
      route: "/projects/project/attempts/attempt",
      projection: :attempt,
      query: %{},
      fingerprint: %{policy_revision: "policy-1"},
      tab: @tab
    }

    cursor = StreamContext.cursor(context)
    assert byte_size(cursor) <= 256
    assert :ok = StreamContext.validate_cursor(context, cursor, [cursor])
    assert :ok = StreamContext.validate_cursor(context, nil, [])

    for field <- [
          :subject,
          :session,
          :session_generation,
          :account_generation,
          :tenant,
          :project,
          :resource,
          :route,
          :projection,
          :query,
          :fingerprint,
          :tab
        ] do
      assert {:error, :invalid_cursor} =
               StreamContext.validate_cursor(Map.put(context, field, "other"), cursor, [])
    end

    assert {:error, :invalid_cursor} = StreamContext.validate_cursor(context, nil, [cursor])

    assert {:error, :invalid_cursor} =
             StreamContext.validate_cursor(context, cursor, [cursor, cursor])

    assert {:error, :invalid_cursor} = StreamContext.validate_cursor(context, cursor <> "bad", [])
  end

  defp raw(query),
    do: ~s({"stream":{"tab":"#{@tab}","request":"#{@request}"},"read_fleet":{#{query}}})
end

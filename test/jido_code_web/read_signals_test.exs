defmodule JidoCodeWeb.ReadSignalsTest do
  use ExUnit.Case, async: true
  alias JidoCodeWeb.ReadSignals

  test "every page has an isolated closed namespace and reset contract" do
    for surface <- ReadSignals.surfaces() do
      schema = ReadSignals.schema(surface)
      assert schema.scope_reset == :discard_all
      assert schema.max_depth == 2
      assert schema.max_list_length == 0
      assert ReadSignals.decode(surface, Jason.encode!(%{schema.namespace => %{}})) == {:ok, %{}}
      assert {:error, :invalid_shape} = ReadSignals.decode(surface, ~s({"wrong":{}}))
    end
  end

  test "normalizes harmless intent with native defaults and bounded pagination" do
    assert {:ok, %{"q" => "é", "page" => 2, "state" => "blocked"}} =
             ReadSignals.decode(
               :fleet,
               Jason.encode!(%{
                 "read_fleet" => %{
                   "q" => " e\u0301 ",
                   "page" => "2",
                   "state" => "blocked",
                   "sort" => "project",
                   "direction" => "ascending"
                 }
               })
             )

    assert {:ok, %{}} =
             ReadSignals.decode(:factory, ~s({"read_factory":{"q":" ","state":"all","page":1}}))

    assert {:error, :unknown_key} =
             ReadSignals.decode(:attempt, ~s({"read_attempt":{"sort":"health"}}))
  end

  test "rejects duplicate keys before lossy map conversion including escaped keys" do
    for raw <- [
          ~s({"read_fleet":{},"read_fleet":{}}),
          ~s({"read_fleet":{"q":"a","q":"b"}}),
          ~S({"read_fleet":{"q":"a","\u0071":"b"}})
        ] do
      assert {:error, :duplicate_key} = ReadSignals.decode(:fleet, raw)
    end
  end

  test "never admits authority or local-only keys in any page namespace" do
    forbidden =
      ~w(principal session tenant project resource graph grant delegation assurance revision fence profile idempotency command csrf _csrf_token _overlay _pending _pauseVisualUpdates cursor view)

    for surface <- ReadSignals.surfaces(), key <- forbidden do
      assert {:error, :unknown_key} =
               ReadSignals.decode(
                 surface,
                 Jason.encode!(%{ReadSignals.namespace(surface) => %{key => "private-value"}})
               )
    end
  end

  test "rejects bytes, depth, collections, scalars, malformed Unicode and shape" do
    for value <- [nil, true, [], %{}, String.duplicate("a", 129), "a\nsecret"] do
      assert {:error, _} =
               ReadSignals.decode(:fleet, Jason.encode!(%{"read_fleet" => %{"q" => value}}))
    end

    for value <- [0, 101, -1, 1.0, "1x", "1000", [], %{}] do
      assert {:error, _} =
               ReadSignals.decode(:fleet, Jason.encode!(%{"read_fleet" => %{"page" => value}}))
    end

    for raw <- [
          "",
          "[",
          "null",
          "[]",
          ~s({"read_fleet":[]}),
          ~s({"read_fleet":{"q":{"x":1}}}),
          <<255>>,
          String.duplicate(" ", 2049)
        ] do
      assert {:error, _} = ReadSignals.decode(:fleet, raw)
    end

    assert {:ok, %{"q" => "{[escaped]}"}} =
             ReadSignals.decode(:fleet, ~s({"read_fleet":{"q":"{[escaped]}"}}))
  end

  test "bounded fuzz corpus always returns closed diagnostics without reflecting input" do
    :rand.seed(:exsss, {14, 22, 61})

    for _ <- 1..1000 do
      raw = for _ <- 1..:rand.uniform(256), into: <<>>, do: <<:rand.uniform(256) - 1>>
      assert {:error, reason} = ReadSignals.decode(:fleet, raw)
      assert reason in [:invalid_json, :invalid_shape, :invalid_utf8, :too_deep]
    end
  end
end

defmodule JidoCodeWeb.Qualification.HypermediaSignalsTest do
  use ExUnit.Case, async: true

  alias JidoCodeWeb.Qualification.HypermediaSignals

  test "accepts and normalizes the exact harmless schema" do
    assert HypermediaSignals.decode(~s({"q":"alpha","state":"ready","page":2}), ~w(q state page)) ==
             {:ok, %{"q" => "alpha", "state" => "ready", "page" => "2"}}

    assert HypermediaSignals.decode(
             ~s({"tabId":"tab_signal_001","scenario":"restart"}),
             ~w(tabId scenario)
           ) == {:ok, %{"tabId" => "tab_signal_001", "scenario" => "restart"}}
  end

  test "rejects unknown, duplicate, nested, malformed, and oversized input" do
    assert {:error, :unknown_key} =
             HypermediaSignals.decode(~s({"actor":"admin"}), ~w(q state page))

    assert {:error, :duplicate_key} =
             HypermediaSignals.decode(~s({"q":"a","q":"b"}), ~w(q state page))

    assert {:error, :invalid_value} =
             HypermediaSignals.decode(~s({"q":{"nested":"value"}}), ~w(q state page))

    assert {:error, :invalid_json} = HypermediaSignals.decode("{", ~w(q state page))

    assert {:error, :oversized} =
             HypermediaSignals.decode(~s({"q":"#{String.duplicate("a", 600)}"}), ~w(q state page))
  end
end

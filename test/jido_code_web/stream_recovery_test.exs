defmodule JidoCodeWeb.StreamRecoveryTest do
  use ExUnit.Case, async: true
  alias JidoCodeWeb.StreamContext
  alias JidoCode.Product.StreamConvergence

  test "revision continuity comes only from a verified scoped cursor" do
    context = %{
      subject: "human",
      session: "session",
      session_generation: 1,
      account_generation: 1,
      tenant: "tenant",
      project: "repository",
      resource: "attempt",
      route: "/projects/repository/attempts/attempt",
      projection: :attempt,
      query: %{"state" => "active"},
      fingerprint: %{policy_revision: "policy-1"},
      tab: "AAAAAAAAAAAAAAAAAAAAAA"
    }

    cursor = StreamContext.cursor(context, 123)
    assert byte_size(cursor) <= 256
    assert {:ok, 123} = StreamContext.cursor_revision(context, cursor)
    assert {:ok, 0} = StreamContext.cursor_revision(context, nil)

    for field <- Map.keys(context) do
      assert {:error, :invalid_cursor} =
               StreamContext.cursor_revision(Map.put(context, field, "other"), cursor)
    end

    assert {:error, :invalid_cursor} = StreamContext.cursor_revision(context, cursor <> "corrupt")

    unknown =
      Phoenix.Token.sign(JidoCodeWeb.Endpoint, "product-stream-cursor-v1", %{revision: 123})

    assert {:error, :invalid_cursor} = StreamContext.cursor_revision(context, unknown)
  end

  test "convergence telemetry has fixed outcomes and contains no scope or query data" do
    id = "d3-telemetry-#{inspect(self())}"
    parent = self()

    :telemetry.attach(
      id,
      [:jido_code, :product_stream, :convergence],
      fn event, measurements, metadata, _ ->
        send(parent, {:metric, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)
    StreamConvergence.emit(:graph_lag, :fleet, 100)

    assert_receive {:metric, [:jido_code, :product_stream, :convergence],
                    %{count: 1, duration_ms: 100}, %{outcome: :graph_lag, projection: :fleet}}

    StreamConvergence.emit("secret", :fleet)
    StreamConvergence.emit(:refreshed, "secret")
    refute_receive {:metric, _, _, _}
  end
end

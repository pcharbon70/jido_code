defmodule JidoCode.Product.StreamRevocationTest do
  use ExUnit.Case, async: false
  alias JidoCode.Identity.{RevocationEvent, Revocations}
  alias JidoCode.Product.StreamCoordinator, as: Coordinator
  alias JidoCodeWeb.StreamDelivery

  test "each of the eight generation topics triggers a fresh control check before the periodic interval" do
    for dimension <- Revocations.dimensions() do
      name = Module.concat(__MODULE__, Atom.to_string(dimension))
      start_supervised!({Coordinator, name: name}, id: dimension)
      assert {:ok, lease} = Coordinator.admit(context(), name)
      assert {:ok, _} = Coordinator.connect(lease, name)
      assert :ok = Coordinator.reserve(lease, 1, name)
      assert :ok = Coordinator.sent(lease, name)
      Revocations.publish(event(dimension))
      assert_receive {:product_stream, ^lease, {:check, _}}, 1_000
      assert %{pending_hints: 1, queued_payload_bytes: 0} = Coordinator.stats(name)
      Coordinator.release(lease, name)
    end
  end

  test "burst, duplicate and reordered generation hints have only one outstanding credit" do
    name = Module.concat(__MODULE__, "Burst")
    start_supervised!({Coordinator, name: name})
    assert {:ok, lease} = Coordinator.admit(context(), name)
    assert {:ok, _} = Coordinator.connect(lease, name)
    assert :ok = Coordinator.reserve(lease, 1, name)
    assert :ok = Coordinator.sent(lease, name)

    for index <- 1..100,
        do: Revocations.publish(%{event(:graph) | next_generation: rem(index, 3) + 1})

    assert_receive {:product_stream, ^lease, {:check, _}}, 1_000
    refute_receive {:product_stream, ^lease, {:check, _}}, 50
    assert %{pending_hints: 1, queued_payload_bytes: 0} = Coordinator.stats(name)
    assert :ok = Coordinator.checked(lease, name)
    assert_receive {:product_stream, ^lease, {:check, _}}, 1_000
    Coordinator.release(lease, name)
  end

  test "terminal patches have one fixed concealed shell root within the reserved wire allowance" do
    for reason <- [:revoked, :expired, :takeover, :idle_timeout, :deploy_drain, :slow_owner] do
      frame = StreamDelivery.terminal_frame(reason)
      assert byte_size(frame) <= Coordinator.limits().terminal_bytes

      html =
        frame
        |> String.split("\n")
        |> Enum.filter(&String.starts_with?(&1, "data: elements "))
        |> Enum.map_join("\n", &String.replace_prefix(&1, "data: elements ", ""))

      doc = LazyHTML.from_fragment(html)

      assert length(Enum.to_list(LazyHTML.query(doc, "#product-shell[data-stream-terminal]"))) ==
               1

      assert Enum.any?(LazyHTML.query(doc, "#product-stream-status[role='alert']"))
      assert LazyHTML.attribute(LazyHTML.query(doc, "#product-stream-reload"), "href") == [""]

      refute Enum.any?(
               LazyHTML.query(
                 doc,
                 "#product-owned-content, #product-context, #product-account-menu, script, form"
               )
             )
    end
  end

  defp context do
    %{
      subject: "human",
      session: "session",
      tenant: "tenant",
      tab: "tab",
      request: "request",
      route: "/factory",
      projection: :factory,
      hard_expires_at: System.system_time(:millisecond) + 60_000,
      idle_expires_at: System.system_time(:millisecond) + 60_000
    }
  end

  defp event(dimension) do
    %RevocationEvent{
      event_ref: "revocation",
      dimension: dimension,
      subject_ref: "human",
      resource_ref: "scope",
      prior_generation: 1,
      next_generation: 2,
      policy_revision: "policy",
      occurred_at: DateTime.utc_now()
    }
  end
end

defmodule JidoCode.Product.StreamSubscriptionTest do
  use ExUnit.Case, async: true
  alias JidoCode.Knowledge.{ProjectionSubscription, ChangeEvent}

  @scope "https://jido.run/id/scope/factory/subscription-test"

  setup do
    {:ok, pid} =
      ProjectionSubscription.start_page_stream(
        owner: self(),
        scopes: [@scope],
        families: [:factory_catalog],
        last_revision: 4
      )

    on_exit(fn -> JidoCode.Product.StreamSubscription.close(pid) end)
    %{pid: pid}
  end

  test "one pull credit coalesces hints without advancing evaluated truth", %{pid: pid} do
    for revision <- [8, 7, 8, 6], do: send(pid, {:jido_code_change, event(revision)})
    assert {:refresh, :hint} = ProjectionSubscription.poll(pid)
    assert :idle = ProjectionSubscription.poll(pid)
    state = :sys.get_state(pid)
    assert state.last_revision == 4
    assert state.hinted_revision == 8
    refute Map.has_key?(state, :event)
    assert :ok = ProjectionSubscription.evaluated(pid, 9)
    assert :idle = ProjectionSubscription.poll(pid)
    assert :sys.get_state(pid).last_revision == 9
  end

  test "wrong scopes and families do not schedule work; caller revisions are not accepted", %{
    pid: pid
  } do
    send(pid, {:jido_code_change, %{event(8) | scope_iri: @scope <> "-other"}})

    send(
      pid,
      {:jido_code_change, %{event(8) | affected_graphs: [%{family: :unknown, revision: 8}]}}
    )

    assert :idle = ProjectionSubscription.poll(pid)
    assert {:error, :invalid_subscription_request} = ProjectionSubscription.evaluated(pid, 8)

    assert {:error, :invalid_subscription_request} =
             Task.async(fn -> ProjectionSubscription.poll(pid) end) |> Task.await()
  end

  test "periodic reconciliation covers complete hint loss and rejects backward query results", %{
    pid: pid
  } do
    :sys.replace_state(pid, &%{&1 | next_refresh: System.monotonic_time(:millisecond) - 1})
    assert {:refresh, :reconcile} = ProjectionSubscription.poll(pid)
    assert {:error, :stale_revision} = ProjectionSubscription.evaluated(pid, 3)
    assert :sys.get_state(pid).last_revision == 4
  end

  test "normal owner exit cleans the subscription without requiring a linked crash" do
    parent = self()

    owner =
      spawn(fn ->
        {:ok, subscription} =
          ProjectionSubscription.start_page_stream(
            owner: self(),
            scopes: [@scope],
            families: [:factory_catalog],
            last_revision: 0
          )

        send(parent, {:subscription, subscription})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:subscription, subscription}
    monitor = Process.monitor(subscription)
    send(owner, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^subscription, :normal}
  end

  defp event(revision),
    do: %ChangeEvent{
      scope_iri: @scope,
      dataset_revision: revision,
      affected_graphs: [%{family: :factory_catalog, revision: revision}],
      command_class: "test",
      receipt_iri: "https://jido.run/id/receipt/never-render-this"
    }
end

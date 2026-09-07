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
    assert {:refresh, :gap} = ProjectionSubscription.poll(pid)
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
    assert {:retry, :stale_revision} = ProjectionSubscription.evaluated(pid, 3)
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

  test "graph lag backs off without accepting hint truth and resets after convergence", %{
    pid: pid
  } do
    send(pid, {:jido_code_change, event(8)})
    assert {:refresh, :gap} = ProjectionSubscription.poll(pid)
    assert {:retry, :graph_lag} = ProjectionSubscription.evaluated(pid, 6)
    assert :sys.get_state(pid).last_revision == 4
    assert :idle = ProjectionSubscription.poll(pid)
    advance_retry(pid)
    assert {:refresh, :gap} = ProjectionSubscription.poll(pid)
    assert :ok = ProjectionSubscription.evaluated(pid, 8)
    assert %{last_revision: 8, failures: 0, retry_at: nil} = :sys.get_state(pid)
  end

  test "query failure retries are finite even when newer hints keep arriving", %{pid: pid} do
    for attempt <- 1..3 do
      send(pid, {:jido_code_change, event(10 + attempt)})
      advance_retry(pid)
      assert {:refresh, :gap} = ProjectionSubscription.poll(pid)
      result = ProjectionSubscription.evaluated(pid, nil)

      if attempt < 3,
        do: assert(result == {:retry, :query_unavailable}),
        else: assert(result == {:error, :recovery_exhausted})
    end

    assert :sys.get_state(pid).last_revision == 4
    advance_retry(pid)
    assert {:error, :recovery_exhausted} = ProjectionSubscription.poll(pid)
  end

  test "hints arriving during a query cannot be acknowledged by an older result", %{pid: pid} do
    send(pid, {:jido_code_change, event(5)})
    assert {:refresh, :hint} = ProjectionSubscription.poll(pid)
    for revision <- [8, 7, 8], do: send(pid, {:jido_code_change, event(revision)})
    assert {:retry, :graph_lag} = ProjectionSubscription.evaluated(pid, 5)
    assert %{last_revision: 4, hinted_revision: 8} = :sys.get_state(pid)
  end

  test "overflow terminates the disposable subscription and is reported as loss", %{pid: pid} do
    monitor = Process.monitor(pid)
    :sys.suspend(pid)
    for _ <- 1..70, do: send(pid, {:jido_code_change, event(9)})
    :sys.resume(pid)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}
    assert {:error, :subscription_lost} = JidoCode.Product.StreamSubscription.poll(pid)
  end

  test "unregistered families and unbounded scopes cannot open a subscription" do
    for options <- [
          [scopes: [@scope], families: [:unknown]],
          [scopes: [@scope, @scope, @scope], families: [:factory_catalog]],
          [scopes: ["https://other.test/scope/factory/x"], families: [:factory_catalog]]
        ] do
      assert {:error, :invalid_page_subscription} =
               ProjectionSubscription.start_page_stream(
                 options ++ [owner: self(), last_revision: 0]
               )
    end
  end

  defp advance_retry(pid),
    do:
      :sys.replace_state(
        pid,
        &%{
          &1
          | retry_at: System.monotonic_time(:millisecond) - 1,
            next_refresh: System.monotonic_time(:millisecond) - 1
        }
      )

  defp event(revision),
    do: %ChangeEvent{
      scope_iri: @scope,
      dataset_revision: revision,
      affected_graphs: [%{family: :factory_catalog, revision: revision}],
      command_class: "test",
      receipt_iri: "https://jido.run/id/receipt/never-render-this"
    }
end

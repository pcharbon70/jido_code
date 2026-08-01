defmodule JidoCode.Knowledge.Phase05ProjectionDeliveryIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.Projection
  alias JidoCode.Knowledge.ProjectionCache
  alias JidoCode.Knowledge.ProjectionSubscription
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ReadDiagnostics
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Telemetry
  alias JidoCode.TestSupport.Phase05Fixture

  setup context do
    {:ok, fixture: Phase05Fixture.complete!(context)}
  end

  test "cache invalidation re-queries the graph and exposes derived staleness", %{
    fixture: fixture
  } do
    assert {:ok, result} = query_evidence(fixture, fixture.authority)
    assert {:ok, projection} = project_evidence(fixture, result, fixture.authority)

    cache = start_supervised!({ProjectionCache, name: nil})
    assert {:ok, key} = ProjectionCache.put(cache, projection)
    context = ProjectionCache.context(projection)
    assert {:ok, ^projection, :hit} = ProjectionCache.fetch(cache, key, context)

    for index <- 1..1_000 do
      parameters_digest =
        :crypto.hash(:sha256, Integer.to_string(index))
        |> Base.encode16(case: :lower)

      assert {:ok, _key} =
               ProjectionCache.put(cache, %{projection | parameters_digest: parameters_digest})
    end

    assert :miss = ProjectionCache.fetch(cache, key, context)
    assert {:ok, ^key} = ProjectionCache.put(cache, projection)

    assert :ok = ChangeFeed.subscribe(fixture.repository_scope)
    updated = Phase05Fixture.append_evidence!(fixture, 630)

    assert_receive {:jido_code_change, %ChangeEvent{} = event}, 1_000
    assert event.dataset_revision == updated.append_receipt.dataset_revision
    assert :ok = ProjectionCache.invalidate_change(cache, event)
    assert :miss = ProjectionCache.fetch(cache, key, context)

    assert {:ok, current} = query_evidence(fixture, fixture.authority)
    assert current.dataset_revision == updated.append_receipt.dataset_revision
    assert current.graph_revisions[fixture.evidence_graph] == 2
    assert {:ok, refreshed} = project_evidence(fixture, current, fixture.authority)
    refute ProjectionCache.key(refreshed) == key

    assert {:ok, refreshed_key} = ProjectionCache.put(cache, refreshed)
    assert :ok = ProjectionCache.reset(cache)

    assert :miss =
             ProjectionCache.fetch(cache, refreshed_key, ProjectionCache.context(refreshed))

    assert {:error, %{kind: :stale_precondition}, consistency} =
             query_derived(fixture, :strict)

    assert :derived_graph_stale in consistency.gaps

    assert {:ok, warned} = query_derived(fixture, :warn)
    assert warned.freshness == :stale
    assert ReadDiagnostics.from_query(warned).action == :rebuild_derived_graph

    restarted =
      start_supervised!(
        Supervisor.child_spec({ProjectionCache, name: nil},
          id: :phase_05_restarted_projection_cache
        )
      )

    assert :miss = ProjectionCache.fetch(restarted, key, context)
    assert {:ok, canonical_again} = query_evidence(fixture, fixture.authority)
    assert canonical_again.data == current.data
  end

  test "delivery converges across duplicate hints, process restart, and reconnect", %{
    fixture: fixture
  } do
    initial_revision = StoreServer.summary(fixture.store_server).dataset_revision
    refresh = refresh_callback(fixture)

    subscription =
      start_subscription(
        :phase_05_projection_subscription_first,
        fixture,
        refresh,
        initial_revision
      )

    first_update = Phase05Fixture.append_evidence!(fixture, 631)
    first_revision = first_update.append_receipt.dataset_revision

    assert_receive {:projection_refreshed, first_projection}, 1_000
    assert first_projection.dataset_revision == first_revision
    assert first_projection.source_graph_revisions[fixture.evidence_graph] == 2
    assert ProjectionSubscription.last_revision(subscription) == first_revision

    send(subscription, {:jido_code_change, event(fixture, first_revision)})
    send(subscription, {:jido_code_change, event(fixture, first_revision - 1)})
    send(subscription, {:jido_code_change, event(fixture, first_revision)})
    refute_receive {:projection_refreshed, _projection}, 75

    :ok = GenServer.stop(subscription)
    second_update = Phase05Fixture.append_evidence!(fixture, 632)
    second_revision = second_update.append_receipt.dataset_revision

    reconnected =
      start_subscription(
        :phase_05_projection_subscription_reconnected,
        fixture,
        refresh,
        first_revision
      )

    assert :ok = ProjectionSubscription.reconnect(reconnected, second_revision)
    assert_receive {:projection_refreshed, second_projection}, 1_000
    assert second_projection.dataset_revision == second_revision
    assert second_projection.source_graph_revisions[fixture.evidence_graph] == 3
    assert ProjectionSubscription.last_revision(reconnected) == second_revision
  end

  test "an active subscription fails closed after its persisted grant is revoked", %{
    fixture: fixture
  } do
    initial_revision = StoreServer.summary(fixture.store_server).dataset_revision

    subscription =
      start_subscription(
        :phase_05_projection_subscription_revoked,
        fixture,
        refresh_callback(fixture),
        initial_revision
      )

    revoked = Phase05Fixture.revoke_observation!(fixture, 633)
    assert revoked.revocation_receipt.dataset_revision > initial_revision
    assert_receive {:projection_inaccessible, %{kind: :unauthorized}}, 1_000
    assert ProjectionSubscription.last_revision(subscription) == initial_revision

    assert {:error, %{kind: :unauthorized}} = query_evidence(fixture, fixture.authority)
  end

  test "catalog reads stay within the integration baseline and emit bounded telemetry", %{
    fixture: fixture
  } do
    handler = "phase-05-query-telemetry-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach(
        handler,
        [:jido_code, :knowledge, :operation, :stop],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:phase_05_telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    {elapsed_microseconds, results} =
      :timer.tc(fn ->
        for _iteration <- 1..25 do
          QueryRunner.execute(
            :graph_metadata,
            QueryCatalog.version(),
            %{graph: fixture.evidence_graph},
            fixture.authority,
            fixture.repository_scope,
            server: fixture.query_runner,
            evaluated_at: fixture.issued_at
          )
        end
      end)

    assert Enum.all?(results, &match?({:ok, _result}, &1))
    assert elapsed_microseconds < 10_000_000

    assert_receive {:phase_05_telemetry, [:jido_code, :knowledge, :operation, :stop],
                    measurements, metadata},
                   1_000

    assert Map.keys(metadata) -- Telemetry.allowed_keys() == []
    assert Map.keys(measurements) -- Telemetry.allowed_measurements() == []
    assert metadata.operation == :read
    assert metadata.outcome == :ok
    refute inspect(metadata) =~ fixture.evidence_graph
    refute inspect(metadata) =~ "SELECT"
  end

  defp query_evidence(fixture, authority) do
    QueryRunner.execute(
      :resource_description,
      QueryCatalog.version(),
      %{graph: fixture.evidence_graph, resource: fixture.evidence_resource},
      authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp project_evidence(fixture, result, authority) do
    Projection.build(result, authority, fixture.repository_scope,
      generated_at: fixture.issued_at,
      parameters: %{graph: fixture.evidence_graph, resource: fixture.evidence_resource}
    )
  end

  defp query_derived(fixture, mode) do
    QueryRunner.execute(
      :derived_graph_freshness,
      QueryCatalog.version(),
      %{graph: fixture.derived_graph},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at,
      consistency: %{mode: mode, derived_rule_set_revision: 0}
    )
  end

  defp refresh_callback(fixture) do
    fn authority, _hinted_revision ->
      with {:ok, result} <- query_evidence(fixture, authority) do
        project_evidence(fixture, result, authority)
      end
    end
  end

  defp start_subscription(id, fixture, refresh, last_revision) do
    start_supervised!(
      Supervisor.child_spec(
        {ProjectionSubscription,
         scope_iri: fixture.repository_scope,
         authority: fixture.authority,
         refresh: refresh,
         owner: self(),
         last_revision: last_revision,
         debounce_ms: 10},
        id: id,
        restart: :temporary
      )
    )
  end

  defp event(fixture, revision) do
    %ChangeEvent{
      dataset_revision: revision,
      affected_graphs: [%{family: :evidence, revision: 2}],
      scope_iri: fixture.repository_scope,
      command_class: "RecordVerificationEvidence",
      receipt_iri: fixture.evidence_receipt.receipt_iri
    }
  end
end

defmodule JidoCode.Knowledge.ProjectionDeliveryTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Projection
  alias JidoCode.Knowledge.ProjectionCache
  alias JidoCode.Knowledge.ProjectionCatalog
  alias JidoCode.Knowledge.ProjectionSubscription
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    {:ok, fixture: fixture, authority: authority}
  end

  test "builds attributable JSON-safe scalar, table, and subgraph envelopes", %{
    fixture: fixture,
    authority: authority
  } do
    assert ProjectionCatalog.shapes() == [:scalar, :table, :timeline, :tree, :bounded_subgraph]
    assert byte_size(ProjectionCatalog.digest()) == 64

    assert {:ok, query_result} =
             QueryRunner.execute(
               :resource_description,
               "1.0.0",
               %{graph: fixture.graphs.catalog, resource: fixture.factory_iri},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert {:ok, projection} =
             Projection.build(query_result, authority, fixture.factory_scope,
               generated_at: fixture.issued_at,
               parameters: %{
                 graph: fixture.graphs.catalog,
                 resource: fixture.factory_iri
               }
             )

    assert projection.shape == :bounded_subgraph
    assert projection.query_name == :resource_description
    assert projection.source_graph_revisions == %{fixture.graphs.catalog => 1}
    assert projection.consistency.constraint_digest
    assert projection.parameters_digest
    assert projection.data != []

    iri_terms = collect_iri_terms(projection.data)
    assert iri_terms != []
    assert Enum.all?(iri_terms, &is_binary(&1.value))
    assert Enum.all?(iri_terms, &is_binary(&1.display_label))
    refute contains_rdf_struct?(projection.data)

    assert {:ok, scalar_result} =
             QueryRunner.execute(
               :dataset_revision,
               "1.0.0",
               %{},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert {:ok, scalar} =
             Projection.build(scalar_result, authority, fixture.factory_scope,
               generated_at: fixture.issued_at
             )

    assert scalar.shape == :scalar
    assert scalar.data.type == :literal

    tampered = %{query_result | consistency: nil}

    assert {:error, %{kind: :invalid_input}} =
             Projection.build(tampered, authority, fixture.factory_scope)
  end

  test "escapes display labels without changing canonical resource IRIs", %{
    fixture: fixture,
    authority: authority
  } do
    {:ok, base} =
      QueryRunner.execute(
        :graph_health,
        "1.0.0",
        %{graph: fixture.graphs.catalog},
        authority,
        fixture.factory_scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )

    result = %QueryResult{
      base
      | query_name: :graph_metadata,
        data: [%{"resource" => %{type: :iri, value: "https://example.test/id/<unsafe>"}}]
    }

    assert {:ok, projection} =
             Projection.build(result, authority, fixture.factory_scope,
               generated_at: fixture.issued_at
             )

    term = projection.data |> hd() |> Map.fetch!("resource")
    assert term.value == "https://example.test/id/<unsafe>"
    assert term.display_label == "&lt;unsafe&gt;"
  end

  test "cache hits only under an exact current context and survives no deletion or restart", %{
    fixture: fixture,
    authority: authority
  } do
    {:ok, result} =
      QueryRunner.execute(
        :graph_metadata,
        "1.0.0",
        %{graph: fixture.graphs.catalog},
        authority,
        fixture.factory_scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )

    {:ok, projection} =
      Projection.build(result, authority, fixture.factory_scope,
        generated_at: fixture.issued_at,
        parameters: %{graph: fixture.graphs.catalog}
      )

    cache = start_supervised!({ProjectionCache, name: nil})
    assert {:ok, key} = ProjectionCache.put(cache, projection)
    context = ProjectionCache.context(projection)
    assert {:ok, ^projection, :hit} = ProjectionCache.fetch(cache, key, context)
    assert :miss = ProjectionCache.fetch(cache, key, %{context | dataset_revision: 999})

    event = event(fixture.factory_scope, projection.dataset_revision + 1)
    assert :ok = ProjectionCache.invalidate_change(cache, event)
    assert :miss = ProjectionCache.fetch(cache, key, context)

    assert {:ok, ^key} = ProjectionCache.put(cache, projection)
    assert :ok = ProjectionCache.reset(cache)
    assert :miss = ProjectionCache.fetch(cache, key, context)

    restarted =
      start_supervised!(
        Supervisor.child_spec({ProjectionCache, name: nil}, id: :restarted_projection_cache)
      )

    assert :miss = ProjectionCache.fetch(restarted, key, context)

    assert {:ok, canonical_again} =
             QueryRunner.execute(
               :graph_metadata,
               "1.0.0",
               %{graph: fixture.graphs.catalog},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert canonical_again.data == result.data
  end

  test "subscription coalesces duplicate and reordered hints and recovers by re-query", %{
    fixture: fixture,
    authority: authority
  } do
    owner = self()

    refresh = fn _authority, hinted_revision ->
      send(owner, {:refresh_called, hinted_revision})
      {:ok, %{dataset_revision: hinted_revision}}
    end

    subscription =
      start_supervised!(
        {ProjectionSubscription,
         scope_iri: fixture.factory_scope,
         authority: authority,
         refresh: refresh,
         owner: owner,
         last_revision: 4,
         debounce_ms: 20}
      )

    send(subscription, {:jido_code_change, event(fixture.factory_scope, 7)})
    send(subscription, {:jido_code_change, event(fixture.factory_scope, 6)})
    send(subscription, {:jido_code_change, event(fixture.factory_scope, 7)})
    send(subscription, {:jido_code_change, event(fixture.factory_scope, 8)})

    assert_receive {:refresh_called, 8}, 500
    assert_receive {:projection_refreshed, %{dataset_revision: 8}}, 500
    refute_receive {:refresh_called, _revision}, 50
    assert ProjectionSubscription.last_revision(subscription) == 8

    assert :ok = ProjectionSubscription.reconnect(subscription, 10)
    assert_receive {:refresh_called, 10}, 500
    assert_receive {:projection_refreshed, %{dataset_revision: 10}}, 500
    assert ProjectionSubscription.last_revision(subscription) == 10
  end

  test "subscription reauthorizes and fails closed after actor authority changes", %{
    fixture: fixture,
    authority: authority
  } do
    owner = self()
    {:ok, stranger_iri} = ResourceIdentity.repository("phase-05-revoked-reader")

    {:ok, stranger} =
      AuthorityContext.new(%{
        principal_iri: stranger_iri,
        actor_iri: stranger_iri,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    refresh = fn current_authority, hinted_revision ->
      if current_authority.actor_iri == fixture.actor do
        {:ok, %{dataset_revision: hinted_revision}}
      else
        {:error, Error.new(:unauthorized, :catalog_query)}
      end
    end

    subscription =
      start_supervised!(
        {ProjectionSubscription,
         scope_iri: fixture.factory_scope,
         authority: authority,
         refresh: refresh,
         owner: owner,
         last_revision: 3,
         debounce_ms: 10}
      )

    assert :ok = ProjectionSubscription.reauthorize(subscription, stranger)
    assert_receive {:projection_inaccessible, %{kind: :unauthorized}}, 500
    assert ProjectionSubscription.last_revision(subscription) == 3
  end

  defp event(scope_iri, revision) do
    %ChangeEvent{
      dataset_revision: revision,
      affected_graphs: [%{family: :factory_catalog, revision: revision}],
      scope_iri: scope_iri,
      command_class: "Phase05Test",
      receipt_iri: "https://jido.run/id/command/00000000000000000000000000000000"
    }
  end

  defp collect_iri_terms(value) when is_list(value),
    do: Enum.flat_map(value, &collect_iri_terms/1)

  defp collect_iri_terms(%{type: :iri} = value), do: [value]

  defp collect_iri_terms(value) when is_map(value),
    do: value |> Map.values() |> Enum.flat_map(&collect_iri_terms/1)

  defp collect_iri_terms(_value), do: []

  defp contains_rdf_struct?(value) when is_list(value),
    do: Enum.any?(value, &contains_rdf_struct?/1)

  defp contains_rdf_struct?(%module{}) when module in [RDF.IRI, RDF.Literal, RDF.BlankNode],
    do: true

  defp contains_rdf_struct?(value) when is_map(value),
    do: value |> Map.values() |> Enum.any?(&contains_rdf_struct?/1)

  defp contains_rdf_struct?(_value), do: false
end

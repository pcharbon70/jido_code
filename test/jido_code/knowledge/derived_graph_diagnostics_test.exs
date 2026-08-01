defmodule JidoCode.Knowledge.DerivedGraphDiagnosticsTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Projection
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ReadDiagnostics
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"

  setup context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    {:ok, rule_set} = ResourceIdentity.repository("phase-05-rule-set")

    {:ok, target} =
      GraphRegistry.graph_iri(:derived, %{rule_set: "phase-five", revision: 0})

    {:ok, fixture: fixture, authority: authority, rule_set: rule_set, target: target}
  end

  test "publishes, detects stale input, marks stale, rebuilds, and deletes derived graphs", %{
    fixture: fixture,
    authority: authority,
    rule_set: rule_set,
    target: target
  } do
    request =
      derivation_attributes(fixture, authority, rule_set, target, 0, :publish, 100, %{
        fixture.graphs.catalog => 1
      })

    assert {:ok, receipt} = DerivedGraphManager.publish(request, writer: fixture.writer)
    assert receipt.outcome == :committed
    assert receipt.graph_revisions[target].new == 1

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(target, server: fixture.query_runner)

    assert metadata.family == :derived
    assert metadata.invalidation_state == :current
    assert metadata.source_graph_revisions == [%{graph: fixture.graphs.catalog, revision: 1}]

    assert {:ok, freshness} =
             query_freshness(fixture, authority, target, %{
               mode: :strict,
               derived_rule_set_revision: 0
             })

    assert freshness.freshness == :current
    assert freshness.consistency.status == :satisfied
    assert freshness.graph_revisions[fixture.graphs.catalog] == 1

    enrolled = Phase04Fixture.enroll!(fixture)

    assert {:ok, :stale} =
             DerivedGraphManager.status(metadata, %{fixture.graphs.catalog => 2})

    assert {:error, %{kind: :stale_precondition}, strict_receipt} =
             query_freshness(
               enrolled,
               authority,
               target,
               %{mode: :strict, derived_rule_set_revision: 0}
             )

    assert :derived_graph_stale in strict_receipt.gaps

    assert {:ok, warned} =
             query_freshness(
               enrolled,
               authority,
               target,
               %{mode: :warn, derived_rule_set_revision: 0}
             )

    assert warned.freshness == :stale
    assert ReadDiagnostics.from_query(warned).action == :rebuild_derived_graph

    stale_request =
      derivation_attributes(enrolled, authority, rule_set, target, 0, :mark_stale, 101, %{
        fixture.graphs.catalog => 1
      })

    assert {:ok, stale_receipt} =
             DerivedGraphManager.publish(stale_request, writer: fixture.writer)

    assert stale_receipt.graph_revisions[target].new == 2

    assert {:ok, stale_metadata} =
             QueryRunner.graph_metadata(target, server: fixture.query_runner)

    assert stale_metadata.invalidation_state == :stale

    {:ok, rebuilt_target} =
      GraphRegistry.graph_iri(:derived, %{rule_set: "phase-five", revision: 1})

    rebuilt_request =
      derivation_attributes(enrolled, authority, rule_set, rebuilt_target, 1, :publish, 102, %{
        fixture.graphs.catalog => 2
      })
      |> Map.put(:expected_prior_derivation, %{graph_iri: target, revision: 2})

    assert {:ok, rebuilt_receipt} =
             DerivedGraphManager.publish(rebuilt_request, writer: fixture.writer)

    assert rebuilt_receipt.graph_revisions[rebuilt_target].new == 1

    delete_request =
      derivation_attributes(enrolled, authority, rule_set, target, 0, :delete, 103, %{
        fixture.graphs.catalog => 2
      })
      |> Map.put(:expected_prior_derivation, %{graph_iri: target, revision: 2})

    assert {:ok, delete_receipt} =
             DerivedGraphManager.publish(delete_request, writer: fixture.writer)

    assert delete_receipt.graph_revisions[target].new == 3

    assert {:ok, invalidated_metadata} =
             QueryRunner.graph_metadata(target, server: fixture.query_runner)

    assert invalidated_metadata.invalidation_state == :invalidated

    assert {:ok, deleted_content} =
             QueryRunner.execute(
               :resource_description,
               "1.0.0",
               %{graph: target, resource: resource!("derived-assertion-100")},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert deleted_content.data == []

    assert {:ok, catalog_metadata} =
             QueryRunner.graph_metadata(
               fixture.graphs.catalog,
               server: fixture.query_runner
             )

    assert catalog_metadata.graph_revision == 2

    stale_publish =
      derivation_attributes(enrolled, authority, rule_set, rebuilt_target, 1, :publish, 104, %{
        fixture.graphs.catalog => 1
      })

    assert {:error, %{kind: :stale_precondition}} =
             DerivedGraphManager.publish(stale_publish, writer: fixture.writer)
  end

  test "read diagnostics remain bounded and hide graph identities from ordinary callers", %{
    fixture: fixture,
    authority: authority
  } do
    assert {:ok, result} =
             QueryRunner.execute(
               :graph_metadata,
               "1.0.0",
               %{graph: fixture.graphs.catalog},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    ordinary = ReadDiagnostics.from_query(result, cache: :miss)
    assert ordinary.query == %{name: :graph_metadata, version: "1.0.0"}
    assert ordinary.evaluated.graph_count == 1
    assert ordinary.cache == :miss
    assert ordinary.action == :requery
    refute inspect(ordinary) =~ fixture.graphs.catalog
    refute Map.has_key?(ordinary, :sparql)
    refute Map.has_key?(ordinary, :backend)

    privileged = ReadDiagnostics.from_query(result, privileged?: true, cache: :hit)
    assert privileged.evaluated.graphs == [%{family: :factory_catalog, revision: 1}]
    refute inspect(privileged) =~ fixture.graphs.catalog

    assert {:ok, projection} =
             Projection.build(result, authority, fixture.factory_scope,
               generated_at: fixture.issued_at,
               parameters: %{graph: fixture.graphs.catalog}
             )

    projection_diagnostic = ReadDiagnostics.from_projection(projection, cache: :hit)
    assert projection_diagnostic.projection.shape == :table
    assert projection_diagnostic.cache == :hit

    error_diagnostic =
      ReadDiagnostics.from_error(Error.new(:corrupt, :catalog_query),
        query: %{name: :graph_metadata, version: "1.0.0"}
      )

    assert error_diagnostic.safe_error == %{
             kind: :corrupt,
             operation: :catalog_query,
             retry: :never
           }

    assert error_diagnostic.action == :escalate_integrity
    refute inspect(error_diagnostic) =~ "SELECT"
    refute inspect(error_diagnostic) =~ fixture.graphs.catalog
  end

  defp query_freshness(fixture, authority, graph, consistency) do
    QueryRunner.execute(
      :derived_graph_freshness,
      "1.0.0",
      %{graph: graph},
      authority,
      fixture.factory_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at,
      consistency: consistency
    )
  end

  defp derivation_attributes(
         fixture,
         authority,
         rule_set,
         target,
         rule_revision,
         operation,
         marker,
         source_revisions
       ) do
    statements =
      if operation == :publish do
        [
          {
            resource!("derived-assertion-#{marker}"),
            @jf <> "derivedValue",
            RDF.literal("result-#{marker}")
          }
        ]
      else
        []
      end

    %{
      operation: operation,
      command_iri: local!(:command, marker),
      authority: authority,
      scope_iri: fixture.factory_scope,
      idempotency_key: "phase-05-derivation-#{marker}",
      correlation_iri: local!(:activity, marker),
      causation_iri: fixture.bootstrap_command_iri,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      target_graph_iri: target,
      rule_set_iri: rule_set,
      rule_set_slug: "phase-five",
      rule_revision: rule_revision,
      query_version: "phase-05-rules/1.0.0",
      source_graph_revisions: source_revisions,
      expected_prior_derivation: nil,
      reason: "phase-05-derived-graph-lifecycle",
      statements: statements
    }
  end

  defp resource!(material) do
    {:ok, iri} = ResourceIdentity.repository(material)
    iri
  end

  defp local!(kind, marker) do
    {:ok, iri} = ResourceIdentity.local(kind, marker, :binary.copy(<<rem(marker, 256)>>, 10))
    iri
  end
end

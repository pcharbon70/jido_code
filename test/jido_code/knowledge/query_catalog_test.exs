defmodule JidoCode.Knowledge.QueryCatalogTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryDefinition
  alias JidoCode.Knowledge.QueryParameters
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

  test "catalog definitions are fixed, digest-bound, and bounded" do
    assert :ok = QueryCatalog.verify()
    assert QueryCatalog.version() == "1.0.0"
    assert length(QueryCatalog.names()) == 17
    assert byte_size(QueryCatalog.digest()) == 64

    for name <- QueryCatalog.names() do
      assert {:ok, definition} = QueryCatalog.fetch(name, "1.0.0")
      assert definition.source_digest == QueryDefinition.source_digest(definition.source)
      assert definition.compatibility_notes != ""
      assert definition.limits.timeout_ms <= 5_000
      refute Regex.match?(~r/\b(?:INSERT|DELETE|SERVICE)\b/i, definition.source)
    end

    assert {:error, %{kind: :invalid_input}} = QueryCatalog.fetch(:unknown, "1.0.0")
    assert {:ok, %{version: "2.0.0"}} = QueryCatalog.fetch(:graph_metadata, "2.0.0")
    assert {:error, %{kind: :invalid_input}} = QueryCatalog.fetch(:graph_metadata, "2.1.0")
  end

  test "typed binding rejects undeclared input and SPARQL injection", %{fixture: fixture} do
    {:ok, definition} = QueryCatalog.fetch(:resource_description, "1.0.0")

    assert {:ok, binding} =
             QueryParameters.bind(definition, %{
               graph: fixture.graphs.catalog,
               resource: fixture.factory_iri
             })

    assert binding.graph_iris == [fixture.graphs.catalog]
    refute String.contains?(binding.query, "{{")

    attacks = [
      "\" } UNION { ?s ?p ?o } #",
      "https://jido.run/resource/x%7D%20SERVICE",
      "https://jido.run/resource/x\nGRAPH ?g",
      "https://jido.run/resource/x> DELETE WHERE { ?s ?p ?o } #",
      "https://jido.run/resource/x%0aINSERT"
    ]

    for attack <- attacks do
      assert {:error, %{kind: :invalid_input}} =
               QueryParameters.bind(definition, %{
                 graph: fixture.graphs.catalog,
                 resource: attack
               })
    end

    assert {:error, %{kind: :invalid_input}} =
             QueryParameters.bind(definition, %{
               graph: fixture.graphs.catalog,
               resource: fixture.factory_iri,
               sparql: "SELECT * WHERE { ?s ?p ?o }"
             })
  end

  test "executes reviewed scalar, metadata, ASK, and CONSTRUCT queries", %{
    fixture: fixture,
    authority: authority
  } do
    assert {:ok, revision} =
             QueryRunner.execute(
               :dataset_revision,
               "1.0.0",
               %{},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert revision.query_name == :dataset_revision
    assert [%{"revision" => %{type: :literal}}] = revision.data
    assert revision.dataset_revision >= 2
    assert revision.graph_revisions == %{}

    assert {:ok, metadata} =
             QueryRunner.execute(
               :graph_metadata,
               "1.0.0",
               %{graph: fixture.graphs.catalog},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert metadata.data != []
    assert metadata.graph_revisions[fixture.graphs.catalog] == 1
    assert metadata.completeness.complete?

    assert {:ok, health} =
             QueryRunner.execute(
               :graph_health,
               "1.0.0",
               %{graph: fixture.graphs.catalog},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert health.data

    assert {:ok, description} =
             QueryRunner.execute(
               :resource_description,
               "1.0.0",
               %{graph: fixture.graphs.catalog, resource: fixture.factory_iri},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert description.data != []
    assert Enum.all?(description.data, &Map.has_key?(&1, :subject))
  end

  test "fails closed for unauthorized actor, scope widening, and raw-query-shaped input", %{
    fixture: fixture,
    authority: authority
  } do
    {:ok, stranger_iri} = ResourceIdentity.repository("unauthorized-stranger")

    {:ok, stranger} =
      AuthorityContext.new(%{
        principal_iri: stranger_iri,
        actor_iri: stranger_iri,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    assert {:error, %{kind: :unauthorized, operation: :catalog_query}} =
             QueryRunner.execute(
               :dataset_revision,
               "1.0.0",
               %{},
               stranger,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    enrolled = Phase04Fixture.enroll!(fixture)

    assert {:error, %{kind: :unauthorized, operation: :catalog_query}} =
             QueryRunner.execute(
               :graph_metadata,
               "1.0.0",
               %{graph: enrolled.graphs.catalog},
               authority,
               enrolled.repository_scope,
               server: enrolled.query_runner,
               evaluated_at: enrolled.issued_at
             )

    assert {:error, %{kind: :invalid_input}} =
             QueryRunner.execute(
               :graph_metadata,
               "1.0.0",
               %{graph: "https://example.test/graph?q=SELECT"},
               authority,
               fixture.factory_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )
  end
end

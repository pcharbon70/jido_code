defmodule JidoCode.Knowledge.RepositoryWiki.Phase02IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLint
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.RepositoryWikiPhase2Fixture

  setup context do
    fixture = RepositoryWikiPhase2Fixture.build!(to_string(context.test))
    on_exit(fn -> RepositoryWikiPhase2Fixture.cleanup!(fixture) end)
    fixture
  end

  test "RW2 compiles, qualifies, segments, and lint-pins an exact zero-token dependency edition",
       fixture do
    lock_names = MapSet.new(Enum.map(fixture.lock.entries, & &1.name))
    catalog_names = MapSet.new(Enum.map(fixture.catalog.nodes, & &1.name))
    assert MapSet.subset?(lock_names, catalog_names)

    expected_edges =
      fixture.lock.entries
      |> Enum.flat_map(fn entry ->
        Enum.map(entry.edges, &{entry.name, &1.name, &1.requirement, &1.optional})
      end)
      |> MapSet.new()

    represented_edges =
      fixture.catalog.edges
      |> Enum.map(&{&1.parent, &1.child, &1.requirement, &1.optional})
      |> MapSet.new()

    assert represented_edges == expected_edges
    assert fixture.compilation.dependency_node_count == MapSet.size(catalog_names)
    assert fixture.compilation.dependency_edge_count == MapSet.size(expected_edges)
    assert fixture.compilation.dependency_extension.source_fence == fixture.source_fence
    assert fixture.compilation.dependency_extension.model_calls == 0
    assert fixture.compilation.dependency_extension.model_input_tokens == 0
    assert fixture.compilation.dependency_extension.model_output_tokens == 0
    assert fixture.compilation.dependency_extension.usage_cost_microunits == 0

    detail_names =
      fixture.compilation.pages
      |> Enum.filter(&(&1.kind == :dependency))
      |> Enum.map(& &1.title)
      |> MapSet.new()

    assert detail_names == catalog_names

    assert Enum.all?(fixture.compilation.pages, fn page ->
             page.source_iris != [] and
               Enum.all?(page.source_iris, fn source_iri ->
                 Enum.any?(fixture.compilation.sources, &(&1.iri == source_iri))
               end)
           end)

    assert Enum.all?(fixture.compilation.pages, fn page ->
             links = if is_map(page.facts), do: page.facts[:links] || [], else: []

             Enum.all?(links, fn link ->
               (link.verification == :verified and is_binary(link.destination)) or
                 (link.verification == :text_only and is_nil(link.destination))
             end)
           end)

    assert {:ok, lint} =
             DependencyLint.lint(
               fixture.compilation,
               fixture.reconciliation,
               fixture.catalog,
               fixture.metadata,
               fixture.link_sets
             )

    assert lint.blocking_count == 0
    assert lint.warning_count > 0
    assert lint.coverage.expected_lock_nodes == lint.coverage.represented_lock_nodes
    assert lint.coverage.expected_edges == lint.coverage.represented_edges
    assert lint.coverage.expected_dependency_pages == lint.coverage.represented_dependency_pages
    assert lint.coverage.zero_model_tokens

    assert {:ok, segments} =
             Knowledge.partition_repository_wiki(
               fixture.compilation.edition_iri,
               fixture.compilation.statements,
               fixture.created_at
             )

    assert {:ok, edition} = Knowledge.repository_wiki_edition(fixture.compilation, segments)
    {:ok, catalog_graph} = GraphRegistry.graph_iri(:factory_catalog, %{})

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: fixture.repository_iri})

    command_attributes = %{
      repository_iri: fixture.repository_iri,
      catalog_graph_iri: catalog_graph,
      control_graph_iri: control_graph,
      wiki_graph_iri: edition.graph_iri,
      expected_catalog_revision: 1,
      expected_control_revision: 1,
      expected_wiki_revision: 1,
      expected_dataset_revision: 2,
      enrollment_revision: 1,
      principal_iri: resource(:authorization_grant, "phase2-principal"),
      actor_iri: resource(:authorization_grant, "phase2-actor"),
      scope_iri: fixture.repository_iri,
      correlation_iri: resource(:authorization_grant, "phase2-correlation"),
      causation_iri: resource(:authorization_grant, "phase2-causation"),
      reason: "qualify exact dependency wiki",
      recorded_at: fixture.created_at,
      source_fence: fixture.source_fence,
      lint_profile_digest: lint.profile_digest
    }

    assert {:ok, linted} =
             Knowledge.lint_repository_wiki_edition(
               edition,
               lint.findings,
               command_attributes,
               clock: fn -> fixture.created_at end
             )

    assert linted.report.blocking_count == 0
    assert linted.report.profile_digest == lint.profile_digest
  end

  test "RW2 rejects cross-repository compilation and lint inputs", fixture do
    other = RepositoryWikiPhase2Fixture.build!("cross-repository")
    on_exit(fn -> RepositoryWikiPhase2Fixture.cleanup!(other) end)

    assert {:error, %{kind: :conflict}} =
             Knowledge.compile_repository_wiki_dependencies(
               fixture.base_compilation,
               fixture.reconciliation,
               other.catalog,
               fixture.metadata,
               fixture.link_sets,
               fixture.dependency_attributes
             )

    assert {:error, %{kind: :conflict}} =
             DependencyLint.lint(
               fixture.compilation,
               fixture.reconciliation,
               other.catalog,
               fixture.metadata,
               fixture.link_sets
             )
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

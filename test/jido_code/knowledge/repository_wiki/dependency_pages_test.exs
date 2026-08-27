defmodule JidoCode.Knowledge.RepositoryWiki.DependencyPagesTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Compiler
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.RepositoryWikiPhase2Fixture

  setup context do
    fixture = RepositoryWikiPhase2Fixture.build!(to_string(context.test))
    on_exit(fn -> RepositoryWikiPhase2Fixture.cleanup!(fixture) end)
    fixture
  end

  test "compiles stable project, runtime, overview, direct, transitive, gap, and freshness pages",
       fixture do
    compilation = fixture.compilation

    assert compilation.dependency_extension.profile == "wiki-dependency-pages/1.0.0"
    assert compilation.dependency_extension.profile_digest
    assert compilation.dependency_extension.reconciliation_digest == fixture.reconciliation.digest
    assert compilation.dependency_extension.catalog_digest == fixture.catalog.digest
    assert compilation.dependency_page_count == 7 + fixture.catalog.node_count
    assert compilation.dependency_node_count == fixture.catalog.node_count
    assert compilation.dependency_edge_count == fixture.catalog.edge_count
    assert compilation.page_count == length(compilation.pages)
    assert compilation.statement_count == length(compilation.statements)

    slugs = Enum.map(compilation.pages, & &1.slug)

    for slug <- ~w[
          project runtime-requirements dependency-overview direct-dependencies
          transitive-dependencies dependency-gaps dependency-metadata-freshness
        ] do
      assert slug in slugs
    end

    assert Enum.map(compilation.pages, & &1.order) ==
             Enum.to_list(0..(compilation.page_count - 1))

    overview = page(compilation, "dependency-overview")
    assert overview.facts.node_count == fixture.catalog.node_count
    assert overview.facts.edge_count == fixture.catalog.edge_count
    assert overview.facts.catalog_digest == fixture.catalog.digest

    gaps = page(compilation, "dependency-gaps")
    assert gaps.completeness == :incomplete
    assert gaps.facts.gaps == fixture.catalog.gaps

    freshness = page(compilation, "dependency-metadata-freshness")
    assert freshness.facts.metadata_count == 1

    assert Enum.find(freshness.facts.dependencies, &(&1.dependency == "alpha")).authority ==
             :observed

    assert Enum.find(freshness.facts.dependencies, &(&1.dependency == "beta")).state ==
             :not_requested
  end

  test "compiles one provenance-bearing detail page per resolved or explicit dependency",
       fixture do
    details = Enum.filter(fixture.compilation.pages, &(&1.kind == :dependency))
    assert length(details) == fixture.catalog.node_count

    alpha = page(fixture.compilation, "dependency-alpha")
    assert alpha.title == "alpha"
    assert alpha.anchor == "dependency-alpha"
    assert alpha.facts.general.classification == :resolved
    assert alpha.facts.general.summary == "Alpha package metadata."
    assert alpha.facts.general.licenses == ["Apache-2.0"]
    assert alpha.facts.scopes.environments == ["dev", "test"]
    assert alpha.facts.scopes.optional
    assert Enum.map(alpha.facts.outgoing, & &1.child) == ["beta", "ghost"]
    assert alpha.facts.root_paths == [["alpha"]]
    assert alpha.facts.metadata.authority == :observed
    assert alpha.facts.metadata.digest == fixture.metadata["alpha"].digest
    assert length(alpha.source_iris) == 3

    assert Enum.any?(alpha.facts.links, fn link ->
             link.kind == :documentation and link.verification == :verified
           end)

    assert Enum.any?(alpha.facts.links, fn link ->
             link.verification == :text_only and is_nil(link.destination) and
               link.reason == :private_or_ambiguous_host
           end)

    ghost = page(fixture.compilation, "dependency-ghost")
    assert ghost.facts.general.classification == :unverifiable
    assert ghost.completeness == :incomplete
    assert ghost.facts.incoming |> hd() |> Map.fetch!(:parent) == "alpha"
    assert ghost.facts.root_paths == [["alpha", "ghost"]]
  end

  test "is deterministic for identical inputs and rejects cross-edition or mutated metadata",
       fixture do
    assert {:ok, repeated} =
             Compiler.compile_dependencies(
               fixture.base_compilation,
               fixture.reconciliation,
               fixture.catalog,
               fixture.metadata,
               fixture.link_sets,
               fixture.dependency_attributes
             )

    assert repeated == fixture.compilation

    {:ok, other_edition} = ResourceIdentity.deterministic(:wiki_edition, "other-edition")
    wrong_attributes = %{fixture.dependency_attributes | edition_iri: other_edition}

    assert {:error, %{kind: :conflict}} =
             Compiler.compile_dependencies(
               fixture.base_compilation,
               fixture.reconciliation,
               fixture.catalog,
               fixture.metadata,
               fixture.link_sets,
               wrong_attributes
             )

    tampered = put_in(fixture.metadata["alpha"].facts.summary, "changed")

    assert {:error, %{kind: :invalid_input}} =
             Compiler.compile_dependencies(
               fixture.base_compilation,
               fixture.reconciliation,
               fixture.catalog,
               tampered,
               fixture.link_sets,
               fixture.dependency_attributes
             )
  end

  test "records exact zero-model accounting and all Phase 2 input profile digests", fixture do
    extension = fixture.compilation.dependency_extension
    assert extension.model_calls == 0
    assert extension.model_input_tokens == 0
    assert extension.model_output_tokens == 0
    assert extension.usage_cost_microunits == 0
    assert extension.parser_profile == "mix-static/1.0.0"
    assert extension.parser_profile_digest == fixture.static.profile_digest
    assert extension.lock_profile == "mix-lock/1.0.0"
    assert extension.lock_profile_digest == fixture.lock.profile_digest
    assert extension.resolver_profile == "wiki-dependency-resolver/1.0.0"
    assert extension.resolver_profile_digest == fixture.catalog.profile_digest
    assert extension.source_profile == "wiki-dependency-sources/1.0.0"
    assert extension.source_profile_digest
    assert extension.compiler_digest
    assert extension.metadata_fixture_digests != []
    assert fixture.compilation.model_input_tokens == 0
    assert fixture.compilation.model_output_tokens == 0
    assert fixture.compilation.usage_cost_microunits == 0
  end

  defp page(compilation, slug), do: Enum.find(compilation.pages, &(&1.slug == slug))
end

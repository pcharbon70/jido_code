defmodule JidoCode.Knowledge.RepositoryWiki.ReviewedReadsTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryParameters
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    repository_wiki_navigation_tree repository_wiki_page_by_slug repository_wiki_backlinks
    repository_wiki_source_references repository_wiki_dependency_lookup
    repository_wiki_guide_collection repository_wiki_known_gaps
    repository_wiki_preview_detail repository_wiki_edition_comparison
  ]a

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("reviewed-wiki-reads")
    {:ok, edition} = ResourceIdentity.wiki_edition(repository, Contract.digest("edition"))
    {:ok, page} = ResourceIdentity.wiki_page(edition, :user_guide, "guide")
    {:ok, other_edition} = ResourceIdentity.wiki_edition(repository, Contract.digest("other"))
    {:ok, preview} = ResourceIdentity.deterministic(:wiki_preview, "reviewed-preview")

    {:ok, wiki_graph} =
      GraphRegistry.graph_iri(:repository_wiki, %{repository: repository, edition: edition})

    {:ok, other_wiki_graph} =
      GraphRegistry.graph_iri(:repository_wiki, %{
        repository: repository,
        edition: other_edition
      })

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    %{
      repository: repository,
      edition: edition,
      other_edition: other_edition,
      preview: preview,
      page: page,
      wiki_graph: wiki_graph,
      other_wiki_graph: other_wiki_graph,
      control_graph: control_graph
    }
  end

  test "publishes each reviewed read only in protocol 2.10.0" do
    names = QueryCatalog.names("2.10.0")

    for name <- @queries ++ [:repository_wiki_generation_profiles] do
      assert name in names
      refute name in QueryCatalog.names("2.9.0")
      assert {:ok, definition} = QueryCatalog.fetch(name, "2.10.0")
      assert definition.allow_graph_variable? == false
      assert definition.limits.row_limit == 200
      assert definition.limits.byte_limit == 256_000
      assert Contract.digest?(String.downcase(definition.source_digest))
    end

    assert :ok = QueryCatalog.verify()
  end

  test "binds stable slug, dependency, audience, edition, page, and graph as typed terms",
       fixture do
    cases = [
      {:repository_wiki_navigation_tree, %{graph: fixture.wiki_graph, resource: fixture.edition}},
      {:repository_wiki_page_by_slug,
       %{
         graph: fixture.wiki_graph,
         resource: fixture.repository,
         edition: fixture.edition,
         slug: "getting-started"
       }},
      {:repository_wiki_backlinks, %{graph: fixture.wiki_graph, resource: fixture.page}},
      {:repository_wiki_source_references, %{graph: fixture.wiki_graph, resource: fixture.page}},
      {:repository_wiki_dependency_lookup,
       %{
         graph: fixture.wiki_graph,
         resource: fixture.repository,
         edition: fixture.edition,
         dependency: "phoenix_live_view"
       }},
      {:repository_wiki_guide_collection,
       %{
         graph: fixture.wiki_graph,
         resource: fixture.repository,
         edition: fixture.edition,
         audience: "developer"
       }},
      {:repository_wiki_known_gaps, %{graph: fixture.wiki_graph, resource: fixture.edition}},
      {:repository_wiki_preview_detail,
       %{
         graph: fixture.wiki_graph,
         resource: fixture.repository,
         edition: fixture.edition,
         preview: fixture.preview
       }},
      {:repository_wiki_edition_comparison,
       %{
         control_graph: fixture.control_graph,
         left_graph: fixture.wiki_graph,
         right_graph: fixture.other_wiki_graph,
         resource: fixture.repository,
         left_edition: fixture.edition,
         right_edition: fixture.other_edition
       }}
    ]

    for {name, parameters} <- cases do
      assert {:ok, definition} = QueryCatalog.fetch(name, "2.10.0")
      assert {:ok, binding} = QueryParameters.bind(definition, parameters)
      assert fixture.wiki_graph in binding.graph_iris
      refute binding.query =~ "{{"
      refute binding.query =~ "GRAPH ?"
    end
  end

  test "rejects query-shaped literals, extra predicates, graph substitution, and unbounded values",
       fixture do
    {:ok, page_query} = QueryCatalog.fetch(:repository_wiki_page_by_slug, "2.10.0")

    assert {:error, %{kind: :invalid_input}} =
             QueryParameters.bind(page_query, %{
               graph: fixture.wiki_graph,
               resource: fixture.repository,
               edition: fixture.edition,
               slug: String.duplicate("a", 161)
             })

    assert {:error, %{kind: :invalid_input}} =
             QueryParameters.bind(page_query, %{
               graph: fixture.wiki_graph,
               resource: fixture.repository,
               edition: fixture.edition,
               slug: "guide",
               predicate: "?p"
             })

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: fixture.repository})

    assert {:error, %{kind: :invalid_input}} =
             QueryParameters.bind(page_query, %{
               graph: control_graph,
               resource: fixture.repository,
               edition: fixture.edition,
               slug: "guide"
             })
  end
end

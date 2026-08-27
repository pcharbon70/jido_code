defmodule JidoCode.Product.RepositoryWikiQuerySecurityTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.RepositoryWikiQuerySecurity

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("wiki-query-security")
    {:ok, edition} = ResourceIdentity.wiki_edition(repository, Contract.digest("edition"))
    {:ok, page} = ResourceIdentity.wiki_page(edition, :user_guide, "guide")
    {:ok, preview} = ResourceIdentity.deterministic(:wiki_preview, "security-preview")
    {:ok, other_edition} = ResourceIdentity.wiki_edition(repository, Contract.digest("other"))
    {:ok, control} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    {:ok, wiki} =
      GraphRegistry.graph_iri(:repository_wiki, %{repository: repository, edition: edition})

    {:ok, other_wiki} =
      GraphRegistry.graph_iri(:repository_wiki, %{repository: repository, edition: other_edition})

    %{
      repository: repository,
      edition: edition,
      other_edition: other_edition,
      preview: preview,
      page: page,
      control: control,
      wiki: wiki,
      other_wiki: other_wiki
    }
  end

  test "admits only closed reviewed query shapes", fixture do
    assert :ok =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_page_by_slug,
               "2.10.0",
               %{
                 graph: fixture.wiki,
                 resource: fixture.repository,
                 edition: fixture.edition,
                 slug: "getting-started"
               }
             )

    assert :ok =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_preview_detail,
               "2.10.0",
               %{
                 graph: fixture.wiki,
                 resource: fixture.repository,
                 edition: fixture.edition,
                 preview: fixture.preview
               }
             )

    assert :ok =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_edition_comparison,
               "2.10.0",
               %{
                 control_graph: fixture.control,
                 left_graph: fixture.wiki,
                 right_graph: fixture.other_wiki,
                 resource: fixture.repository,
                 left_edition: fixture.edition,
                 right_edition: fixture.other_edition
               }
             )

    assert :ok =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_backlinks,
               "2.10.0",
               %{graph: fixture.wiki, resource: fixture.page}
             )

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiQuerySecurity.validate(:raw_sparql, "2.10.0", %{})

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_page_by_slug,
               "2.10.0",
               %{
                 graph: fixture.wiki,
                 resource: fixture.repository,
                 edition: fixture.edition,
                 slug: "../outside",
                 predicate: "arbitrary"
               }
             )
  end

  test "rejects graph-family substitution, cross-edition literals, and unknown audiences",
       fixture do
    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_navigation_tree,
               "2.10.0",
               %{graph: fixture.control, resource: fixture.edition}
             )

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_edition_comparison,
               "2.10.0",
               %{
                 control_graph: fixture.control,
                 left_graph: fixture.wiki,
                 right_graph: fixture.wiki,
                 resource: fixture.repository,
                 left_edition: fixture.edition,
                 right_edition: fixture.edition
               }
             )

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_guide_collection,
               "2.10.0",
               %{
                 graph: fixture.wiki,
                 resource: fixture.repository,
                 edition: fixture.edition,
                 audience: "executive-secret"
               }
             )

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiQuerySecurity.validate(
               :repository_wiki_current_edition,
               "2.10.0",
               %{
                 control_graph: fixture.wiki,
                 wiki_graph: fixture.control,
                 resource: fixture.repository
               }
             )
  end
end

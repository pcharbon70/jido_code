defmodule JidoCode.Product.RepositoryWikiSearchIndexTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.RepositoryWikiSearchIndex

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("wiki-search")
    {:ok, edition} = ResourceIdentity.wiki_edition(repository, digest("search-edition"))

    pages = [
      page(edition, :user_guide, "getting-started", "Getting Started", "user", 0),
      page(edition, :developer_guide, "developer-workflow", "Developer Workflow", "developer", 1),
      page(edition, :dependency, "dependency-phoenix", "phoenix", "developer", 2)
    ]

    {:ok, index} = RepositoryWikiSearchIndex.build(edition, 42, pages)
    %{edition: edition, pages: pages, index: index}
  end

  test "builds a deterministic disposable per-edition index", fixture do
    assert {:ok, repeated} = RepositoryWikiSearchIndex.build(fixture.edition, 42, fixture.pages)
    assert repeated == fixture.index
    assert repeated.document_count == 3
    assert repeated.durable_authority? == false
    assert Contract.digest?(repeated.digest)
    assert repeated.profile_digest == RepositoryWikiSearchIndex.profile().digest
  end

  test "uses bounded exact tokenization, stable ranking, limits, and safe snippets", fixture do
    assert {:ok, [first]} =
             RepositoryWikiSearchIndex.search(fixture.index, "developer workflow", 5)

    assert first.slug == "developer-workflow"
    assert first.score > 0
    assert first.snippet == "Developer Workflow · developer · developer_guide"

    assert {:ok, [dependency]} = RepositoryWikiSearchIndex.search(fixture.index, "phoenix", 1)
    assert dependency.slug == "dependency-phoenix"

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiSearchIndex.search(fixture.index, "phoenix|raw", 10)

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiSearchIndex.search(fixture.index, String.duplicate("a", 81), 10)

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiSearchIndex.search(fixture.index, "phoenix", 21)
  end

  test "rejects unbounded or malformed candidate fields before indexing", fixture do
    malformed = put_in(hd(fixture.pages).slug, "../outside")

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiSearchIndex.build(fixture.edition, 42, [malformed])

    assert {:error, %{kind: :invalid_input}} =
             RepositoryWikiSearchIndex.build(
               fixture.edition,
               42,
               List.duplicate(hd(fixture.pages), 3_073)
             )
  end

  defp page(edition, kind, slug, title, audience, order) do
    {:ok, page_iri} = ResourceIdentity.wiki_page(edition, kind, slug)

    %{
      page_iri: page_iri,
      kind: Atom.to_string(kind),
      slug: slug,
      title: title,
      audience: audience,
      order: order
    }
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

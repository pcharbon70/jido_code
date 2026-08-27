defmodule JidoCode.Knowledge.RepositoryWiki.DependencyLintTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLint
  alias JidoCode.TestSupport.RepositoryWikiPhase2Fixture

  setup context do
    fixture = RepositoryWikiPhase2Fixture.build!(to_string(context.test))
    on_exit(fn -> RepositoryWikiPhase2Fixture.cleanup!(fixture) end)
    fixture
  end

  test "qualifies exact closure and retains explicit uncertainty as machine-readable warnings",
       fixture do
    assert {:ok, first} = lint(fixture)
    assert {:ok, second} = lint(fixture)
    assert first == second
    assert first.profile == "wiki-lint/1.0.0"
    assert first.extension == "dependency-completeness/1.0.0"
    assert first.blocking_count == 0
    assert first.warning_count > 0
    assert first.truncated_finding_count == 0
    assert first.profile_digest
    assert first.digest
    assert Enum.all?(first.findings, &(&1.severity == :warning))
    assert Enum.any?(first.findings, &String.starts_with?(&1.code, "dependency_gap_"))

    assert first.coverage.expected_lock_nodes == fixture.lock.entry_count
    assert first.coverage.represented_lock_nodes == fixture.lock.entry_count
    assert first.coverage.expected_declarations == fixture.static.dependency_count
    assert first.coverage.represented_declarations == fixture.static.dependency_count
    assert first.coverage.expected_edges == fixture.lock.edge_count
    assert first.coverage.represented_edges == fixture.lock.edge_count
    assert first.coverage.expected_dependency_pages == fixture.catalog.node_count
    assert first.coverage.represented_dependency_pages == fixture.catalog.node_count
    assert first.coverage.zero_model_tokens
  end

  test "blocks omitted pages and supported edges", fixture do
    pages =
      Enum.reject(fixture.compilation.pages, fn page ->
        page.kind == :dependency and page.title == "beta"
      end)

    omitted_page =
      fixture.compilation
      |> Map.put(:pages, pages)
      |> Map.put(:page_count, length(pages))
      |> put_compilation_digest()

    assert {:ok, page_report} =
             DependencyLint.lint(
               omitted_page,
               fixture.reconciliation,
               fixture.catalog,
               fixture.metadata,
               fixture.link_sets
             )

    assert page_report.blocking_count > 0
    assert Enum.any?(page_report.findings, &(&1.code == "dependency_page_missing"))

    [_removed | edges] = fixture.catalog.edges

    omitted_edge =
      fixture.catalog
      |> Map.put(:edges, edges)
      |> Map.put(:edge_count, length(edges))
      |> put_digest(:digest)

    assert {:ok, edge_report} =
             DependencyLint.lint(
               fixture.compilation,
               fixture.reconciliation,
               omitted_edge,
               fixture.metadata,
               fixture.link_sets
             )

    assert edge_report.blocking_count > 0
    assert Enum.any?(edge_report.findings, &(&1.code == "dependency_edge_missing"))
    assert Enum.any?(edge_report.findings, &(&1.code == "dependency_catalog_digest_stale"))
  end

  test "blocks unsafe clickable links and remote metadata promoted to authority", fixture do
    alpha_links = fixture.link_sets["alpha"]
    unsafe_index = Enum.find_index(alpha_links.links, &(&1.verification == :text_only))
    unsafe = Enum.at(alpha_links.links, unsafe_index)

    unsafe = %{
      unsafe
      | verification: :verified,
        destination: "http://localhost/admin",
        navigation: :external_noopener_noreferrer_nofollow
    }

    links = List.replace_at(alpha_links.links, unsafe_index, unsafe)

    unsafe_set =
      alpha_links
      |> Map.put(:links, links)
      |> put_digest(:digest)

    link_sets = Map.put(fixture.link_sets, "alpha", unsafe_set)

    assert {:ok, unsafe_report} =
             DependencyLint.lint(
               fixture.compilation,
               fixture.reconciliation,
               fixture.catalog,
               fixture.metadata,
               link_sets
             )

    assert unsafe_report.blocking_count > 0
    assert Enum.any?(unsafe_report.findings, &(&1.code == "unsafe_dependency_link"))
    assert Enum.any?(unsafe_report.findings, &(&1.code == "dependency_links_omitted"))

    promoted =
      fixture.metadata["alpha"]
      |> Map.put(:authority, :accepted)
      |> put_digest(:digest)

    metadata = Map.put(fixture.metadata, "alpha", promoted)

    assert {:ok, authority_report} =
             DependencyLint.lint(
               fixture.compilation,
               fixture.reconciliation,
               fixture.catalog,
               metadata,
               fixture.link_sets
             )

    assert authority_report.blocking_count > 0
    assert Enum.any?(authority_report.findings, &(&1.code == "metadata_authority_invalid"))
  end

  defp lint(fixture) do
    DependencyLint.lint(
      fixture.compilation,
      fixture.reconciliation,
      fixture.catalog,
      fixture.metadata,
      fixture.link_sets
    )
  end

  defp put_compilation_digest(compilation), do: put_digest(compilation, :compilation_digest)

  defp put_digest(value, key),
    do: Map.put(value, key, Contract.digest(Map.delete(value, key)))
end

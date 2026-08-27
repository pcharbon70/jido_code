defmodule JidoCode.Product.RepositoryWikiProjectionProviderTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.RepositoryWikiProjectionProvider

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("wiki-product-projection")
    {:ok, edition} = ResourceIdentity.wiki_edition(repository, Contract.digest("edition"))
    {:ok, overview} = ResourceIdentity.wiki_page(edition, :project_overview, "overview")
    {:ok, guide} = ResourceIdentity.wiki_page(edition, :user_guide, "getting-started")
    {:ok, source} = ResourceIdentity.deterministic(:wiki_source, "wiki-product-source")

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: resource(:authorization_grant, "principal"),
        actor_iri: resource(:authorization_grant, "actor"),
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    %{
      repository: repository,
      edition: edition,
      overview: overview,
      guide: guide,
      source: source,
      authority: authority,
      identity: %{actor_iri: authority.actor_iri}
    }
  end

  test "rebuilds authorized navigation, page detail, gaps, history, and search from graph reads",
       fixture do
    test_pid = self()
    query = query_fixture(fixture, test_pid)

    metadata = fn _graph ->
      {:ok, %{owner_scope: fixture.repository, lifecycle_state: :closed}}
    end

    assert {:ok, projection} =
             RepositoryWikiProjectionProvider.load(fixture.authority, fixture.identity,
               repository: fixture.repository,
               repository_authorized?: true,
               page_slug: "getting-started",
               search_query: "getting started",
               query: query,
               metadata: metadata
             )

    assert projection.state == :current
    assert projection.visible?
    assert projection.dataset_revision == 73
    assert projection.enrollment.state == :automatic
    assert projection.enrollment.read_visibility == :retained
    assert projection.edition.edition_iri == fixture.edition
    assert Enum.map(projection.navigation, & &1.slug) == ["overview", "getting-started"]
    assert projection.selected_page.page_iri == fixture.guide
    assert length(projection.backlinks) == 1
    assert length(projection.sources) == 1
    assert length(projection.gaps) == 1
    assert length(projection.history) == 1
    assert hd(projection.search_results).slug == "getting-started"
    assert projection.settings.generation_mode == :deterministic_only
    assert projection.settings.token_posture == :zero_model_tokens

    assert_receive {:wiki_query, :repository_wiki_enrollment_detail, "2.10.0", _, _, []}
    assert_receive {:wiki_query, :repository_wiki_current_edition, "2.10.0", _, _, []}
    assert_receive {:wiki_query, :repository_wiki_navigation_tree, "2.10.0", _, _, []}
    assert_receive {:wiki_query, :repository_wiki_page_by_slug, "2.10.0", _, _, []}
    refute_receive {:wiki_query, :raw_sparql, _, _, _, _}
  end

  test "authorizes the repository before querying or constructing search candidates", fixture do
    query = fn _name, _version, _parameters, _authority, _scope, _options ->
      flunk("concealed repository must not issue a query")
    end

    assert {:ok, projection} =
             RepositoryWikiProjectionProvider.load(fixture.authority, fixture.identity,
               repository: fixture.repository,
               repository_authorized?: false,
               query: query
             )

    assert projection.state == :unauthorized
    refute projection.visible?
    assert projection.navigation == []
    assert projection.search_results == []
  end

  test "conceals hidden enrollment and keeps an enabled but not-yet-compiled wiki empty",
       fixture do
    metadata = fn _graph -> {:ok, %{owner_scope: fixture.repository, lifecycle_state: :open}} end

    hidden_query = fn name, _version, _parameters, _authority, _scope, _options ->
      {:ok,
       result(
         name,
         enrollment_rows(
           fixture,
           "https://jido.run/ontology/concept/WikiReadHidden",
           fixture.edition
         )
       )}
    end

    assert {:ok, hidden} =
             RepositoryWikiProjectionProvider.load(fixture.authority, fixture.identity,
               repository: fixture.repository,
               repository_authorized?: true,
               query: hidden_query,
               metadata: metadata
             )

    assert hidden.state == :hidden
    refute hidden.visible?

    empty_query = fn name, _version, _parameters, _authority, _scope, _options ->
      {:ok,
       result(
         name,
         enrollment_rows(fixture, "https://jido.run/ontology/concept/WikiReadRetained", nil)
       )}
    end

    assert {:ok, empty} =
             RepositoryWikiProjectionProvider.load(fixture.authority, fixture.identity,
               repository: fixture.repository,
               repository_authorized?: true,
               query: empty_query,
               metadata: metadata
             )

    assert empty.state == :empty
    assert empty.visible?
    assert empty.navigation == []
  end

  test "rejects cross-revision query mixtures instead of publishing a torn projection", fixture do
    metadata = fn _graph ->
      {:ok, %{owner_scope: fixture.repository, lifecycle_state: :closed}}
    end

    query = fn name, _version, _parameters, _authority, _scope, _options ->
      revision = if name == :repository_wiki_navigation_tree, do: 74, else: 73
      {:ok, result(name, data(name, fixture), revision)}
    end

    assert {:ok, projection} =
             RepositoryWikiProjectionProvider.load(fixture.authority, fixture.identity,
               repository: fixture.repository,
               repository_authorized?: true,
               query: query,
               metadata: metadata
             )

    assert projection.state == :unavailable
    refute projection.visible?
  end

  defp query_fixture(fixture, test_pid) do
    fn name, version, parameters, _authority, scope, options ->
      send(test_pid, {:wiki_query, name, version, parameters, scope, options})
      {:ok, result(name, data(name, fixture))}
    end
  end

  defp data(:repository_wiki_enrollment_detail, fixture),
    do:
      enrollment_rows(
        fixture,
        "https://jido.run/ontology/concept/WikiReadRetained",
        fixture.edition
      )

  defp data(:repository_wiki_current_edition, fixture) do
    [
      %{
        "edition" => term(fixture.edition),
        "editionState" => term("https://jido.run/ontology/concept/WikiClosed"),
        "sourceSnapshot" => term(resource(:repository_snapshot, "source")),
        "sourceFence" => term("source-fence-73"),
        "compilerProfile" => term("wiki-deterministic-elixir/1.0.0"),
        "compilerDigest" => term(Contract.digest("compiler")),
        "freshness" => term("https://jido.run/ontology/concept/WikiFresh"),
        "closedAt" => term("2026-08-27T12:00:00Z")
      }
    ]
  end

  defp data(:repository_wiki_navigation_tree, fixture) do
    [
      page_row(fixture.overview, "project_overview", "overview", "Overview", 0, "user"),
      page_row(fixture.guide, "user_guide", "getting-started", "Getting Started", 1, "user")
    ]
  end

  defp data(:repository_wiki_known_gaps, _fixture) do
    [
      %{
        "gap" => term(resource(:wiki_gap, "gap")),
        "gapKind" => term("https://jido.run/ontology/concept/WikiIncomplete"),
        "sourceLocator" => term("docs/missing.md"),
        "omissionCode" => term("absent")
      }
    ]
  end

  defp data(:repository_wiki_edition_history, fixture),
    do: [
      hd(
        enrollment_rows(
          fixture,
          "https://jido.run/ontology/concept/WikiReadRetained",
          fixture.edition
        )
      )
    ]

  defp data(:repository_wiki_page_by_slug, fixture),
    do: [page_row(fixture.guide, "user_guide", "getting-started", "Getting Started", 1, "user")]

  defp data(:repository_wiki_backlinks, fixture) do
    [
      %{
        "link" => term(resource(:wiki_link, "backlink")),
        "kind" => term("https://jido.run/ontology/concept/Contains"),
        "sourcePage" => term(fixture.overview),
        "sourceSlug" => term("overview"),
        "sourceTitle" => term("Overview")
      }
    ]
  end

  defp data(:repository_wiki_source_references, fixture) do
    [
      %{
        "source" => term(fixture.source),
        "sourceKind" => term("https://jido.run/ontology/concept/RepositoryFile"),
        "sourceAuthority" => term("exact_git_snapshot"),
        "sourceLocator" => term("README.md"),
        "sourceDigest" => term(Contract.digest("README")),
        "freshness" => term("https://jido.run/ontology/concept/WikiFresh")
      }
    ]
  end

  defp data(_name, _fixture), do: []

  defp enrollment_rows(_fixture, visibility, edition) do
    [
      %{
        "enrollment" => term(resource(:repository_wiki_enrollment, "enrollment")),
        "revision" => term(3),
        "state" => term("https://jido.run/ontology/concept/WikiAutomatic"),
        "generation" => term("https://jido.run/ontology/concept/WikiDeterministicOnly"),
        "preview" => term("https://jido.run/ontology/concept/WikiPreviewDisabled"),
        "readVisibility" => term(visibility),
        "accountingRetention" => term("wiki_accounting"),
        "auditRetention" => term("wiki_audit"),
        "cancellationGeneration" => term(2),
        "currentEdition" => if(edition, do: term(edition), else: nil),
        "recorded" => term("2026-08-27T12:00:00Z")
      }
    ]
  end

  defp page_row(page, kind, slug, title, order, audience) do
    %{
      "page" => term(page),
      "kind" => term("https://jido.run/ontology/concept/Wiki#{Macro.camelize(kind)}"),
      "stableKey" => term(slug),
      "slug" => term(slug),
      "title" => term(title),
      "pageOrder" => term(order),
      "audience" => term(audience),
      "parentSlug" => if(slug == "overview", do: nil, else: term("overview")),
      "contentDigest" => term(Contract.digest(slug)),
      "freshness" => term("https://jido.run/ontology/concept/WikiFresh"),
      "completeness" => term("https://jido.run/ontology/concept/Complete")
    }
  end

  defp result(name, data, revision \\ 73) do
    %QueryResult{
      query_name: name,
      query_version: "2.10.0",
      dataset_revision: revision,
      graph_revisions: %{},
      ontology_version: "1.5.0",
      completeness: %{complete?: true},
      freshness: %{state: :current},
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: :snapshot,
      evaluated_at: ~U[2026-08-27 12:00:00Z],
      data: data
    }
  end

  defp term(value), do: %{type: :literal, value: value}

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

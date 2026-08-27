defmodule JidoCode.Knowledge.RepositoryWiki.Compiler do
  @moduledoc "Deterministic zero-model compiler for repository wiki pages and extensions."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.DependencyPages
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.SemanticContract
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @page_specs [
    {:project_overview, "overview", "Overview"},
    {:reference, "repository-inventory", "Repository Inventory"},
    {:adr_index, "architecture-index", "Architecture Index"},
    {:source_area, "source-map", "Source Map"},
    {:guide_index, "documentation-index", "Documentation Index"},
    {:about_this_wiki, "provenance", "Provenance"},
    {:known_gap, "known-gaps", "Known Gaps"}
  ]

  @spec compile(map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def compile(inventory, attributes) when is_map(inventory) and is_map(attributes) do
    with true <- inventory[:profile] == "wiki-source-inventory/1.0.0",
         true <- Contract.digest?(inventory[:digest]),
         true <- inventory[:model_calls] == 0 and inventory[:model_tokens] == 0,
         true <- inventory[:repository_iri] == attributes[:repository_iri],
         :ok <- Contract.resource(attributes[:tenant_iri]),
         %DateTime{} = created_at <- attributes[:created_at],
         true <- created_at == DateTime.truncate(created_at, :microsecond),
         edition_root <- edition_root(inventory, attributes),
         {:ok, edition_iri} <-
           ResourceIdentity.wiki_edition(inventory.repository_iri, edition_root),
         {:ok, wiki_iri} <- ResourceIdentity.repository_wiki(inventory.repository_iri),
         {:ok, attempt_iri} <-
           ResourceIdentity.deterministic(:wiki_compilation_attempt, edition_iri),
         {:ok, sources} <- sources(inventory, attributes, edition_iri),
         pages <- pages(inventory, attributes, edition_iri, sources),
         :ok <- validate_pages(pages),
         {:ok, usage} <- zero_usage(inventory, attributes, edition_iri, attempt_iri),
         gaps <- gaps(inventory, attributes, edition_iri),
         statements <-
           Enum.flat_map(sources, &source_statements/1) ++
             Enum.flat_map(pages, &page_statements/1) ++
             Enum.flat_map(gaps, &gap_statements/1) ++ usage.statements do
      manifest = %{
        protocol: "1.0.0",
        repository_iri: inventory.repository_iri,
        tenant_iri: attributes.tenant_iri,
        wiki_iri: wiki_iri,
        edition_iri: edition_iri,
        edition_root: edition_root,
        source_snapshot_iri: inventory.source_snapshot_iri,
        source_fence: inventory.source_fence,
        input_manifest_digest: inventory.digest,
        compiler_profile: Protocol.compiler_profile(),
        compiler_digest: Protocol.compiler_digest(),
        purpose: Map.get(attributes, :purpose, :current),
        predecessor_edition_iri: Map.get(attributes, :predecessor_edition_iri),
        expected_current_edition_iri: Map.get(attributes, :expected_current_edition_iri),
        attempt_iri: attempt_iri,
        pages: pages,
        sources: sources,
        gaps: gaps,
        usage: usage.record,
        statements: statements,
        page_count: length(pages),
        section_count: 0,
        citation_count: Enum.sum(Enum.map(pages, &length(&1.source_iris))),
        link_count: 0,
        gap_count: length(gaps),
        statement_count: length(statements),
        content_bytes: Enum.sum(Enum.map(inventory.entries, & &1.bytes)),
        created_at: created_at,
        generation_mode: :deterministic_only,
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        model_cached_tokens: 0,
        model_reasoning_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(manifest, :compilation_digest, Contract.digest(manifest))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_compile)
    end
  rescue
    _error -> invalid(:repository_wiki_compile)
  end

  def compile(_inventory, _attributes), do: invalid(:repository_wiki_compile)

  @spec compile_dependencies(map(), map(), map(), map(), map(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def compile_dependencies(compilation, reconciliation, catalog, metadata, link_sets, attributes),
    do:
      DependencyPages.compile(
        compilation,
        reconciliation,
        catalog,
        metadata,
        link_sets,
        attributes
      )

  defp edition_root(inventory, attributes) do
    Contract.digest(%{
      protocol: "1.0.0",
      repository: inventory.repository_iri,
      tenant: attributes[:tenant_iri],
      source_snapshot: inventory.source_snapshot_iri,
      source_fence: inventory.source_fence,
      inventory: inventory.digest,
      compiler_profile: Protocol.compiler_profile(),
      compiler_digest: Protocol.compiler_digest(),
      purpose: Map.get(attributes, :purpose, :current),
      predecessor: Map.get(attributes, :predecessor_edition_iri)
    })
  end

  defp sources(inventory, attributes, edition_iri) do
    manifest_entry = %{
      path: "inventory:#{inventory.digest}",
      kind: :artifact_manifest,
      media_type: "application/vnd.jido.wiki-inventory",
      bytes: 0,
      digest: inventory.digest,
      module_names: []
    }

    graph_entries =
      Enum.map(inventory.graph_sources, fn source ->
        %{
          path: "graph:#{source.resource_iri}",
          kind: :graph_source,
          media_type: "application/n-quads",
          bytes: 0,
          digest: source.digest,
          module_names: [],
          graph_iri: source.graph_iri,
          resource_iri: source.resource_iri,
          graph_family: source.family,
          graph_revision: source.revision
        }
      end)

    [manifest_entry | inventory.entries ++ graph_entries]
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, result} ->
      with {:ok, iri} <-
             ResourceIdentity.deterministic(
               :wiki_source,
               Enum.join([edition_iri, entry.path, entry.digest], "\n")
             ) do
        source = %{
          iri: iri,
          repository_iri: inventory.repository_iri,
          tenant_iri: attributes.tenant_iri,
          edition_iri: edition_iri,
          source_snapshot_iri: inventory.source_snapshot_iri,
          path: entry.path,
          source_kind: source_kind(entry.kind),
          authority: source_authority(entry.kind),
          digest: entry.digest,
          freshness: :fresh,
          source_graph_iri: Map.get(entry, :graph_iri),
          source_resource_iri: Map.get(entry, :resource_iri),
          graph_revision: Map.get(entry, :graph_revision)
        }

        {:cont, {:ok, [source | result]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp pages(inventory, attributes, edition_iri, sources) do
    manifest_source = hd(sources)

    Enum.with_index(@page_specs)
    |> Enum.map(fn {{kind, slug, title}, order} ->
      selected = select_sources(slug, sources, manifest_source)
      facts = page_facts(slug, inventory)
      {:ok, page_iri} = ResourceIdentity.wiki_page(edition_iri, kind, slug)

      %{
        iri: page_iri,
        repository_iri: inventory.repository_iri,
        tenant_iri: attributes.tenant_iri,
        edition_iri: edition_iri,
        kind: kind,
        stable_key: slug,
        title: title,
        slug: slug,
        order: order,
        facts: facts,
        content_digest: Contract.digest(facts),
        source_iris: Enum.map(selected, & &1.iri)
      }
    end)
  end

  defp page_facts("overview", inventory) do
    [
      %{label: "source files", value: Enum.count(inventory.entries, &(&1.kind == :source))},
      %{label: "test files", value: Enum.count(inventory.entries, &(&1.kind == :test))},
      %{label: "documentation files", value: documentation_count(inventory)},
      %{label: "known modules", value: length(inventory.module_names)}
    ]
  end

  defp page_facts("repository-inventory", inventory),
    do: Enum.map(inventory.entries, &Map.take(&1, [:path, :kind, :media_type, :bytes, :digest]))

  defp page_facts("architecture-index", inventory),
    do: paths_by_kind(inventory, [:architecture_document, :plan_document, :research_document])

  defp page_facts("source-map", inventory),
    do: [modules: inventory.module_names, paths: paths_by_kind(inventory, [:source, :test])]

  defp page_facts("documentation-index", inventory),
    do:
      paths_by_kind(inventory, [
        :readme,
        :documentation,
        :architecture_document,
        :plan_document,
        :research_document,
        :guide
      ])

  defp page_facts("provenance", inventory),
    do: [
      inventory_profile: inventory.profile,
      inventory_digest: inventory.digest,
      source_snapshot: inventory.source_snapshot_iri,
      source_fence: inventory.source_fence,
      compiler_profile: Protocol.compiler_profile(),
      compiler_digest: Protocol.compiler_digest(),
      accepted_graph_sources: inventory.graph_sources,
      model_calls: 0,
      model_tokens: 0
    ]

  defp page_facts("known-gaps", inventory), do: inventory.gaps

  defp select_sources("repository-inventory", sources, _manifest), do: sources

  defp select_sources("architecture-index", sources, manifest),
    do:
      matching_sources(
        sources,
        [:architecture_document, :plan_document, :research_document],
        manifest
      )

  defp select_sources("source-map", sources, manifest),
    do: matching_sources(sources, [:source, :test], manifest)

  defp select_sources("documentation-index", sources, manifest),
    do:
      matching_sources(
        sources,
        [
          :readme,
          :documentation,
          :architecture_document,
          :plan_document,
          :research_document,
          :guide
        ],
        manifest
      )

  defp select_sources("provenance", sources, manifest) do
    [manifest | Enum.filter(sources, &(!is_nil(&1.source_graph_iri)))]
    |> Enum.uniq_by(& &1.iri)
  end

  defp select_sources(_slug, sources, manifest) do
    readme_or_manifest = Enum.filter(sources, &(&1.path == "README.md" or &1.iri == manifest.iri))
    if readme_or_manifest == [], do: [manifest], else: readme_or_manifest
  end

  defp matching_sources(sources, kinds, manifest) do
    selected = Enum.filter(sources, &(source_entry_kind(&1.path) in kinds))
    if selected == [], do: [manifest], else: [manifest | selected] |> Enum.uniq_by(& &1.iri)
  end

  defp source_entry_kind(path) do
    cond do
      path == "README.md" ->
        :readme

      String.starts_with?(path, "lib/") ->
        :source

      String.starts_with?(path, "test/") ->
        :test

      String.contains?(path, "/architecture/") or String.contains?(path, "/adr/") ->
        :architecture_document

      String.contains?(path, "/planning/") ->
        :plan_document

      String.contains?(path, "/research/") ->
        :research_document

      String.starts_with?(path, "guides/") ->
        :guide

      String.starts_with?(path, "docs/") ->
        :documentation

      true ->
        :artifact_manifest
    end
  end

  defp gaps(inventory, attributes, edition_iri) do
    Enum.with_index(inventory.gaps)
    |> Enum.map(fn {gap, index} ->
      {:ok, iri} =
        ResourceIdentity.deterministic(
          :wiki_gap,
          Enum.join(
            [edition_iri, Integer.to_string(index), gap.path, Atom.to_string(gap.reason)],
            "\n"
          )
        )

      %{
        iri: iri,
        repository_iri: inventory.repository_iri,
        tenant_iri: attributes.tenant_iri,
        edition_iri: edition_iri,
        source_snapshot_iri: inventory.source_snapshot_iri,
        kind: gap_kind(gap.reason),
        path: gap.path,
        omission_code: Atom.to_string(gap.reason)
      }
    end)
  end

  defp zero_usage(inventory, attributes, edition_iri, attempt_iri) do
    with {:ok, usage_iri} <-
           ResourceIdentity.deterministic(
             :wiki_usage_record,
             edition_iri <> "\ndeterministic-zero"
           ) do
      record = %{
        usage_iri: usage_iri,
        repository_iri: inventory.repository_iri,
        tenant_iri: attributes.tenant_iri,
        attempt_iri: attempt_iri,
        edition_iri: edition_iri,
        reservation_iri: nil,
        generation_mode: :deterministic_only,
        accounting_state: :success,
        input_tokens: 0,
        output_tokens: 0,
        cached_tokens: 0,
        reasoning_tokens: 0,
        cost_microunits: 0,
        currency: "XXX",
        recorded_at: attributes.created_at
      }

      :ok = SemanticContract.validate(:usage_record, record)

      statements = [
        {usage_iri, @rdf_type, RDF.iri(@jf <> "WikiUsageRecord")},
        {usage_iri, @jf <> "repositoryScope", RDF.iri(inventory.repository_iri)},
        {usage_iri, @jf <> "tenantScope", RDF.iri(attributes.tenant_iri)},
        {usage_iri, @jf <> "wikiEdition", RDF.iri(edition_iri)},
        {usage_iri, @jf <> "wikiCompilationAttempt", RDF.iri(attempt_iri)},
        {usage_iri, @jf <> "accountingState", RDF.iri(Contract.concept(:wiki_success))},
        {usage_iri, @jf <> "modelInputTokens", RDF.XSD.NonNegativeInteger.new(0)},
        {usage_iri, @jf <> "modelOutputTokens", RDF.XSD.NonNegativeInteger.new(0)},
        {usage_iri, @jf <> "modelCachedTokens", RDF.XSD.NonNegativeInteger.new(0)},
        {usage_iri, @jf <> "modelReasoningTokens", RDF.XSD.NonNegativeInteger.new(0)},
        {usage_iri, @jf <> "usageCurrency", RDF.XSD.String.new("XXX")},
        {usage_iri, @jf <> "usageCost", RDF.XSD.Decimal.new(0)},
        {usage_iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(attributes.created_at)}
      ]

      {:ok, %{record: record, statements: statements}}
    end
  end

  defp source_statements(source) do
    [
      {source.iri, @rdf_type, RDF.iri(@jf <> "WikiSource")},
      {source.iri, @jf <> "repositoryScope", RDF.iri(source.repository_iri)},
      {source.iri, @jf <> "tenantScope", RDF.iri(source.tenant_iri)},
      {source.iri, @jf <> "wikiEdition", RDF.iri(source.edition_iri)},
      {source.iri, @jf <> "sourceKind", RDF.iri(Contract.concept(source.source_kind))},
      {source.iri, @jf <> "sourceSnapshot", RDF.iri(source.source_snapshot_iri)},
      {source.iri, @jf <> "sourceLocator", RDF.XSD.String.new(source.path)},
      {source.iri, @jf <> "sourceAuthority", RDF.XSD.String.new(source.authority)},
      {source.iri, @jf <> "sourceContentDigest", RDF.XSD.String.new(source.digest)},
      {source.iri, @jf <> "sourceConfidence", RDF.XSD.Decimal.new(1)},
      {source.iri, @jf <> "freshnessState", RDF.iri(Contract.concept(:wiki_fresh))}
    ] ++
      optional_iri(source.iri, @jf <> "sourceGraph", source.source_graph_iri) ++
      optional_iri(source.iri, @jf <> "sourceResource", source.source_resource_iri)
  end

  defp page_statements(page) do
    [
      {page.iri, @rdf_type, RDF.iri(@jf <> "WikiPage")},
      {page.iri, @jf <> "repositoryScope", RDF.iri(page.repository_iri)},
      {page.iri, @jf <> "tenantScope", RDF.iri(page.tenant_iri)},
      {page.iri, @jf <> "wikiEdition", RDF.iri(page.edition_iri)},
      {page.iri, @jf <> "pageKind", RDF.iri(Contract.concept(wiki_page_kind(page.kind)))},
      {page.iri, @jf <> "stableKey", RDF.XSD.String.new(page.stable_key)},
      {page.iri, @jf <> "title", RDF.XSD.String.new(page.title)},
      {page.iri, @jf <> "slug", RDF.XSD.String.new(page.slug)},
      {page.iri, @jf <> "pageOrder", RDF.XSD.NonNegativeInteger.new(page.order)},
      {page.iri, @jf <> "contentDigest", RDF.XSD.String.new(page.content_digest)},
      {page.iri, @jf <> "freshnessState", RDF.iri(Contract.concept(:wiki_fresh))},
      {page.iri, @jf <> "completenessState", RDF.iri(Contract.concept(:complete))}
      | Enum.map(page.source_iris, &{page.iri, @jf <> "wikiSource", RDF.iri(&1)})
    ]
  end

  defp gap_statements(gap) do
    [
      {gap.iri, @rdf_type, RDF.iri(@jf <> "WikiGap")},
      {gap.iri, @jf <> "repositoryScope", RDF.iri(gap.repository_iri)},
      {gap.iri, @jf <> "tenantScope", RDF.iri(gap.tenant_iri)},
      {gap.iri, @jf <> "wikiEdition", RDF.iri(gap.edition_iri)},
      {gap.iri, @jf <> "sourceSnapshot", RDF.iri(gap.source_snapshot_iri)},
      {gap.iri, @jf <> "gapKind", RDF.iri(Contract.concept(wiki_gap_kind(gap.kind)))},
      {gap.iri, @jf <> "sourceLocator", RDF.XSD.String.new(gap.path)},
      {gap.iri, @jf <> "omissionCode", RDF.XSD.String.new(gap.omission_code)}
    ]
  end

  defp source_kind(:artifact_manifest), do: :artifact_manifest
  defp source_kind(:graph_source), do: :source_graph
  defp source_kind(_kind), do: :repository_file
  defp source_authority(:artifact_manifest), do: "deterministic_inventory"
  defp source_authority(_kind), do: "exact_git_snapshot"

  defp gap_kind(reason) when reason in [:missing], do: :absent

  defp gap_kind(reason) when reason in [:unsupported, :binary, :symlinked, :ignored],
    do: :unsupported

  defp gap_kind(:oversized), do: :truncated
  defp gap_kind(:changed_during_read), do: :changed_during_read
  defp gap_kind(_reason), do: :unavailable

  defp wiki_page_kind(kind), do: :"wiki_#{kind}"
  defp wiki_gap_kind(kind), do: :"wiki_#{kind}"

  defp documentation_count(inventory) do
    Enum.count(inventory.entries, fn entry ->
      entry.kind in [
        :readme,
        :documentation,
        :architecture_document,
        :plan_document,
        :research_document,
        :guide
      ]
    end)
  end

  defp paths_by_kind(inventory, kinds) do
    inventory.entries
    |> Enum.filter(&(&1.kind in kinds))
    |> Enum.map(& &1.path)
  end

  defp validate_pages(pages) do
    Enum.reduce_while(pages, :ok, fn page, :ok ->
      result =
        SemanticContract.validate(:page, %{
          page_iri: page.iri,
          repository_iri: page.repository_iri,
          tenant_iri: page.tenant_iri,
          edition_iri: page.edition_iri,
          kind: page.kind,
          stable_key: page.stable_key,
          title: page.title,
          slug: page.slug,
          content_digest: page.content_digest,
          source_iris: page.source_iris
        })

      case result do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, iri), do: [{subject, predicate, RDF.iri(iri)}]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

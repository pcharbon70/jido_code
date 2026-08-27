defmodule JidoCode.Knowledge.RepositoryWiki.DependencyPages do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.SemanticContract
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @profile "wiki-dependency-pages/1.0.0"
  @summary_specs [
    {:project_overview, "project", "Project"},
    {:runtime, "runtime-requirements", "Runtime Requirements"},
    {:dependency_overview, "dependency-overview", "Dependency Overview"},
    {:dependency_overview, "direct-dependencies", "Direct Dependencies"},
    {:dependency_overview, "transitive-dependencies", "Transitive Dependencies"},
    {:dependency_gap, "dependency-gaps", "Dependency Gaps"},
    {:dependency_overview, "dependency-metadata-freshness", "Dependency Metadata Freshness"}
  ]
  @maximums %{nodes: 2_048, edges: 16_384, pages: 2_055, metadata: 2_048}

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      base_compiler_profile: Protocol.compiler_profile(),
      base_compiler_digest: Protocol.compiler_digest(),
      limits: @maximums,
      ordering: :stable_key,
      rendering: :facts_only,
      model_calls: 0
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec compile(map(), map(), map(), map(), map(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def compile(compilation, reconciliation, catalog, metadata, link_sets, attributes)
      when is_map(compilation) and is_map(reconciliation) and is_map(catalog) and
             is_map(metadata) and is_map(link_sets) and is_map(attributes) do
    with :ok <- validate(compilation, reconciliation, catalog, metadata, link_sets, attributes),
         {:ok, sources} <- dependency_sources(compilation, reconciliation, catalog, metadata),
         {:ok, pages} <-
           dependency_pages(compilation, reconciliation, catalog, metadata, link_sets, sources),
         :ok <- validate_pages(pages),
         true <- length(pages) <= @maximums.pages do
      all_pages = compilation.pages ++ pages
      all_sources = compilation.sources ++ sources

      additions =
        Enum.flat_map(sources, &source_statements/1) ++ Enum.flat_map(pages, &page_statements/1)

      extension = %{
        profile: @profile,
        profile_digest: profile().digest,
        reconciliation_digest: reconciliation.digest,
        catalog_digest: catalog.digest,
        source_profile_digest: catalog[:source_profile_digest],
        metadata_digests:
          metadata |> Enum.map(fn {name, value} -> {name, value.digest} end) |> Enum.sort(),
        metadata_fixture_digests:
          metadata
          |> Enum.map(fn {name, value} -> {name, value[:fixture_digest]} end)
          |> Enum.reject(fn {_name, digest} -> is_nil(digest) end)
          |> Enum.sort(),
        link_digests:
          link_sets |> Enum.map(fn {name, value} -> {name, value.digest} end) |> Enum.sort(),
        parser_profile: reconciliation.parser_profile,
        parser_profile_digest: reconciliation.parser_profile_digest,
        lock_profile: reconciliation.lock_profile,
        lock_profile_digest: reconciliation.lock_profile_digest,
        sandbox_profile: reconciliation.sandbox_profile,
        sandbox_profile_digest: reconciliation.sandbox_profile_digest,
        resolver_profile: catalog.profile,
        resolver_profile_digest: catalog.profile_digest,
        source_profile: catalog[:source_profile],
        source_fence: catalog.source_fence,
        toolchain_digest: reconciliation.toolchain_digest,
        policy_revision: reconciliation.policy_revision,
        compiler_profile: Protocol.compiler_profile(),
        compiler_digest: Protocol.compiler_digest(),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      result = %{
        compilation
        | pages: all_pages,
          sources: all_sources,
          statements: compilation.statements ++ additions,
          page_count: length(all_pages),
          citation_count:
            compilation.citation_count + Enum.sum(Enum.map(pages, &length(&1.source_iris))),
          link_count:
            compilation.link_count +
              Enum.sum(Enum.map(link_sets, fn {_name, set} -> length(set.links) end)),
          statement_count: compilation.statement_count + length(additions)
      }

      result =
        result
        |> Map.put(:dependency_extension, extension)
        |> Map.put(:dependency_page_count, length(pages))
        |> Map.put(:dependency_node_count, catalog.node_count)
        |> Map.put(:dependency_edge_count, catalog.edge_count)
        |> Map.put(:dependency_gap_count, length(catalog.gaps))
        |> Map.put(:dependency_completeness, catalog.completeness)

      {:ok,
       Map.put(
         result,
         :compilation_digest,
         Contract.digest(Map.delete(result, :compilation_digest))
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def compile(_compilation, _reconciliation, _catalog, _metadata, _link_sets, _attributes),
    do: invalid()

  defp validate(compilation, reconciliation, catalog, metadata, link_sets, attributes) do
    nodes = catalog[:nodes] || []
    node_names = MapSet.new(Enum.map(nodes, & &1.name))

    cond do
      not Contract.digest?(compilation[:compilation_digest]) or
          Contract.digest(Map.delete(compilation, :compilation_digest)) !=
            compilation.compilation_digest ->
        invalid()

      reconciliation[:profile] != "mix-reconcile/1.0.0" or
          not exact_digest?(reconciliation, :digest) ->
        invalid()

      catalog[:profile] != "wiki-dependency-resolver/1.0.0" or not exact_digest?(catalog, :digest) ->
        invalid()

      catalog[:repository_iri] != compilation[:repository_iri] or
        catalog[:tenant_iri] != compilation[:tenant_iri] or
        catalog[:edition_iri] != compilation[:edition_iri] or
        catalog[:source_fence] != compilation[:source_fence] or
          reconciliation[:source_fence] != compilation[:source_fence] ->
        conflict()

      attributes[:repository_iri] != compilation[:repository_iri] or
        attributes[:tenant_iri] != compilation[:tenant_iri] or
          attributes[:edition_iri] != compilation[:edition_iri] ->
        conflict()

      length(nodes) > @maximums.nodes or length(catalog[:edges] || []) > @maximums.edges or
        map_size(metadata) > @maximums.metadata or map_size(link_sets) > @maximums.metadata ->
        invalid()

      not MapSet.subset?(MapSet.new(Map.keys(metadata)), node_names) or
          not MapSet.subset?(MapSet.new(Map.keys(link_sets)), node_names) ->
        invalid()

      not Enum.all?(metadata, fn {name, value} -> valid_metadata?(name, value, nodes) end) ->
        invalid()

      not Enum.all?(link_sets, fn {name, value} -> valid_link_set?(name, value, nodes) end) ->
        invalid()

      true ->
        :ok
    end
  end

  defp exact_digest?(value, key) do
    digest = value[key]
    Contract.digest?(digest) and Contract.digest(Map.delete(value, key)) == digest
  end

  defp valid_metadata?(name, value, nodes) do
    node = Enum.find(nodes, &(&1.name == name))

    is_map(value) and value[:profile] == "hex-req/1.0.0" and exact_digest?(value, :digest) and
      value[:version] == node[:selected_version] and value[:authority] == :observed
  end

  defp valid_link_set?(name, value, nodes) do
    node = Enum.find(nodes, &(&1.name == name))

    is_map(value) and value[:profile] == "wiki-dependency-links/1.0.0" and
      exact_digest?(value, :digest) and value[:dependency_iri] == node.iri
  end

  defp dependency_sources(compilation, reconciliation, catalog, metadata) do
    specifications = [
      {"mix-reconciliation", :artifact_manifest, :declared_locked_observed,
       reconciliation.digest},
      {"dependency-catalog", :artifact_manifest, :deterministic_resolver, catalog.digest}
      | Enum.map(metadata, fn {name, value} ->
          {"hex-metadata:#{name}", :external_observation, :observed_remote, value.digest}
        end)
    ]

    specifications
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce_while({:ok, []}, fn {locator, kind, authority, digest}, {:ok, result} ->
      case ResourceIdentity.deterministic(
             :wiki_source,
             Enum.join([compilation.edition_iri, locator, digest], "\n")
           ) do
        {:ok, iri} ->
          source = %{
            iri: iri,
            repository_iri: compilation.repository_iri,
            tenant_iri: compilation.tenant_iri,
            edition_iri: compilation.edition_iri,
            source_snapshot_iri: compilation.source_snapshot_iri,
            path: locator,
            source_kind: kind,
            authority: authority,
            digest: digest,
            freshness: :fresh,
            source_graph_iri: nil,
            source_resource_iri: nil,
            graph_revision: nil
          }

          {:cont, {:ok, [source | result]}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp dependency_pages(compilation, reconciliation, catalog, metadata, link_sets, sources) do
    source_index = Map.new(sources, &{&1.path, &1.iri})
    base_order = length(compilation.pages)

    summary_pages =
      @summary_specs
      |> Enum.with_index()
      |> Enum.map(fn {{kind, slug, title}, index} ->
        page(
          compilation,
          kind,
          slug,
          title,
          base_order + index,
          summary_facts(slug, reconciliation, catalog, metadata),
          summary_sources(slug, source_index),
          if(slug == "dependency-gaps" and catalog.gaps != [], do: :incomplete, else: :complete)
        )
      end)

    detail_pages =
      catalog.nodes
      |> Enum.sort_by(& &1.name)
      |> Enum.with_index()
      |> Enum.map(fn {node, index} ->
        metadata_value = metadata[node.name]
        links = link_sets[node.name]
        source_iris = detail_sources(node.name, source_index, metadata_value)

        page(
          compilation,
          :dependency,
          "dependency-" <> node.name,
          node.name,
          base_order + length(@summary_specs) + index,
          detail_facts(node, catalog.edges, metadata_value, links),
          source_iris,
          if(node.classification in [:resolved, :locked_only, :orphaned_lock],
            do: :complete,
            else: :incomplete
          )
        )
      end)

    {:ok, summary_pages ++ detail_pages}
  end

  defp page(compilation, kind, slug, title, order, facts, sources, completeness) do
    {:ok, iri} = ResourceIdentity.wiki_page(compilation.edition_iri, kind, slug)

    %{
      iri: iri,
      repository_iri: compilation.repository_iri,
      tenant_iri: compilation.tenant_iri,
      edition_iri: compilation.edition_iri,
      kind: kind,
      stable_key: slug,
      title: title,
      slug: slug,
      anchor: slug,
      order: order,
      facts: facts,
      content_digest: Contract.digest(facts),
      source_iris: Enum.sort(Enum.uniq(sources)),
      completeness: completeness,
      compiler_profile: @profile
    }
  end

  defp summary_facts("project", reconciliation, _catalog, _metadata) do
    %{
      fields: reconciliation.fields,
      source_digest: reconciliation.source_digest,
      lock_digest: reconciliation.lock_digest,
      reconciliation_digest: reconciliation.digest,
      completeness: reconciliation.completeness,
      gaps: reconciliation.gaps
    }
  end

  defp summary_facts("runtime-requirements", reconciliation, catalog, _metadata) do
    %{
      runtime_fields:
        Enum.filter(reconciliation.fields, fn field ->
          field.name in ["elixir", "application.mod", "application.extra_applications"]
        end),
      managers: catalog.nodes |> Enum.flat_map(& &1.managers) |> Enum.uniq() |> Enum.sort(),
      runtime_dependencies:
        catalog.nodes
        |> Enum.filter(&(&1.runtime != false))
        |> Enum.map(& &1.name)
        |> Enum.sort()
    }
  end

  defp summary_facts("dependency-overview", _reconciliation, catalog, _metadata) do
    %{
      node_count: catalog.node_count,
      edge_count: catalog.edge_count,
      root_count: length(catalog.roots),
      cycle_count: length(catalog.cycles),
      maximum_depth: catalog.maximum_depth,
      classifications: frequencies(catalog.nodes, :classification),
      completeness: catalog.completeness,
      catalog_digest: catalog.digest
    }
  end

  defp summary_facts("direct-dependencies", _reconciliation, catalog, _metadata),
    do: catalog.nodes |> Enum.filter(&(:direct in &1.roles)) |> Enum.map(&summary_node/1)

  defp summary_facts("transitive-dependencies", _reconciliation, catalog, _metadata),
    do: catalog.nodes |> Enum.filter(&(:transitive in &1.roles)) |> Enum.map(&summary_node/1)

  defp summary_facts("dependency-gaps", _reconciliation, catalog, _metadata),
    do: %{gaps: catalog.gaps, completeness: catalog.completeness}

  defp summary_facts("dependency-metadata-freshness", _reconciliation, catalog, metadata) do
    values =
      catalog.nodes
      |> Enum.map(fn node ->
        case metadata[node.name] do
          nil ->
            %{dependency: node.name, state: :not_requested, authority: :none}

          value ->
            %{
              dependency: node.name,
              state: value.state,
              authority: value.authority,
              retrieved_at: value.retrieved_at,
              cache_state: value.cache_state,
              metadata_digest: value.digest,
              fixture_digest: value.fixture_digest
            }
        end
      end)

    %{dependencies: values, metadata_count: map_size(metadata)}
  end

  defp detail_facts(node, edges, metadata, links) do
    outgoing =
      edges |> Enum.filter(&(&1.parent == node.name)) |> Enum.sort_by(&{&1.child, &1.requirement})

    incoming =
      edges |> Enum.filter(&(&1.child == node.name)) |> Enum.sort_by(&{&1.parent, &1.requirement})

    %{
      anchor: "dependency-" <> node.name,
      general: %{
        name: node.name,
        classification: node.classification,
        roles: node.roles,
        scm: node.scm,
        requirement: node.requirement,
        selected_version: node.selected_version,
        selected_revision: node.selected_revision,
        managers: node.managers,
        summary: metadata_fact(metadata, :summary),
        licenses: metadata_fact(metadata, :licenses) || [],
        maintainers: metadata_fact(metadata, :maintainers) || [],
        retirement: metadata_fact(metadata, :retirement),
        release_date: metadata_fact(metadata, :release_date)
      },
      declared: node.declaration,
      locked: node.lock,
      observed: node.observation,
      incoming: incoming,
      outgoing: outgoing,
      canonical_path: node.canonical_path,
      root_paths: node.root_paths,
      depth: node.depth,
      cycle: node.cycle,
      scopes: %{
        environments: node.environments,
        targets: node.targets,
        optional: node.optional,
        override: node.override,
        runtime: node.runtime,
        source_options: node.source_options,
        lock_options: node.lock_options
      },
      source: node[:source],
      provenance: node.provenance,
      metadata: metadata_summary(metadata),
      links: if(links, do: links.links, else: [])
    }
  end

  defp metadata_fact(nil, _key), do: nil
  defp metadata_fact(metadata, key), do: metadata.facts[key]

  defp metadata_summary(nil), do: %{state: :not_requested, authority: :none}

  defp metadata_summary(metadata) do
    %{
      state: metadata.state,
      authority: metadata.authority,
      source_kind: metadata.source_kind,
      retrieved_at: metadata.retrieved_at,
      cache_state: metadata.cache_state,
      digest: metadata.digest,
      fixture_digest: metadata.fixture_digest,
      limitations: metadata.limitations,
      diagnostics: metadata.diagnostics
    }
  end

  defp summary_node(node) do
    Map.take(node, [
      :iri,
      :name,
      :classification,
      :roles,
      :scm,
      :requirement,
      :selected_version,
      :selected_revision,
      :managers,
      :environments,
      :targets,
      :optional,
      :override,
      :runtime,
      :depth,
      :cycle
    ])
  end

  defp frequencies(values, key) do
    values
    |> Enum.frequencies_by(& &1[key])
    |> Enum.sort_by(fn {name, _count} -> to_string(name) end)
  end

  defp summary_sources(slug, source_index) do
    reconciliation = source_index["mix-reconciliation"]
    catalog = source_index["dependency-catalog"]

    cond do
      slug == "project" or slug == "runtime-requirements" ->
        [reconciliation]

      slug == "dependency-metadata-freshness" ->
        metadata_sources =
          source_index
          |> Enum.filter(fn {name, _iri} -> String.starts_with?(name, "hex-metadata:") end)
          |> Enum.map(&elem(&1, 1))

        [reconciliation, catalog | metadata_sources]

      true ->
        [reconciliation, catalog]
    end
  end

  defp detail_sources(name, source_index, metadata) do
    values = [source_index["mix-reconciliation"], source_index["dependency-catalog"]]
    values = if metadata, do: [source_index["hex-metadata:#{name}"] | values], else: values
    Enum.reject(values, &is_nil/1)
  end

  defp validate_pages(pages) do
    unique =
      length(pages) == length(Enum.uniq_by(pages, & &1.iri)) and
        length(pages) == length(Enum.uniq_by(pages, & &1.slug))

    if unique do
      Enum.reduce_while(pages, :ok, fn page, :ok ->
        attributes = %{
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
        }

        case SemanticContract.validate(:page, attributes) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end)
    else
      invalid()
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
      {source.iri, @jf <> "sourceAuthority", RDF.XSD.String.new(to_string(source.authority))},
      {source.iri, @jf <> "sourceContentDigest", RDF.XSD.String.new(source.digest)},
      {source.iri, @jf <> "sourceConfidence", RDF.XSD.Decimal.new(1)},
      {source.iri, @jf <> "freshnessState", RDF.iri(Contract.concept(:wiki_fresh))}
    ]
  end

  defp page_statements(page) do
    [
      {page.iri, @rdf_type, RDF.iri(@jf <> "WikiPage")},
      {page.iri, @jf <> "repositoryScope", RDF.iri(page.repository_iri)},
      {page.iri, @jf <> "tenantScope", RDF.iri(page.tenant_iri)},
      {page.iri, @jf <> "wikiEdition", RDF.iri(page.edition_iri)},
      {page.iri, @jf <> "pageKind", RDF.iri(Contract.concept(:"wiki_#{page.kind}"))},
      {page.iri, @jf <> "stableKey", RDF.XSD.String.new(page.stable_key)},
      {page.iri, @jf <> "title", RDF.XSD.String.new(page.title)},
      {page.iri, @jf <> "slug", RDF.XSD.String.new(page.slug)},
      {page.iri, @jf <> "pageOrder", RDF.XSD.NonNegativeInteger.new(page.order)},
      {page.iri, @jf <> "contentDigest", RDF.XSD.String.new(page.content_digest)},
      {page.iri, @jf <> "freshnessState", RDF.iri(Contract.concept(:wiki_fresh))},
      {page.iri, @jf <> "completenessState",
       RDF.iri(
         Contract.concept(if(page.completeness == :complete, do: :complete, else: :incomplete))
       )}
      | Enum.map(page.source_iris, &{page.iri, @jf <> "wikiSource", RDF.iri(&1)})
    ]
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_dependency_pages)}
  defp conflict, do: {:error, Error.new(:conflict, :repository_wiki_dependency_pages)}
end

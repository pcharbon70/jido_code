defmodule JidoCode.Knowledge.RepositoryWiki.FullCompiler do
  @moduledoc """
  Deterministic final assembly of repository, dependency, guide, and accepted-document pages.

  The compiler consumes only content-addressed stage outputs. It adds no model
  capability and emits a complete navigation/page graph extension whose
  digests can be replayed from the same admitted inputs.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GuideDiscovery
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.SemanticContract
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @profile "wiki-full-edition/1.0.0"
  @maximums %{guides: 512, accepted_documents: 256, pages: 3_072, links: 32_768, gaps: 4_096}
  @collection_specs [
    %{slug: "overview", title: "Overview", kind: :project_overview, audience: :user},
    %{slug: "getting-started", title: "Getting Started", kind: :guide_index, audience: :user},
    %{slug: "user-guides", title: "User Guides", kind: :guide_index, audience: :user},
    %{
      slug: "developer-guides",
      title: "Developer Guides",
      kind: :guide_index,
      audience: :developer
    },
    %{
      slug: "architecture-index",
      title: "Architecture",
      kind: :adr_index,
      audience: :architecture
    },
    %{slug: "source-map", title: "Source Map", kind: :source_area, audience: :developer},
    %{slug: "project", title: "Project", kind: :project_overview, audience: :developer},
    %{
      slug: "dependency-overview",
      title: "Dependencies",
      kind: :dependency_overview,
      audience: :developer
    },
    %{slug: "operations", title: "Operations", kind: :operations, audience: :operator},
    %{
      slug: "provenance",
      title: "Provenance",
      kind: :about_this_wiki,
      audience: :reference
    },
    %{slug: "freshness", title: "Freshness", kind: :reference, audience: :reference},
    %{slug: "known-gaps", title: "Known Gaps", kind: :known_gap, audience: :reference}
  ]
  @accepted_kinds ~w[architecture_overview adr research_note reference operations security]a

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      compiler_profile: Protocol.compiler_profile(),
      compiler_digest: Protocol.compiler_digest(),
      guide_profile: GuideDiscovery.profile().digest,
      renderer_profile: GuideRenderer.profile().digest,
      collections: Enum.map(@collection_specs, & &1.slug),
      limits: @maximums,
      ordering: :collection_then_stable_slug,
      generation_mode: :deterministic_only,
      model_calls: 0
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec compile(map(), map(), [map()], [map()], map()) ::
          {:ok, map()} | {:error, Error.t()}
  def compile(compilation, guide_manifest, rendered_guides, accepted_documents, attributes)
      when is_map(compilation) and is_map(guide_manifest) and is_list(rendered_guides) and
             is_list(accepted_documents) and is_map(attributes) do
    with :ok <-
           validate(
             compilation,
             guide_manifest,
             rendered_guides,
             accepted_documents,
             attributes
           ),
         {:ok, guide_sources} <- guide_sources(compilation, guide_manifest.guides),
         {:ok, document_sources} <- document_sources(compilation, accepted_documents),
         source_index <- Map.new(guide_sources, &{&1.source_path, &1.iri}),
         document_source_index <- Map.new(document_sources, &{&1.document_iri, &1.iri}),
         {:ok, guide_pages} <-
           guide_pages(compilation, guide_manifest, rendered_guides, source_index),
         {:ok, document_pages} <-
           document_pages(compilation, accepted_documents, document_source_index),
         base_pages <- Enum.map(compilation.pages, &normalize_base_page/1),
         {:ok, pages, navigation} <-
           assemble_pages(compilation, base_pages, guide_pages, document_pages),
         true <- length(pages) <= @maximums.pages,
         true <- Enum.sum(Enum.map(pages, &length(&1.links))) <= @maximums.links,
         gaps <- full_gaps(compilation, guide_manifest, rendered_guides, pages),
         true <- length(gaps) <= @maximums.gaps,
         added_sources <-
           unique_added_sources(compilation.sources, guide_sources ++ document_sources),
         sources <- compilation.sources ++ added_sources,
         coverage <- source_coverage(sources, pages),
         digests <- digests(pages, navigation, coverage, rendered_guides, gaps),
         statements <-
           statements(
             compilation,
             added_sources,
             pages,
             gaps
           ) do
      extension = %{
        profile: @profile,
        profile_digest: profile().digest,
        compiler_profile: Protocol.compiler_profile(),
        compiler_digest: Protocol.compiler_digest(),
        base_compilation_digest: compilation.compilation_digest,
        dependency_profile: compilation.dependency_extension.profile,
        dependency_profile_digest: compilation.dependency_extension.profile_digest,
        parser_profile: compilation.dependency_extension.parser_profile,
        parser_profile_digest: compilation.dependency_extension.parser_profile_digest,
        lock_profile: compilation.dependency_extension.lock_profile,
        lock_profile_digest: compilation.dependency_extension.lock_profile_digest,
        sandbox_profile: compilation.dependency_extension.sandbox_profile || :not_run,
        sandbox_profile_digest:
          compilation.dependency_extension.sandbox_profile_digest ||
            Contract.digest(%{profile: :not_run, reason: :static_extraction_complete}),
        resolver_profile: compilation.dependency_extension.resolver_profile,
        resolver_profile_digest: compilation.dependency_extension.resolver_profile_digest,
        metadata_digests: compilation.dependency_extension.metadata_digests,
        metadata_fixture_digests: compilation.dependency_extension.metadata_fixture_digests,
        source_profile: compilation.dependency_extension.source_profile,
        source_profile_digest: compilation.dependency_extension.source_profile_digest,
        guide_profile: guide_manifest.profile,
        guide_profile_digest: guide_manifest.profile_digest,
        guide_manifest_digest: guide_manifest.digest,
        renderer_profile: GuideRenderer.profile().revision,
        renderer_profile_digest: GuideRenderer.profile().digest,
        accepted_document_digest: Contract.digest(accepted_documents),
        policy_revision: attributes.policy_revision,
        policy_digest: attributes.policy_digest,
        source_revision: attributes.source_revision,
        page_manifest_digest: digests.page_manifest,
        edition_content_digest: digests.content,
        page_graph_digest: digests.page_graph,
        navigation_digest: digests.navigation,
        source_coverage_digest: digests.source_coverage,
        render_digest: digests.render,
        usage_record_iri: compilation.usage.usage_iri,
        usage_record_digest: Contract.digest(compilation.usage),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        model_cached_tokens: 0,
        model_reasoning_tokens: 0,
        usage_cost_microunits: 0
      }

      result =
        compilation
        |> Map.merge(%{
          pages: pages,
          sources: sources,
          gaps: compilation.gaps ++ gaps,
          statements: statements,
          navigation: navigation,
          source_coverage: coverage,
          full_extension: extension,
          page_count: length(pages),
          section_count: Enum.sum(Enum.map(rendered_guides, & &1.counts.nodes)),
          citation_count: Enum.sum(Enum.map(pages, &length(&1.source_iris))),
          link_count: Enum.sum(Enum.map(pages, &length(&1.links))),
          gap_count: length(compilation.gaps) + length(gaps),
          statement_count: length(statements),
          generation_mode: :deterministic_only,
          model_calls: 0,
          model_input_tokens: 0,
          model_output_tokens: 0,
          model_cached_tokens: 0,
          model_reasoning_tokens: 0,
          usage_cost_microunits: 0
        })

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

  def compile(_compilation, _manifest, _rendered, _documents, _attributes), do: invalid()

  defp validate(compilation, manifest, rendered, documents, attributes) do
    cond do
      not exact_digest?(compilation, :compilation_digest) ->
        invalid()

      compilation[:dependency_extension][:profile] != "wiki-dependency-pages/1.0.0" or
        compilation[:generation_mode] != :deterministic_only or compilation[:model_calls] != 0 or
          compilation[:usage_cost_microunits] != 0 ->
        invalid()

      manifest[:profile] != GuideDiscovery.profile().revision or
        manifest[:profile_digest] != GuideDiscovery.profile().digest or
          not exact_digest?(manifest, :digest) ->
        invalid()

      manifest[:repository_iri] != compilation[:repository_iri] or
        manifest[:tenant_iri] != compilation[:tenant_iri] or
          manifest[:source_snapshot_iri] != compilation[:source_snapshot_iri] ->
        conflict()

      attributes[:repository_iri] != compilation[:repository_iri] or
        attributes[:tenant_iri] != compilation[:tenant_iri] or
        attributes[:edition_iri] != compilation[:edition_iri] or
        attributes[:source_fence] != compilation[:source_fence] or
          attributes[:source_revision] != manifest[:source_revision] ->
        conflict()

      not Contract.digest?(attributes[:source_revision]) or
        not Contract.digest?(attributes[:policy_digest]) or
        not is_integer(attributes[:policy_revision]) or attributes[:policy_revision] < 0 ->
        invalid()

      length(manifest[:guides] || []) > @maximums.guides or
          length(documents) > @maximums.accepted_documents ->
        invalid()

      not valid_render_set?(manifest.guides, rendered) or
          not Enum.all?(documents, &valid_document?/1) ->
        invalid()

      true ->
        :ok
    end
  end

  defp valid_render_set?(guides, rendered) do
    guide_ids = Enum.map(guides, & &1.iri) |> Enum.sort()
    render_ids = Enum.map(rendered, & &1[:guide_iri]) |> Enum.sort()
    guide_by_iri = Map.new(guides, &{&1.iri, &1})

    guide_ids == render_ids and length(render_ids) == length(Enum.uniq(render_ids)) and
      Enum.all?(rendered, fn render ->
        guide = guide_by_iri[render[:guide_iri]]

        is_map(guide) and render[:profile] == GuideRenderer.profile().revision and
          render[:profile_digest] == GuideRenderer.profile().digest and
          exact_digest?(render, :digest) and exact_render_digest?(render) and
          render[:source_digest] == guide.digest and
          render[:source_revision] == guide.source_revision and
          render[:source_path] == guide.path and render[:model_calls] == 0 and
          render[:model_input_tokens] == 0 and render[:model_output_tokens] == 0 and
          render[:usage_cost_microunits] == 0
      end)
  end

  defp valid_document?(document) do
    is_map(document) and document[:kind] in @accepted_kinds and
      ResourceIdentity.validate(document[:document_iri]) == :ok and
      Contract.digest?(document[:digest]) and Contract.digest?(document[:source_revision]) and
      is_binary(document[:stable_key]) and byte_size(document.stable_key) in 1..160 and
      is_binary(document[:title]) and byte_size(document.title) in 1..256 and
      document[:status] in [:accepted, :adopted, :published] and
      is_map(document[:facts] || %{})
  end

  defp guide_sources(compilation, guides) do
    reduce_sources(guides, fn guide ->
      with {:ok, iri} <-
             ResourceIdentity.deterministic(
               :wiki_source,
               Enum.join([compilation.edition_iri, guide.path, guide.digest], "\n")
             ) do
        {:ok,
         %{
           iri: iri,
           repository_iri: compilation.repository_iri,
           tenant_iri: compilation.tenant_iri,
           edition_iri: compilation.edition_iri,
           source_snapshot_iri: compilation.source_snapshot_iri,
           source_path: guide.path,
           path: guide.path,
           source_kind: :repository_file,
           authority: :exact_git_snapshot,
           digest: guide.digest,
           freshness: guide.freshness,
           discovered_source_iri: guide.iri,
           document_iri: nil
         }}
      end
    end)
  end

  defp document_sources(compilation, documents) do
    reduce_sources(documents, fn document ->
      with {:ok, iri} <-
             ResourceIdentity.deterministic(
               :wiki_source,
               Enum.join([compilation.edition_iri, document.document_iri, document.digest], "\n")
             ) do
        {:ok,
         %{
           iri: iri,
           repository_iri: compilation.repository_iri,
           tenant_iri: compilation.tenant_iri,
           edition_iri: compilation.edition_iri,
           source_snapshot_iri: compilation.source_snapshot_iri,
           source_path: "accepted:#{document.stable_key}",
           path: "accepted:#{document.stable_key}",
           source_kind: :source_graph,
           authority: :accepted_graph_document,
           digest: document.digest,
           freshness: :fresh,
           discovered_source_iri: nil,
           document_iri: document.document_iri
         }}
      end
    end)
  end

  defp reduce_sources(values, callback) do
    values
    |> Enum.sort_by(&source_sort_key/1)
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, result} ->
      case callback.(value) do
        {:ok, source} -> {:cont, {:ok, [source | result]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, result} -> {:ok, Enum.reverse(result)}
      error -> error
    end
  end

  defp source_sort_key(value), do: value[:path] || value[:stable_key]

  defp guide_pages(compilation, manifest, rendered, source_index) do
    guides = manifest.guides
    render_index = Map.new(rendered, &{&1.guide_iri, &1})
    slug_index = guide_slug_index(guides)
    predecessor_index = Map.new(manifest.changes.renamed, &{&1.to, &1.from})

    guides
    |> Enum.sort_by(&{&1.order, &1.path})
    |> Enum.reduce_while({:ok, []}, fn guide, {:ok, result} ->
      render = render_index[guide.iri]
      slug = slug_index[guide.path]
      kind = guide_kind(guide)
      stable_key = bounded_stable_key(guide.path)

      with {:ok, iri} <- ResourceIdentity.wiki_page(compilation.edition_iri, kind, stable_key) do
        links = guide_links(render.links, slug_index)

        facts = %{
          authority: :authored,
          source_path: guide.path,
          source_revision: guide.source_revision,
          source_digest: guide.digest,
          source_ref: guide.source_ref,
          title_evidence: guide.title_evidence,
          audience_evidence: guide.audience_evidence,
          ambiguous_classification?: guide.ambiguous_classification?,
          headings: guide.headings,
          safe_ast: render.blocks,
          table_of_contents: render.table_of_contents,
          rendered_links: render.links,
          render_warnings: render.warnings,
          blocking_findings: render.blocking_findings,
          activation_allowed?: render.activation_allowed?
        }

        page = %{
          iri: iri,
          repository_iri: compilation.repository_iri,
          tenant_iri: compilation.tenant_iri,
          edition_iri: compilation.edition_iri,
          kind: kind,
          stable_key: stable_key,
          title: guide.title,
          slug: slug,
          audience: guide.audience,
          summary: guide_summary(render),
          facts: facts,
          content_digest: Contract.digest(facts),
          source_iris: [source_index[guide.path]],
          source_links: [guide.source_ref],
          links: links,
          backlinks: [],
          completeness: if(render.activation_allowed?, do: :complete, else: :incomplete),
          freshness: guide.freshness,
          parent_slug: collection_for_guide(guide),
          hierarchy_depth: 1,
          order: 0,
          predecessor_path: predecessor_index[guide.path]
        }

        {:cont, {:ok, [page | result]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp document_pages(compilation, documents, source_index) do
    documents
    |> Enum.sort_by(&{&1.kind, &1.stable_key})
    |> Enum.reduce_while({:ok, []}, fn document, {:ok, result} ->
      slug = bounded_slug("accepted-" <> slug(document.stable_key), document.stable_key)

      with {:ok, iri} <-
             ResourceIdentity.wiki_page(
               compilation.edition_iri,
               document.kind,
               document.stable_key
             ) do
        facts = %{
          authority: :accepted_graph_document,
          document_iri: document.document_iri,
          source_revision: document.source_revision,
          status: document.status,
          facts: document[:facts] || %{}
        }

        page = %{
          iri: iri,
          repository_iri: compilation.repository_iri,
          tenant_iri: compilation.tenant_iri,
          edition_iri: compilation.edition_iri,
          kind: document.kind,
          stable_key: document.stable_key,
          title: document.title,
          slug: slug,
          audience: document_audience(document.kind),
          summary: document[:summary] || document.title,
          facts: facts,
          content_digest: Contract.digest(facts),
          source_iris: [source_index[document.document_iri]],
          source_links: [document.document_iri],
          links: [],
          backlinks: [],
          completeness: :complete,
          freshness: :fresh,
          parent_slug: document_collection(document.kind),
          hierarchy_depth: 1,
          order: 0,
          predecessor_path: nil
        }

        {:cont, {:ok, [page | result]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp normalize_base_page(page) do
    page
    |> Map.put_new(:audience, base_audience(page.kind))
    |> Map.put_new(:summary, page.title)
    |> Map.put_new(:source_links, page.source_iris)
    |> Map.put_new(:links, [])
    |> Map.put_new(:backlinks, [])
    |> Map.put_new(:completeness, :complete)
    |> Map.put_new(:freshness, :fresh)
    |> Map.put_new(:parent_slug, base_parent(page.slug, page.kind))
    |> Map.put_new(:hierarchy_depth, 1)
    |> Map.put_new(:predecessor_path, nil)
  end

  defp assemble_pages(compilation, base_pages, guide_pages, document_pages) do
    detail_pages = guide_pages ++ document_pages
    pages_by_slug = Map.new(base_pages ++ detail_pages, &{&1.slug, &1})
    manifest_source = compilation.sources |> hd() |> Map.fetch!(:iri)

    collections =
      @collection_specs
      |> Enum.with_index()
      |> Enum.map(fn {spec, order} ->
        existing = pages_by_slug[spec.slug]
        children = collection_children(spec.slug, base_pages, detail_pages)
        source_iris = collection_sources(children, pages_by_slug, manifest_source)
        facts = collection_facts(spec, existing, children)

        page =
          existing ||
            new_collection_page(compilation, spec, source_iris)

        %{
          page
          | title: spec.title,
            order: order,
            audience: spec.audience,
            summary: spec.title,
            facts: facts,
            content_digest: Contract.digest(facts),
            source_iris: source_iris,
            source_links: source_iris,
            links: Enum.map(children, &internal_link(page.iri, &1, :contains)),
            backlinks: [],
            completeness: collection_completeness(children, pages_by_slug),
            freshness: :fresh,
            parent_slug: if(spec.slug == "overview", do: nil, else: "overview"),
            hierarchy_depth: if(spec.slug == "overview", do: 0, else: 1)
        }
      end)

    collection_slugs = MapSet.new(Enum.map(collections, & &1.slug))

    details =
      (base_pages ++ detail_pages)
      |> Enum.reject(&MapSet.member?(collection_slugs, &1.slug))
      |> Enum.sort_by(&{parent_order(&1.parent_slug), &1.parent_slug, &1.slug, &1.iri})
      |> Enum.with_index(length(collections))
      |> Enum.map(fn {page, order} -> %{page | order: order} end)

    ordered = collections ++ details
    target_index = Map.new(ordered, &{&1.slug, &1.iri})
    linked = Enum.map(ordered, &resolve_link_iris(&1, target_index))
    backlinked = add_backlinks(linked)

    navigation =
      Enum.map(backlinked, fn page ->
        %{
          page_iri: page.iri,
          slug: page.slug,
          title: page.title,
          audience: page.audience,
          parent_slug: page.parent_slug,
          hierarchy_depth: page.hierarchy_depth,
          order: page.order,
          child_slugs:
            page.links
            |> Enum.filter(&(&1.kind == :contains))
            |> Enum.map(& &1.target_slug)
        }
      end)

    if unique_pages?(backlinked) do
      {:ok, backlinked, navigation}
    else
      invalid()
    end
  end

  defp new_collection_page(compilation, spec, sources) do
    {:ok, iri} = ResourceIdentity.wiki_page(compilation.edition_iri, spec.kind, spec.slug)

    %{
      iri: iri,
      repository_iri: compilation.repository_iri,
      tenant_iri: compilation.tenant_iri,
      edition_iri: compilation.edition_iri,
      kind: spec.kind,
      stable_key: spec.slug,
      title: spec.title,
      slug: spec.slug,
      order: 0,
      facts: %{},
      content_digest: Contract.digest(%{}),
      source_iris: sources,
      audience: spec.audience,
      summary: spec.title,
      source_links: sources,
      links: [],
      backlinks: [],
      completeness: :complete,
      freshness: :fresh,
      parent_slug: nil,
      hierarchy_depth: 0,
      predecessor_path: nil
    }
  end

  defp collection_children("overview", _base, _details),
    do: Enum.map(tl(@collection_specs), & &1.slug)

  defp collection_children("getting-started", _base, details) do
    details
    |> Enum.filter(fn page ->
      page.kind == :user_guide and
        (page.stable_key == "README.md" or
           String.contains?(String.downcase(page.stable_key), ["install", "getting", "usage"]))
    end)
    |> Enum.map(& &1.slug)
  end

  defp collection_children("user-guides", _base, details),
    do: child_slugs(details, ~w[user reference contributor]a)

  defp collection_children("developer-guides", _base, details),
    do: child_slugs(details, [:developer])

  defp collection_children("architecture-index", _base, details),
    do: child_slugs(details, [:architecture])

  defp collection_children("operations", _base, details),
    do: child_slugs(details, ~w[operator policy]a)

  defp collection_children("source-map", base, _details),
    do: select_base(base, [:source_area, :test_area, :module, :reference], ["source-map"])

  defp collection_children("project", base, _details),
    do: select_base(base, [:runtime, :project_overview], ["project", "overview"])

  defp collection_children("dependency-overview", base, _details),
    do:
      select_base(base, [:dependency, :dependency_gap, :dependency_overview], [
        "dependency-overview"
      ])

  defp collection_children("provenance", base, _details),
    do: select_base(base, [:about_this_wiki], ["provenance"])

  defp collection_children("freshness", base, _details),
    do: select_base(base, [:reference], ["freshness"])

  defp collection_children("known-gaps", base, _details),
    do: select_base(base, [:known_gap, :dependency_gap], ["known-gaps"])

  defp child_slugs(details, audiences) do
    details
    |> Enum.filter(&(&1.audience in audiences))
    |> Enum.map(& &1.slug)
    |> Enum.sort()
  end

  defp select_base(base, kinds, excluded) do
    base
    |> Enum.filter(&(&1.kind in kinds and &1.slug not in excluded))
    |> Enum.map(& &1.slug)
    |> Enum.sort()
  end

  defp collection_sources(children, pages_by_slug, fallback) do
    values =
      children
      |> Enum.flat_map(fn slug ->
        case pages_by_slug[slug] do
          nil -> []
          page -> page.source_iris
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    if values == [], do: [fallback], else: values
  end

  defp collection_facts(spec, existing, children) do
    %{
      collection: spec.slug,
      title: spec.title,
      audience: spec.audience,
      child_slugs: children,
      child_count: length(children),
      existing_facts: if(existing, do: existing.facts, else: nil)
    }
  end

  defp collection_completeness(children, pages_by_slug) do
    if Enum.all?(children, fn slug ->
         case pages_by_slug[slug] do
           nil -> true
           page -> page.completeness == :complete
         end
       end),
       do: :complete,
       else: :incomplete
  end

  defp resolve_link_iris(page, target_index) do
    links =
      Enum.map(page.links, fn link ->
        target_iri = target_index[link.target_slug]
        identity = Enum.join([page.iri, link.kind, link.target_slug, link[:fragment] || ""], "\n")
        {:ok, link_iri} = ResourceIdentity.deterministic(:wiki_link, identity)
        Map.merge(link, %{iri: link_iri, source_page_iri: page.iri, target_page_iri: target_iri})
      end)
      |> Enum.filter(&is_binary(&1.target_page_iri))
      |> Enum.uniq_by(&{&1.kind, &1.target_page_iri, &1[:fragment]})
      |> Enum.sort_by(&{&1.kind, &1.target_slug, &1[:fragment] || ""})

    %{page | links: links}
  end

  defp add_backlinks(pages) do
    backlink_index =
      Enum.reduce(pages, %{}, fn page, result ->
        Enum.reduce(page.links, result, fn link, nested ->
          backlink = %{
            source_page_iri: page.iri,
            source_slug: page.slug,
            kind: :backlink,
            target_page_iri: link.target_page_iri
          }

          Map.update(nested, link.target_page_iri, [backlink], &[backlink | &1])
        end)
      end)

    Enum.map(pages, fn page ->
      backlinks =
        backlink_index
        |> Map.get(page.iri, [])
        |> Enum.uniq_by(& &1.source_page_iri)
        |> Enum.sort_by(& &1.source_slug)

      %{page | backlinks: backlinks}
    end)
  end

  defp guide_links(links, slug_index) do
    links
    |> Enum.filter(&(&1.status == :resolved and is_binary(&1[:source_path])))
    |> Enum.map(fn link ->
      %{
        kind: :documents,
        target_slug: slug_index[link.source_path],
        fragment: link[:fragment],
        presentation_ref: link.presentation_ref
      }
    end)
    |> Enum.filter(&is_binary(&1.target_slug))
  end

  defp internal_link(_source_iri, target_slug, kind),
    do: %{kind: kind, target_slug: target_slug, fragment: nil, presentation_ref: nil}

  defp unique_pages?(pages) do
    length(pages) == length(Enum.uniq_by(pages, & &1.iri)) and
      length(pages) == length(Enum.uniq_by(pages, & &1.slug)) and
      Enum.map(pages, & &1.order) == Enum.to_list(0..(length(pages) - 1)) and
      Enum.all?(pages, &valid_page?/1)
  end

  defp valid_page?(page) do
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
    }) == :ok
  end

  defp full_gaps(compilation, manifest, rendered, pages) do
    discovery =
      Enum.map(manifest.gaps, fn gap ->
        gap(:guide_discovery, gap.path, gap.reason, [], :warning)
      end)

    ambiguous =
      manifest.guides
      |> Enum.filter(& &1.ambiguous_classification?)
      |> Enum.map(fn guide ->
        page = Enum.find(pages, &(&1.facts[:source_path] == guide.path))
        gap(:ambiguous_audience, guide.path, :ambiguous_classification, [page.iri], :warning)
      end)

    rendering =
      Enum.flat_map(rendered, fn render ->
        page = Enum.find(pages, &(&1.facts[:source_path] == render.source_path))

        warning_gaps =
          Enum.map(render.warnings, fn warning ->
            gap(:guide_render, render.source_path, warning, [page.iri], :warning)
          end)

        blocking_gaps =
          Enum.map(render.blocking_findings, fn finding ->
            gap(:guide_secret, render.source_path, finding.kind, [page.iri], :blocking)
          end)

        unresolved =
          render.links
          |> Enum.filter(&(&1.status in [:unresolved, :text_only]))
          |> Enum.map(fn link ->
            gap(
              :broken_link,
              render.source_path,
              link.reason || :unresolved,
              [page.iri],
              :warning
            )
          end)

        warning_gaps ++ blocking_gaps ++ unresolved
      end)

    missing =
      [
        {:user_guide, Enum.any?(manifest.guides, &(&1.audience == :user))},
        {:developer_guide, Enum.any?(manifest.guides, &(&1.audience == :developer))},
        {:operator_guide, Enum.any?(manifest.guides, &(&1.audience == :operator))}
      ]
      |> Enum.reject(&elem(&1, 1))
      |> Enum.map(fn {kind, _present} ->
        gap(:missing_guide, Atom.to_string(kind), :absent, [], :informational)
      end)

    dependency =
      if compilation[:dependency_completeness] == :complete do
        []
      else
        [gap(:dependency, "mix", :incomplete, [], :warning)]
      end

    (discovery ++ ambiguous ++ rendering ++ missing ++ dependency)
    |> Enum.uniq_by(&{&1.category, &1.path, &1.reason, &1.affected_page_iris})
    |> Enum.sort_by(&{&1.severity, &1.category, &1.path, &1.reason})
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      {:ok, iri} =
        ResourceIdentity.deterministic(
          :wiki_gap,
          Enum.join(
            [compilation.edition_iri, Integer.to_string(index), Contract.digest(value)],
            "\n"
          )
        )

      Map.put(value, :iri, iri)
    end)
  end

  defp gap(category, path, reason, pages, severity) do
    %{
      category: category,
      path: path,
      reason: reason,
      severity: severity,
      affected_page_iris: Enum.sort(pages),
      remediation: :review_source_or_policy
    }
  end

  defp source_coverage(sources, pages) do
    source_index =
      Enum.reduce(pages, %{}, fn page, result ->
        Enum.reduce(page.source_iris, result, fn source_iri, nested ->
          Map.update(nested, source_iri, [page.slug], &[page.slug | &1])
        end)
      end)

    Enum.map(sources, fn source ->
      page_slugs = source_index |> Map.get(source.iri, []) |> Enum.uniq() |> Enum.sort()

      %{
        source_iri: source.iri,
        locator: source.path,
        digest: source.digest,
        freshness: source[:freshness] || :fresh,
        page_slugs: page_slugs,
        covered?: page_slugs != []
      }
    end)
    |> Enum.sort_by(&{&1.locator, &1.source_iri})
  end

  defp digests(pages, navigation, coverage, rendered, gaps) do
    page_manifest =
      Enum.map(pages, fn page ->
        Map.take(page, [
          :iri,
          :kind,
          :stable_key,
          :title,
          :slug,
          :order,
          :audience,
          :parent_slug,
          :content_digest,
          :source_iris,
          :completeness,
          :freshness
        ])
      end)

    page_graph =
      Enum.map(pages, fn page ->
        %{
          page_iri: page.iri,
          links: Enum.map(page.links, &Map.take(&1, [:kind, :target_page_iri, :fragment])),
          backlinks: Enum.map(page.backlinks, &Map.take(&1, [:source_page_iri, :kind]))
        }
      end)

    page_content = Enum.map(pages, &{&1.iri, &1.content_digest})
    source_coverage_digest = Contract.digest(coverage)
    render_digest = Contract.digest(Enum.map(rendered, &{&1.guide_iri, &1.render_digest}))

    %{
      page_manifest: Contract.digest(page_manifest),
      content:
        Contract.digest(%{
          pages: page_content,
          source_coverage: source_coverage_digest,
          renders: render_digest,
          gaps: gaps
        }),
      page_graph: Contract.digest(page_graph),
      navigation: Contract.digest(navigation),
      source_coverage: source_coverage_digest,
      render: render_digest
    }
  end

  defp statements(compilation, added_sources, pages, gaps) do
    base_page_iris = MapSet.new(Enum.map(compilation.pages, & &1.iri))

    retained =
      Enum.reject(compilation.statements, fn {subject, _predicate, _object} ->
        MapSet.member?(base_page_iris, subject)
      end)

    retained ++
      Enum.flat_map(added_sources, &source_statements/1) ++
      Enum.flat_map(pages, &page_statements/1) ++
      Enum.flat_map(pages, fn page -> Enum.flat_map(page.links, &link_statements/1) end) ++
      Enum.flat_map(gaps, &gap_statements(compilation, &1))
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
      {page.iri, @jf <> "completenessState", RDF.iri(Contract.concept(page.completeness))},
      {page.iri, @jf <> "audience", RDF.XSD.String.new(to_string(page.audience))}
      | Enum.map(page.source_iris, &{page.iri, @jf <> "wikiSource", RDF.iri(&1)})
    ]
  end

  defp link_statements(link) do
    [
      {link.iri, @rdf_type, RDF.iri(@jf <> "WikiLink")},
      {link.iri, @jf <> "linkKind", RDF.iri(Contract.concept(link.kind))},
      {link.iri, @jf <> "sourcePage", RDF.iri(link.source_page_iri)},
      {link.iri, @jf <> "targetPage", RDF.iri(link.target_page_iri)}
    ]
  end

  defp gap_statements(compilation, gap) do
    [
      {gap.iri, @rdf_type, RDF.iri(@jf <> "WikiGap")},
      {gap.iri, @jf <> "repositoryScope", RDF.iri(compilation.repository_iri)},
      {gap.iri, @jf <> "tenantScope", RDF.iri(compilation.tenant_iri)},
      {gap.iri, @jf <> "wikiEdition", RDF.iri(compilation.edition_iri)},
      {gap.iri, @jf <> "gapKind", RDF.iri(Contract.concept(:wiki_incomplete))},
      {gap.iri, @jf <> "sourceLocator", RDF.XSD.String.new(gap.path)},
      {gap.iri, @jf <> "omissionCode", RDF.XSD.String.new(to_string(gap.reason))}
    ]
  end

  defp guide_slug_index(guides) do
    base =
      Enum.map(guides, fn guide ->
        candidate = "guide-" <> slug(Path.rootname(guide.path))
        {guide.path, candidate, String.slice(candidate, 0, 148)}
      end)

    frequencies = Enum.frequencies_by(base, &elem(&1, 2))

    Map.new(base, fn {path, candidate, prefix} ->
      value =
        if byte_size(candidate) <= 160 and frequencies[prefix] == 1 do
          candidate
        else
          prefix <> "-" <> String.slice(Contract.digest(path), 0, 10)
        end

      {path, value}
    end)
  end

  defp bounded_slug(candidate, _identity) when byte_size(candidate) <= 160, do: candidate

  defp bounded_slug(candidate, identity),
    do: String.slice(candidate, 0, 148) <> "-" <> String.slice(Contract.digest(identity), 0, 10)

  defp bounded_stable_key(path) when byte_size(path) <= 160, do: path
  defp bounded_stable_key(path), do: "guide-path-" <> Contract.digest(path)

  defp slug(value) do
    value
    |> String.normalize(:nfc)
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "document"
      normalized -> normalized
    end
  end

  defp guide_kind(%{audience: :user}), do: :user_guide
  defp guide_kind(%{audience: :developer}), do: :developer_guide
  defp guide_kind(%{audience: :operator}), do: :operator_guide
  defp guide_kind(%{audience: :contributor}), do: :contributor_guide
  defp guide_kind(%{audience: :policy}), do: :security

  defp guide_kind(%{audience: :architecture, path: path}) do
    cond do
      String.contains?(String.downcase(path), "/adr") -> :adr
      String.contains?(String.downcase(path), "/research") -> :research_note
      true -> :architecture_overview
    end
  end

  defp guide_kind(%{audience: :reference, path: path}) do
    if String.contains?(String.downcase(path), "changelog"), do: :changelog, else: :reference
  end

  defp guide_kind(_guide), do: :reference

  defp collection_for_guide(%{audience: audience})
       when audience in [:user, :reference, :contributor],
       do: "user-guides"

  defp collection_for_guide(%{audience: :developer}), do: "developer-guides"
  defp collection_for_guide(%{audience: :architecture}), do: "architecture-index"

  defp collection_for_guide(%{audience: audience}) when audience in [:operator, :policy],
    do: "operations"

  defp collection_for_guide(_guide), do: "known-gaps"

  defp document_collection(kind) when kind in [:architecture_overview, :adr, :research_note],
    do: "architecture-index"

  defp document_collection(kind) when kind in [:operations, :security], do: "operations"
  defp document_collection(_kind), do: "user-guides"

  defp document_audience(kind) when kind in [:architecture_overview, :adr, :research_note],
    do: :architecture

  defp document_audience(kind) when kind in [:operations, :security], do: :operator
  defp document_audience(_kind), do: :reference

  defp base_audience(kind) when kind in [:dependency, :dependency_overview, :dependency_gap],
    do: :developer

  defp base_audience(kind) when kind in [:source_area, :test_area, :module, :runtime],
    do: :developer

  defp base_audience(kind)
       when kind in [:adr, :adr_index, :research_note, :architecture_overview],
       do: :architecture

  defp base_audience(:operations), do: :operator
  defp base_audience(_kind), do: :reference

  defp base_parent(slug, kind) do
    cond do
      kind in [:dependency, :dependency_gap] -> "dependency-overview"
      kind in [:source_area, :test_area, :module] and slug != "source-map" -> "source-map"
      kind in [:adr, :research_note, :architecture_overview] -> "architecture-index"
      slug == "runtime-requirements" -> "project"
      slug in ["repository-inventory", "documentation-index"] -> "source-map"
      true -> "overview"
    end
  end

  defp parent_order(nil), do: -1

  defp parent_order(parent) do
    Enum.find_index(@collection_specs, &(&1.slug == parent)) || length(@collection_specs)
  end

  defp guide_summary(render) do
    render.blocks
    |> Enum.find_value(render.title, fn block ->
      if block.type in [:paragraph, :blockquote, :list_item] do
        block
        |> Map.get(:segments, [])
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map_join(& &1.text)
        |> String.trim()
        |> case do
          "" -> nil
          text -> String.slice(text, 0, 280)
        end
      end
    end)
  end

  defp unique_added_sources(existing, additions) do
    existing_iris = MapSet.new(Enum.map(existing, & &1.iri))

    additions
    |> Enum.reject(&MapSet.member?(existing_iris, &1.iri))
    |> Enum.uniq_by(& &1.iri)
  end

  defp exact_digest?(value, key) when is_map(value) do
    digest = value[key]
    Contract.digest?(digest) and Contract.digest(Map.delete(value, key)) == digest
  end

  defp exact_render_digest?(render) do
    digest = render[:render_digest]

    Contract.digest?(digest) and
      Contract.digest(render |> Map.delete(:digest) |> Map.delete(:render_digest)) == digest
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_full_compile)}
  defp conflict, do: {:error, Error.new(:conflict, :repository_wiki_full_compile)}
end

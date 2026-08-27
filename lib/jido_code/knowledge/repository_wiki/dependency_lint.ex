defmodule JidoCode.Knowledge.RepositoryWiki.DependencyLint do
  @moduledoc "Dependency completeness and safe-link extension for wiki-lint/1.0.0."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.DependencyPages
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-lint/1.0.0"
  @extension "dependency-completeness/1.0.0"
  @maximum_findings 200
  @classifications ~w[
    declared_only locked_only resolved missing_lock orphaned_lock conflicting unsupported unverifiable
  ]a

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      extension: @extension,
      dependency_compiler_profile: DependencyPages.profile().revision,
      maximum_findings: @maximum_findings,
      supported_omission: :blocking,
      explicit_uncertainty: :warning,
      unsafe_link: :blocking,
      remote_authority: :observed_only
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec lint(map(), map(), map(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def lint(compilation, reconciliation, catalog, metadata, link_sets)
      when is_map(compilation) and is_map(reconciliation) and is_map(catalog) and
             is_map(metadata) and is_map(link_sets) do
    with :ok <- validate_inputs(compilation, reconciliation, catalog),
         findings <-
           closure_findings(reconciliation, catalog) ++
             page_findings(compilation, reconciliation, catalog) ++
             source_findings(compilation) ++
             link_findings(compilation, catalog, link_sets) ++
             metadata_findings(compilation, catalog, metadata) ++
             integrity_findings(compilation, reconciliation, catalog),
         normalized <- normalize_findings(findings),
         coverage <- coverage(compilation, reconciliation, catalog, metadata, link_sets) do
      blocking_count = Enum.count(normalized, &(&1.severity == :blocking))
      warning_count = Enum.count(normalized, &(&1.severity == :warning))
      retained = Enum.take(normalized, @maximum_findings)

      report = %{
        profile: @profile,
        extension: @extension,
        profile_digest: profile().digest,
        edition_iri: compilation.edition_iri,
        compilation_digest: compilation.compilation_digest,
        catalog_digest: catalog.digest,
        reconciliation_digest: reconciliation.digest,
        blocking_count: blocking_count,
        warning_count: warning_count,
        finding_count: length(normalized),
        truncated_finding_count: max(length(normalized) - length(retained), 0),
        findings: retained,
        coverage: coverage,
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(report, :digest, Contract.digest(report))}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  rescue
    _error -> invalid()
  end

  def lint(_compilation, _reconciliation, _catalog, _metadata, _link_sets), do: invalid()

  defp validate_inputs(compilation, reconciliation, catalog) do
    cond do
      not exact_digest?(compilation, :compilation_digest) or
          get_in(compilation, [:dependency_extension, :profile]) != "wiki-dependency-pages/1.0.0" ->
        invalid()

      reconciliation[:profile] != "mix-reconcile/1.0.0" or
          not exact_digest?(reconciliation, :digest) ->
        invalid()

      catalog[:profile] != "wiki-dependency-resolver/1.0.0" or not exact_digest?(catalog, :digest) ->
        invalid()

      compilation[:repository_iri] != catalog[:repository_iri] or
        compilation[:tenant_iri] != catalog[:tenant_iri] or
        compilation[:edition_iri] != catalog[:edition_iri] or
        compilation[:source_fence] != catalog[:source_fence] or
          reconciliation[:source_fence] != catalog[:source_fence] ->
        conflict()

      true ->
        :ok
    end
  end

  defp closure_findings(reconciliation, catalog) do
    node_groups = Enum.group_by(catalog.nodes, & &1.name)

    declared =
      Enum.flat_map(reconciliation.declared_dependencies, fn dependency ->
        case node_groups[dependency.name] do
          [_node] ->
            []

          nil ->
            [finding(:blocking, "declared_dependency_missing", nil, dependency.name)]

          _duplicates ->
            [finding(:blocking, "dependency_identity_duplicate", nil, dependency.name)]
        end
      end)

    locked =
      Enum.flat_map(reconciliation.lock_entries, fn entry ->
        case node_groups[entry.name] do
          [_node] -> []
          nil -> [finding(:blocking, "lock_dependency_missing", nil, entry.name)]
          _duplicates -> [finding(:blocking, "dependency_identity_duplicate", nil, entry.name)]
        end
      end)

    expected_edges =
      reconciliation.lock_entries
      |> Enum.flat_map(fn entry ->
        Enum.map(entry.edges, &{entry.name, &1.name, &1.requirement, &1.optional})
      end)
      |> MapSet.new()

    actual_edges =
      catalog.edges
      |> Enum.map(&{&1.parent, &1.child, &1.requirement, &1.optional})
      |> MapSet.new()

    edge_findings =
      expected_edges
      |> MapSet.difference(actual_edges)
      |> Enum.map(fn {parent, child, _requirement, _optional} ->
        finding(
          :blocking,
          "dependency_edge_missing",
          node_iri(catalog, parent),
          "#{parent}->#{child}"
        )
      end)

    terminating =
      catalog.edges
      |> Enum.reject(
        &(Map.has_key?(node_groups, &1.parent) and Map.has_key?(node_groups, &1.child))
      )
      |> Enum.map(fn edge ->
        finding(:blocking, "dependency_edge_unrepresented", nil, "#{edge.parent}->#{edge.child}")
      end)

    identity_findings =
      catalog.nodes
      |> Enum.group_by(& &1.iri)
      |> Enum.flat_map(fn
        {_iri, [_node]} -> []
        {iri, _duplicates} -> [finding(:blocking, "dependency_iri_duplicate", iri, nil)]
      end)

    classification_findings =
      Enum.flat_map(catalog.nodes, fn node ->
        values =
          if node.classification in @classifications,
            do: [],
            else: [finding(:blocking, "dependency_classification_invalid", node.iri, node.name)]

        path_valid =
          is_nil(node.canonical_path) or
            (is_list(node.canonical_path) and length(node.canonical_path) <= 64 and
               List.last(node.canonical_path) == node.name)

        root_paths_valid =
          is_list(node[:root_paths]) and
            Enum.all?(node.root_paths, fn path ->
              is_list(path) and path != [] and length(path) <= 64 and
                List.last(path) == node.name and hd(path) in catalog.roots
            end)

        maybe_finding(
          values,
          not path_valid or not root_paths_valid,
          :blocking,
          "dependency_path_invalid",
          node.iri,
          node.name
        )
      end)

    count_findings =
      []
      |> maybe_finding(
        catalog.node_count != length(catalog.nodes),
        :blocking,
        "dependency_node_count_invalid",
        nil,
        nil
      )
      |> maybe_finding(
        catalog.edge_count != length(catalog.edges),
        :blocking,
        "dependency_edge_count_invalid",
        nil,
        nil
      )
      |> maybe_finding(
        catalog.completeness[:expected_lock_nodes] != length(reconciliation.lock_entries) or
          catalog.completeness[:represented_lock_nodes] != length(reconciliation.lock_entries),
        :blocking,
        "dependency_lock_coverage_invalid",
        nil,
        nil
      )

    gap_warnings =
      Enum.map(catalog.gaps, fn gap ->
        finding(
          :warning,
          "dependency_gap_#{gap.kind}",
          node_iri(catalog, gap[:dependency]),
          gap[:reason]
        )
      end)

    declared ++
      locked ++
      edge_findings ++
      terminating ++
      identity_findings ++
      classification_findings ++ count_findings ++ gap_warnings
  end

  defp page_findings(compilation, reconciliation, catalog) do
    dependency_pages =
      Enum.filter(compilation.pages, &(&1[:compiler_profile] == "wiki-dependency-pages/1.0.0"))

    detail_pages = Enum.filter(dependency_pages, &(&1.kind == :dependency))
    detail_by_name = Map.new(detail_pages, &{get_in(&1, [:facts, :general, :name]), &1})

    detail_findings =
      Enum.flat_map(catalog.nodes, fn node ->
        case detail_by_name[node.name] do
          nil ->
            [finding(:blocking, "dependency_page_missing", node.iri, node.name)]

          page ->
            {:ok, expected_iri} =
              ResourceIdentity.wiki_page(
                compilation.edition_iri,
                :dependency,
                "dependency-#{node.name}"
              )

            []
            |> maybe_finding(
              page.iri != expected_iri,
              :blocking,
              "dependency_page_identity",
              node.iri,
              node.name
            )
            |> maybe_finding(
              get_in(page, [:facts, :general, :classification]) != node.classification,
              :blocking,
              "dependency_classification_hidden",
              node.iri,
              node.name
            )
            |> maybe_finding(
              page.source_iris == [],
              :blocking,
              "dependency_source_missing",
              node.iri,
              node.name
            )
        end
      end)

    required_slugs = ~w[
      project runtime-requirements dependency-overview direct-dependencies
      transitive-dependencies dependency-gaps dependency-metadata-freshness
    ]

    summary_findings =
      Enum.flat_map(required_slugs, fn slug ->
        case Enum.filter(dependency_pages, &(&1.slug == slug)) do
          [_page] -> []
          [] -> [finding(:blocking, "dependency_summary_page_missing", nil, slug)]
          _duplicates -> [finding(:blocking, "dependency_summary_page_duplicate", nil, slug)]
        end
      end)

    project_page = Enum.find(dependency_pages, &(&1.slug == "project"))

    conflict_findings =
      reconciliation.fields
      |> Enum.filter(&(&1.state == :conflicting))
      |> Enum.flat_map(fn field ->
        visible =
          project_page &&
            Enum.any?(get_in(project_page, [:facts, :fields]) || [], fn page_field ->
              page_field.name == field.name and page_field.state == :conflicting
            end)

        if visible,
          do: [],
          else: [finding(:blocking, "mix_conflict_hidden", nil, field.name)]
      end)

    page_integrity =
      Enum.flat_map(dependency_pages, fn page ->
        []
        |> maybe_finding(
          page.content_digest != Contract.digest(page.facts),
          :blocking,
          "dependency_page_digest_invalid",
          page.iri,
          page.slug
        )
        |> maybe_finding(
          page.order < 0,
          :blocking,
          "dependency_page_order_invalid",
          page.iri,
          page.slug
        )
      end)

    uniqueness =
      []
      |> maybe_finding(
        length(dependency_pages) != length(Enum.uniq_by(dependency_pages, & &1.iri)),
        :blocking,
        "dependency_page_iri_duplicate",
        nil,
        nil
      )
      |> maybe_finding(
        length(dependency_pages) != length(Enum.uniq_by(dependency_pages, & &1.slug)),
        :blocking,
        "dependency_page_slug_duplicate",
        nil,
        nil
      )

    detail_findings ++ summary_findings ++ conflict_findings ++ page_integrity ++ uniqueness
  end

  defp source_findings(compilation) do
    source_iris = MapSet.new(Enum.map(compilation.sources, & &1.iri))

    compilation.pages
    |> Enum.filter(&(&1[:compiler_profile] == "wiki-dependency-pages/1.0.0"))
    |> Enum.flat_map(fn page ->
      if page.source_iris != [] and Enum.all?(page.source_iris, &MapSet.member?(source_iris, &1)),
        do: [],
        else: [finding(:blocking, "dependency_source_provenance_invalid", page.iri, page.slug)]
    end)
  end

  defp link_findings(compilation, catalog, link_sets) do
    page_by_name =
      compilation.pages
      |> Enum.filter(&(&1.kind == :dependency))
      |> Map.new(&{get_in(&1, [:facts, :general, :name]), &1})

    Enum.flat_map(link_sets, fn {name, set} ->
      node = Enum.find(catalog.nodes, &(&1.name == name))
      page_links = get_in(page_by_name[name] || %{}, [:facts, :links]) || []

      set_findings =
        []
        |> maybe_finding(
          not exact_digest?(set, :digest),
          :blocking,
          "dependency_link_digest_invalid",
          node && node.iri,
          name
        )
        |> maybe_finding(
          page_links != set.links,
          :blocking,
          "dependency_links_omitted",
          node && node.iri,
          name
        )

      set_findings ++
        Enum.flat_map(set.links, fn link ->
          valid =
            case link.verification do
              :verified ->
                safe_destination?(link.destination) and
                  link.navigation == :external_noopener_noreferrer_nofollow and
                  is_nil(URI.parse(link.destination).userinfo)

              :text_only ->
                is_nil(link.destination) and link.navigation == :none

              _invalid ->
                false
            end

          if valid,
            do: [],
            else: [finding(:blocking, "unsafe_dependency_link", link[:iri], name)]
        end)
    end)
  end

  defp metadata_findings(compilation, catalog, metadata) do
    page_by_name =
      compilation.pages
      |> Enum.filter(&(&1.kind == :dependency))
      |> Map.new(&{get_in(&1, [:facts, :general, :name]), &1})

    represented =
      Enum.flat_map(metadata, fn {name, value} ->
        node = Enum.find(catalog.nodes, &(&1.name == name))
        summary = get_in(page_by_name[name] || %{}, [:facts, :metadata])

        []
        |> maybe_finding(
          value.authority != :observed,
          :blocking,
          "metadata_authority_invalid",
          node && node.iri,
          name
        )
        |> maybe_finding(
          not exact_digest?(value, :digest),
          :blocking,
          "metadata_digest_invalid",
          node && node.iri,
          name
        )
        |> maybe_finding(
          not is_map(summary) or summary[:authority] != :observed or
            summary[:digest] != value.digest,
          :blocking,
          "metadata_provenance_omitted",
          node && node.iri,
          name
        )
      end)

    availability =
      catalog.nodes
      |> Enum.filter(&(&1.scm == "hex" and not is_nil(&1.selected_version)))
      |> Enum.flat_map(fn node ->
        case metadata[node.name] do
          nil ->
            [finding(:warning, "dependency_metadata_unavailable", node.iri, node.name)]

          %{state: state} when state in [:unavailable, :partial] ->
            [finding(:warning, "dependency_metadata_#{state}", node.iri, node.name)]

          %{cache_state: :stale} ->
            [finding(:warning, "dependency_metadata_stale", node.iri, node.name)]

          _available ->
            []
        end
      end)

    represented ++ availability
  end

  defp integrity_findings(compilation, reconciliation, catalog) do
    extension = compilation.dependency_extension

    []
    |> maybe_finding(
      not exact_digest?(compilation, :compilation_digest),
      :blocking,
      "dependency_compilation_digest_invalid",
      compilation.edition_iri,
      nil
    )
    |> maybe_finding(
      extension.model_calls != 0 or extension.model_input_tokens != 0 or
        extension.model_output_tokens != 0 or extension.usage_cost_microunits != 0,
      :blocking,
      "dependency_compiler_usage_nonzero",
      compilation.edition_iri,
      nil
    )
    |> maybe_finding(
      extension.reconciliation_digest != reconciliation.digest,
      :blocking,
      "dependency_reconciliation_digest_stale",
      compilation.edition_iri,
      nil
    )
    |> maybe_finding(
      extension.catalog_digest != catalog.digest,
      :blocking,
      "dependency_catalog_digest_stale",
      compilation.edition_iri,
      nil
    )
  end

  defp coverage(compilation, reconciliation, catalog, metadata, link_sets) do
    lock_names = MapSet.new(Enum.map(reconciliation.lock_entries, & &1.name))
    declared_names = MapSet.new(Enum.map(reconciliation.declared_dependencies, & &1.name))
    node_names = MapSet.new(Enum.map(catalog.nodes, & &1.name))
    expected_edges = Enum.sum(Enum.map(reconciliation.lock_entries, &length(&1.edges)))
    detail_pages = Enum.count(compilation.pages, &(&1.kind == :dependency))

    %{
      expected_lock_nodes: MapSet.size(lock_names),
      represented_lock_nodes: MapSet.size(MapSet.intersection(lock_names, node_names)),
      expected_declarations: MapSet.size(declared_names),
      represented_declarations: MapSet.size(MapSet.intersection(declared_names, node_names)),
      expected_edges: expected_edges,
      represented_edges: length(catalog.edges),
      expected_dependency_pages: length(catalog.nodes),
      represented_dependency_pages: detail_pages,
      metadata_records: map_size(metadata),
      available_metadata_records:
        Enum.count(metadata, fn {_name, value} -> value.state == :available end),
      link_sets: map_size(link_sets),
      safe_clickable_links:
        Enum.sum(Enum.map(link_sets, fn {_name, value} -> value.clickable_count end)),
      zero_model_tokens:
        compilation.model_input_tokens == 0 and compilation.model_output_tokens == 0 and
          compilation.usage_cost_microunits == 0
    }
  end

  defp normalize_findings(findings) do
    findings
    |> Enum.uniq_by(&{&1.severity, &1.code, &1.resource_iri, &1[:detail]})
    |> Enum.sort_by(
      &{severity_order(&1.severity), &1.code, &1.resource_iri || "", to_string(&1[:detail] || "")}
    )
  end

  defp finding(severity, code, resource_iri, detail) do
    code = code |> String.slice(0, 64)
    %{severity: severity, code: code, resource_iri: resource_iri, detail: detail}
  end

  defp maybe_finding(findings, true, severity, code, resource_iri, detail),
    do: [finding(severity, code, resource_iri, detail) | findings]

  defp maybe_finding(findings, false, _severity, _code, _resource_iri, _detail), do: findings

  defp exact_digest?(value, key) when is_map(value) do
    digest = value[key]
    Contract.digest?(digest) and Contract.digest(Map.delete(value, key)) == digest
  end

  defp node_iri(_catalog, nil), do: nil

  defp node_iri(catalog, name) do
    case Enum.find(catalog.nodes, &(&1.name == name)) do
      nil -> nil
      node -> node.iri
    end
  end

  defp severity_order(:blocking), do: 0
  defp severity_order(:warning), do: 1

  defp safe_destination?(destination) when is_binary(destination) do
    uri = URI.parse(destination)
    host = uri.host && String.downcase(uri.host)

    host_valid =
      is_binary(host) and host != "" and host == uri.host and
        Regex.match?(~r/^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$/, host) and
        host not in ["localhost", "jido.run"] and
        not Enum.any?([".localhost", ".local", ".internal", ".jido.run"], fn suffix ->
          String.ends_with?(host, suffix)
        end) and
        match?({:error, :einval}, :inet.parse_address(String.to_charlist(host)))

    destination |> :binary.bin_to_list() |> Enum.all?(&(&1 >= 32 and &1 <= 126)) and
      uri.scheme == "https" and host_valid and is_nil(uri.userinfo) and uri.port in [nil, 443]
  rescue
    _error -> false
  end

  defp safe_destination?(_destination), do: false

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_dependency_lint)}
  defp conflict, do: {:error, Error.new(:conflict, :repository_wiki_dependency_lint)}
end

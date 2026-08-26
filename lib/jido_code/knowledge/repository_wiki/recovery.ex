defmodule JidoCode.Knowledge.RepositoryWiki.Recovery do
  @moduledoc "Graph-only repository wiki recovery, restore verification, and index rebuilding."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @max_quads 25_000

  @spec recover(RDF.Dataset.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def recover(%RDF.Dataset{} = dataset, edition_iri, authority) when is_map(authority) do
    quads = RDF.Dataset.quads(dataset)

    with true <- length(quads) <= @max_quads,
         :ok <- ResourceIdentity.validate(edition_iri),
         [graph] <- graphs_with_type(quads, edition_iri, @jf <> "WikiEdition"),
         [repository] <- iris(quads, edition_iri, @jf <> "repositoryScope", graph),
         [tenant] <- iris(quads, edition_iri, @jf <> "tenantScope", graph),
         [source_snapshot] <- iris(quads, edition_iri, @jf <> "sourceSnapshot", graph),
         [source_fence] <- literals(quads, edition_iri, @jf <> "sourceFence", graph),
         [compiler_profile] <- literals(quads, edition_iri, @jf <> "compilerProfile", graph),
         [compiler_digest] <- literals(quads, edition_iri, @jf <> "compilerDigest", graph),
         [lifecycle] <- iris(quads, graph, @jf <> "lifecycleState", graph),
         [completeness] <- iris(quads, graph, @jf <> "completenessState", graph),
         {:ok, segments} <- segments(quads, edition_iri, graph),
         {:ok, state} <-
           recovery_state(quads, edition_iri, graph, lifecycle, completeness, authority, %{
             repository: repository,
             tenant: tenant,
             source_snapshot: source_snapshot,
             source_fence: source_fence,
             compiler_profile: compiler_profile,
             compiler_digest: compiler_digest
           }) do
      pages = resources_of_type(quads, @jf <> "WikiPage", graph)

      {:ok,
       Map.merge(state, %{
         protocol: "1.0.0",
         edition_iri: edition_iri,
         graph_iri: graph,
         repository_iri: repository,
         tenant_iri: tenant,
         source_snapshot_iri: source_snapshot,
         source_fence: source_fence,
         compiler_profile: compiler_profile,
         compiler_digest: compiler_digest,
         segments: segments,
         page_iris: pages,
         next_segment_index: length(segments),
         reconstructed_from: :rdf_only,
         process_memory_used?: false,
         queue_state_used?: false,
         filesystem_cursor_used?: false
       })}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> corrupt(:repository_wiki_recovery)
    end
  rescue
    _error -> corrupt(:repository_wiki_recovery)
  end

  def recover(_dataset, _edition_iri, _authority),
    do: invalid(:repository_wiki_recovery)

  @spec rebuild_disposable_indexes(RDF.Dataset.t(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def rebuild_disposable_indexes(%RDF.Dataset{} = dataset, edition_iri) do
    quads = RDF.Dataset.quads(dataset)

    with [graph] <- graphs_with_type(quads, edition_iri, @jf <> "WikiEdition") do
      pages =
        resources_of_type(quads, @jf <> "WikiPage", graph)
        |> Enum.map(fn page ->
          %{
            iri: page,
            slug: one_literal(quads, page, @jf <> "slug", graph),
            title: one_literal(quads, page, @jf <> "title", graph),
            sources: iris(quads, page, @jf <> "wikiSource", graph) |> Enum.sort()
          }
        end)
        |> Enum.sort_by(&{&1.slug, &1.iri})

      {:ok,
       %{
         edition_iri: edition_iri,
         navigation: pages,
         search_documents: Enum.map(pages, &Map.take(&1, [:iri, :slug, :title])),
         disposable?: true,
         rebuilt_from: :rdf_only
       }}
    else
      _invalid -> corrupt(:repository_wiki_index_rebuild)
    end
  end

  def rebuild_disposable_indexes(_dataset, _edition_iri),
    do: invalid(:repository_wiki_index_rebuild)

  @spec verify_restore(map()) :: :ok | {:error, Error.t()}
  def verify_restore(snapshot) when is_map(snapshot) do
    current = Map.get(snapshot, :current_edition_iris, [])
    enrollment_state = snapshot[:enrollment_state]

    cond do
      not is_list(current) or length(current) > 1 ->
        corrupt(:repository_wiki_restore_current)

      current != [] and enrollment_state == :off ->
        corrupt(:repository_wiki_restore_enrollment)

      snapshot[:repository_iri] != snapshot[:edition_repository_iri] ->
        corrupt(:repository_wiki_restore_scope)

      not is_list(snapshot[:audit_iris]) or snapshot.audit_iris == [] ->
        corrupt(:repository_wiki_restore_audit)

      snapshot[:graph_lifecycle] not in [:open, :closed, :invalidated] ->
        corrupt(:repository_wiki_restore_graph)

      true ->
        :ok
    end
  end

  def verify_restore(_snapshot), do: invalid(:repository_wiki_restore)

  defp recovery_state(
         quads,
         edition,
         graph,
         lifecycle,
         completeness,
         authority,
         persisted
       ) do
    closed? = lifecycle == @jf <> "Closed" or String.ends_with?(lifecycle, "Closed")
    open? = lifecycle == @jf <> "Open" or String.ends_with?(lifecycle, "Open")
    closure? = literals(quads, edition, @jf <> "closureDigest", graph) |> length() == 1
    lint? = iris(quads, edition, @jf <> "wikiLintReport", graph) |> length() == 1
    exact? = authority_exact?(authority, persisted)

    cond do
      closed? and String.ends_with?(completeness, "Complete") and closure? and lint? ->
        {:ok,
         %{
           recovery_status: :closed,
           resumable?: false,
           visible?:
             authority[:current_edition_iri] == edition and
               authority[:read_visibility] == :retained,
           recovery_action: :none
         }}

      open? and not closure? and exact? ->
        {:ok,
         %{
           recovery_status: :resumable,
           resumable?: true,
           visible?: false,
           recovery_action: :resume_exact_fence
         }}

      open? ->
        {:ok,
         %{
           recovery_status: :abandoned,
           resumable?: false,
           visible?: false,
           recovery_action: :mark_incomplete_and_preserve
         }}

      true ->
        corrupt(:repository_wiki_recovery_state)
    end
  end

  defp authority_exact?(authority, persisted) do
    authority[:enrollment_state] in [:manual, :automatic] and
      authority[:repository_iri] == persisted.repository and
      authority[:tenant_iri] == persisted.tenant and
      authority[:source_snapshot_iri] == persisted.source_snapshot and
      authority[:source_fence] == persisted.source_fence and
      persisted.compiler_profile == Protocol.compiler_profile() and
      persisted.compiler_digest == Protocol.compiler_digest()
  end

  defp segments(quads, edition, graph) do
    values =
      resources_of_type(quads, @jf <> "WikiEditionSegment", graph)
      |> Enum.map(fn segment ->
        with [index] <- integers(quads, segment, @jf <> "segmentIndex", graph),
             [digest] <- literals(quads, segment, @jf <> "segmentDigest", graph),
             [count] <- integers(quads, segment, @jf <> "segmentStatementCount", graph),
             [bytes] <- integers(quads, segment, @jf <> "segmentBytes", graph),
             [^edition] <- iris(quads, segment, @jf <> "wikiEdition", graph) do
          %{
            iri: segment,
            index: index,
            digest: digest,
            statement_count: count,
            content_bytes: bytes,
            predecessor_iri:
              case iris(quads, segment, @jf <> "predecessorWikiSegment", graph) do
                [] -> nil
                [predecessor] -> predecessor
                _many -> :corrupt
              end
          }
        else
          _invalid -> :corrupt
        end
      end)
      |> Enum.sort_by(fn
        %{index: index} -> index
        _corrupt -> -1
      end)

    valid? =
      values != [] and
        Enum.with_index(values)
        |> Enum.all?(fn
          {%{index: 0, predecessor_iri: nil}, 0} ->
            true

          {%{index: index, predecessor_iri: predecessor}, index} ->
            predecessor == Enum.at(values, index - 1).iri

          _invalid ->
            false
        end)

    if valid?, do: {:ok, values}, else: corrupt(:repository_wiki_recovery_segments)
  end

  defp graphs_with_type(quads, subject, type) do
    Enum.flat_map(quads, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: @rdf_type}, %RDF.IRI{value: ^type},
       %RDF.IRI{value: graph}} ->
        [graph]

      _other ->
        []
    end)
    |> Enum.uniq()
  end

  defp resources_of_type(quads, type, graph) do
    Enum.flat_map(quads, fn
      {%RDF.IRI{value: subject}, %RDF.IRI{value: @rdf_type}, %RDF.IRI{value: ^type},
       %RDF.IRI{value: ^graph}} ->
        [subject]

      _other ->
        []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp iris(quads, subject, predicate, graph) do
    Enum.flat_map(quads, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: ^predicate}, %RDF.IRI{value: value},
       %RDF.IRI{value: ^graph}} ->
        [value]

      _other ->
        []
    end)
  end

  defp literals(quads, subject, predicate, graph) do
    Enum.flat_map(quads, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: ^predicate}, %RDF.Literal{} = value,
       %RDF.IRI{value: ^graph}} ->
        [RDF.Literal.value(value)]

      _other ->
        []
    end)
  end

  defp integers(quads, subject, predicate, graph),
    do: literals(quads, subject, predicate, graph) |> Enum.filter(&is_integer/1)

  defp one_literal(quads, subject, predicate, graph) do
    case literals(quads, subject, predicate, graph) do
      [value] -> value
      _invalid -> nil
    end
  end

  defp corrupt(operation), do: {:error, Error.new(:corrupt, operation)}
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

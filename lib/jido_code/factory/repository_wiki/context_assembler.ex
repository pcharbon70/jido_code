defmodule JidoCode.Factory.RepositoryWiki.ContextAssembler do
  @moduledoc """
  Adds reviewed repository-wiki evidence to the existing bounded host context.

  Direct task/source context is compiled first. Current wiki evidence is then
  ranked ahead of optional memory evidence under the same item, byte, and token
  budget. All wiki content is serialized inside an advisory, non-instructional
  boundary and only identities/digests enter launch metadata.
  """

  alias JidoCode.Factory.Harness.ContextCompiler
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @type disabled :: :disabled | nil

  @spec compile(map(), disabled() | map(), disabled() | map(), keyword()) ::
          {:ok, ContextCompiler.t()} | {:error, Error.t()}
  def compile(attributes, memory, wiki, options \\ [])

  def compile(attributes, memory, wiki, options)
      when is_map(attributes) and is_list(options) and wiki in [:disabled, nil] do
    ContextCompiler.compile_with_memory(attributes, memory, options)
  end

  def compile(attributes, memory, wiki, options)
      when is_map(attributes) and is_list(options) do
    with :ok <- validate_wiki(wiki, attributes),
         {:ok, memory_packet} <- validate_memory(memory),
         {:ok, base} <- ContextCompiler.compile(attributes, options),
         {:ok, wiki_items, wiki_omissions} <- wiki_items(wiki, attributes),
         {:ok, memory_items, memory_omissions} <- memory_items(memory_packet, attributes),
         candidates <- deduplicate(wiki_items, memory_items, attributes),
         {:ok, selected, budget_omissions} <- select(candidates, base, attributes.budget),
         omissions <- base.omissions ++ wiki_omissions ++ memory_omissions ++ budget_omissions,
         {:ok, source_graphs} <- source_graphs(base, wiki, selected),
         serialized <- serialize(base, wiki, memory_packet, selected),
         true <- byte_size(serialized) <= attributes.budget.max_bytes,
         true <- token_estimate(serialized) <= attributes.budget.max_tokens,
         digest <- sha256(serialized),
         {:ok, manifest} <-
           manifest(
             base,
             wiki,
             memory_packet,
             selected,
             omissions,
             source_graphs,
             serialized,
             digest
           ) do
      {:ok,
       %ContextCompiler{
         manifest: manifest,
         items: base.items ++ selected,
         serialized: serialized,
         digest: digest,
         omissions: omissions,
         retrievals: base.retrievals ++ Enum.map(selected, & &1.retrieval),
         revision_pins: revision_pins(base, wiki, memory_packet)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:compile_repository_wiki_context)
    end
  rescue
    _error -> invalid(:compile_repository_wiki_context)
  end

  def compile(_attributes, _memory, _wiki, _options),
    do: invalid(:compile_repository_wiki_context)

  @spec stale?(ContextCompiler.t(), map()) :: boolean()
  def stale?(%ContextCompiler{revision_pins: %{repository_wiki_context: pins}}, current)
      when is_map(current) do
    Enum.any?(pins, fn {key, expected} -> current[key] != expected end) or
      current[:enrollment_visible?] != true or current[:task_authorized?] != true
  end

  def stale?(%ContextCompiler{}, _current), do: false

  defp validate_wiki(wiki, attributes) do
    profile = Knowledge.repository_wiki_context_profile()

    cond do
      not Knowledge.repository_wiki_context_packet?(wiki) ->
        invalid(:repository_wiki_context_packet)

      wiki.revision != Knowledge.repository_wiki_context_revision() ->
        invalid(:repository_wiki_context_revision)

      wiki.profile_key != profile.key or wiki.profile_digest != profile.digest ->
        stale(:repository_wiki_context_profile)

      wiki.non_authoritative? != true or wiki.preview_context? != false ->
        invalid(:repository_wiki_context_authority)

      wiki.attempt_iri != attributes[:attempt_iri] ->
        stale(:repository_wiki_context_attempt)

      wiki.repository_iri != attributes[:repository_iri] ->
        {:error, Error.new(:unauthorized, :repository_wiki_context_repository)}

      wiki.source_snapshot_iri != attributes[:snapshot_iri] ->
        stale(:repository_wiki_context_source)

      not digest?(wiki.digest) or not digest?(wiki.edition_root) or
          not digest?(wiki.compiler_digest) ->
        invalid(:repository_wiki_context_digest)

      true ->
        :ok
    end
  end

  defp validate_memory(value) when value in [:disabled, nil], do: {:ok, nil}

  defp validate_memory(packet) when is_map(packet) do
    if Knowledge.memory_evidence_packet?(packet),
      do: {:ok, packet},
      else: invalid(:repository_wiki_context_memory)
  end

  defp validate_memory(_memory), do: invalid(:repository_wiki_context_memory)

  defp wiki_items(wiki, attributes) do
    maximum = attributes.budget.max_item_bytes

    wiki.fragments
    |> Enum.reduce_while({:ok, [], []}, fn fragment, {:ok, items, omissions} ->
      full =
        canonical_json(%{
          boundary: :untrusted_repository_wiki_data,
          authority: false,
          advisory: true,
          page_kind: fragment.page_kind,
          page_class: fragment.page_class,
          authority_class: fragment.authority_class,
          provenance: fragment.provenance,
          quoted_content: fragment.content
        })

      required? = fragment.page_class == :known_gaps or fragment.contradictory?

      {content, summarized?, omission} =
        if byte_size(full) <= maximum do
          {full, false, nil}
        else
          summary =
            canonical_json(%{
              boundary: :untrusted_repository_wiki_data,
              authority: false,
              advisory: true,
              page_iri: fragment.page_iri,
              fragment_iri: fragment.iri,
              content_digest: fragment.content_digest,
              provenance_digest: fragment.provenance_digest,
              payload_omitted: true
            })

          {summary, true, omission(fragment, :item_byte_limit)}
        end

      if byte_size(content) <= maximum do
        item = %{
          iri: fragment.iri,
          source: :repository_wiki,
          page_iri: fragment.page_iri,
          page_class: fragment.page_class,
          authority_class: fragment.authority_class,
          classification: fragment.classification,
          confidence_basis_points: fragment.confidence_basis_points,
          contradictory?: fragment.contradictory?,
          required?: required?,
          source_iris: fragment.source_iris,
          source_digests: fragment.source_digests,
          original_content_digest: fragment.content_digest,
          content: content,
          digest: sha256(content),
          bytes: byte_size(content),
          estimated_tokens: token_estimate(content),
          provenance_digest: fragment.provenance_digest,
          summarized?: summarized?,
          retrieval: %{
            source: :repository_wiki,
            edition_iri: wiki.edition_iri,
            edition_root: wiki.edition_root,
            page_iri: fragment.page_iri,
            fragment_iri: fragment.iri,
            source_iris: fragment.source_iris,
            source_revision: wiki.source_revision,
            packet_digest: wiki.digest
          }
        }

        next_omissions = if is_nil(omission), do: omissions, else: [omission | omissions]
        {:cont, {:ok, [item | items], next_omissions}}
      else
        {:halt, invalid(:repository_wiki_context_item)}
      end
    end)
    |> case do
      {:ok, items, omissions} -> {:ok, Enum.reverse(items), Enum.reverse(omissions)}
      error -> error
    end
  end

  defp memory_items(nil, _attributes), do: {:ok, [], []}

  defp memory_items(packet, attributes) do
    maximum = attributes.budget.max_item_bytes

    packet.items
    |> Enum.reduce_while({:ok, [], []}, fn item, {:ok, items, omissions} ->
      full =
        canonical_json(%{
          boundary: :non_instructional_evidence_data,
          authority: false,
          evidence: item
        })

      {content, summarized?, omission} =
        if byte_size(full) <= maximum do
          {full, false, nil}
        else
          summary =
            canonical_json(%{
              boundary: :non_instructional_evidence_data,
              authority: false,
              evidence: %{
                iri: item.iri,
                source_iri: item.source_iri,
                original_digest: sha256(full),
                recovery_handle: item.recovery_handle,
                payload_omitted: true
              }
            })

          {summary, true, %{kind: :memory_evidence, item_iri: item.iri, reason: :item_budget}}
        end

      if byte_size(content) <= maximum do
        memory_item = %{
          iri: item.iri,
          source: :memory,
          source_iri: item.source_iri,
          source_iris: [item.source_iri],
          source_digests: [],
          classification: item.classification,
          trust: item.trust,
          reconstruction:
            if(item.recovery_handle.exact_content_permit_required?,
              do: :recoverable_reference,
              else: :semantic_only
            ),
          packet_digest: packet.digest,
          required?: false,
          confidence_basis_points: memory_confidence(item),
          content: content,
          digest: sha256(content),
          bytes: byte_size(content),
          estimated_tokens: token_estimate(content),
          provenance_digest: Knowledge.repository_wiki_digest(item.recovery_handle),
          summarized?: summarized?,
          retrieval: item.recovery_handle
        }

        next_omissions = if is_nil(omission), do: omissions, else: [omission | omissions]
        {:cont, {:ok, [memory_item | items], next_omissions}}
      else
        {:halt, invalid(:repository_wiki_context_memory_item)}
      end
    end)
    |> case do
      {:ok, items, omissions} ->
        packet_omissions =
          Enum.map(
            packet.omissions,
            &%{kind: :memory_evidence, item_iri: &1.iri, reason: &1.reason}
          )

        {:ok, Enum.reverse(items), packet_omissions ++ Enum.reverse(omissions)}

      error ->
        error
    end
  end

  defp deduplicate(wiki_items, memory_items, attributes) do
    accepted_digests = MapSet.new(Map.get(attributes, :accepted_source_digests, []))

    {wiki_items, wiki_duplicate_omissions} =
      wiki_items
      |> Enum.uniq_by(&{&1.original_content_digest, &1.source_iris, &1.source_digests})
      |> Enum.split_with(fn item ->
        not MapSet.member?(accepted_digests, item.original_content_digest) and
          MapSet.disjoint?(accepted_digests, MapSet.new(item.source_digests))
      end)

    wiki_sources = wiki_items |> Enum.flat_map(& &1.source_iris) |> MapSet.new()

    {memory_items, memory_duplicate_omissions} =
      Enum.split_with(memory_items, fn item ->
        MapSet.disjoint?(wiki_sources, MapSet.new(item.source_iris))
      end)

    ordered =
      Enum.sort_by(wiki_items, &wiki_rank/1) ++
        Enum.sort_by(memory_items, &memory_rank/1)

    duplicate_omissions =
      Enum.map(wiki_duplicate_omissions, &omission(&1, :source_digest_duplicate)) ++
        Enum.map(memory_duplicate_omissions, &omission(&1, :source_relationship_duplicate))

    {ordered, duplicate_omissions}
  end

  defp select({candidates, duplicate_omissions}, base, budget) do
    usage = %{
      items: length(base.items),
      bytes: byte_size(base.serialized),
      tokens: token_estimate(base.serialized)
    }

    candidates
    |> Enum.reduce_while({:ok, [], duplicate_omissions, usage}, fn item,
                                                                   {:ok, selected, omitted,
                                                                    current} ->
      reason = budget_reason(item, current, budget)

      cond do
        is_nil(reason) ->
          next = %{
            items: current.items + 1,
            bytes: current.bytes + item.bytes,
            tokens: current.tokens + item.estimated_tokens
          }

          {:cont, {:ok, [item | selected], omitted, next}}

        item.required? ->
          {:halt, invalid(:repository_wiki_context_required_item)}

        true ->
          {:cont, {:ok, selected, [omission(item, reason) | omitted], current}}
      end
    end)
    |> case do
      {:ok, selected, omissions, _usage} ->
        {:ok, Enum.reverse(selected), Enum.reverse(omissions)}

      error ->
        error
    end
  end

  defp budget_reason(item, usage, budget) do
    cond do
      usage.items + 1 > budget.max_items -> :item_budget
      usage.bytes + item.bytes > budget.max_bytes -> :byte_budget
      usage.tokens + item.estimated_tokens > budget.max_tokens -> :token_budget
      true -> nil
    end
  end

  defp source_graphs(base, wiki, selected) do
    wiki_graph = {wiki.wiki_graph_iri, wiki.wiki_graph_revision}

    memory_graphs =
      selected
      |> Enum.filter(&(&1.source == :memory))
      |> Enum.map(fn item ->
        {item.retrieval.graph_iri, item.retrieval.graph_revision}
      end)

    graphs = base.manifest.source_graphs ++ [wiki_graph] ++ memory_graphs
    grouped = Enum.group_by(graphs, &elem(&1, 0), &elem(&1, 1))

    if length(Map.keys(grouped)) <= 20 and
         Enum.all?(grouped, fn {_graph, revisions} -> length(Enum.uniq(revisions)) == 1 end) do
      {:ok, graphs |> Enum.uniq() |> Enum.sort()}
    else
      stale(:repository_wiki_context_graph_revisions)
    end
  end

  defp manifest(base, wiki, memory, selected, omissions, source_graphs, serialized, digest) do
    Knowledge.context_manifest(base.manifest.attempt_iri, %{
      index: base.manifest.index,
      digest: digest,
      kind: :host_context,
      reconstruction: if(omissions == [], do: :exact, else: :partial),
      source_graphs: source_graphs,
      items: base.manifest.items ++ Enum.map(selected, &manifest_item/1),
      serialized_bytes: byte_size(serialized),
      estimated_tokens: token_estimate(serialized),
      omissions: Enum.map(omissions, &manifest_omission/1),
      missing_classes: if(omissions == [], do: nil, else: [:retention_gap]),
      retrieval_commitment: memory_commitment(memory),
      wiki_context_commitment: %{
        packet_digest: wiki.digest,
        profile_digest: wiki.profile_digest,
        edition_iri: wiki.edition_iri,
        edition_root: wiki.edition_root
      }
    })
  end

  defp serialize(base, wiki, memory, selected) do
    wiki_items = selected |> Enum.filter(&(&1.source == :repository_wiki))
    memory_items = selected |> Enum.filter(&(&1.source == :memory))

    document = %{
      contract: "jido-code-context/1.2.0",
      instruction_context: Jason.decode!(base.serialized),
      repository_wiki_evidence: %{
        boundary: :untrusted_non_instructional_data,
        authority: false,
        advisory: true,
        packet_digest: wiki.digest,
        profile_key: wiki.profile_key,
        profile_digest: wiki.profile_digest,
        edition_iri: wiki.edition_iri,
        edition_root: wiki.edition_root,
        source_revision: wiki.source_revision,
        items: Enum.map(wiki_items, &Jason.decode!(&1.content))
      }
    }

    document =
      if is_nil(memory) do
        document
      else
        Map.put(document, :memory_evidence, %{
          boundary: :non_instructional_data,
          authority: false,
          packet_iri: memory.iri,
          packet_digest: memory.digest,
          items: Enum.map(memory_items, &Jason.decode!(&1.content))
        })
      end

    canonical_json(document)
  end

  defp revision_pins(base, wiki, memory) do
    wiki_pins = %{
      actor_iri: wiki.actor_iri,
      tenant_iri: wiki.tenant_iri,
      repository_iri: wiki.repository_iri,
      task_iri: wiki.task_iri,
      session_iri: wiki.session_iri,
      attempt_iri: wiki.attempt_iri,
      source_snapshot_iri: wiki.source_snapshot_iri,
      source_revision: wiki.source_revision,
      enrollment_revision: wiki.enrollment_revision,
      edition_iri: wiki.edition_iri,
      edition_root: wiki.edition_root,
      compiler_profile: wiki.compiler_profile,
      compiler_digest: wiki.compiler_digest,
      dataset_revision: wiki.dataset_revision,
      wiki_graph_revision: wiki.wiki_graph_revision,
      profile_digest: wiki.profile_digest
    }

    pins = Map.put(base.revision_pins, :repository_wiki_context, wiki_pins)

    if is_nil(memory) do
      pins
    else
      Map.put(pins, :memory_evidence_packet, %{
        iri: memory.iri,
        digest: memory.digest,
        partition_digest: memory.partition_digest
      })
    end
  end

  defp manifest_item(%{source: :memory} = item) do
    %{
      iri: item.iri,
      digest: item.digest,
      bytes: item.bytes,
      classification: item.classification,
      provenance_digest: item.provenance_digest,
      kind: :memory_evidence,
      source_iri: item.source_iri,
      trust: item.trust,
      reconstruction: item.reconstruction,
      packet_digest: item.packet_digest
    }
  end

  defp manifest_item(item) do
    %{
      iri: item.iri,
      digest: item.digest,
      bytes: item.bytes,
      classification: item.classification,
      provenance_digest: item.provenance_digest
    }
  end

  defp memory_commitment(nil), do: nil

  defp memory_commitment(packet) do
    %{
      request_iri: packet.request_iri,
      packet_iri: packet.iri,
      packet_digest: packet.digest,
      partition_digest: packet.partition_digest,
      query_version: packet.query_version,
      ranking_version: packet.ranking_version,
      index_version: packet.index_version
    }
  end

  defp memory_confidence(%{trust: :verified}), do: 6_500
  defp memory_confidence(%{trust: :accepted}), do: 5_500
  defp memory_confidence(_item), do: 3_000

  defp wiki_rank(item) do
    gap = if item.page_class == :known_gaps, do: 0, else: 1
    contradiction = if item.contradictory?, do: 0, else: 1
    authored = if item.authority_class == :authored, do: 0, else: 1

    {gap, contradiction, authored, -item.confidence_basis_points, item.page_class, item.iri}
  end

  defp memory_rank(item), do: {-item.confidence_basis_points, item.iri}

  defp omission(item, reason) do
    %{
      kind: if(item.source == :repository_wiki, do: :repository_wiki, else: :memory_evidence),
      item_iri: item.iri,
      reason: reason
    }
  end

  defp manifest_omission(%{kind: kind, reason: reason}),
    do: %{class: to_string(kind), reason: to_string(reason)}

  defp manifest_omission(%{reason: reason}),
    do: %{class: "repository_wiki", reason: to_string(reason)}

  defp canonical_json(%DateTime{} = value), do: Jason.encode!(DateTime.to_iso8601(value))

  defp canonical_json(value) when is_map(value) do
    value = if Map.has_key?(value, :__struct__), do: Map.from_struct(value), else: value

    value
    |> Enum.map(fn {key, item} -> {to_string(key), item} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join(",", fn {key, item} -> Jason.encode!(key) <> ":" <> canonical_json(item) end)
    |> then(&("{" <> &1 <> "}"))
  end

  defp canonical_json(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &canonical_json/1) <> "]"

  defp canonical_json(value) when is_atom(value) and value not in [true, false, nil],
    do: Jason.encode!(Atom.to_string(value))

  defp canonical_json(value), do: Jason.encode!(value)
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp token_estimate(value), do: div(byte_size(value) + 3, 4)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp stale(operation), do: {:error, Error.new(:stale_precondition, operation)}
end

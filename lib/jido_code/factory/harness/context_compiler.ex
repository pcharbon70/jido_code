defmodule JidoCode.Factory.Harness.ContextCompiler do
  @moduledoc """
  Compiles deterministic, revision-pinned model context from reviewed queries.

  Query receipts are checked for their exact query identity, dataset and graph
  revisions, completeness, freshness, and truncation before serialization.
  Oversized results become explicitly linked summaries with just-in-time
  retrieval descriptors; a branch tip, nearby snapshot, cache, or index is
  never substituted for the requested revision.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @section_order ~w[
    system_contract authority_summary task policy_repository graph_resource
    source_excerpt tool_definition observation objective_checklist
  ]a
  @classifications ~w[public internal confidential]a
  @required ~w[
    attempt_iri manifest_index repository_iri snapshot_iri analysis_profile
    expected_dataset_revision source_graph_revisions authority scope_iri sections budget
  ]a
  @max_sections 200
  @max_graphs 20
  @max_bytes 262_144
  @max_tokens 65_536
  @max_item_bytes 32_768

  @enforce_keys [
    :manifest,
    :items,
    :serialized,
    :digest,
    :omissions,
    :retrievals,
    :revision_pins
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec compile(map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def compile(attributes, options \\ [])

  def compile(attributes, options) when is_map(attributes) and is_list(options) do
    with true <- Enum.all?(@required, &Map.has_key?(attributes, &1)),
         :ok <- validate_identity_pins(attributes),
         {:ok, budget} <- validate_budget(attributes.budget),
         {:ok, sections} <- validate_sections(attributes.sections, attributes),
         {:ok, resolved} <- resolve_sections(sections, attributes, options),
         {:ok, selected, omissions, retrievals} <- select(resolved, attributes, budget),
         serialized <- serialize(selected, attributes),
         true <- byte_size(serialized) <= budget.max_bytes,
         true <- token_estimate(serialized) <= budget.max_tokens,
         digest <- sha256(serialized),
         {:ok, manifest} <-
           Knowledge.context_manifest(attributes.attempt_iri, %{
             index: attributes.manifest_index,
             digest: digest,
             kind: :host_context,
             reconstruction: if(omissions == [], do: :exact, else: :partial),
             source_graphs: Map.to_list(attributes.source_graph_revisions),
             items: Enum.map(selected, &manifest_item/1),
             serialized_bytes: byte_size(serialized),
             estimated_tokens: token_estimate(serialized),
             omissions: Enum.map(omissions, &manifest_omission/1),
             missing_classes: if(omissions == [], do: nil, else: [:retention_gap])
           }) do
      {:ok,
       %__MODULE__{
         manifest: manifest,
         items: selected,
         serialized: serialized,
         digest: digest,
         omissions: omissions,
         retrievals: retrievals,
         revision_pins: revision_pins(attributes)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:compile_model_context)
    end
  rescue
    _error -> invalid(:compile_model_context)
  end

  def compile(_attributes, _options), do: invalid(:compile_model_context)

  @doc """
  Compiles ordinary context and, when supplied, appends a structurally separate
  non-instructional evidence packet. Disabled mode delegates directly to
  `compile/2`, preserving bit-identical context, authorization, and tool input.
  """
  @spec compile_with_memory(map(), :disabled | nil | map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def compile_with_memory(attributes, memory, options \\ [])

  def compile_with_memory(attributes, memory, options) when memory in [:disabled, nil],
    do: compile(attributes, options)

  def compile_with_memory(attributes, packet, options)
      when is_map(attributes) and is_list(options) do
    with true <- Knowledge.memory_evidence_packet?(packet),
         {:ok, base} <- compile(attributes, options),
         {:ok, memory_items, memory_omissions} <-
           memory_items(packet, attributes.budget.max_item_bytes),
         {:ok, source_graphs} <- merge_source_graphs(base.manifest.source_graphs, memory_items),
         serialized <- serialize_with_memory(base, packet, memory_items),
         true <- byte_size(serialized) <= attributes.budget.max_bytes,
         true <- token_estimate(serialized) <= attributes.budget.max_tokens,
         true <- length(base.items) + length(memory_items) <= attributes.budget.max_items,
         digest <- sha256(serialized),
         omissions <- base.omissions ++ packet_omissions(packet) ++ memory_omissions,
         {:ok, manifest} <-
           Knowledge.context_manifest(attributes.attempt_iri, %{
             index: attributes.manifest_index,
             digest: digest,
             kind: :host_context,
             reconstruction: if(omissions == [], do: :exact, else: :partial),
             source_graphs: source_graphs,
             items: base.manifest.items ++ Enum.map(memory_items, &memory_manifest_item/1),
             serialized_bytes: byte_size(serialized),
             estimated_tokens: token_estimate(serialized),
             omissions: Enum.map(omissions, &manifest_omission/1),
             missing_classes: if(omissions == [], do: nil, else: [:retention_gap]),
             retrieval_commitment: %{
               request_iri: packet.request_iri,
               packet_iri: packet.iri,
               packet_digest: packet.digest,
               partition_digest: packet.partition_digest,
               query_version: packet.query_version,
               ranking_version: packet.ranking_version,
               index_version: packet.index_version
             }
           }) do
      {:ok,
       %__MODULE__{
         manifest: manifest,
         items: base.items ++ memory_items,
         serialized: serialized,
         digest: digest,
         omissions: omissions,
         retrievals: base.retrievals ++ Enum.map(memory_items, & &1.recovery_handle),
         revision_pins:
           Map.put(base.revision_pins, :memory_evidence_packet, %{
             iri: packet.iri,
             digest: packet.digest,
             partition_digest: packet.partition_digest
           })
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:compile_memory_context)
    end
  rescue
    _error -> invalid(:compile_memory_context)
  end

  def compile_with_memory(_attributes, _memory, _options),
    do: invalid(:compile_memory_context)

  @spec section_order() :: [atom()]
  def section_order, do: @section_order

  defp validate_identity_pins(attributes) do
    revisions = attributes.source_graph_revisions

    cond do
      Knowledge.validate_resource_identity(attributes.attempt_iri) != :ok ->
        invalid(:context_attempt_identity)

      Knowledge.validate_resource_identity(attributes.repository_iri) != :ok ->
        invalid(:context_repository_identity)

      Knowledge.validate_resource_identity(attributes.snapshot_iri) != :ok ->
        invalid(:context_snapshot_identity)

      Knowledge.validate_resource_identity(attributes.scope_iri) != :ok ->
        invalid(:context_scope_identity)

      not is_integer(attributes.manifest_index) or attributes.manifest_index < 0 ->
        invalid(:context_manifest_index)

      not is_binary(attributes.analysis_profile) or
          byte_size(attributes.analysis_profile) not in 1..128 ->
        invalid(:context_analysis_profile)

      not is_integer(attributes.expected_dataset_revision) or
          attributes.expected_dataset_revision < 0 ->
        invalid(:context_dataset_revision)

      not is_map(revisions) or map_size(revisions) not in 1..@max_graphs ->
        invalid(:context_graph_revisions)

      not Enum.all?(revisions, fn {graph, revision} ->
        match?({:ok, _family}, Knowledge.validate_graph_identity(graph)) and
          is_integer(revision) and revision >= 0
      end) ->
        invalid(:context_graph_revisions)

      true ->
        :ok
    end
  end

  defp validate_budget(
         %{
           max_items: items,
           max_bytes: bytes,
           max_tokens: tokens,
           max_item_bytes: item_bytes
         } = budget
       )
       when items in 1..@max_sections and bytes in 1..@max_bytes and
              tokens in 1..@max_tokens and item_bytes in 512..@max_item_bytes do
    {:ok, Map.take(budget, [:max_items, :max_bytes, :max_tokens, :max_item_bytes])}
  end

  defp validate_budget(_budget), do: invalid(:context_compiler_budget)

  defp validate_sections(sections, attributes)
       when is_list(sections) and sections != [] and length(sections) <= @max_sections do
    sections
    |> Enum.reduce_while({:ok, []}, fn section, {:ok, acc} ->
      case validate_section(section, attributes) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} ->
        {:ok,
         Enum.sort_by(values, fn section ->
           {Enum.find_index(@section_order, &(&1 == section.kind)), section.query_name,
            section.item_iri}
         end)}

      error ->
        error
    end
  end

  defp validate_sections(_sections, _attributes), do: invalid(:context_compiler_sections)

  defp validate_section(section, attributes) when is_map(section) do
    graphs = section[:graph_revisions]

    with kind when kind in @section_order <- section[:kind],
         query_name when is_atom(query_name) <- section[:query_name],
         query_version when is_binary(query_version) and byte_size(query_version) in 1..32 <-
           section[:query_version],
         {:ok, _definition} <- Knowledge.reviewed_query(query_name, query_version),
         parameters when is_map(parameters) <- section[:parameters],
         :ok <- Knowledge.validate_resource_identity(section[:item_iri]),
         classification when classification in @classifications <- section[:classification],
         true <- is_map(graphs) and graphs != %{},
         true <- Map.take(attributes.source_graph_revisions, Map.keys(graphs)) == graphs,
         true <- section[:repository_iri] == attributes.repository_iri,
         true <- section[:snapshot_iri] == attributes.snapshot_iri,
         true <- section[:analysis_profile] == attributes.analysis_profile do
      {:ok,
       %{
         kind: kind,
         query_name: query_name,
         query_version: query_version,
         parameters: parameters,
         item_iri: section.item_iri,
         classification: classification,
         required?: Map.get(section, :required?, false) == true,
         graph_revisions: graphs
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:context_compiler_section)
    end
  end

  defp validate_section(_section, _attributes), do: invalid(:context_compiler_section)

  defp resolve_sections(sections, attributes, options) do
    query = Keyword.get(options, :query, &Knowledge.query/6)
    query_options = Keyword.get(options, :query_options, [])

    if is_function(query, 6) and is_list(query_options) do
      Enum.reduce_while(sections, {:ok, []}, fn section, {:ok, acc} ->
        case query.(
               section.query_name,
               section.query_version,
               section.parameters,
               attributes.authority,
               attributes.scope_iri,
               query_options
             ) do
          {:ok, result} ->
            case result_item(result, section, attributes) do
              {:ok, item} -> {:cont, {:ok, [item | acc]}}
              {:error, %Error{} = error} -> {:halt, {:error, error}}
            end

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}

          _invalid ->
            {:halt, invalid(:context_compiler_query)}
        end
      end)
      |> case do
        {:ok, values} -> {:ok, Enum.reverse(values)}
        error -> error
      end
    else
      invalid(:context_compiler_query)
    end
  end

  defp result_item(result, section, attributes) when is_map(result) do
    with true <- result[:query_name] == section.query_name,
         true <- result[:query_version] == section.query_version,
         true <- result[:dataset_revision] == attributes.expected_dataset_revision,
         true <-
           Map.take(result[:graph_revisions] || %{}, Map.keys(section.graph_revisions)) ==
             section.graph_revisions,
         true <- complete?(result[:completeness]),
         true <- result[:freshness] == :current,
         true <- result[:truncated?] == false,
         content <- canonical_json(result[:data]),
         true <- content != "" do
      provenance = %{
        query_name: section.query_name,
        query_version: section.query_version,
        dataset_revision: result.dataset_revision,
        graph_revisions: section.graph_revisions,
        repository_iri: attributes.repository_iri,
        snapshot_iri: attributes.snapshot_iri,
        analysis_profile: attributes.analysis_profile
      }

      {:ok,
       Map.merge(section, %{
         content: content,
         digest: sha256(content),
         bytes: byte_size(content),
         provenance: provenance,
         provenance_digest: digest_term(provenance),
         summarized?: false
       })}
    else
      _invalid -> {:error, Error.new(:stale_precondition, :compile_model_context)}
    end
  rescue
    _error -> invalid(:context_compiler_result)
  end

  defp result_item(_result, _section, _attributes), do: invalid(:context_compiler_result)

  defp complete?(%{complete?: true}), do: true
  defp complete?(:complete), do: true
  defp complete?(:declared), do: true
  defp complete?(_value), do: false

  defp select(items, attributes, budget) do
    select(items, attributes, budget, [], [], [], %{items: 0, bytes: 0, tokens: 0})
  end

  defp select([], _attributes, _budget, selected, omissions, retrievals, _usage),
    do: {:ok, Enum.reverse(selected), Enum.reverse(omissions), Enum.reverse(retrievals)}

  defp select([item | rest], attributes, budget, selected, omissions, retrievals, usage) do
    {candidate, retrieval} = compact(item, attributes, budget.max_item_bytes)
    candidate_tokens = token_estimate(candidate.content)

    reason =
      cond do
        usage.items + 1 > budget.max_items -> :item_budget
        usage.bytes + candidate.bytes > budget.max_bytes -> :byte_budget
        usage.tokens + candidate_tokens > budget.max_tokens -> :token_budget
        true -> nil
      end

    cond do
      is_nil(reason) ->
        omissions =
          if candidate.summarized? do
            [%{kind: item.kind, item_iri: item.item_iri, reason: :lossy_summary} | omissions]
          else
            omissions
          end

        select(
          rest,
          attributes,
          budget,
          [candidate | selected],
          omissions,
          maybe_prepend(retrieval, retrievals),
          %{
            items: usage.items + 1,
            bytes: usage.bytes + candidate.bytes,
            tokens: usage.tokens + candidate_tokens
          }
        )

      item.required? ->
        invalid(:context_compiler_required_item)

      true ->
        omission = %{kind: item.kind, item_iri: item.item_iri, reason: reason}
        retrieval = retrieval || retrieval(item, attributes, reason)

        select(
          rest,
          attributes,
          budget,
          selected,
          [omission | omissions],
          [retrieval | retrievals],
          usage
        )
    end
  end

  defp compact(item, _attributes, max_item_bytes) when item.bytes <= max_item_bytes,
    do: {item, nil}

  defp compact(item, attributes, _max_item_bytes) do
    summary = %{
      summary_of: item.item_iri,
      original_digest: item.digest,
      original_bytes: item.bytes,
      query_name: item.query_name,
      query_version: item.query_version,
      content_state: :available_by_reviewed_query
    }

    content = canonical_json(summary)

    candidate = %{
      item
      | content: content,
        digest: sha256(content),
        bytes: byte_size(content),
        summarized?: true
    }

    {candidate, retrieval(item, attributes, :lossy_summary)}
  end

  defp retrieval(item, attributes, reason) do
    %{
      item_iri: item.item_iri,
      reason: reason,
      query_name: item.query_name,
      query_version: item.query_version,
      parameters_digest: digest_term(item.parameters),
      repository_iri: attributes.repository_iri,
      snapshot_iri: attributes.snapshot_iri,
      analysis_profile: attributes.analysis_profile,
      dataset_revision: attributes.expected_dataset_revision,
      graph_revisions: item.graph_revisions,
      original_digest: item.digest
    }
  end

  defp serialize(items, attributes) do
    canonical_json(%{
      contract: "jido-code-context/1.0.0",
      pins: revision_pins(attributes),
      sections:
        Enum.map(items, fn item ->
          %{
            kind: item.kind,
            item_iri: item.item_iri,
            classification: item.classification,
            digest: item.digest,
            provenance_digest: item.provenance_digest,
            summarized: item.summarized?,
            content: item.content
          }
        end)
    })
  end

  defp revision_pins(attributes) do
    %{
      repository_iri: attributes.repository_iri,
      snapshot_iri: attributes.snapshot_iri,
      analysis_profile: attributes.analysis_profile,
      dataset_revision: attributes.expected_dataset_revision,
      graph_revisions: attributes.source_graph_revisions
    }
  end

  defp manifest_item(item) do
    %{
      iri: item.item_iri,
      digest: item.digest,
      bytes: item.bytes,
      classification: item.classification,
      provenance_digest: item.provenance_digest
    }
  end

  defp memory_items(packet, max_item_bytes) do
    packet.items
    |> Enum.reduce_while({:ok, [], []}, fn item, {:ok, items, omissions} ->
      case memory_item(item, packet.digest, max_item_bytes) do
        {:ok, memory_item, nil} ->
          {:cont, {:ok, [memory_item | items], omissions}}

        {:ok, memory_item, omission} ->
          {:cont, {:ok, [memory_item | items], [omission | omissions]}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, items, omissions} -> {:ok, Enum.reverse(items), Enum.reverse(omissions)}
      error -> error
    end
  end

  defp memory_item(item, packet_digest, max_item_bytes) do
    full_content =
      canonical_json(%{
        boundary: :non_instructional_evidence_data,
        authority: false,
        evidence: item
      })

    {content, summarized?, omission} =
      if byte_size(full_content) <= max_item_bytes do
        {full_content, false, nil}
      else
        summary =
          canonical_json(%{
            boundary: :non_instructional_evidence_data,
            authority: false,
            evidence: %{
              iri: item.iri,
              source_iri: item.source_iri,
              original_digest: sha256(full_content),
              recovery_handle: item.recovery_handle,
              payload_omitted: true
            }
          })

        {summary, true, %{kind: :memory_evidence, item_iri: item.iri, reason: :item_budget}}
      end

    if byte_size(content) <= max_item_bytes do
      {:ok,
       %{
         kind: :memory_evidence,
         item_iri: item.iri,
         source_iri: item.source_iri,
         classification: item.classification,
         trust: item.trust,
         reconstruction:
           if(item.recovery_handle.exact_content_permit_required?,
             do: :recoverable_reference,
             else: :semantic_only
           ),
         packet_digest: packet_digest,
         content: content,
         digest: sha256(content),
         bytes: byte_size(content),
         provenance_digest: digest_term(item.recovery_handle),
         summarized?: summarized?,
         recovery_handle: item.recovery_handle
       }, omission}
    else
      invalid(:compile_memory_item)
    end
  end

  defp merge_source_graphs(base_graphs, memory_items) do
    references =
      base_graphs ++
        Enum.map(memory_items, fn item ->
          {item.recovery_handle.graph_iri, item.recovery_handle.graph_revision}
        end)

    grouped = Enum.group_by(references, &elem(&1, 0), &elem(&1, 1))

    if Enum.all?(grouped, fn {_graph, revisions} -> length(Enum.uniq(revisions)) == 1 end) do
      {:ok, references |> Enum.uniq() |> Enum.sort()}
    else
      {:error, Error.new(:stale_precondition, :compile_memory_graph_revisions)}
    end
  end

  defp serialize_with_memory(base, packet, memory_items) do
    canonical_json(%{
      contract: "jido-code-context/1.1.0",
      instruction_context: Jason.decode!(base.serialized),
      memory_evidence: %{
        boundary: :non_instructional_data,
        authority: false,
        packet_iri: packet.iri,
        packet_digest: packet.digest,
        items: Enum.map(memory_items, &Jason.decode!(&1.content))
      }
    })
  end

  defp memory_manifest_item(item) do
    %{
      iri: item.item_iri,
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

  defp packet_omissions(packet) do
    Enum.map(packet.omissions, fn omission ->
      %{kind: :memory_evidence, item_iri: omission.iri, reason: omission.reason}
    end)
  end

  defp manifest_omission(omission),
    do: %{class: to_string(omission.kind), reason: to_string(omission.reason)}

  defp maybe_prepend(nil, values), do: values
  defp maybe_prepend(value, values), do: [value | values]

  defp digest_term(value), do: value |> canonical_json() |> sha256()
  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp token_estimate(value), do: div(byte_size(value) + 3, 4)

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

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

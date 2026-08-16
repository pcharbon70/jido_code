defmodule JidoCode.Knowledge.Execution.ContextManifest do
  @moduledoc """
  Immutable, digest-attributed context manifests for governed model calls.

  The first manifest (index 0) is created atomically with its execution
  attempt; later manifests are created atomically with the model-invocation
  start that changed context. A manifest records what JidoCode supplied, its
  reconstruction status, and - for delegated input - explicitly marks
  provider-internal context unavailable rather than inferred.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [:iri, :attempt_iri, :index, :digest, :kind, :reconstruction]
  defstruct @enforce_keys ++
              [
                :source_graphs,
                :items,
                :serialized_bytes,
                :estimated_tokens,
                :omissions,
                :unavailable_fields,
                :missing_classes
              ]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @kinds ~w[host_context delegated_input]a
  @reconstructions ~w[exact partial unavailable]a
  @digest64 ~r/^[a-f0-9]{64}$/

  @max_source_graphs 20
  @max_items 200
  @max_serialized_bytes 262_144
  @max_estimated_tokens 65_536
  @max_item_bytes 32_768
  @max_instruction_bytes 16_384

  @unavailable_field_classes ~w[
    prompts context_assembly memory internal_model_turns tool_manifests
  ]a
  @missing_reconstruction_classes ~w[
    raw_prompt raw_response raw_tool_output provider_session retention_gap
  ]a

  @spec new(String.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attempt_iri, attributes) when is_binary(attempt_iri) and is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attempt_iri),
         index when is_integer(index) and index >= 0 <- attributes[:index],
         digest when is_binary(digest) <- attributes[:digest],
         true <- Regex.match?(@digest64, digest),
         kind when kind in @kinds <- attributes[:kind],
         reconstruction when reconstruction in @reconstructions <-
           attributes[:reconstruction],
         {:ok, source_graphs} <- source_graphs(attributes[:source_graphs]),
         {:ok, items} <- items(attributes[:items]),
         :ok <- totals(source_graphs, items, attributes),
         :ok <- instruction_bound(attributes[:instruction_bytes]),
         {:ok, omissions} <- omissions(attributes[:omissions]),
         :ok <- unavailable_fields(kind, attributes[:unavailable_fields]),
         :ok <- missing_classes(reconstruction, attributes[:missing_classes]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :context_manifest,
             attempt_iri <> "\n" <> Integer.to_string(index)
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attempt_iri,
         index: index,
         digest: digest,
         kind: kind,
         reconstruction: reconstruction,
         source_graphs: source_graphs || [],
         items: items || [],
         serialized_bytes: attributes[:serialized_bytes] || 0,
         estimated_tokens: attributes[:estimated_tokens] || 0,
         omissions: omissions || [],
         unavailable_fields: attributes[:unavailable_fields] || [],
         missing_classes: attributes[:missing_classes] || []
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:context_manifest)
    end
  rescue
    _error -> invalid(:context_manifest)
  end

  def new(_attempt_iri, _attributes), do: invalid(:context_manifest)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = manifest) do
    [
      {manifest.iri, @rdf_type, RDF.iri(@jf <> "ContextManifest")},
      {manifest.iri, @jf <> "manifestOf", RDF.iri(manifest.attempt_iri)},
      {manifest.iri, @jf <> "manifestIndex", RDF.XSD.NonNegativeInteger.new(manifest.index)},
      {manifest.iri, @jf <> "manifestDigest", RDF.XSD.String.new(manifest.digest)},
      {manifest.iri, @jf <> "manifestKind",
       RDF.iri(@concept <> Macro.camelize(to_string(manifest.kind)))},
      {manifest.iri, @jf <> "reconstructionState",
       RDF.iri(@concept <> Macro.camelize(to_string(manifest.reconstruction)))},
      {manifest.iri, @jf <> "serializedBytes",
       RDF.XSD.NonNegativeInteger.new(manifest.serialized_bytes)},
      {manifest.iri, @jf <> "estimatedTokens",
       RDF.XSD.NonNegativeInteger.new(manifest.estimated_tokens)},
      {manifest.iri, @jf <> "itemCount", RDF.XSD.NonNegativeInteger.new(length(manifest.items))}
    ] ++
      graph_reference_statements(manifest) ++
      item_statements(manifest) ++
      omission_statements(manifest) ++
      unavailable_field_statements(manifest) ++
      missing_class_statements(manifest)
  end

  @spec first_manifest_iri(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def first_manifest_iri(attempt_iri) when is_binary(attempt_iri),
    do: ResourceIdentity.deterministic(:context_manifest, attempt_iri <> "\n0")

  def first_manifest_iri(_attempt_iri), do: invalid(:context_manifest)

  defp graph_reference_statements(manifest) do
    Enum.flat_map(manifest.source_graphs, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          manifest.iri <> "\n" <> graph <> "\n" <> Integer.to_string(revision)
        )

      [
        {manifest.iri, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp item_statements(manifest) do
    Enum.map(manifest.items, fn item ->
      {manifest.iri, @jf <> "manifestItem",
       RDF.XSD.String.new(item.iri <> "|" <> item.digest <> "|" <> Integer.to_string(item.bytes))}
    end)
  end

  defp omission_statements(manifest) do
    Enum.map(manifest.omissions, fn omission ->
      {manifest.iri, @jf <> "manifestOmission",
       RDF.XSD.String.new(omission.class <> "|" <> omission.reason)}
    end)
  end

  defp unavailable_field_statements(manifest) do
    Enum.map(manifest.unavailable_fields, fn field ->
      {manifest.iri, @jf <> "providerFieldUnavailable", RDF.XSD.String.new(field)}
    end)
  end

  defp missing_class_statements(manifest) do
    Enum.map(manifest.missing_classes, fn class ->
      {manifest.iri, @jf <> "reconstructionMissing", RDF.XSD.String.new(class)}
    end)
  end

  defp source_graphs(nil), do: {:ok, nil}

  defp source_graphs(values) when is_list(values) do
    if length(values) <= @max_source_graphs and
         Enum.all?(values, fn {graph, revision} ->
           is_binary(graph) and
             match?({:ok, _family}, JidoCode.Knowledge.GraphRegistry.identify(graph)) and
             is_integer(revision) and revision >= 0
         end),
       do: {:ok, values},
       else: invalid(:context_manifest_graphs)
  rescue
    _error -> invalid(:context_manifest_graphs)
  end

  defp source_graphs(_values), do: invalid(:context_manifest_graphs)

  defp items(nil), do: {:ok, nil}

  defp items(values) when is_list(values) do
    if length(values) <= @max_items and
         Enum.all?(values, fn item ->
           is_map(item) and is_binary(item[:iri]) and
             ResourceIdentity.validate(item.iri) == :ok and
             is_binary(item[:digest]) and Regex.match?(@digest64, item.digest) and
             is_integer(item[:bytes]) and item.bytes in 1..@max_item_bytes
         end),
       do: {:ok, values},
       else: invalid(:context_manifest_items)
  rescue
    _error -> invalid(:context_manifest_items)
  end

  defp items(_values), do: invalid(:context_manifest_items)

  defp totals(source_graphs, items, attributes) do
    serialized = attributes[:serialized_bytes] || 0
    tokens = attributes[:estimated_tokens] || 0
    item_bytes = Enum.map(items || [], & &1.bytes)

    cond do
      not is_integer(serialized) or serialized < 0 or serialized > @max_serialized_bytes ->
        :error

      not is_integer(tokens) or tokens < 0 or tokens > @max_estimated_tokens ->
        :error

      Enum.sum(item_bytes) > @max_serialized_bytes ->
        :error

      (source_graphs == nil and items != nil) or (source_graphs != nil and items == nil) ->
        :error

      true ->
        :ok
    end
  end

  defp instruction_bound(nil), do: :ok

  defp instruction_bound(value) when is_integer(value) and value in 1..@max_instruction_bytes,
    do: :ok

  defp instruction_bound(_value), do: :error

  defp omissions(nil), do: {:ok, nil}

  defp omissions(values) when is_list(values) do
    if length(values) <= @max_items and
         Enum.all?(values, fn omission ->
           is_map(omission) and is_binary(omission[:class]) and byte_size(omission.class) in 1..64 and
             is_binary(omission[:reason]) and byte_size(omission.reason) in 1..256
         end),
       do: {:ok, values},
       else: invalid(:context_manifest_omissions)
  rescue
    _error -> invalid(:context_manifest_omissions)
  end

  defp omissions(_values), do: invalid(:context_manifest_omissions)

  defp unavailable_fields(:delegated_input, nil),
    do: invalid(:context_manifest_unavailable_fields)

  defp unavailable_fields(:delegated_input, values) when is_list(values) do
    if values != [] and Enum.all?(values, &(&1 in @unavailable_field_classes)),
      do: :ok,
      else: invalid(:context_manifest_unavailable_fields)
  rescue
    _error -> invalid(:context_manifest_unavailable_fields)
  end

  defp unavailable_fields(_kind, nil), do: :ok

  defp unavailable_fields(_kind, values) when is_list(values),
    do:
      if(Enum.all?(values, &(&1 in @unavailable_field_classes)),
        do: :ok,
        else: invalid(:context_manifest_unavailable_fields)
      )

  defp unavailable_fields(_kind, _values), do: invalid(:context_manifest_unavailable_fields)

  defp missing_classes(reconstruction, _fields) when reconstruction == :exact, do: :ok

  defp missing_classes(_reconstruction, nil), do: invalid(:context_manifest_missing)

  defp missing_classes(_reconstruction, values) when is_list(values) do
    if values != [] and Enum.all?(values, &(&1 in @missing_reconstruction_classes)),
      do: :ok,
      else: invalid(:context_manifest_missing)
  rescue
    _error -> invalid(:context_manifest_missing)
  end

  defp missing_classes(_reconstruction, _values), do: invalid(:context_manifest_missing)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

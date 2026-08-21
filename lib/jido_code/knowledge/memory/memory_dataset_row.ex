defmodule JidoCode.Knowledge.Memory.MemoryDatasetRow do
  @moduledoc "Payload-free dataset row identity with exact chronological source lineage."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @outcomes ~w[success failure revert flake infrastructure ambiguous]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @forbidden_keys ~w[payload plaintext prompt hidden_reasoning provider_private personal_data]a

  @enforce_keys [
    :iri,
    :revision,
    :manifest_iri,
    :repository_iri,
    :task_iri,
    :patch_digest,
    :incident_iri,
    :classification,
    :outcome,
    :split,
    :effective_at,
    :source_resource_iris,
    :semantic_digest,
    :representation_digest,
    :erasure_generation,
    :status
  ]
  defstruct @enforce_keys

  def outcomes, do: @outcomes

  def new(%MemoryDatasetManifest{} = manifest, attributes) when is_map(attributes) do
    with true <- Enum.all?(@forbidden_keys, &(not Map.has_key?(attributes, &1))),
         true <- attributes[:repository_iri] in manifest.repository_iris,
         :ok <- ResourceIdentity.validate(attributes[:task_iri]),
         true <- optional_resource?(attributes[:incident_iri]),
         true <- digest?(attributes[:patch_digest]),
         true <- attributes[:classification] in manifest.classifications,
         true <- attributes[:outcome] in @outcomes,
         true <-
           attributes[:split] == Map.fetch!(manifest.split_policy, attributes.repository_iri),
         %DateTime{} = effective_at <- attributes[:effective_at],
         true <- DateTime.compare(effective_at, manifest.cutoff) in [:lt, :eq],
         {:ok, sources} <- exact_sources(attributes[:source_resource_iris]),
         true <- Enum.all?(sources, &(&1 in manifest.source_resource_iris)),
         true <- digest?(attributes[:semantic_digest]),
         true <- digest?(attributes[:representation_digest]),
         true <-
           attributes[:erasure_generation] ==
             Map.fetch!(manifest.erasure_generations, attributes.repository_iri),
         {:ok, iri} <- identity(manifest, attributes, sources) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         manifest_iri: manifest.iri,
         repository_iri: attributes.repository_iri,
         task_iri: attributes.task_iri,
         patch_digest: attributes.patch_digest,
         incident_iri: attributes[:incident_iri],
         classification: attributes.classification,
         outcome: attributes.outcome,
         split: attributes.split,
         effective_at: DateTime.truncate(effective_at, :microsecond),
         source_resource_iris: sources,
         semantic_digest: attributes.semantic_digest,
         representation_digest: attributes.representation_digest,
         erasure_generation: attributes.erasure_generation,
         status: :available
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_manifest, _attributes), do: invalid()

  def statements(%__MODULE__{} = row) do
    [
      {row.iri, @rdf_type, RDF.iri(@jf <> "MemoryDatasetRow")},
      {row.iri, @jf <> "datasetManifest", RDF.iri(row.manifest_iri)},
      {row.iri, @jf <> "repository", RDF.iri(row.repository_iri)},
      {row.iri, @jf <> "task", RDF.iri(row.task_iri)},
      {row.iri, @jf <> "patchDigest", RDF.XSD.String.new(row.patch_digest)},
      {row.iri, @jf <> "classification", concept(row.classification)},
      {row.iri, @jf <> "outcome", concept(row.outcome)},
      {row.iri, @jf <> "split", concept(row.split)},
      {row.iri, @jf <> "effectiveAt", RDF.XSD.DateTime.new(row.effective_at)},
      {row.iri, @jf <> "semanticDigest", RDF.XSD.String.new(row.semantic_digest)},
      {row.iri, @jf <> "representationDigest", RDF.XSD.String.new(row.representation_digest)},
      {row.iri, @jf <> "erasureGeneration",
       RDF.XSD.NonNegativeInteger.new(row.erasure_generation)},
      {row.iri, @jf <> "datasetRowState", concept(row.status)}
    ] ++
      optional_iri(row.iri, @jf <> "incident", row.incident_iri) ++
      Enum.map(row.source_resource_iris, &{row.iri, @jf <> "sourceResource", RDF.iri(&1)})
  end

  defp identity(manifest, attributes, sources) do
    ResourceIdentity.deterministic(
      :memory_dataset_row,
      Enum.join(
        [
          manifest.iri,
          attributes.repository_iri,
          attributes.task_iri,
          attributes.patch_digest,
          attributes[:incident_iri] || "none",
          Atom.to_string(attributes.classification),
          Atom.to_string(attributes.outcome),
          Atom.to_string(attributes.split),
          DateTime.to_iso8601(attributes.effective_at),
          Enum.join(sources, "\n"),
          attributes.semantic_digest,
          attributes.representation_digest,
          Integer.to_string(attributes.erasure_generation)
        ],
        "\n"
      )
    )
  end

  defp exact_sources(values) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if normalized != [] and normalized == Enum.sort(values) and length(normalized) <= 100 and
         Enum.all?(normalized, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, normalized},
       else: :error
  end

  defp exact_sources(_values), do: :error
  defp optional_resource?(nil), do: true
  defp optional_resource?(value), do: ResourceIdentity.validate(value) == :ok
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, value), do: [{subject, predicate, RDF.iri(value)}]

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_dataset_row)}
end

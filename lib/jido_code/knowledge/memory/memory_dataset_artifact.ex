defmodule JidoCode.Knowledge.Memory.MemoryDatasetArtifact do
  @moduledoc "Graph-authoritative metadata for an externally stored dataset payload."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.DatasetExportPermit
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @forbidden_keys ~w[payload bytes rows plaintext]a

  @enforce_keys [
    :iri,
    :revision,
    :manifest_iri,
    :permit_iri,
    :authorization_iri,
    :sink_iri,
    :dataset_digest,
    :schema_revision,
    :row_count,
    :byte_count,
    :source_row_iris,
    :external_copy_iris,
    :availability_state,
    :created_at,
    :payload_external?
  ]
  defstruct @enforce_keys

  def new(
        %MemoryDatasetManifest{} = manifest,
        %DatasetExportPermit{} = permit,
        attributes
      )
      when is_map(attributes) do
    with true <- Enum.all?(@forbidden_keys, &(not Map.has_key?(attributes, &1))),
         true <- permit.manifest_iri == manifest.iri,
         true <- permit.authorization_iri == manifest.authorization_iri,
         true <- permit.state == :issued,
         true <- digest?(attributes[:dataset_digest]),
         true <- revision?(attributes[:schema_revision]),
         true <- is_integer(attributes[:row_count]) and attributes[:row_count] > 0,
         true <- attributes[:row_count] <= permit.row_limit,
         true <- is_integer(attributes[:byte_count]) and attributes[:byte_count] > 0,
         true <- attributes[:byte_count] <= permit.byte_limit,
         {:ok, rows} <- resources(attributes[:source_row_iris], attributes.row_count),
         true <- length(rows) == attributes.row_count,
         {:ok, copies} <- resources(attributes[:external_copy_iris], 20),
         true <- copies != [],
         %DateTime{} = created_at <- attributes[:created_at],
         {:ok, iri} <- identity(manifest, permit, attributes, rows, copies) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         manifest_iri: manifest.iri,
         permit_iri: permit.iri,
         authorization_iri: manifest.authorization_iri,
         sink_iri: permit.sink_iri,
         dataset_digest: attributes.dataset_digest,
         schema_revision: attributes.schema_revision,
         row_count: attributes.row_count,
         byte_count: attributes.byte_count,
         source_row_iris: rows,
         external_copy_iris: copies,
         availability_state: :available,
         created_at: DateTime.truncate(created_at, :microsecond),
         payload_external?: true
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_manifest, _permit, _attributes), do: invalid()

  def statements(%__MODULE__{} = artifact) do
    [
      {artifact.iri, @rdf_type, RDF.iri(@jf <> "MemoryDatasetArtifact")},
      {artifact.iri, @jf <> "datasetManifest", RDF.iri(artifact.manifest_iri)},
      {artifact.iri, @jf <> "exportPermit", RDF.iri(artifact.permit_iri)},
      {artifact.iri, @jf <> "authorization", RDF.iri(artifact.authorization_iri)},
      {artifact.iri, @jf <> "approvedSink", RDF.iri(artifact.sink_iri)},
      {artifact.iri, @jf <> "datasetDigest", RDF.XSD.String.new(artifact.dataset_digest)},
      {artifact.iri, @jf <> "schemaRevision", RDF.XSD.String.new(artifact.schema_revision)},
      {artifact.iri, @jf <> "rowCount", RDF.XSD.NonNegativeInteger.new(artifact.row_count)},
      {artifact.iri, @jf <> "byteCount", RDF.XSD.NonNegativeInteger.new(artifact.byte_count)},
      {artifact.iri, @jf <> "availabilityState", concept(artifact.availability_state)},
      {artifact.iri, @jf <> "createdAt", RDF.XSD.DateTime.new(artifact.created_at)},
      {artifact.iri, @jf <> "payloadExternal", RDF.XSD.Boolean.new(true)}
    ] ++
      Enum.map(artifact.source_row_iris, &{artifact.iri, @jf <> "sourceRow", RDF.iri(&1)}) ++
      Enum.map(artifact.external_copy_iris, &{artifact.iri, @jf <> "externalCopy", RDF.iri(&1)})
  end

  defp identity(manifest, permit, attributes, rows, copies) do
    ResourceIdentity.deterministic(
      :dataset_artifact,
      Enum.join(
        [
          manifest.iri,
          permit.iri,
          attributes.dataset_digest,
          attributes.schema_revision,
          Integer.to_string(attributes.row_count),
          Integer.to_string(attributes.byte_count),
          Enum.join(rows, "\n"),
          Enum.join(copies, "\n")
        ],
        "\n"
      )
    )
  end

  defp resources(values, maximum) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if normalized == Enum.sort(values) and length(normalized) <= maximum and
         Enum.all?(normalized, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, normalized},
       else: :error
  end

  defp resources(_values, _maximum), do: :error
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp revision?(value), do: is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value)

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_dataset_artifact)}
end

defmodule JidoCode.Knowledge.Memory.DatasetExportPermit do
  @moduledoc "Expiring, manifest-bound permit for one approved dataset sink."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @enforce_keys [
    :iri,
    :revision,
    :manifest_iri,
    :authorization_iri,
    :actor_iri,
    :sink_iri,
    :purpose,
    :classifications,
    :row_limit,
    :byte_limit,
    :issued_at,
    :expires_at,
    :state,
    :consumed_at
  ]
  defstruct @enforce_keys

  def new(%MemoryDatasetManifest{status: :verified} = manifest, attributes)
      when is_map(attributes) do
    with true <- attributes[:manifest_iri] == manifest.iri,
         true <- attributes[:authorization_iri] == manifest.authorization_iri,
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:sink_iri]),
         true <- attributes[:purpose] == manifest.purpose,
         {:ok, classifications} <- classifications(attributes[:classifications], manifest),
         true <- positive_bounded?(attributes[:row_limit], 100_000),
         true <- positive_bounded?(attributes[:byte_limit], 1_073_741_824),
         %DateTime{} = issued_at <- attributes[:issued_at],
         %DateTime{} = expires_at <- attributes[:expires_at],
         true <- DateTime.compare(issued_at, expires_at) == :lt,
         true <- DateTime.diff(expires_at, issued_at, :second) <= 86_400,
         {:ok, iri} <- identity(manifest, attributes, classifications) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         manifest_iri: manifest.iri,
         authorization_iri: manifest.authorization_iri,
         actor_iri: attributes.actor_iri,
         sink_iri: attributes.sink_iri,
         purpose: manifest.purpose,
         classifications: classifications,
         row_limit: attributes.row_limit,
         byte_limit: attributes.byte_limit,
         issued_at: DateTime.truncate(issued_at, :microsecond),
         expires_at: DateTime.truncate(expires_at, :microsecond),
         state: :issued,
         consumed_at: nil
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_manifest, _attributes), do: invalid()

  def current?(%__MODULE__{state: :issued} = permit, now) when is_struct(now, DateTime) do
    DateTime.compare(permit.issued_at, now) in [:lt, :eq] and
      DateTime.compare(now, permit.expires_at) == :lt
  end

  def current?(_permit, _now), do: false

  def consume(%__MODULE__{} = permit, now) when is_struct(now, DateTime) do
    if current?(permit, now) do
      {:ok,
       %__MODULE__{permit | state: :consumed, consumed_at: DateTime.truncate(now, :microsecond)}}
    else
      {:error, Error.new(:unauthorized, :dataset_export_permit)}
    end
  end

  def consume(_permit, _now), do: {:error, Error.new(:unauthorized, :dataset_export_permit)}

  def statements(%__MODULE__{} = permit) do
    [
      {permit.iri, @rdf_type, RDF.iri(@jf <> "DatasetExportPermit")},
      {permit.iri, @jf <> "datasetManifest", RDF.iri(permit.manifest_iri)},
      {permit.iri, @jf <> "authorization", RDF.iri(permit.authorization_iri)},
      {permit.iri, @jf <> "actor", RDF.iri(permit.actor_iri)},
      {permit.iri, @jf <> "approvedSink", RDF.iri(permit.sink_iri)},
      {permit.iri, @jf <> "purpose", concept(permit.purpose)},
      {permit.iri, @jf <> "rowLimit", RDF.XSD.NonNegativeInteger.new(permit.row_limit)},
      {permit.iri, @jf <> "byteLimit", RDF.XSD.NonNegativeInteger.new(permit.byte_limit)},
      {permit.iri, @jf <> "issuedAt", RDF.XSD.DateTime.new(permit.issued_at)},
      {permit.iri, @jf <> "validTo", RDF.XSD.DateTime.new(permit.expires_at)},
      {permit.iri, @jf <> "permitState", concept(permit.state)}
    ] ++
      Enum.map(permit.classifications, &{permit.iri, @jf <> "allowedDataClass", concept(&1)})
  end

  defp identity(manifest, attributes, classifications) do
    ResourceIdentity.deterministic(
      :dataset_export_permit,
      Enum.join(
        [
          manifest.iri,
          manifest.authorization_iri,
          attributes.actor_iri,
          attributes.sink_iri,
          Atom.to_string(manifest.purpose),
          Enum.map_join(classifications, "\n", &Atom.to_string/1),
          Integer.to_string(attributes.row_limit),
          Integer.to_string(attributes.byte_limit),
          DateTime.to_iso8601(attributes.issued_at),
          DateTime.to_iso8601(attributes.expires_at)
        ],
        "\n"
      )
    )
  end

  defp classifications(values, manifest) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if normalized != [] and Enum.all?(normalized, &(&1 in manifest.classifications)),
      do: {:ok, normalized},
      else: :error
  end

  defp classifications(_values, _manifest), do: :error
  defp positive_bounded?(value, maximum), do: is_integer(value) and value > 0 and value <= maximum

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp invalid, do: {:error, Error.new(:invalid_input, :dataset_export_permit)}
end

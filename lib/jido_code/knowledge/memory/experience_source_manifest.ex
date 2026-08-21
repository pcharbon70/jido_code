defmodule JidoCode.Knowledge.Memory.ExperienceSourceManifest do
  @moduledoc "Exact source and effective-time boundary used to construct one experience case."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :digest,
    :repository_iri,
    :repository_scope_iri,
    :attempt_iri,
    :effective_at,
    :source_event_iris,
    :source_artifact_iris,
    :source_evidence_iris,
    :source_graph_revisions
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  @revision "1.0.0"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec new(map()) :: {:ok, struct()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes, [:repository_iri, :repository_scope_iri, :attempt_iri]),
         %DateTime{} = effective_at <- attributes[:effective_at],
         {:ok, events} <- iri_list(attributes[:source_event_iris], 200, false),
         {:ok, artifacts} <- iri_list(attributes[:source_artifact_iris], 100, true),
         {:ok, evidence} <- iri_list(attributes[:source_evidence_iris], 100, false),
         {:ok, revisions} <- revisions(attributes[:source_graph_revisions]),
         material <-
           {
             @revision,
             attributes.repository_iri,
             attributes.repository_scope_iri,
             attributes.attempt_iri,
             DateTime.to_iso8601(effective_at),
             events,
             artifacts,
             evidence,
             revisions
           },
         digest <- digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:experience_source_manifest, digest) do
      {:ok,
       %__MODULE__{
         iri: iri,
         digest: digest,
         repository_iri: attributes.repository_iri,
         repository_scope_iri: attributes.repository_scope_iri,
         attempt_iri: attributes.attempt_iri,
         effective_at: DateTime.truncate(effective_at, :microsecond),
         source_event_iris: events,
         source_artifact_iris: artifacts,
         source_evidence_iris: evidence,
         source_graph_revisions: revisions
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = manifest) do
    [
      {manifest.iri, @rdf_type, RDF.iri(@jf <> "ExperienceSourceManifest")},
      {manifest.iri, @jf <> "about", RDF.iri(manifest.repository_iri)},
      {manifest.iri, @jf <> "attempt", RDF.iri(manifest.attempt_iri)},
      {manifest.iri, @jf <> "manifestDigest", RDF.XSD.String.new(manifest.digest)},
      {manifest.iri, @jf <> "effectiveAt", RDF.XSD.DateTime.new(manifest.effective_at)}
    ] ++
      refs(manifest.iri, @jf <> "sourceEvent", manifest.source_event_iris) ++
      refs(manifest.iri, @jf <> "sourceArtifact", manifest.source_artifact_iris) ++
      refs(manifest.iri, @jf <> "evidenceSource", manifest.source_evidence_iris) ++
      revision_statements(manifest.iri, manifest.source_graph_revisions)
  end

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid()
  end

  defp iri_list(values, maximum, empty?) when is_list(values) and length(values) <= maximum do
    if (empty? or values != []) and length(values) == length(Enum.uniq(values)) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp iri_list(_values, _maximum, _empty?), do: :error

  defp revisions(values) when is_map(values) and map_size(values) in 1..16 do
    if Enum.all?(values, fn {graph, revision} ->
         match?({:ok, _family}, GraphRegistry.identify(graph)) and is_integer(revision) and
           revision >= 0
       end),
       do: {:ok, values |> Enum.sort() |> Map.new()},
       else: :error
  end

  defp revisions(_values), do: :error

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp refs(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp revision_statements(subject, revisions) do
    Enum.flat_map(revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          Enum.join([subject, graph, Integer.to_string(revision)], "\n")
        )

      [
        {subject, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :experience_source_manifest)}
end

defmodule JidoCode.Knowledge.Memory.CandidateFactOrSummary do
  @moduledoc "Untrusted model proposal that can never itself become accepted knowledge."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ExperienceSourceManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :case_iri,
    :author_iri,
    :source_manifest_iri,
    :source_manifest_digest,
    :summary,
    :claims,
    :related_iris,
    :triggers,
    :recorded_at,
    :epistemic_state,
    :non_authoritative?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  @revision "1.0.0"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec new(String.t(), ExperienceSourceManifest.t(), map()) ::
          {:ok, struct()} | {:error, Error.t()}
  def new(case_iri, %ExperienceSourceManifest{} = manifest, attributes)
      when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(case_iri),
         :ok <- ResourceIdentity.validate(attributes[:author_iri]),
         true <- safe_container?(attributes[:summary], 8_192),
         {:ok, claims} <- texts(attributes[:claims], 50, 1_024),
         {:ok, related} <- iris(attributes[:related_iris], 100),
         {:ok, triggers} <- texts(attributes[:triggers], 50, 256),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- DateTime.compare(recorded_at, manifest.effective_at) in [:lt, :eq],
         digest <-
           digest({
             @revision,
             case_iri,
             attributes.author_iri,
             manifest.digest,
             attributes.summary,
             claims,
             related,
             triggers,
             DateTime.to_iso8601(recorded_at)
           }),
         {:ok, iri} <- ResourceIdentity.deterministic(:candidate_fact_or_summary, digest) do
      {:ok,
       %__MODULE__{
         iri: iri,
         case_iri: case_iri,
         author_iri: attributes.author_iri,
         source_manifest_iri: manifest.iri,
         source_manifest_digest: manifest.digest,
         summary: attributes.summary,
         claims: claims,
         related_iris: related,
         triggers: triggers,
         recorded_at: DateTime.truncate(recorded_at, :microsecond),
         epistemic_state: :candidate_fact_or_summary,
         non_authoritative?: true
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_case_iri, _manifest, _attributes), do: invalid()

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = summary) do
    [
      {summary.iri, @rdf_type, RDF.iri(@jf <> "CandidateFactOrSummary")},
      {summary.iri, @jf <> "about", RDF.iri(summary.case_iri)},
      {summary.iri, @jf <> "sourceManifest", RDF.iri(summary.source_manifest_iri)},
      {summary.iri, @jf <> "sourceManifestDigest",
       RDF.XSD.String.new(summary.source_manifest_digest)},
      {summary.iri, @jf <> "candidateSummary", RDF.XSD.String.new(summary.summary)},
      {summary.iri, @jf <> "epistemicState",
       RDF.iri("https://jido.run/ontology/concept/CandidateFactOrSummary")},
      {summary.iri, @jf <> "nonAuthoritative", RDF.XSD.Boolean.new(true)},
      {summary.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(summary.recorded_at)}
    ] ++
      Enum.map(summary.claims, &{summary.iri, @jf <> "candidateClaim", RDF.XSD.String.new(&1)}) ++
      Enum.map(summary.related_iris, &{summary.iri, @jf <> "relatedResource", RDF.iri(&1)})
  end

  defp texts(values, maximum, bytes) when is_list(values) and length(values) <= maximum do
    if length(values) == length(Enum.uniq(values)) and
         Enum.all?(values, &safe_container?(&1, bytes)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp texts(_values, _maximum, _bytes), do: :error

  defp iris(values, maximum) when is_list(values) and length(values) <= maximum do
    if length(values) == length(Enum.uniq(values)) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp iris(_values, _maximum), do: :error

  defp safe_container?(value, maximum) when is_binary(value),
    do:
      byte_size(value) >= 1 and byte_size(value) <= maximum and
        not Regex.match?(~r/[\x00\x7F]/u, value)

  defp safe_container?(_value, _maximum), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :candidate_fact_or_summary)}
end

defmodule JidoCode.Knowledge.Memory.CrossRepositoryAuthorization do
  @moduledoc "Explicit, expiring authority for one bounded cross-repository cohort purpose."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @revision "1.0.0"
  @purposes ~w[evaluation dataset_construction incident_analysis]a
  @uses ~w[query analysis candidate_generation dataset_construction export]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  @enforce_keys [
    :iri,
    :revision,
    :cohort_iri,
    :repository_iris,
    :actor_iris,
    :purpose,
    :allowed_uses,
    :data_classes,
    :effective_cutoff,
    :valid_from,
    :expires_at,
    :policy_revision,
    :decision_iri,
    :decision,
    :erasure_generations,
    :revocation_generation,
    :revoked_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  def revision, do: @revision
  def purposes, do: @purposes
  def allowed_uses, do: @uses

  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:cohort_iri]),
         {:ok, repositories} <- resources(attributes[:repository_iris], 2, 50),
         {:ok, actors} <- resources(attributes[:actor_iris], 1, 50),
         true <- attributes[:purpose] in @purposes,
         {:ok, uses} <- atoms(attributes[:allowed_uses], @uses),
         {:ok, classes} <- atoms(attributes[:data_classes], DataPolicy.classifications()),
         %DateTime{} = cutoff <- attributes[:effective_cutoff],
         %DateTime{} = valid_from <- attributes[:valid_from],
         %DateTime{} = expires_at <- attributes[:expires_at],
         true <- DateTime.compare(cutoff, valid_from) in [:lt, :eq],
         true <- DateTime.compare(valid_from, expires_at) == :lt,
         true <- revision?(attributes[:policy_revision]),
         :ok <- ResourceIdentity.validate(attributes[:decision_iri]),
         true <- attributes[:decision] == :authorized,
         {:ok, generations} <- generations(attributes[:erasure_generations], repositories),
         {:ok, iri} <- identity(attributes, repositories, actors, uses, classes, generations) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         cohort_iri: attributes.cohort_iri,
         repository_iris: repositories,
         actor_iris: actors,
         purpose: attributes.purpose,
         allowed_uses: uses,
         data_classes: classes,
         effective_cutoff: DateTime.truncate(cutoff, :microsecond),
         valid_from: DateTime.truncate(valid_from, :microsecond),
         expires_at: DateTime.truncate(expires_at, :microsecond),
         policy_revision: attributes.policy_revision,
         decision_iri: attributes.decision_iri,
         decision: :authorized,
         erasure_generations: generations,
         revocation_generation: 0,
         revoked_at: nil
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  def current?(%__MODULE__{} = authorization, actor_iri, purpose, use, now)
      when is_struct(now, DateTime) do
    is_nil(authorization.revoked_at) and actor_iri in authorization.actor_iris and
      purpose == authorization.purpose and use in authorization.allowed_uses and
      DateTime.compare(authorization.valid_from, now) in [:lt, :eq] and
      DateTime.compare(now, authorization.expires_at) == :lt
  end

  def current?(_authorization, _actor, _purpose, _use, _now), do: false

  def revoke(%__MODULE__{revoked_at: nil} = authorization, revoked_at, generation)
      when is_struct(revoked_at, DateTime) and is_integer(generation) and generation > 0 do
    if generation > authorization.revocation_generation and
         DateTime.compare(authorization.valid_from, revoked_at) in [:lt, :eq] do
      {:ok,
       %__MODULE__{
         authorization
         | revoked_at: DateTime.truncate(revoked_at, :microsecond),
           revocation_generation: generation
       }}
    else
      invalid()
    end
  end

  def revoke(_authorization, _revoked_at, _generation), do: invalid()

  def statements(%__MODULE__{} = authorization) do
    [
      {authorization.iri, @rdf_type, RDF.iri(@jf <> "CrossRepositoryAuthorization")},
      {authorization.iri, @jf <> "version", RDF.XSD.String.new(authorization.revision)},
      {authorization.iri, @jf <> "cohort", RDF.iri(authorization.cohort_iri)},
      {authorization.iri, @jf <> "purpose", concept(authorization.purpose)},
      {authorization.iri, @jf <> "effectiveCutoff",
       RDF.XSD.DateTime.new(authorization.effective_cutoff)},
      {authorization.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(authorization.valid_from)},
      {authorization.iri, @jf <> "validTo", RDF.XSD.DateTime.new(authorization.expires_at)},
      {authorization.iri, @jf <> "policyRevision",
       RDF.XSD.String.new(authorization.policy_revision)},
      {authorization.iri, @jf <> "authorizationDecision", RDF.iri(authorization.decision_iri)},
      {authorization.iri, @jf <> "authorizationState", concept(:authorized)}
    ] ++
      iri_values(authorization.iri, @jf <> "authorizedRepository", authorization.repository_iris) ++
      iri_values(authorization.iri, @jf <> "authorizedActor", authorization.actor_iris) ++
      concept_values(authorization.iri, @jf <> "allowedUse", authorization.allowed_uses) ++
      concept_values(authorization.iri, @jf <> "allowedDataClass", authorization.data_classes) ++
      Enum.flat_map(authorization.erasure_generations, fn {repository, generation} ->
        suffix = :crypto.hash(:sha256, repository) |> Base.encode16(case: :lower)
        node = authorization.iri <> "/erasure-generation/" <> suffix

        [
          {authorization.iri, @jf <> "erasureGeneration", RDF.iri(node)},
          {node, @jf <> "repository", RDF.iri(repository)},
          {node, @jf <> "generation", RDF.XSD.NonNegativeInteger.new(generation)}
        ]
      end)
  end

  defp identity(attributes, repositories, actors, uses, classes, generations) do
    material =
      [
        attributes.cohort_iri,
        Enum.join(repositories, "\n"),
        Enum.join(actors, "\n"),
        Atom.to_string(attributes.purpose),
        Enum.map_join(uses, "\n", &Atom.to_string/1),
        Enum.map_join(classes, "\n", &Atom.to_string/1),
        DateTime.to_iso8601(attributes.effective_cutoff),
        DateTime.to_iso8601(attributes.valid_from),
        DateTime.to_iso8601(attributes.expires_at),
        attributes.policy_revision,
        attributes.decision_iri,
        Enum.map_join(generations, "\n", fn {repository, generation} ->
          repository <> ":" <> Integer.to_string(generation)
        end)
      ]
      |> Enum.join("\n--\n")

    ResourceIdentity.deterministic(:cross_repository_authorization, material)
  end

  defp resources(values, minimum, maximum) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if length(normalized) >= minimum and length(normalized) <= maximum and
         Enum.all?(normalized, &(ResourceIdentity.validate(&1) == :ok)) do
      {:ok, normalized}
    else
      :error
    end
  end

  defp resources(_values, _minimum, _maximum), do: :error

  defp atoms(values, allowed) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if normalized != [] and Enum.all?(normalized, &(&1 in allowed)),
      do: {:ok, normalized},
      else: :error
  end

  defp atoms(_values, _allowed), do: :error

  defp generations(values, repositories) when is_map(values) do
    if Enum.sort(Map.keys(values)) == repositories and
         Enum.all?(values, fn {_repository, generation} ->
           is_integer(generation) and generation >= 0
         end) do
      {:ok, Map.new(values)}
    else
      :error
    end
  end

  defp generations(_values, _repositories), do: :error
  defp revision?(value), do: is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value)

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp iri_values(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp concept_values(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, concept(&1)})

  defp invalid, do: {:error, Error.new(:invalid_input, :cross_repository_authorization)}
end

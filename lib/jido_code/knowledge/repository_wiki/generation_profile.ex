defmodule JidoCode.Knowledge.RepositoryWiki.GenerationProfile do
  @moduledoc "Closed, immutable deterministic wiki generation profile."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :profile_key,
    :revision,
    :maintenance_mode,
    :generation_mode,
    :preview_mode,
    :read_visibility,
    :accounting_retention,
    :audit_retention,
    :compiler_profile,
    :compiler_digest,
    :approved_at,
    :expires_at,
    :profile_digest
  ]
  defstruct @enforce_keys

  @type key :: :manual_deterministic | :automatic_deterministic
  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @modes %{
    manual_deterministic: :manual,
    automatic_deterministic: :automatic
  }
  @profile_keys Map.keys(@modes)
  @preview_modes [:disabled, :allowed]

  @spec new(key(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(key, attributes) when key in @profile_keys and is_map(attributes) do
    with %DateTime{} = approved_at <- attributes[:approved_at],
         expires_at <- Map.get(attributes, :expires_at),
         true <- Contract.valid_interval?(approved_at, expires_at),
         preview_mode when preview_mode in @preview_modes <-
           Map.get(attributes, :preview_mode, :disabled),
         material <- material(key, preview_mode, approved_at, expires_at),
         profile_digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_generation_profile, profile_digest) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(material, %{
           iri: iri,
           profile_digest: profile_digest
         })
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_generation_profile)
    end
  rescue
    _error -> invalid(:wiki_generation_profile)
  end

  def new(_key, _attributes), do: invalid(:wiki_generation_profile)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = profile) do
    [
      {profile.iri, @rdf_type, RDF.iri(@jf <> "WikiGenerationProfile")},
      {profile.iri, @jf <> "profileKey", RDF.XSD.String.new(Atom.to_string(profile.profile_key))},
      {profile.iri, @jf <> "profileRevision", RDF.XSD.NonNegativeInteger.new(profile.revision)},
      {profile.iri, @jf <> "profileDigest", RDF.XSD.String.new(profile.profile_digest)},
      {profile.iri, @jf <> "maintenanceMode",
       RDF.iri(Contract.concept(wiki_concept(profile.maintenance_mode)))},
      {profile.iri, @jf <> "generationMode", RDF.iri(Contract.concept(:wiki_deterministic_only))},
      {profile.iri, @jf <> "previewMode",
       RDF.iri(Contract.concept(preview_concept(profile.preview_mode)))},
      {profile.iri, @jf <> "wikiReadVisibility", RDF.iri(Contract.concept(:wiki_read_retained))},
      {profile.iri, @jf <> "wikiAccountingRetention",
       RDF.iri(Contract.concept(:wiki_accounting_retention))},
      {profile.iri, @jf <> "wikiAuditRetention",
       RDF.iri(Contract.concept(:wiki_audit_retention))},
      {profile.iri, @jf <> "compilerProfile", RDF.XSD.String.new(profile.compiler_profile)},
      {profile.iri, @jf <> "compilerDigest", RDF.XSD.String.new(profile.compiler_digest)},
      {profile.iri, @jf <> "approvedAt", RDF.XSD.DateTime.new(profile.approved_at)}
      | optional_datetime(profile.iri, @jf <> "expiresAt", profile.expires_at)
    ]
  end

  @spec register_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def register_command(profile, attributes, options \\ [])

  def register_command(%__MODULE__{} = profile, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:catalog_graph_iri]

    with true <- exact_catalog_graph?(graph),
         revision when is_integer(revision) and revision > 0 <-
           attributes[:expected_catalog_revision],
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, profile.iri <> "\nregister"),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(command_iri, profile, graph, revision, attributes),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:register_wiki_generation_profile)
    end
  end

  def register_command(_profile, _attributes, _options),
    do: invalid(:register_wiki_generation_profile)

  defp material(key, preview_mode, approved_at, expires_at) do
    %{
      profile_key: key,
      revision: 1,
      maintenance_mode: Map.fetch!(@modes, key),
      generation_mode: :deterministic_only,
      preview_mode: preview_mode,
      read_visibility: :retained,
      accounting_retention: :wiki_accounting,
      audit_retention: :wiki_audit,
      compiler_profile: Protocol.compiler_profile(),
      compiler_digest: Protocol.compiler_digest(),
      approved_at: DateTime.truncate(approved_at, :microsecond),
      expires_at: expires_at
    }
  end

  defp envelope(command_iri, profile, graph, revision, attributes) do
    %{
      command_type: "RegisterWikiGenerationProfile",
      command_version: Protocol.semantic_version(),
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: Protocol.ontology_version(),
      shape_version: Protocol.ontology_version(),
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{graph => revision},
      reason: attributes[:reason],
      payload: %{
        changes: [
          %{
            family: :factory_catalog,
            graph_iri: graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: statements(profile),
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        guards: [{:subject_absent, graph, profile.iri}]
      }
    }
  end

  defp wiki_concept(:manual), do: :wiki_manual
  defp wiki_concept(:automatic), do: :wiki_automatic
  defp preview_concept(:disabled), do: :wiki_preview_disabled
  defp preview_concept(:allowed), do: :wiki_preview_allowed

  defp exact_catalog_graph?(graph) do
    case GraphRegistry.graph_iri(:factory_catalog, %{}) do
      {:ok, expected} -> expected == graph
      {:error, %Error{}} -> false
    end
  end

  defp optional_datetime(_subject, _predicate, nil), do: []

  defp optional_datetime(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.DateTime.new(value)}]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

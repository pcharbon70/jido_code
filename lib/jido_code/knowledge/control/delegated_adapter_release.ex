defmodule JidoCode.Knowledge.Control.DelegatedAdapterRelease do
  @moduledoc "Immutable, reviewed delegated coding adapter release contract."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :provider,
    :adapter_key,
    :release_revision,
    :jido_harness_revision,
    :jido_harness_digest,
    :jido_harness_protocol,
    :cli_product,
    :cli_versions,
    :executable_registry_key,
    :prompt_transport,
    :input_protocol_revision,
    :event_protocol_revision,
    :status_protocol_revision,
    :cancellation_protocol_revision,
    :candidate_protocol_revision,
    :capability_classes,
    :deployment_classes,
    :journal_policy,
    :session_policy,
    :cancellation_enforcement,
    :observation_completeness,
    :unavailable_fields,
    :conformance_digest,
    :security_evidence_digest,
    :state,
    :approved_at,
    :expires_at,
    :signer_iri,
    :release_digest,
    :signed_digest
  ]
  defstruct @enforce_keys ++ [:supersedes_iri]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @providers ~w[codex pi claude gemini opencode amp grok kimi zai]a
  @executable_keys %{
    codex: ~w[codex_cli],
    pi: ~w[pi_cli],
    claude: ~w[claude_cli],
    gemini: ~w[gemini_cli],
    opencode: ~w[opencode_cli],
    amp: ~w[amp_cli],
    grok: ~w[grok_cli],
    kimi: ~w[kimi_cli],
    zai: ~w[zai_cli]
  }
  @prompt_transports ~w[stdin protected_file]a
  @capabilities ~w[deny_all bounded_read_only workspace_write workspace_write_registered_checks]a
  @deployments ~w[developer_local managed_fleet]a
  @states ~w[accepted revoked superseded]a
  @cancellation ~w[native outer_enforced native_and_outer]a
  @completeness ~w[complete partial unavailable]a

  @spec material_digest(map()) :: String.t()
  def material_digest(attributes),
    do: Contract.digest(Map.drop(attributes, [:iri, :release_digest, :signed_digest]))

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, provider} <- Contract.enum(attributes[:provider], @providers),
         {:ok, adapter_key} <- Contract.identifier(attributes[:adapter_key], 64),
         revision when is_integer(revision) and revision > 0 <- attributes[:release_revision],
         true <- Contract.digest?(attributes[:jido_harness_revision]),
         true <- Contract.digest?(attributes[:jido_harness_digest]),
         {:ok, harness_protocol} <- Contract.text(attributes[:jido_harness_protocol], 32),
         {:ok, cli_product} <- Contract.identifier(attributes[:cli_product], 64),
         {:ok, cli_versions} <- cli_versions(attributes[:cli_versions]),
         {:ok, executable_key} <- Contract.identifier(attributes[:executable_registry_key], 64),
         true <- executable_key in Map.fetch!(@executable_keys, provider),
         {:ok, prompt_transport} <-
           Contract.enum(attributes[:prompt_transport], @prompt_transports),
         true <- prompt_transport != :argv,
         :ok <- validate_protocols(attributes),
         {:ok, capabilities} <- closed_set(attributes[:capability_classes], @capabilities),
         {:ok, deployments} <- closed_set(attributes[:deployment_classes], @deployments),
         {:ok, journal_policy} <- Contract.identifier(attributes[:journal_policy], 64),
         {:ok, session_policy} <- Contract.identifier(attributes[:session_policy], 64),
         {:ok, cancellation} <-
           Contract.enum(attributes[:cancellation_enforcement], @cancellation),
         {:ok, completeness} <-
           Contract.enum(attributes[:observation_completeness], @completeness),
         {:ok, unavailable} <- optional_identifiers(attributes[:unavailable_fields]),
         true <- Contract.digest?(attributes[:conformance_digest]),
         true <- Contract.digest?(attributes[:security_evidence_digest]),
         {:ok, state} <- Contract.enum(attributes[:state], @states),
         :ok <- Contract.interval(attributes[:approved_at], attributes[:expires_at]),
         :ok <- Contract.resource(attributes[:signer_iri]),
         :ok <- Contract.optional_resource(attributes[:supersedes_iri]),
         true <- Contract.digest?(attributes[:signed_digest]),
         expected_digest <- material_digest(attributes),
         ^expected_digest <- attributes[:release_digest],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :delegated_adapter_release,
             Enum.join(
               [provider, adapter_key, Integer.to_string(revision), expected_digest],
               "\n"
             )
           ) do
      normalized = %{
        provider: provider,
        adapter_key: adapter_key,
        jido_harness_protocol: harness_protocol,
        cli_product: cli_product,
        cli_versions: cli_versions,
        executable_registry_key: executable_key,
        prompt_transport: prompt_transport,
        capability_classes: capabilities,
        deployment_classes: deployments,
        journal_policy: journal_policy,
        session_policy: session_policy,
        cancellation_enforcement: cancellation,
        observation_completeness: completeness,
        unavailable_fields: unavailable,
        state: state
      }

      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys ++ [:supersedes_iri])
         |> Map.merge(normalized)
         |> Map.put(:iri, iri)
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_adapter_release)
    end
  rescue
    _error -> invalid(:delegated_adapter_release)
  end

  def new(_attributes), do: invalid(:delegated_adapter_release)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = release) do
    base = [
      {release.iri, @rdf_type, RDF.iri(@jf <> "DelegatedAdapterRelease")},
      {release.iri, @jf <> "adapterProvider", RDF.iri(Contract.concept(release.provider))},
      {release.iri, @jf <> "adapterKey", RDF.XSD.String.new(release.adapter_key)},
      {release.iri, @jf <> "releaseRevision",
       RDF.XSD.NonNegativeInteger.new(release.release_revision)},
      {release.iri, @jf <> "jidoHarnessRevision",
       RDF.XSD.String.new(release.jido_harness_revision)},
      {release.iri, @jf <> "jidoHarnessDigest", RDF.XSD.String.new(release.jido_harness_digest)},
      {release.iri, @jf <> "jidoHarnessProtocol",
       RDF.XSD.String.new(release.jido_harness_protocol)},
      {release.iri, @jf <> "cliProduct", RDF.XSD.String.new(release.cli_product)},
      {release.iri, @jf <> "executableRegistryKey",
       RDF.XSD.String.new(release.executable_registry_key)},
      {release.iri, @jf <> "promptTransport",
       RDF.iri(Contract.concept(release.prompt_transport))},
      {release.iri, @jf <> "inputProtocolRevision",
       RDF.XSD.String.new(release.input_protocol_revision)},
      {release.iri, @jf <> "eventProtocolRevision",
       RDF.XSD.String.new(release.event_protocol_revision)},
      {release.iri, @jf <> "statusProtocolRevision",
       RDF.XSD.String.new(release.status_protocol_revision)},
      {release.iri, @jf <> "cancellationProtocolRevision",
       RDF.XSD.String.new(release.cancellation_protocol_revision)},
      {release.iri, @jf <> "candidateProtocolRevision",
       RDF.XSD.String.new(release.candidate_protocol_revision)},
      {release.iri, @jf <> "journalPolicy", RDF.XSD.String.new(release.journal_policy)},
      {release.iri, @jf <> "sessionPolicy", RDF.XSD.String.new(release.session_policy)},
      {release.iri, @jf <> "cancellationEnforcement",
       RDF.iri(Contract.concept(release.cancellation_enforcement))},
      {release.iri, @jf <> "observationCompleteness",
       RDF.iri(Contract.concept(release.observation_completeness))},
      {release.iri, @jf <> "conformanceDigest", RDF.XSD.String.new(release.conformance_digest)},
      {release.iri, @jf <> "securityEvidenceDigest",
       RDF.XSD.String.new(release.security_evidence_digest)},
      {release.iri, @jf <> "releaseState", RDF.iri(Contract.concept(release.state))},
      {release.iri, @jf <> "approvedAt", RDF.XSD.DateTime.new(release.approved_at)},
      {release.iri, @jf <> "expiresAt", RDF.XSD.DateTime.new(release.expires_at)},
      {release.iri, @jf <> "signedBy", RDF.iri(release.signer_iri)},
      {release.iri, @jf <> "releaseDigest", RDF.XSD.String.new(release.release_digest)},
      {release.iri, @jf <> "signedDigest", RDF.XSD.String.new(release.signed_digest)},
      {release.iri, @prov <> "wasAttributedTo", RDF.iri(release.signer_iri)}
    ]

    base ++
      literals(release, "cliVersion", release.cli_versions) ++
      concepts(release, "supportedCapabilityClass", release.capability_classes) ++
      concepts(release, "supportedDeploymentClass", release.deployment_classes) ++
      literals(release, "unavailableObservationField", release.unavailable_fields) ++
      optional_iri(release.iri, @jf <> "supersedes", release.supersedes_iri)
  end

  @spec register_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def register_command(release, attributes, options \\ [])

  def register_command(%__MODULE__{} = release, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <- positive?(attributes[:expected_policy_revision]),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, release.iri <> "\nregister"),
         {:ok, command} <-
           CommandEnvelope.new(envelope(command_iri, release, attributes, graph), options) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:register_delegated_adapter_release)
    end
  end

  def register_command(_release, _attributes, _options),
    do: invalid(:register_delegated_adapter_release)

  defp envelope(command_iri, release, attributes, graph) do
    %{
      command_type: "RegisterDelegatedAdapterRelease",
      command_version: "2.9.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.4.0",
      shape_version: "1.4.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{graph => attributes[:expected_policy_revision]},
      reason: attributes[:reason],
      payload: %{
        changes: [
          %{
            family: :factory_policy,
            graph_iri: graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: statements(release),
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        guards: [{:subject_absent, graph, release.iri}]
      }
    }
  end

  defp validate_protocols(attributes) do
    fields =
      ~w[input_protocol_revision event_protocol_revision status_protocol_revision cancellation_protocol_revision candidate_protocol_revision]a

    if Enum.all?(fields, &Contract.digest?(attributes[&1])), do: :ok, else: :error
  end

  defp closed_set(values, allowed)
       when is_list(values) and values != [] and length(values) <= 16 do
    if Enum.all?(values, &(&1 in allowed)),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp closed_set(_values, _allowed), do: :error

  defp cli_versions(values) when is_list(values) and values != [] and length(values) <= 32 do
    if Enum.all?(values, &valid_cli_version?/1),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp cli_versions(_values), do: :error

  defp valid_cli_version?(value) when is_binary(value) and byte_size(value) in 1..64//1,
    do: Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9._+-]*$/, value)

  defp valid_cli_version?(_value), do: false
  defp optional_identifiers([]), do: {:ok, []}
  defp optional_identifiers(values), do: Contract.identifiers(values, 64, 64)
  defp positive?(value), do: is_integer(value) and value > 0

  defp literals(release, local, values),
    do: Enum.map(values, &{release.iri, @jf <> local, RDF.XSD.String.new(&1)})

  defp concepts(release, local, values),
    do: Enum.map(values, &{release.iri, @jf <> local, RDF.iri(Contract.concept(&1))})

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, iri), do: [{subject, predicate, RDF.iri(iri)}]
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

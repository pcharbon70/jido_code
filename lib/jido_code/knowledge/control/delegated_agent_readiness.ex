defmodule JidoCode.Knowledge.Control.DelegatedAgentReadiness do
  @moduledoc "Expiring observation for one exact delegated profile and adapter tuple."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :profile_iri,
    :profile_digest,
    :adapter_release_iri,
    :adapter_release_digest,
    :cli_version,
    :credential_generation,
    :worker_revision,
    :sandbox_profile_revision,
    :network_policy_revision,
    :verification_profile_revision,
    :candidate_protocol_revision,
    :worker_ready,
    :network_ready,
    :authentication_ready,
    :candidate_ready,
    :verifier_ready,
    :observed_at,
    :expires_at,
    :observation_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @revision_fields ~w[profile_digest adapter_release_digest worker_revision sandbox_profile_revision network_policy_revision verification_profile_revision candidate_protocol_revision]a
  @ready_fields ~w[worker_ready network_ready authentication_ready candidate_ready verifier_ready]a

  @spec material_digest(map()) :: String.t()
  def material_digest(attributes),
    do: Contract.digest(Map.drop(attributes, [:iri, :observation_digest]))

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Contract.resource(attributes[:profile_iri]),
         :ok <- Contract.resource(attributes[:adapter_release_iri]),
         true <- Enum.all?(@revision_fields, &Contract.digest?(attributes[&1])),
         {:ok, cli_version} <- cli_version(attributes[:cli_version]),
         generation when is_integer(generation) and generation > 0 <-
           attributes[:credential_generation],
         true <- Enum.all?(@ready_fields, &is_boolean(attributes[&1])),
         :ok <- Contract.interval(attributes[:observed_at], attributes[:expires_at]),
         expected_digest <- material_digest(attributes),
         ^expected_digest <- attributes[:observation_digest],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :delegated_agent_readiness,
             Enum.join(
               [
                 attributes.profile_iri,
                 attributes.adapter_release_iri,
                 Integer.to_string(generation),
                 DateTime.to_iso8601(attributes.observed_at),
                 expected_digest
               ],
               "\n"
             )
           ) do
      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys)
         |> Map.put(:iri, iri)
         |> Map.put(:cli_version, cli_version)
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_agent_readiness)
    end
  rescue
    _error -> invalid(:delegated_agent_readiness)
  end

  def new(_attributes), do: invalid(:delegated_agent_readiness)

  @spec selectable?(t(), DateTime.t()) :: boolean()
  def selectable?(%__MODULE__{} = readiness, %DateTime{} = at) do
    Enum.all?(@ready_fields, &Map.fetch!(readiness, &1)) and
      DateTime.compare(readiness.observed_at, at) in [:lt, :eq] and
      DateTime.compare(at, readiness.expires_at) == :lt
  end

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = readiness) do
    [
      {readiness.iri, @rdf_type, RDF.iri(@jf <> "DelegatedAgentReadiness")},
      {readiness.iri, @jf <> "validFor", RDF.iri(readiness.profile_iri)},
      {readiness.iri, @jf <> "profileDigest", RDF.XSD.String.new(readiness.profile_digest)},
      {readiness.iri, @jf <> "adapterRelease", RDF.iri(readiness.adapter_release_iri)},
      {readiness.iri, @jf <> "releaseDigest",
       RDF.XSD.String.new(readiness.adapter_release_digest)},
      {readiness.iri, @jf <> "cliVersion", RDF.XSD.String.new(readiness.cli_version)},
      {readiness.iri, @jf <> "credentialGeneration",
       RDF.XSD.NonNegativeInteger.new(readiness.credential_generation)},
      {readiness.iri, @jf <> "workerRevision", RDF.XSD.String.new(readiness.worker_revision)},
      {readiness.iri, @jf <> "sandboxProfileRevision",
       RDF.XSD.String.new(readiness.sandbox_profile_revision)},
      {readiness.iri, @jf <> "networkPolicyRevision",
       RDF.XSD.String.new(readiness.network_policy_revision)},
      {readiness.iri, @jf <> "verificationProfileRevision",
       RDF.XSD.String.new(readiness.verification_profile_revision)},
      {readiness.iri, @jf <> "candidateProtocolRevision",
       RDF.XSD.String.new(readiness.candidate_protocol_revision)},
      {readiness.iri, @jf <> "workerReady", RDF.XSD.Boolean.new(readiness.worker_ready)},
      {readiness.iri, @jf <> "networkReady", RDF.XSD.Boolean.new(readiness.network_ready)},
      {readiness.iri, @jf <> "authenticationReady",
       RDF.XSD.Boolean.new(readiness.authentication_ready)},
      {readiness.iri, @jf <> "candidateReady", RDF.XSD.Boolean.new(readiness.candidate_ready)},
      {readiness.iri, @jf <> "verifierReady", RDF.XSD.Boolean.new(readiness.verifier_ready)},
      {readiness.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(readiness.observed_at)},
      {readiness.iri, @jf <> "expiresAt", RDF.XSD.DateTime.new(readiness.expires_at)},
      {readiness.iri, @jf <> "observationDigest",
       RDF.XSD.String.new(readiness.observation_digest)}
    ]
  end

  @spec record_command(t(), map(), keyword()) :: {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(readiness, attributes, options \\ [])

  def record_command(%__MODULE__{} = readiness, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_policy_revision]) and
             attributes[:expected_policy_revision] > 0,
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, readiness.iri <> "\nrecord"),
         {:ok, command} <-
           CommandEnvelope.new(envelope(command_iri, readiness, attributes, graph), options) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_delegated_agent_readiness)
    end
  end

  def record_command(_readiness, _attributes, _options),
    do: invalid(:record_delegated_agent_readiness)

  defp envelope(command_iri, readiness, attributes, graph) do
    %{
      command_type: "RecordDelegatedAgentReadiness",
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
            additions: statements(readiness),
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        guards: [
          {:subject_present, graph, readiness.profile_iri},
          {:subject_present, graph, readiness.adapter_release_iri},
          {:subject_absent, graph, readiness.iri}
        ]
      }
    }
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}

  defp cli_version(value) when is_binary(value) and byte_size(value) in 1..64//1 do
    if Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9._+-]*$/, value), do: {:ok, value}, else: :error
  end

  defp cli_version(_value), do: :error
end

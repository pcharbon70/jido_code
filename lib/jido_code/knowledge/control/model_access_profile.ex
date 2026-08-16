defmodule JidoCode.Knowledge.Control.ModelAccessProfile do
  @moduledoc """
  Graph-native model-access-profile contracts for the agent harness.

  A profile binds one actor scope to an explicit access mode, external
  credential reference, credential class, billing classification, provider
  surface, readiness evidence, and revocation generation. Secret bytes never
  enter the profile; revocation is recorded as a monotonic generation so
  credential release can be linearized against it.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :owner_iri,
    :scope_iri,
    :access_mode,
    :credential_reference_iri,
    :credential_class,
    :billing_mode,
    :provider,
    :model,
    :endpoint,
    :readiness,
    :revocation_generation
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @access_modes ~w[host_api host_subscription delegated_cli]a
  @credential_classes ~w[static_reusable short_lived_bearer workload_exchange attaching_proxy]a
  @billing_modes ~w[metered_api subscription unknown]a
  @readiness ~w[
    installed credential_available authenticated model_available sandbox_ready policy_allowed
    live_verified
  ]a
  @digest64 ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- validate_resource(attributes[:owner_iri]),
         :ok <- validate_resource(attributes[:scope_iri]),
         :ok <- validate_resource(attributes[:credential_reference_iri]),
         access_mode when access_mode in @access_modes <- attributes[:access_mode],
         credential_class when credential_class in @credential_classes <-
           attributes[:credential_class],
         billing_mode when billing_mode in @billing_modes <- attributes[:billing_mode],
         {:ok, provider} <- bounded_text(attributes[:provider], 128),
         {:ok, model} <- bounded_text(attributes[:model], 128),
         {:ok, endpoint} <- bounded_text(attributes[:endpoint], 256),
         {:ok, readiness} <- readiness(attributes[:readiness]),
         generation when is_integer(generation) and generation >= 1 <-
           attributes[:revocation_generation],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :model_access_profile,
             Enum.join(
               [attributes.owner_iri, to_string(access_mode), provider, model],
               "\n"
             )
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         owner_iri: attributes.owner_iri,
         scope_iri: attributes.scope_iri,
         access_mode: access_mode,
         credential_reference_iri: attributes.credential_reference_iri,
         credential_class: credential_class,
         billing_mode: billing_mode,
         provider: provider,
         model: model,
         endpoint: endpoint,
         readiness: readiness,
         revocation_generation: generation
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:model_access_profile)
    end
  rescue
    _error -> invalid(:model_access_profile)
  end

  def new(_attributes), do: invalid(:model_access_profile)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = profile) do
    [
      {profile.iri, @rdf_type, RDF.iri(@jf <> "ModelAccessProfile")},
      {profile.iri, @jf <> "accessMode", RDF.iri(@concept <> camelize(profile.access_mode))},
      {profile.iri, @jf <> "credentialReference", RDF.iri(profile.credential_reference_iri)},
      {profile.iri, @jf <> "credentialClass",
       RDF.iri(@concept <> camelize(profile.credential_class))},
      {profile.iri, @jf <> "billingMode", RDF.iri(@concept <> camelize(profile.billing_mode))},
      {profile.iri, @jf <> "profileProvider", RDF.XSD.String.new(profile.provider)},
      {profile.iri, @jf <> "profileModel", RDF.XSD.String.new(profile.model)},
      {profile.iri, @jf <> "profileEndpoint", RDF.XSD.String.new(profile.endpoint)},
      {profile.iri, @jf <> "revocationGeneration",
       RDF.XSD.NonNegativeInteger.new(profile.revocation_generation)},
      {profile.iri, @jf <> "ownedBy", RDF.iri(profile.owner_iri)},
      {profile.iri, @jf <> "validFor", RDF.iri(profile.scope_iri)},
      {profile.iri, @prov <> "wasAttributedTo", RDF.iri(profile.owner_iri)}
    ] ++
      Enum.map(profile.readiness, fn state ->
        {profile.iri, @jf <> "readinessState", RDF.iri(@concept <> camelize(state))}
      end)
  end

  @spec revocation_statements(t(), non_neg_integer(), DateTime.t()) ::
          [tuple()] | {:error, Error.t()}
  def revocation_statements(%__MODULE__{} = profile, generation, revoked_at)
      when is_integer(generation) and generation >= 2 do
    if match?(%DateTime{}, revoked_at) do
      [
        {profile.iri, @jf <> "revocationGeneration", RDF.XSD.NonNegativeInteger.new(generation)},
        {profile.iri, @jf <> "revokedAt", RDF.XSD.DateTime.new(revoked_at)}
      ]
    else
      invalid(:model_access_profile_revocation)
    end
  end

  def revocation_statements(_profile, _generation, _revoked_at),
    do: invalid(:model_access_profile_revocation)

  @spec enroll_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def enroll_command(profile, attributes, options \\ [])

  def enroll_command(%__MODULE__{} = profile, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_policy_revision]) and
             attributes[:expected_policy_revision] > 0,
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, profile.iri <> "\nenroll"),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "EnrollModelAccessProfile",
               command_iri,
               profile,
               attributes,
               graph,
               [
                 %{
                   family: :factory_policy,
                   graph_iri: graph,
                   operation: :append,
                   metadata: %{lifecycle_state: :open},
                   additions: statements(profile),
                   supersessions: [],
                   invalidations: [],
                   removals: []
                 }
               ]
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enroll_model_access_profile)
    end
  end

  def enroll_command(_profile, _attributes, _options),
    do: invalid(:enroll_model_access_profile)

  @spec revoke_command(t(), non_neg_integer(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def revoke_command(profile, expected_generation, attributes, options \\ [])

  def revoke_command(%__MODULE__{} = profile, expected_generation, attributes, options)
      when is_integer(expected_generation) and expected_generation >= 1 and
             is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_policy_revision]) and
             attributes[:expected_policy_revision] > 0,
         %DateTime{} = revoked_at <- attributes[:revoked_at],
         statements when is_list(statements) <-
           revocation_statements(profile, expected_generation + 1, revoked_at),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, profile.iri <> "\nrevoke"),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RevokeModelAccessProfile",
               command_iri,
               profile,
               attributes,
               graph,
               [
                 %{
                   family: :factory_policy,
                   graph_iri: graph,
                   operation: :append,
                   metadata: %{lifecycle_state: :open},
                   additions: statements,
                   supersessions: [],
                   invalidations: [],
                   removals: []
                 }
               ],
               expected_generation
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:revoke_model_access_profile)
    end
  end

  def revoke_command(_profile, _expected_generation, _attributes, _options),
    do: invalid(:revoke_model_access_profile)

  @spec profile_guard(String.t(), String.t()) :: tuple()
  def profile_guard(graph, profile_iri), do: {:subject_present, graph, profile_iri}

  defp envelope(
         type,
         command_iri,
         profile,
         attributes,
         graph,
         changes,
         expected_generation \\ nil
       ) do
    %{
      command_type: type,
      command_version: "1.8.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{graph => attributes[:expected_policy_revision]},
      reason: attributes[:reason],
      payload: %{changes: changes, guards: guards(type, graph, profile, expected_generation)}
    }
  end

  defp guards("EnrollModelAccessProfile", graph, profile, _expected_generation),
    do: [{:subject_absent, graph, profile.iri}]

  defp guards("RevokeModelAccessProfile", graph, profile, expected_generation),
    do: [
      {:subject_present, graph, profile.iri},
      {:triple_present, graph, profile.iri, RDF.iri(@jf <> "revocationGeneration"),
       RDF.XSD.NonNegativeInteger.new(expected_generation || profile.revocation_generation)}
    ]

  defp readiness(values) when is_list(values) and values != [] do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(&1 in @readiness)),
      do: {:ok, values},
      else: invalid(:model_access_profile_readiness)
  rescue
    _error -> invalid(:model_access_profile_readiness)
  end

  defp readiness(_values), do: invalid(:model_access_profile_readiness)

  defp bounded_text(value, maximum) when is_binary(value) and byte_size(value) in 1..maximum//1,
    do: {:ok, value}

  defp bounded_text(_value, _maximum), do: invalid(:model_access_profile_text)

  defp validate_resource(value), do: ResourceIdentity.validate(value)

  defp camelize(value), do: Macro.camelize(to_string(value))

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}

  @spec digest64?(term()) :: boolean()
  def digest64?(value), do: is_binary(value) and Regex.match?(@digest64, value)
end

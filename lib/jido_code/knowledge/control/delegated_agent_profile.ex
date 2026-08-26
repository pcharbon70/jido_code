defmodule JidoCode.Knowledge.Control.DelegatedAgentProfile do
  @moduledoc "Immutable delegated coding agent profile and append-only lifecycle commands."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :display_name,
    :agent_key,
    :runtime_class,
    :provider,
    :harness_profile_iri,
    :model_access_profile_iri,
    :adapter_release_iri,
    :deployment_class,
    :authentication_kind,
    :billing_mode,
    :prompt_transport,
    :session_policy,
    :capability_class,
    :tool_manifest_digest,
    :workspace_policy_revision,
    :sandbox_profile_revision,
    :network_policy_revision,
    :credential_delivery,
    :candidate_protocol_revision,
    :verification_profile_revision,
    :budget,
    :task_classes,
    :language_classes,
    :owner_iri,
    :tenant_iris,
    :repository_iris,
    :actor_iris,
    :capability_iris,
    :state,
    :rollout_stage,
    :approved_at,
    :expires_at,
    :signer_iri,
    :profile_digest,
    :signed_digest
  ]
  defstruct @enforce_keys ++ [:supersedes_iri]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @providers ~w[codex pi claude gemini opencode amp grok kimi zai]a
  @deployments ~w[developer_local managed_fleet]a
  @authentication ~w[existing_cli_session oauth api_key workload_identity attaching_proxy]a
  @billing ~w[subscription metered_api unknown]a
  @prompt_transports ~w[stdin protected_file]a
  @session_policies ~w[none controller_reconstructed_turns bounded_resume]a
  @capabilities ~w[deny_all bounded_read_only workspace_write workspace_write_registered_checks]a
  @credential_delivery ~w[local_reference workload_exchange attaching_proxy]a
  @states ~w[disabled enabled revoked superseded]a
  @rollout ~w[disabled evaluation shadow pilot production]a
  @digest_fields ~w[tool_manifest_digest workspace_policy_revision sandbox_profile_revision network_policy_revision candidate_protocol_revision verification_profile_revision]a
  @binding_fields ~w[tenant_iris repository_iris actor_iris capability_iris]a

  @spec material_digest(map()) :: String.t()
  def material_digest(attributes),
    do: Contract.digest(Map.drop(attributes, [:iri, :profile_digest, :signed_digest]))

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         {:ok, display_name} <- Contract.text(attributes[:display_name], 128),
         {:ok, agent_key} <- Contract.identifier(attributes[:agent_key], 64),
         {:ok, :delegated_cli} <- Contract.enum(attributes[:runtime_class], [:delegated_cli]),
         {:ok, provider} <- Contract.enum(attributes[:provider], @providers),
         :ok <- validate_references(attributes),
         {:ok, deployment} <- Contract.enum(attributes[:deployment_class], @deployments),
         {:ok, authentication} <- Contract.enum(attributes[:authentication_kind], @authentication),
         {:ok, billing} <- Contract.enum(attributes[:billing_mode], @billing),
         {:ok, prompt_transport} <-
           Contract.enum(attributes[:prompt_transport], @prompt_transports),
         {:ok, session_policy} <- Contract.enum(attributes[:session_policy], @session_policies),
         {:ok, capability} <- Contract.enum(attributes[:capability_class], @capabilities),
         true <- Enum.all?(@digest_fields, &Contract.digest?(attributes[&1])),
         {:ok, delivery} <- Contract.enum(attributes[:credential_delivery], @credential_delivery),
         :ok <- compatible_delivery(deployment, delivery),
         {:ok, budget} <- Contract.bounded_map(attributes[:budget], 16_384),
         {:ok, task_classes} <- Contract.identifiers(attributes[:task_classes], 32, 64),
         {:ok, language_classes} <- Contract.identifiers(attributes[:language_classes], 32, 64),
         :ok <- Contract.resource(attributes[:owner_iri]),
         {:ok, bindings} <- bindings(attributes),
         {:ok, :disabled} <- Contract.enum(attributes[:state], @states),
         {:ok, rollout} <- Contract.enum(attributes[:rollout_stage], @rollout),
         :ok <- Contract.interval(attributes[:approved_at], attributes[:expires_at]),
         :ok <- Contract.resource(attributes[:signer_iri]),
         :ok <- Contract.optional_resource(attributes[:supersedes_iri]),
         true <- Contract.digest?(attributes[:signed_digest]),
         expected_digest <- material_digest(attributes),
         ^expected_digest <- attributes[:profile_digest],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :delegated_agent_profile,
             Enum.join(
               [
                 attributes.owner_iri,
                 agent_key,
                 Atom.to_string(provider),
                 Atom.to_string(deployment),
                 Integer.to_string(revision),
                 expected_digest
               ],
               "\n"
             )
           ) do
      normalized = %{
        display_name: display_name,
        agent_key: agent_key,
        runtime_class: :delegated_cli,
        provider: provider,
        deployment_class: deployment,
        authentication_kind: authentication,
        billing_mode: billing,
        prompt_transport: prompt_transport,
        session_policy: session_policy,
        capability_class: capability,
        credential_delivery: delivery,
        budget: budget,
        task_classes: task_classes,
        language_classes: language_classes,
        state: :disabled,
        rollout_stage: rollout
      }

      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys ++ [:supersedes_iri])
         |> Map.merge(bindings)
         |> Map.merge(normalized)
         |> Map.put(:iri, iri)
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_agent_profile)
    end
  rescue
    _error -> invalid(:delegated_agent_profile)
  end

  def new(_attributes), do: invalid(:delegated_agent_profile)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = profile) do
    base = [
      {profile.iri, @rdf_type, RDF.iri(@jf <> "DelegatedAgentProfile")},
      {profile.iri, @jf <> "profileRevision", RDF.XSD.NonNegativeInteger.new(profile.revision)},
      {profile.iri, @jf <> "displayName", RDF.XSD.String.new(profile.display_name)},
      {profile.iri, @jf <> "agentKey", RDF.XSD.String.new(profile.agent_key)},
      {profile.iri, @jf <> "runtimeClass", RDF.iri(Contract.concept(profile.runtime_class))},
      {profile.iri, @jf <> "profileProvider", RDF.iri(Contract.concept(profile.provider))},
      {profile.iri, @jf <> "harnessProfile", RDF.iri(profile.harness_profile_iri)},
      {profile.iri, @jf <> "modelAccessProfile", RDF.iri(profile.model_access_profile_iri)},
      {profile.iri, @jf <> "adapterRelease", RDF.iri(profile.adapter_release_iri)},
      {profile.iri, @jf <> "deploymentClass",
       RDF.iri(Contract.concept(profile.deployment_class))},
      {profile.iri, @jf <> "authenticationKind",
       RDF.iri(Contract.concept(profile.authentication_kind))},
      {profile.iri, @jf <> "billingMode", RDF.iri(Contract.concept(profile.billing_mode))},
      {profile.iri, @jf <> "promptTransport",
       RDF.iri(Contract.concept(profile.prompt_transport))},
      {profile.iri, @jf <> "sessionPolicy", RDF.iri(Contract.concept(profile.session_policy))},
      {profile.iri, @jf <> "capabilityClass",
       RDF.iri(Contract.concept(profile.capability_class))},
      {profile.iri, @jf <> "toolManifestDigest",
       RDF.XSD.String.new(profile.tool_manifest_digest)},
      {profile.iri, @jf <> "workspacePolicyRevision",
       RDF.XSD.String.new(profile.workspace_policy_revision)},
      {profile.iri, @jf <> "sandboxProfileRevision",
       RDF.XSD.String.new(profile.sandbox_profile_revision)},
      {profile.iri, @jf <> "networkPolicyRevision",
       RDF.XSD.String.new(profile.network_policy_revision)},
      {profile.iri, @jf <> "credentialDelivery",
       RDF.iri(Contract.concept(profile.credential_delivery))},
      {profile.iri, @jf <> "candidateProtocolRevision",
       RDF.XSD.String.new(profile.candidate_protocol_revision)},
      {profile.iri, @jf <> "verificationProfileRevision",
       RDF.XSD.String.new(profile.verification_profile_revision)},
      {profile.iri, @jf <> "budgetContract", RDF.XSD.String.new(Jason.encode!(profile.budget))},
      {profile.iri, @jf <> "ownedBy", RDF.iri(profile.owner_iri)},
      {profile.iri, @jf <> "profileState", RDF.iri(Contract.concept(profile.state))},
      {profile.iri, @jf <> "rolloutStage", RDF.iri(Contract.concept(profile.rollout_stage))},
      {profile.iri, @jf <> "approvedAt", RDF.XSD.DateTime.new(profile.approved_at)},
      {profile.iri, @jf <> "expiresAt", RDF.XSD.DateTime.new(profile.expires_at)},
      {profile.iri, @jf <> "signedBy", RDF.iri(profile.signer_iri)},
      {profile.iri, @jf <> "profileDigest", RDF.XSD.String.new(profile.profile_digest)},
      {profile.iri, @jf <> "signedDigest", RDF.XSD.String.new(profile.signed_digest)},
      {profile.iri, @prov <> "wasAttributedTo", RDF.iri(profile.owner_iri)}
    ]

    base ++
      literals(profile.iri, "taskClass", profile.task_classes) ++
      literals(profile.iri, "languageClass", profile.language_classes) ++
      iris(profile.iri, "boundTenant", profile.tenant_iris) ++
      iris(profile.iri, "boundRepository", profile.repository_iris) ++
      iris(profile.iri, "boundActor", profile.actor_iris) ++
      iris(profile.iri, "boundCapability", profile.capability_iris) ++
      optional_iri(profile.iri, @jf <> "supersedes", profile.supersedes_iri)
  end

  @spec register_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def register_command(profile, attributes, options \\ [])

  def register_command(%__MODULE__{} = profile, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <- positive?(attributes[:expected_policy_revision]),
         %DateTime{} <- attributes[:recorded_at],
         {:ok, transition} <- profile_transition(profile, nil, :disabled, attributes),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, profile.iri <> "\nregister"),
         additions = statements(profile) ++ Transition.statements(transition),
         guards = [
           {:subject_absent, graph, profile.iri},
           {:subject_present, graph, profile.harness_profile_iri},
           {:subject_present, graph, profile.model_access_profile_iri},
           {:subject_present, graph, profile.adapter_release_iri}
         ],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RegisterDelegatedAgentProfile",
               command_iri,
               attributes,
               graph,
               additions,
               guards
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:register_delegated_agent_profile)
    end
  end

  def register_command(_profile, _attributes, _options),
    do: invalid(:register_delegated_agent_profile)

  @spec transition_command(t(), map(), atom(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def transition_command(profile, resolution, next_state, attributes, options \\ [])

  def transition_command(%__MODULE__{} = profile, resolution, next_state, attributes, options)
      when is_map(resolution) and is_atom(next_state) and is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with true <- resolution[:current_state] in @states,
         true <-
           Transition.allowed_edge?(
             :delegated_agent_profile,
             resolution.current_state,
             next_state
           ),
         :ok <- Contract.resource(resolution[:current_transition]),
         revision when is_integer(revision) and revision >= 0 <- resolution[:current_revision],
         {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <- positive?(attributes[:expected_policy_revision]),
         %DateTime{} <- attributes[:recorded_at],
         {:ok, transition} <- profile_transition(profile, resolution, next_state, attributes),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(
             :command_request,
             Enum.join([profile.iri, transition.iri, Atom.to_string(next_state)], "\n")
           ),
         guards = [
           {:subject_present, graph, profile.iri},
           {:subject_present, graph, resolution.current_transition},
           {:subject_absent, graph, transition.iri}
         ],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionDelegatedAgentProfile",
               command_iri,
               attributes,
               graph,
               Transition.statements(transition),
               guards
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_delegated_agent_profile)
    end
  rescue
    _error -> invalid(:transition_delegated_agent_profile)
  end

  def transition_command(_profile, _resolution, _next_state, _attributes, _options),
    do: invalid(:transition_delegated_agent_profile)

  defp envelope(type, command_iri, attributes, graph, additions, guards) do
    %{
      command_type: type,
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
            additions: additions,
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        guards: guards
      }
    }
  end

  defp profile_transition(profile, nil, :disabled, attributes) do
    Transition.new(%{
      subject_iri: profile.iri,
      domain: :delegated_agent_profile,
      prior_state: nil,
      next_state: :disabled,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes.actor_iri,
      cause_iri: attributes.causation_iri,
      reason: attributes.reason,
      recorded_at: attributes.recorded_at
    })
  end

  defp profile_transition(profile, resolution, next_state, attributes) do
    Transition.new(%{
      subject_iri: profile.iri,
      domain: :delegated_agent_profile,
      prior_state: resolution.current_state,
      next_state: next_state,
      revision: resolution.current_revision + 1,
      expected_predecessor: resolution.current_transition,
      actor_iri: attributes.actor_iri,
      cause_iri: attributes.causation_iri,
      reason: attributes.reason,
      recorded_at: attributes.recorded_at
    })
  end

  defp validate_references(attributes) do
    fields = ~w[harness_profile_iri model_access_profile_iri adapter_release_iri]a
    if Enum.all?(fields, &(Contract.resource(attributes[&1]) == :ok)), do: :ok, else: :error
  end

  defp bindings(attributes) do
    Enum.reduce_while(@binding_fields, {:ok, %{}}, fn field, {:ok, result} ->
      case Contract.resources(attributes[field], 64) do
        {:ok, values} -> {:cont, {:ok, Map.put(result, field, values)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp compatible_delivery(:developer_local, :local_reference), do: :ok

  defp compatible_delivery(:managed_fleet, delivery)
       when delivery in [:workload_exchange, :attaching_proxy], do: :ok

  defp compatible_delivery(_deployment, _delivery), do: :error
  defp positive?(value), do: is_integer(value) and value > 0

  defp literals(subject, local, values),
    do: Enum.map(values, &{subject, @jf <> local, RDF.XSD.String.new(&1)})

  defp iris(subject, local, values), do: Enum.map(values, &{subject, @jf <> local, RDF.iri(&1)})
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, iri), do: [{subject, predicate, RDF.iri(iri)}]
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

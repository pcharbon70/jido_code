defmodule JidoCode.Knowledge.Control.ManagedCodingProfile do
  @moduledoc "Graph-native managed coding profile and append-only lifecycle commands."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :profile_digest,
    :jido_version,
    :strategy_revision,
    :strategy_iri,
    :prompt_bundle_revision,
    :model_access_profile_iri,
    :context_policy_revision,
    :memory_policy_revision,
    :tool_catalog_revision,
    :adapter_set_revision,
    :sandbox_profile_revision,
    :verifier_profile_revision,
    :candidate_schema_revision,
    :budget_contract,
    :task_classes,
    :actor_iris,
    :tenant_iris,
    :repository_iris,
    :capability_iris
  ]
  defstruct @enforce_keys ++ [:supersedes_iri]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @digest ~r/^[a-f0-9]{64}$/
  @revision_fields ~w[strategy_revision prompt_bundle_revision context_policy_revision memory_policy_revision tool_catalog_revision adapter_set_revision sandbox_profile_revision verifier_profile_revision candidate_schema_revision]a
  @binding_fields ~w[actor_iris tenant_iris repository_iris capability_iris]a
  @states ~w[disabled enabled revoked superseded]a

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:iri]),
         revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         true <- digest?(attributes[:profile_digest]),
         "2.3.2" <- attributes[:jido_version],
         true <- Enum.all?(@revision_fields, &digest?(attributes[&1])),
         :ok <- ResourceIdentity.validate(attributes[:model_access_profile_iri]),
         {:ok, strategy_iri} <-
           ResourceIdentity.deterministic(
             :harness_profile,
             "managed-coding-strategy\n" <> attributes.strategy_revision
           ),
         budget when is_map(budget) <- attributes[:budget_contract],
         true <- bounded?(budget, 16_384),
         {:ok, task_classes} <- task_classes(attributes[:task_classes]),
         {:ok, bindings} <- bindings(attributes),
         :ok <- optional_resource(attributes[:supersedes_iri]) do
      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys ++ [:supersedes_iri])
         |> Map.merge(bindings)
         |> Map.put(:task_classes, task_classes)
         |> Map.put(:strategy_iri, strategy_iri)
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:managed_coding_profile)
    end
  rescue
    _error -> invalid(:managed_coding_profile)
  end

  def new(_attributes), do: invalid(:managed_coding_profile)

  @spec register_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def register_command(profile, attributes, options \\ [])

  def register_command(%__MODULE__{} = profile, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <- positive_revision?(attributes[:expected_policy_revision]),
         %DateTime{} <- attributes[:recorded_at],
         {:ok, transition} <- profile_transition(profile, nil, :disabled, attributes),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, profile.iri <> "\nregister"),
         additions =
           statements(profile) ++
             Transition.statements(transition),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RegisterManagedCodingProfile",
               command_iri,
               attributes,
               graph,
               additions,
               [
                 {:subject_absent, graph, profile.iri},
                 {:subject_present, graph, profile.model_access_profile_iri}
               ]
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:register_managed_coding_profile)
    end
  end

  def register_command(_profile, _attributes, _options),
    do: invalid(:register_managed_coding_profile)

  @spec transition_command(t(), map(), atom(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def transition_command(profile, resolution, next_state, attributes, options \\ [])

  def transition_command(
        %__MODULE__{} = profile,
        resolution,
        next_state,
        attributes,
        options
      )
      when is_map(resolution) and is_atom(next_state) and is_map(attributes) and
             is_list(options) do
    graph = attributes[:policy_graph_iri]
    current = resolution[:current_state]

    with true <-
           current in @states and
             Transition.allowed_edge?(:managed_coding_profile, current, next_state),
         :ok <- ResourceIdentity.validate(resolution[:current_transition]),
         true <- is_integer(resolution[:current_revision]) and resolution.current_revision >= 0,
         {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <- positive_revision?(attributes[:expected_policy_revision]),
         %DateTime{} <- attributes[:recorded_at],
         {:ok, transition} <- profile_transition(profile, resolution, next_state, attributes),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(
             :command_request,
             Enum.join([profile.iri, transition.revision, next_state], "\n")
           ),
         additions = Transition.statements(transition),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionManagedCodingProfile",
               command_iri,
               attributes,
               graph,
               additions,
               [
                 {:subject_present, graph, profile.iri},
                 {:subject_present, graph, resolution.current_transition},
                 {:subject_absent, graph, transition.iri}
               ]
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_managed_coding_profile)
    end
  rescue
    _error -> invalid(:transition_managed_coding_profile)
  end

  def transition_command(_profile, _resolution, _next, _attributes, _options),
    do: invalid(:transition_managed_coding_profile)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = profile) do
    base = [
      {profile.iri, @rdf_type, RDF.iri(@jf <> "ManagedCodingProfile")},
      {profile.iri, @jf <> "profileRevision", RDF.XSD.NonNegativeInteger.new(profile.revision)},
      {profile.iri, @jf <> "profileDigest", RDF.XSD.String.new(profile.profile_digest)},
      {profile.iri, @jf <> "jidoVersion", RDF.XSD.String.new(profile.jido_version)},
      {profile.iri, @jf <> "usesCodingStrategyRevision", RDF.iri(profile.strategy_iri)},
      {profile.iri, @jf <> "strategyRevisionDigest",
       RDF.XSD.String.new(profile.strategy_revision)},
      {profile.strategy_iri, @rdf_type, RDF.iri(@jf <> "CodingStrategyRevision")},
      {profile.strategy_iri, @jf <> "strategyRevisionDigest",
       RDF.XSD.String.new(profile.strategy_revision)},
      {profile.iri, @jf <> "promptBundleRevision",
       RDF.XSD.String.new(profile.prompt_bundle_revision)},
      {profile.iri, @jf <> "modelAccessProfile", RDF.iri(profile.model_access_profile_iri)},
      {profile.iri, @jf <> "contextPolicyRevision",
       RDF.XSD.String.new(profile.context_policy_revision)},
      {profile.iri, @jf <> "memoryPolicyRevision",
       RDF.XSD.String.new(profile.memory_policy_revision)},
      {profile.iri, @jf <> "toolCatalogRevision",
       RDF.XSD.String.new(profile.tool_catalog_revision)},
      {profile.iri, @jf <> "adapterSetRevision",
       RDF.XSD.String.new(profile.adapter_set_revision)},
      {profile.iri, @jf <> "sandboxProfileRevision",
       RDF.XSD.String.new(profile.sandbox_profile_revision)},
      {profile.iri, @jf <> "verifierProfileRevision",
       RDF.XSD.String.new(profile.verifier_profile_revision)},
      {profile.iri, @jf <> "candidateSchemaRevision",
       RDF.XSD.String.new(profile.candidate_schema_revision)},
      {profile.iri, @jf <> "budgetContract",
       RDF.XSD.String.new(Jason.encode!(profile.budget_contract))}
    ]

    base ++
      literals(profile.iri, "taskClass", profile.task_classes) ++
      iris(profile.iri, "boundActor", profile.actor_iris) ++
      iris(profile.iri, "boundTenant", profile.tenant_iris) ++
      iris(profile.iri, "boundRepository", profile.repository_iris) ++
      iris(profile.iri, "boundCapability", profile.capability_iris) ++
      optional_iri(profile.iri, @jf <> "supersedes", profile.supersedes_iri)
  end

  @spec project([map()], String.t()) :: {:ok, map()} | {:error, Error.t()}
  def project(rows, profile_iri) when is_list(rows) and length(rows) <= 256 do
    transitions =
      rows
      |> Enum.filter(&is_integer(value(&1, "revision")))
      |> Enum.map(fn row ->
        %{
          transition_iri: value(row, "transition"),
          state: concept(value(row, "state")),
          revision: value(row, "revision"),
          predecessor_iri: value(row, "predecessor")
        }
      end)
      |> Enum.uniq()
      |> Enum.sort_by(& &1.revision)

    with :ok <- ResourceIdentity.validate(profile_iri),
         [_ | _] <- transitions,
         true <- valid_chain?(transitions),
         current <- List.last(transitions) do
      {:ok,
       %{
         profile_iri: profile_iri,
         current_state: current.state,
         current_revision: current.revision,
         current_transition: current.transition_iri,
         selectable?: current.state == :enabled,
         transitions: transitions
       }}
    else
      _invalid -> invalid(:managed_coding_profile_projection)
    end
  end

  def project(_rows, _profile_iri), do: invalid(:managed_coding_profile_projection)

  defp envelope(type, command_iri, attributes, graph, additions, guards) do
    %{
      command_type: type,
      command_version: "2.8.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.3.0",
      shape_version: "1.3.0",
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
      domain: :managed_coding_profile,
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
      domain: :managed_coding_profile,
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

  defp bindings(attributes) do
    Enum.reduce_while(@binding_fields, {:ok, %{}}, fn field, {:ok, result} ->
      case resources(attributes[field]) do
        {:ok, values} -> {:cont, {:ok, Map.put(result, field, values)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp resources(values) when is_list(values) and values != [] and length(values) <= 64 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp resources(_values), do: :error

  defp task_classes(values) when is_list(values) and values != [] and length(values) <= 32 do
    if Enum.all?(values, &valid_task_class?/1),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp task_classes(_values), do: :error

  defp valid_task_class?(value) when is_binary(value) and byte_size(value) in 1..64//1,
    do: Regex.match?(~r/^[a-z][a-z0-9_-]*$/, value)

  defp valid_task_class?(_value), do: false
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)
  defp positive_revision?(value), do: is_integer(value) and value > 0
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp bounded?(value, limit),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit

  defp literals(subject, local, values),
    do: Enum.map(values, &{subject, @jf <> local, RDF.XSD.String.new(&1)})

  defp iris(subject, local, values), do: Enum.map(values, &{subject, @jf <> local, RDF.iri(&1)})
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, iri), do: [{subject, predicate, RDF.iri(iri)}]

  defp value(row, key) do
    case Map.get(row, key) do
      %{value: value} -> value
      value -> value
    end
  end

  defp concept(value) do
    case Transition.state_from_iri(:managed_coding_profile, value) do
      {:ok, state} -> state
      _error -> nil
    end
  end

  defp valid_chain?([first | rest]) do
    first.revision == 0 and is_nil(first.predecessor_iri) and first.state == :disabled and
      Enum.reduce_while(rest, first, fn current, prior ->
        if current.revision == prior.revision + 1 and
             current.predecessor_iri == prior.transition_iri and
             Transition.allowed_edge?(:managed_coding_profile, prior.state, current.state),
           do: {:cont, current},
           else: {:halt, false}
      end) != false
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

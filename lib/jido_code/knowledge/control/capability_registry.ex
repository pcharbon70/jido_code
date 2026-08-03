defmodule JidoCode.Knowledge.Control.CapabilityRegistry do
  @moduledoc """
  Declared and observed capability facts for actors, agents, tools, and sandboxes.

  Possession, availability, and authorization are separate graph relationships.
  Inferred hierarchy facts are published only to rebuildable derived graphs.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :holder_iri,
    :scope_iri,
    :kind,
    :capability_iri,
    :provider_iri,
    :provider_version,
    :mode,
    :supported_scope_refs,
    :supported_effect_refs,
    :authorization_grant_refs,
    :evidence_source_iri,
    :limits,
    :complete?,
    :valid_from,
    :valid_to,
    :transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @kinds ~w[actor agent tool sandbox]a
  @modes ~w[declared observed]a
  @limit_keys ~w[concurrency time_seconds cost_units memory_bytes disk_bytes risk_level]a
  @max_refs 30

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- validate_resource(attributes[:holder_iri]),
         :ok <- validate_resource(attributes[:scope_iri]),
         kind when kind in @kinds <- attributes[:kind],
         :ok <- validate_resource(attributes[:capability_iri]),
         :ok <- validate_resource(attributes[:provider_iri]),
         {:ok, provider_version} <- version(attributes[:provider_version]),
         mode when mode in @modes <- attributes[:mode],
         {:ok, scopes} <- resources(attributes[:supported_scope_refs], true),
         {:ok, effects} <- resources(attributes[:supported_effect_refs], true),
         {:ok, grants} <- resources(attributes[:authorization_grant_refs], false),
         :ok <- validate_resource(attributes[:evidence_source_iri]),
         {:ok, limits} <- limits(attributes[:limits]),
         true <- is_boolean(attributes[:complete?]),
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         {:ok, iri} <- capability_identity(attributes, provider_version),
         {:ok, transition} <- initial_transition(iri, attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         holder_iri: attributes[:holder_iri],
         scope_iri: attributes[:scope_iri],
         kind: kind,
         capability_iri: attributes[:capability_iri],
         provider_iri: attributes[:provider_iri],
         provider_version: provider_version,
         mode: mode,
         supported_scope_refs: scopes,
         supported_effect_refs: effects,
         authorization_grant_refs: grants,
         evidence_source_iri: attributes[:evidence_source_iri],
         limits: limits,
         complete?: attributes[:complete?],
         valid_from: valid_from,
         valid_to: valid_to,
         transition: transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:capability_declaration)
    end
  rescue
    _error -> invalid(:capability_declaration)
  end

  def new(_attributes), do: invalid(:capability_declaration)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = capability) do
    [
      {capability.iri, @rdf_type, RDF.iri(@jf <> "Capability")},
      {capability.iri, @jf <> "heldBy", RDF.iri(capability.holder_iri)},
      {capability.iri, @jf <> "validFor", RDF.iri(capability.scope_iri)},
      {capability.iri, @jf <> "about", RDF.iri(capability.capability_iri)},
      {capability.iri, @jf <> "capabilityKind", RDF.iri(kind_iri(capability.kind))},
      {capability.iri, @jf <> "sourceActivity", RDF.iri(capability.provider_iri)},
      {capability.iri, @jf <> "version", RDF.XSD.String.new(capability.provider_version)},
      {capability.iri, @jf <> "epistemicState", RDF.iri(mode_iri(capability.mode))},
      {capability.iri, @jf <> "evidenceSource", RDF.iri(capability.evidence_source_iri)},
      {capability.iri, @jf <> "completenessState",
       RDF.iri(@concept <> if(capability.complete?, do: "Complete", else: "Incomplete"))},
      {capability.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(capability.valid_from)},
      {capability.iri, @jf <> "validTo", RDF.XSD.DateTime.new(capability.valid_to)}
    ] ++
      Enum.map(
        capability.supported_scope_refs,
        &{capability.iri, @jf <> "supportsScope", RDF.iri(&1)}
      ) ++
      Enum.map(
        capability.supported_effect_refs,
        &{capability.iri, @jf <> "supportsEffect", RDF.iri(&1)}
      ) ++
      Enum.map(
        capability.authorization_grant_refs,
        &{capability.iri, @jf <> "authorizedBy", RDF.iri(&1)}
      ) ++
      Enum.flat_map(capability.limits, fn limit ->
        [
          {capability.iri, @jf <> "constrainedBy", RDF.iri(limit.iri)},
          {limit.iri, @rdf_type, RDF.iri(@jf <> "Constraint")},
          {limit.iri, @jf <> "about", RDF.iri(capability.iri)},
          {limit.iri, @jf <> "taskKind", RDF.iri(limit.kind_iri)},
          {limit.iri, @jf <> "displayId", RDF.XSD.NonNegativeInteger.new(limit.value)}
        ]
      end) ++ Transition.statements(capability.transition)
  end

  @spec register_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), capability: t()}} | {:error, Error.t()}
  def register_command(capability, attributes, options \\ [])

  def register_command(%__MODULE__{} = capability, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         target = policy_target(graph, statements(capability)),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RegisterCapability",
               attributes,
               capability.scope_iri,
               %{graph => attributes[:expected_policy_revision]},
               [target],
               [{:subject_absent, graph, capability.iri}]
             ),
             options
           ) do
      {:ok, %{command: command, capability: capability}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:register_capability_command)
    end
  end

  def register_command(_capability, _attributes, _options),
    do: invalid(:register_capability_command)

  @spec transition_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}}
          | {:error, Error.t()}
  def transition_command(resolution, attributes, options \\ [])

  def transition_command(%{domain: :capability} = resolution, attributes, options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         {:ok, transition} <- next_transition(resolution, attributes),
         target = policy_target(graph, Transition.statements(transition)),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionCapability",
               attributes,
               attributes[:scope_iri],
               %{graph => attributes[:expected_policy_revision]},
               [target],
               [Transition.guard(transition, graph)]
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_capability_command)
    end
  end

  def transition_command(_resolution, _attributes, _options),
    do: invalid(:transition_capability_command)

  @spec publish_hierarchy([map()], map(), keyword()) :: term()
  def publish_hierarchy(classifications, attributes, options \\ [])

  def publish_hierarchy(classifications, attributes, options)
      when is_list(classifications) and length(classifications) <= 100 and is_map(attributes) do
    with {:ok, statements} <- classification_statements(classifications, attributes),
         {:ok, target_graph} <-
           GraphRegistry.graph_iri(:derived, %{
             rule_set: attributes[:rule_set_slug],
             revision: attributes[:rule_revision]
           }),
         true <- target_graph == attributes[:target_graph_iri] do
      DerivedGraphManager.publish(
        %{
          operation: :publish,
          command_iri: attributes[:command_iri],
          authority: attributes[:authority],
          scope_iri: attributes[:scope_iri],
          idempotency_key: attributes[:idempotency_key],
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          target_graph_iri: target_graph,
          rule_set_iri: attributes[:rule_set_iri],
          rule_set_slug: attributes[:rule_set_slug],
          rule_revision: attributes[:rule_revision],
          query_version: attributes[:evaluator_version],
          source_graph_revisions: attributes[:source_graph_revisions],
          expected_prior_derivation: Map.get(attributes, :expected_prior_derivation),
          reason: attributes[:reason],
          statements: statements
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:publish_capability_hierarchy)
    end
  end

  def publish_hierarchy(_classifications, _attributes, _options),
    do: invalid(:publish_capability_hierarchy)

  @spec schedulable?(map(), DateTime.t()) :: {:ok, map()} | {:blocked, [atom()]}
  def schedulable?(projection, %DateTime{} = now) when is_map(projection) do
    reasons =
      []
      |> add_reason(projection[:state] != :available, :capability_unavailable)
      |> add_reason(projection[:complete?] != true, :capability_incomplete)
      |> add_reason(projection[:authorization_grant_refs] in [nil, []], :authorization_absent)
      |> add_reason(projection[:authorization_complete?] != true, :authorization_incomplete)
      |> add_reason(projection[:authorized_scope?] != true, :authorization_scope_mismatch)
      |> add_reason(projection[:inferred?] == true, :capability_inferred_only)
      |> add_reason(not valid_at?(projection, now), :capability_stale)

    if reasons == [], do: {:ok, projection}, else: {:blocked, Enum.reverse(reasons)}
  end

  def schedulable?(_projection, _now), do: {:blocked, [:capability_invalid]}

  defp classification_statements(values, attributes) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, statements} ->
      with :ok <- validate_resource(value[:capability_iri]),
           :ok <- validate_resource(value[:broader_capability_iri]),
           {:ok, iri} <-
             ResourceIdentity.deterministic(
               :capability_classification,
               Enum.join(
                 [
                   value[:capability_iri],
                   value[:broader_capability_iri],
                   attributes[:evaluator_version]
                 ],
                 "\n"
               )
             ) do
        additions = [
          {iri, @rdf_type, RDF.iri(@jf <> "CapabilityClassification")},
          {iri, @jf <> "member", RDF.iri(value[:capability_iri])},
          {iri, @jf <> "broaderCapability", RDF.iri(value[:broader_capability_iri])},
          {iri, @jf <> "version", RDF.XSD.String.new(attributes[:evaluator_version])}
        ]

        {:cont, {:ok, additions ++ statements}}
      else
        _invalid -> {:halt, invalid(:capability_classification)}
      end
    end)
  end

  defp initial_transition(iri, attributes) do
    Transition.new(%{
      subject_iri: iri,
      domain: :capability,
      prior_state: nil,
      next_state: :proposed,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes[:holder_iri],
      cause_iri: attributes[:cause_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp next_transition(resolution, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: :capability,
      prior_state: resolution.current_state,
      next_state: attributes[:next_state],
      revision: resolution.current_revision + 1,
      expected_predecessor: resolution.current_transition,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp policy_target(graph, additions) do
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
  end

  defp envelope(type, attributes, scope, revisions, changes, guards) do
    %{
      command_type: type,
      command_version: "1.3.0",
      command_iri: attributes[:command_iri],
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: scope,
      idempotency_key: attributes[:idempotency_key],
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: revisions,
      reason: attributes[:reason],
      payload: %{changes: changes, guards: guards}
    }
  end

  defp limits(values) when is_map(values) and map_size(values) <= length(@limit_keys) do
    Enum.reduce_while(values, {:ok, []}, fn {key, value}, {:ok, limits} ->
      if key in @limit_keys and is_integer(value) and value >= 0 do
        kind_iri = @concept <> "CapabilityLimit" <> Macro.camelize(to_string(key))

        case ResourceIdentity.deterministic(
               :control_constraint,
               kind_iri <> "\n" <> Integer.to_string(value)
             ) do
          {:ok, iri} ->
            {:cont, {:ok, [%{iri: iri, kind_iri: kind_iri, value: value} | limits]}}

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}
        end
      else
        {:halt, invalid(:capability_limits)}
      end
    end)
    |> case do
      {:ok, limits} -> {:ok, Enum.sort_by(limits, & &1.kind_iri)}
      error -> error
    end
  end

  defp limits(_values), do: invalid(:capability_limits)

  defp resources(values, required?)
       when is_list(values) and length(values) <= @max_refs and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:capability_references)
  end

  defp resources(_values, _required), do: invalid(:capability_references)

  defp capability_identity(attributes, provider_version) do
    ResourceIdentity.deterministic(
      :capability_declaration,
      Enum.join(
        [
          attributes[:holder_iri],
          attributes[:capability_iri],
          attributes[:provider_iri],
          provider_version,
          Atom.to_string(attributes[:mode])
        ],
        "\n"
      )
    )
  end

  defp version(value) when is_binary(value) and byte_size(value) in 1..128,
    do: {:ok, value}

  defp version(_value), do: invalid(:capability_version)

  defp interval(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) == :lt,
      do: {:ok, DateTime.truncate(from, :microsecond), DateTime.truncate(to, :microsecond)},
      else: invalid(:capability_interval)
  end

  defp interval(_from, _to), do: invalid(:capability_interval)

  defp valid_at?(projection, now) do
    match?(%DateTime{}, projection[:valid_from]) and match?(%DateTime{}, projection[:valid_to]) and
      DateTime.compare(projection.valid_from, now) in [:lt, :eq] and
      DateTime.compare(now, projection.valid_to) == :lt
  end

  defp add_reason(reasons, true, reason), do: [reason | reasons]
  defp add_reason(reasons, false, _reason), do: reasons
  defp kind_iri(kind), do: @concept <> "Capability" <> Macro.camelize(to_string(kind))
  defp mode_iri(mode), do: @concept <> Macro.camelize(to_string(mode))
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

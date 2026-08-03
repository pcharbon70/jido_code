defmodule JidoCode.Knowledge.Control.Policy do
  @moduledoc """
  Versioned policy contracts and lifecycle commands.

  Policy definitions cite reviewed evaluator identities and closed graph inputs;
  RDF never contains executable policy code.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :name,
    :version,
    :owner_iri,
    :scope_iri,
    :kind,
    :evaluator,
    :closed_inputs,
    :desired_outcome_refs,
    :constraint_refs,
    :obligation_template_iri,
    :evidence_requirement_refs,
    :decision_requirement_refs,
    :valid_from,
    :valid_to,
    :priority,
    :conflict_posture,
    :conflicts_with,
    :transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @kinds ~w[desired_posture authorization acceptance]a
  @priorities %{low: 10, normal: 20, high: 30, critical: 40}
  @conflict_postures ~w[fail_closed explicit_decision priority]a
  @evaluators %{
    {:static_membership, "1.0.0"} => :factory_repository_cohort,
    {:repository_metadata, "1.0.0"} => :active_enrollment,
    {:repository_claim, "1.0.0"} => :observation_claim_history,
    {:source_semantics, "1.0.0"} => :source_entity_neighborhood,
    {:protected_main, "1.0.0"} => :latest_complete_observation
  }
  @max_refs 30
  @max_inputs 8

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, name} <- name(attributes[:name]),
         {:ok, version} <- semantic_version(attributes[:version]),
         :ok <- validate_resource(attributes[:owner_iri]),
         :ok <- validate_resource(attributes[:scope_iri]),
         kind when kind in @kinds <- attributes[:kind],
         {:ok, evaluator} <- evaluator(attributes[:evaluator]),
         {:ok, closed_inputs} <- closed_inputs(attributes[:closed_inputs]),
         {:ok, desired} <- resources(attributes[:desired_outcome_refs], kind == :desired_posture),
         {:ok, constraints} <- resources(attributes[:constraint_refs], false),
         :ok <- validate_resource(attributes[:obligation_template_iri]),
         {:ok, evidence} <- resources(attributes[:evidence_requirement_refs], false),
         {:ok, decisions} <- resources(attributes[:decision_requirement_refs], false),
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         true <- Map.has_key?(@priorities, attributes[:priority]),
         posture when posture in @conflict_postures <- attributes[:conflict_posture],
         {:ok, conflicts} <- resources(Map.get(attributes, :conflicts_with, []), false),
         {:ok, iri} <- policy_identity(name, version, attributes[:owner_iri]),
         {:ok, transition} <- initial_transition(iri, attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         name: name,
         version: version,
         owner_iri: attributes[:owner_iri],
         scope_iri: attributes[:scope_iri],
         kind: kind,
         evaluator: evaluator,
         closed_inputs: closed_inputs,
         desired_outcome_refs: desired,
         constraint_refs: constraints,
         obligation_template_iri: attributes[:obligation_template_iri],
         evidence_requirement_refs: evidence,
         decision_requirement_refs: decisions,
         valid_from: valid_from,
         valid_to: valid_to,
         priority: attributes[:priority],
         conflict_posture: posture,
         conflicts_with: conflicts,
         transition: transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:policy_contract)
    end
  rescue
    _error -> invalid(:policy_contract)
  end

  def new(_attributes), do: invalid(:policy_contract)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = policy) do
    [
      {policy.iri, @rdf_type, RDF.iri(@jf <> "Policy")},
      {policy.iri, @jf <> "displayId", RDF.XSD.String.new(policy.name)},
      {policy.iri, @jf <> "version", RDF.XSD.String.new(policy.version)},
      {policy.iri, @jf <> "ownedBy", RDF.iri(policy.owner_iri)},
      {policy.iri, @jf <> "validFor", RDF.iri(policy.scope_iri)},
      {policy.iri, @jf <> "policyKind", RDF.iri(kind_iri(policy.kind))},
      {policy.iri, @jf <> "applicabilityEvaluator", RDF.iri(policy.evaluator.iri)},
      {policy.iri, @jf <> "obligationTemplate", RDF.iri(policy.obligation_template_iri)},
      {policy.iri, @jf <> "priority", RDF.iri(priority_iri(policy.priority))},
      {policy.iri, @jf <> "conflictPosture", RDF.iri(posture_iri(policy.conflict_posture))},
      {policy.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(policy.valid_from)},
      {policy.iri, @jf <> "validTo", RDF.XSD.DateTime.new(policy.valid_to)},
      {policy.iri, @prov <> "wasAttributedTo", RDF.iri(policy.owner_iri)},
      {policy.evaluator.iri, @rdf_type, RDF.iri(@prov <> "SoftwareAgent")},
      {policy.evaluator.iri, @jf <> "displayId", RDF.XSD.String.new(policy.evaluator.name)},
      {policy.evaluator.iri, @jf <> "version", RDF.XSD.String.new(policy.evaluator.version)},
      {policy.evaluator.iri, @jf <> "queryVersion", RDF.XSD.String.new(policy.evaluator.query)}
    ] ++
      Enum.map(policy.closed_inputs, &{policy.iri, @jf <> "closedInput", RDF.iri(&1)}) ++
      Enum.map(policy.desired_outcome_refs, &{policy.iri, @jf <> "requiredOutcome", RDF.iri(&1)}) ++
      Enum.map(policy.constraint_refs, &{policy.iri, @jf <> "constrainedBy", RDF.iri(&1)}) ++
      Enum.map(
        policy.evidence_requirement_refs,
        &{
          policy.iri,
          @jf <> "expectedEvidence",
          RDF.iri(&1)
        }
      ) ++
      Enum.map(
        policy.decision_requirement_refs,
        &{
          policy.iri,
          @jf <> "requiresDecision",
          RDF.iri(&1)
        }
      ) ++
      Enum.map(policy.conflicts_with, &{policy.iri, @jf <> "conflictsWith", RDF.iri(&1)}) ++
      Transition.statements(policy.transition)
  end

  @spec propose_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), policy: t()}} | {:error, Error.t()}
  def propose_command(policy, attributes, options \\ [])

  def propose_command(%__MODULE__{} = policy, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_policy_revision]) and
             attributes[:expected_policy_revision] > 0,
         target = policy_target(graph, statements(policy)),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "ProposePolicy",
               attributes,
               %{graph => attributes[:expected_policy_revision]},
               [target],
               [{:subject_absent, graph, policy.iri}]
             ),
             options
           ) do
      {:ok, %{command: command, policy: policy}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:propose_policy_command)
    end
  end

  def propose_command(_policy, _attributes, _options), do: invalid(:propose_policy_command)

  @spec transition_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}}
          | {:error, Error.t()}
  def transition_command(resolution, attributes, options \\ [])

  def transition_command(%{domain: :policy} = resolution, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         {:ok, transition} <- next_transition(resolution, attributes),
         target = policy_target(graph, Transition.statements(transition)),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionPolicy",
               attributes,
               %{graph => attributes[:expected_policy_revision]},
               [target],
               [Transition.guard(transition, graph)]
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_policy_command)
    end
  end

  def transition_command(_resolution, _attributes, _options),
    do: invalid(:transition_policy_command)

  @spec resolve_conflicts([t()]) ::
          {:ok, map()} | {:requires_decision, map()} | {:error, Error.t()}
  def resolve_conflicts(policies) when is_list(policies) and policies != [] do
    with true <- Enum.all?(policies, &match?(%__MODULE__{}, &1)),
         true <- Enum.all?(policies, &(&1.kind == hd(policies).kind)) do
      ordered = Enum.sort_by(policies, &{-Map.fetch!(@priorities, &1.priority), &1.iri})
      [winner | rest] = ordered

      conflicts = Enum.filter(rest, &conflict?(&1, winner))

      if conflicts == [] do
        {:ok, %{winner: winner, superseded: rest, explanation: :deterministic_priority}}
      else
        {:requires_decision,
         %{candidates: [winner | conflicts], explanation: :incompatible_applicable_policies}}
      end
    else
      _invalid -> invalid(:policy_conflict_evaluation)
    end
  end

  def resolve_conflicts(_policies), do: invalid(:policy_conflict_evaluation)

  @spec evaluator_allowed?(atom(), String.t(), atom()) :: boolean()
  def evaluator_allowed?(name, version, query),
    do: Map.get(@evaluators, {name, version}) == query

  defp evaluator(%{name: name, version: version, query: query}) do
    with true <- evaluator_allowed?(name, version, query),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :policy_evaluator,
             Enum.join([Atom.to_string(name), version, Atom.to_string(query)], "\n")
           ) do
      {:ok,
       %{iri: iri, name: Atom.to_string(name), version: version, query: Atom.to_string(query)}}
    else
      _invalid -> invalid(:policy_evaluator)
    end
  end

  defp evaluator(_value), do: invalid(:policy_evaluator)

  defp initial_transition(policy_iri, attributes) do
    Transition.new(%{
      subject_iri: policy_iri,
      domain: :policy,
      prior_state: nil,
      next_state: :proposed,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes[:owner_iri],
      cause_iri: attributes[:cause_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp next_transition(resolution, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: :policy,
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

  defp envelope(type, attributes, revisions, changes, guards) do
    %{
      command_type: type,
      command_version: "1.3.0",
      command_iri: attributes[:command_iri],
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
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

  defp closed_inputs(values)
       when is_list(values) and length(values) in 1..@max_inputs do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &match?({:ok, _family}, GraphRegistry.identify(&1))),
      do: {:ok, values},
      else: invalid(:policy_closed_inputs)
  end

  defp closed_inputs(_values), do: invalid(:policy_closed_inputs)

  defp resources(values, required?)
       when is_list(values) and length(values) <= @max_refs and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:policy_references)
  end

  defp resources(_values, _required), do: invalid(:policy_references)

  defp conflict?(left, right) do
    left.iri in right.conflicts_with or right.iri in left.conflicts_with or
      (left.priority == right.priority and
         (left.conflict_posture != :priority or right.conflict_posture != :priority))
  end

  defp policy_identity(name, version, owner) do
    ResourceIdentity.deterministic(:policy_version, Enum.join([owner, name, version], "\n"))
  end

  defp name(value) when is_binary(value) and byte_size(value) in 1..128 do
    if Regex.match?(~r/^[a-z][a-z0-9._-]*$/, value), do: {:ok, value}, else: invalid(:policy_name)
  end

  defp name(_value), do: invalid(:policy_name)

  defp semantic_version(value) when is_binary(value) do
    if Regex.match?(~r/^\d+\.\d+\.\d+$/, value),
      do: {:ok, value},
      else: invalid(:policy_version)
  end

  defp semantic_version(_value), do: invalid(:policy_version)

  defp interval(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) == :lt,
      do: {:ok, DateTime.truncate(from, :microsecond), DateTime.truncate(to, :microsecond)},
      else: invalid(:policy_interval)
  end

  defp interval(_from, _to), do: invalid(:policy_interval)

  defp kind_iri(value), do: @concept <> "Policy" <> Macro.camelize(to_string(value))
  defp priority_iri(value), do: @concept <> "Priority" <> Macro.camelize(to_string(value))
  defp posture_iri(value), do: @concept <> "Conflict" <> Macro.camelize(to_string(value))
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

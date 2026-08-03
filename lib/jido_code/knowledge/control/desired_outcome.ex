defmodule JidoCode.Knowledge.Control.DesiredOutcome do
  @moduledoc """
  Builds graph-native desired-outcome commands.

  A desired proposition is reified in the factory policy graph and is never a
  claim about observed reality. Its lifecycle is an accepted transition chain
  in the repository control graph.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :scope_iri,
    :repository_iri,
    :actor_iri,
    :target,
    :priority,
    :valid_from,
    :valid_to,
    :policy_refs,
    :evidence_refs,
    :constraints,
    :conflicts_with,
    :transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @constraint_kinds ~w[
    allowed_branch allowed_path change_bound risk_bound required_check required_approval
    time_budget cost_budget required_tool required_sandbox prohibited_effect
  ]a
  @priorities ~w[low normal high critical]a
  @max_constraints 30
  @max_refs 30

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- validate_resource(attributes[:scope_iri]),
         :ok <- validate_resource(attributes[:repository_iri]),
         :ok <- validate_resource(attributes[:actor_iri]),
         {:ok, target, target_material} <- target(attributes),
         priority when priority in @priorities <- attributes[:priority],
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         {:ok, policy_refs} <- resources(attributes[:policy_refs], @max_refs, false),
         {:ok, evidence_refs} <- resources(attributes[:evidence_refs], @max_refs, true),
         {:ok, conflicts} <-
           resources(Map.get(attributes, :conflicts_with, []), @max_refs, false),
         :ok <- conflict_resolution(conflicts, attributes),
         {:ok, iri} <- desired_identity(attributes, target_material),
         {:ok, constraints} <- constraints(iri, attributes[:constraints]),
         {:ok, transition} <-
           Transition.new(%{
             subject_iri: iri,
             domain: :desired_outcome,
             prior_state: nil,
             next_state: :proposed,
             revision: 0,
             expected_predecessor: nil,
             actor_iri: attributes[:actor_iri],
             cause_iri: attributes[:cause_iri],
             reason: attributes[:reason],
             recorded_at: attributes[:recorded_at]
           }) do
      {:ok,
       %__MODULE__{
         iri: iri,
         scope_iri: attributes[:scope_iri],
         repository_iri: attributes[:repository_iri],
         actor_iri: attributes[:actor_iri],
         target: target,
         priority: priority,
         valid_from: valid_from,
         valid_to: valid_to,
         policy_refs: policy_refs,
         evidence_refs: evidence_refs,
         constraints: constraints,
         conflicts_with: conflicts,
         transition: transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:desired_outcome)
    end
  rescue
    _error -> invalid(:desired_outcome)
  end

  def new(_attributes), do: invalid(:desired_outcome)

  @spec statements(t(), map()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = outcome, attributes) do
    base = [
      {outcome.iri, @rdf <> "type", RDF.iri(@jf <> "DesiredOutcome")},
      {outcome.iri, @jf <> "about", RDF.iri(outcome.repository_iri)},
      {outcome.iri, @jf <> "validFor", RDF.iri(outcome.scope_iri)},
      {outcome.iri, @jf <> "priority", RDF.iri(priority_iri(outcome.priority))},
      {outcome.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(outcome.valid_from)},
      {outcome.iri, @jf <> "validTo", RDF.XSD.DateTime.new(outcome.valid_to)},
      {outcome.iri, @prov <> "wasAttributedTo", RDF.iri(outcome.actor_iri)}
    ]

    base ++
      target_statements(outcome) ++
      Enum.map(outcome.policy_refs, &{outcome.iri, @jf <> "governedBy", RDF.iri(&1)}) ++
      Enum.map(outcome.evidence_refs, &{outcome.iri, @jf <> "expectedEvidence", RDF.iri(&1)}) ++
      Enum.flat_map(outcome.constraints, fn constraint ->
        [{outcome.iri, @jf <> "constrainedBy", RDF.iri(constraint.iri)} | constraint.statements]
      end) ++ conflict_statements(outcome, attributes)
  end

  @spec assert_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), outcome: t()}} | {:error, Error.t()}
  def assert_command(outcome, attributes, options \\ [])

  def assert_command(%__MODULE__{} = outcome, attributes, options)
      when is_map(attributes) and is_list(options) do
    enrollment = attributes[:enrollment]

    with :ok <- active_enrollment(enrollment),
         {:ok, :factory_policy} <- GraphRegistry.identify(attributes[:policy_graph_iri]),
         {:ok, control_graph} <- Graph.repository_control(outcome.repository_iri),
         true <- control_graph == attributes[:control_graph_iri],
         {:ok, control_target} <-
           Graph.target(
             control_graph,
             attributes[:expected_control_revision],
             outcome.scope_iri,
             attributes[:command_iri],
             outcome.transition.recorded_at,
             Transition.statements(outcome.transition)
           ),
         {:ok, command} <-
           command(
             outcome,
             attributes,
             options,
             control_target,
             enrollment,
             conflict_guards(outcome, attributes)
           ) do
      {:ok, %{command: command, outcome: outcome}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:assert_desired_outcome_command)
    end
  end

  def assert_command(_outcome, _attributes, _options),
    do: invalid(:assert_desired_outcome_command)

  @spec transition_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}}
          | {:error, Error.t()}
  def transition_command(resolution, attributes, options \\ [])

  def transition_command(resolution, attributes, options)
      when is_map(resolution) and is_map(attributes) and is_list(options) do
    with true <- resolution[:domain] == :desired_outcome,
         {:ok, transition} <-
           Transition.new(%{
             subject_iri: resolution[:subject_iri],
             domain: :desired_outcome,
             prior_state: resolution[:current_state],
             next_state: attributes[:next_state],
             revision: resolution[:current_revision] + 1,
             expected_predecessor: resolution[:current_transition],
             actor_iri: attributes[:actor_iri],
             cause_iri: attributes[:causation_iri],
             reason: attributes[:reason],
             recorded_at: attributes[:recorded_at]
           }),
         {:ok, target} <-
           Graph.target(
             attributes[:control_graph_iri],
             attributes[:expected_control_revision],
             attributes[:repository_scope_iri],
             attributes[:command_iri],
             transition.recorded_at,
             Transition.statements(transition)
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope_attributes(
               "TransitionDesiredOutcome",
               attributes,
               %{
                 attributes[:control_graph_iri] => attributes[:expected_control_revision]
               },
               [target],
               [Transition.guard(transition, attributes[:control_graph_iri])]
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_desired_outcome_command)
    end
  end

  def transition_command(_resolution, _attributes, _options),
    do: invalid(:transition_desired_outcome_command)

  defp command(outcome, attributes, options, control_target, enrollment, conflict_guards) do
    policy_graph = attributes[:policy_graph_iri]
    control_graph = attributes[:control_graph_iri]
    catalog_graph = enrollment[:catalog_graph_iri]

    policy_target = %{
      family: :factory_policy,
      graph_iri: policy_graph,
      operation: :append,
      metadata: %{lifecycle_state: :open},
      additions: statements(outcome, attributes),
      supersessions: [],
      invalidations: [],
      removals: []
    }

    guards = [
      {:subject_absent, policy_graph, outcome.iri},
      {:transition_endpoint, catalog_graph, enrollment[:enrollment_iri],
       enrollment[:current_transition]}
      | conflict_guards
    ]

    revisions = %{
      policy_graph => attributes[:expected_policy_revision],
      control_graph => attributes[:expected_control_revision],
      catalog_graph => enrollment[:catalog_revision]
    }

    CommandEnvelope.new(
      envelope_attributes(
        "AssertDesiredOutcome",
        attributes,
        revisions,
        [policy_target, control_target],
        guards
      ),
      options
    )
  end

  defp envelope_attributes(type, attributes, revisions, changes, guards) do
    %{
      command_type: type,
      command_version: "1.2.0",
      command_iri: attributes[:command_iri],
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
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

  defp target(%{proposition: proposition}) when is_map(proposition) do
    with :ok <- validate_resource(proposition[:subject]),
         true <- is_binary(proposition[:predicate]) and RDF.IRI.valid?(proposition[:predicate]),
         {:ok, object} <- rdf_object(proposition[:object]),
         triple <-
           RDF.Triple.new(
             {RDF.iri(proposition[:subject]), RDF.iri(proposition[:predicate]), object}
           ),
         true <- RDF.Triple.valid?(triple) and not RDF.Triple.has_bnode?(triple) do
      material = RDF.NTriples.write_string!(RDF.Graph.new([triple]), sort: true)
      {:ok, {:proposition, triple}, material}
    else
      _invalid -> invalid(:desired_outcome_target)
    end
  rescue
    _error -> invalid(:desired_outcome_target)
  end

  defp target(%{capability_iri: capability}) do
    with :ok <- validate_resource(capability), do: {:ok, {:capability, capability}, capability}
  end

  defp target(_attributes), do: invalid(:desired_outcome_target)

  defp target_statements(
         %__MODULE__{target: {:proposition, {subject, predicate, object}}} = outcome
       ) do
    [
      {outcome.iri, @rdf <> "subject", subject},
      {outcome.iri, @rdf <> "predicate", predicate},
      {outcome.iri, @rdf <> "object", object}
    ]
  end

  defp target_statements(%__MODULE__{target: {:capability, capability}} = outcome),
    do: [{outcome.iri, @jf <> "targetCapability", RDF.iri(capability)}]

  defp constraints(outcome_iri, values)
       when is_list(values) and length(values) <= @max_constraints do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, constraints} ->
      case constraint(outcome_iri, value) do
        {:ok, constraint} -> {:cont, {:ok, [constraint | constraints]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, constraints} -> {:ok, Enum.reverse(constraints)}
      error -> error
    end
  end

  defp constraints(_outcome, _values), do: invalid(:desired_outcome_constraints)

  defp constraint(outcome_iri, %{kind: kind, value: value}) when kind in @constraint_kinds do
    with {:ok, object, material} <- constraint_value(value),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :control_constraint,
             Enum.join([outcome_iri, Atom.to_string(kind), material], "\n")
           ) do
      {:ok,
       %{
         iri: iri,
         kind: kind,
         statements: [
           {iri, @rdf <> "type", RDF.iri(@jf <> "Constraint")},
           {iri, @jf <> "about", RDF.iri(outcome_iri)},
           {iri, @jf <> "taskKind", RDF.iri(constraint_kind_iri(kind))},
           {iri, @jf <> "displayId", object}
         ]
       }}
    end
  end

  defp constraint(_outcome, _value), do: invalid(:desired_outcome_constraint)

  defp constraint_value(value) when is_integer(value) and value >= 0,
    do: {:ok, RDF.XSD.NonNegativeInteger.new(value), Integer.to_string(value)}

  defp constraint_value(value) when is_boolean(value),
    do: {:ok, RDF.XSD.Boolean.new(value), to_string(value)}

  defp constraint_value(value) when is_binary(value) and byte_size(value) in 1..256 do
    case ResourceIdentity.validate(value) do
      :ok -> {:ok, RDF.iri(value), value}
      _not_resource -> {:ok, RDF.XSD.String.new(value), value}
    end
  end

  defp constraint_value(_value), do: invalid(:desired_outcome_constraint_value)

  defp resources(values, maximum, required?)
       when is_list(values) and length(values) <= maximum and (not required? or values != []) do
    values = Enum.uniq(values)

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, Enum.sort(values)},
      else: invalid(:desired_outcome_references)
  end

  defp resources(_values, _maximum, _required), do: invalid(:desired_outcome_references)

  defp conflict_resolution([], _attributes), do: :ok

  defp conflict_resolution(_conflicts, attributes) do
    supersede? = Map.get(attributes, :supersede_conflicts?, false)
    decision = Map.get(attributes, :conflict_decision_iri)

    cond do
      supersede? and is_nil(decision) -> :ok
      not supersede? and ResourceIdentity.validate(decision) == :ok -> :ok
      true -> invalid(:desired_outcome_conflict_resolution)
    end
  end

  defp conflict_statements(%__MODULE__{conflicts_with: []}, _attributes), do: []

  defp conflict_statements(outcome, attributes) do
    relations =
      Enum.map(outcome.conflicts_with, &{outcome.iri, @jf <> "conflictsWith", RDF.iri(&1)})

    if Map.get(attributes, :supersede_conflicts?, false) do
      relations ++
        Enum.map(outcome.conflicts_with, &{outcome.iri, @jf <> "supersedes", RDF.iri(&1)})
    else
      relations ++
        [{outcome.iri, @jf <> "governedBy", RDF.iri(attributes[:conflict_decision_iri])}]
    end
  end

  defp conflict_guards(%__MODULE__{conflicts_with: conflicts}, attributes) do
    policy_graph = attributes[:policy_graph_iri]
    conflict_guards = Enum.map(conflicts, &{:subject_present, policy_graph, &1})

    case Map.get(attributes, :conflict_decision_iri) do
      nil -> conflict_guards
      decision -> [{:subject_present, policy_graph, decision} | conflict_guards]
    end
  end

  defp desired_identity(attributes, target_material) do
    ResourceIdentity.deterministic(
      :desired_outcome,
      Enum.join([attributes.actor_iri, attributes.scope_iri, target_material], "\n")
    )
  end

  defp active_enrollment(%{
         enrollment_iri: enrollment,
         current_transition: transition,
         current_state: :active,
         admission: :allowed,
         catalog_graph_iri: graph,
         catalog_revision: revision
       })
       when is_integer(revision) and revision > 0 do
    with :ok <- validate_resource(enrollment),
         :ok <- validate_resource(transition),
         {:ok, :factory_catalog} <- GraphRegistry.identify(graph) do
      :ok
    end
  end

  defp active_enrollment(_enrollment), do: invalid(:desired_outcome_enrollment)

  defp interval(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) == :lt,
      do: {:ok, DateTime.truncate(from, :microsecond), DateTime.truncate(to, :microsecond)},
      else: invalid(:desired_outcome_interval)
  end

  defp interval(_from, _to), do: invalid(:desired_outcome_interval)

  defp rdf_object(value) when is_binary(value) do
    case ResourceIdentity.validate(value) do
      :ok -> {:ok, RDF.iri(value)}
      _not_resource when byte_size(value) in 1..512 -> {:ok, RDF.XSD.String.new(value)}
      _invalid -> invalid(:desired_outcome_object)
    end
  end

  defp rdf_object(value) when is_boolean(value), do: {:ok, RDF.XSD.Boolean.new(value)}

  defp rdf_object(value) when is_integer(value),
    do: {:ok, RDF.XSD.Integer.new(value)}

  defp rdf_object(_value), do: invalid(:desired_outcome_object)

  defp priority_iri(priority), do: @concept <> "Priority" <> Macro.camelize(to_string(priority))

  defp constraint_kind_iri(kind),
    do: @concept <> "Constraint" <> Macro.camelize(to_string(kind))

  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

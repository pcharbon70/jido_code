defmodule JidoCode.Knowledge.Control.Obligation do
  @moduledoc """
  Stable, graph-native policy obligations and governed lifecycle transitions.

  An obligation is distinct from an approved goal and from executable tasks.
  Reconciliation reuses its identity for the same policy/scope/outcome/source
  context instead of creating a queue item on every pass.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :policy_iri,
    :scope_iri,
    :repository_iri,
    :desired_outcome_iri,
    :dimension_iri,
    :applicability_evidence_iri,
    :gap_iri,
    :constraint_refs,
    :acceptance_requirement_refs,
    :valid_from,
    :valid_to,
    :graph_references,
    :transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @max_refs 30
  @max_graphs 8

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- validate_resource(attributes[:policy_iri]),
         :ok <- validate_resource(attributes[:scope_iri]),
         :ok <- validate_resource(attributes[:repository_iri]),
         :ok <- validate_resource(attributes[:desired_outcome_iri]),
         :ok <- validate_resource(attributes[:dimension_iri]),
         :ok <- validate_resource(attributes[:applicability_evidence_iri]),
         :ok <- validate_resource(attributes[:gap_iri]),
         {:ok, constraints} <- resources(attributes[:constraint_refs], false),
         {:ok, acceptance} <- resources(attributes[:acceptance_requirement_refs], true),
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         {:ok, references} <- graph_references(attributes[:source_graph_revisions]),
         {:ok, iri} <- obligation_identity(attributes, references),
         {:ok, transition} <- initial_transition(iri, attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         policy_iri: attributes[:policy_iri],
         scope_iri: attributes[:scope_iri],
         repository_iri: attributes[:repository_iri],
         desired_outcome_iri: attributes[:desired_outcome_iri],
         dimension_iri: attributes[:dimension_iri],
         applicability_evidence_iri: attributes[:applicability_evidence_iri],
         gap_iri: attributes[:gap_iri],
         constraint_refs: constraints,
         acceptance_requirement_refs: acceptance,
         valid_from: valid_from,
         valid_to: valid_to,
         graph_references: references,
         transition: transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:policy_obligation)
    end
  rescue
    _error -> invalid(:policy_obligation)
  end

  def new(_attributes), do: invalid(:policy_obligation)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = obligation) do
    [
      {obligation.iri, @rdf_type, RDF.iri(@jf <> "Obligation")},
      {obligation.iri, @jf <> "governedBy", RDF.iri(obligation.policy_iri)},
      {obligation.iri, @jf <> "validFor", RDF.iri(obligation.scope_iri)},
      {obligation.iri, @jf <> "about", RDF.iri(obligation.gap_iri)},
      {obligation.iri, @jf <> "requiredOutcome", RDF.iri(obligation.desired_outcome_iri)},
      {obligation.iri, @jf <> "taskKind", RDF.iri(obligation.dimension_iri)},
      {obligation.iri, @jf <> "applicabilityEvidence",
       RDF.iri(obligation.applicability_evidence_iri)},
      {obligation.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(obligation.valid_from)},
      {obligation.iri, @jf <> "validTo", RDF.XSD.DateTime.new(obligation.valid_to)}
    ] ++
      Enum.map(obligation.constraint_refs, &{obligation.iri, @jf <> "constrainedBy", RDF.iri(&1)}) ++
      Enum.map(
        obligation.acceptance_requirement_refs,
        &{
          obligation.iri,
          @jf <> "acceptanceRequirement",
          RDF.iri(&1)
        }
      ) ++
      Enum.flat_map(obligation.graph_references, fn reference ->
        [
          {obligation.iri, @jf <> "sourceGraphRevision", RDF.iri(reference.iri)},
          {reference.iri, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
          {reference.iri, @jf <> "sourceGraph", RDF.iri(reference.graph_iri)},
          {reference.iri, @jf <> "sourceRevisionNumber",
           RDF.XSD.NonNegativeInteger.new(reference.revision)}
        ]
      end) ++ Transition.statements(obligation.transition)
  end

  @spec derive_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), obligation: t()}} | {:error, Error.t()}
  def derive_command(obligation, attributes, options \\ [])

  def derive_command(%__MODULE__{} = obligation, attributes, options)
      when is_map(attributes) and is_list(options) do
    with {:ok, control_graph} <- Graph.repository_control(obligation.repository_iri),
         true <- control_graph == attributes[:control_graph_iri],
         {:ok, target} <-
           Graph.target(
             control_graph,
             attributes[:expected_control_revision],
             obligation.scope_iri,
             attributes[:command_iri],
             obligation.transition.recorded_at,
             statements(obligation)
           ),
         {:ok, guards} <- source_guards(obligation, attributes),
         revisions =
           obligation.graph_references
           |> Map.new(&{&1.graph_iri, &1.revision})
           |> Map.put(control_graph, attributes[:expected_control_revision]),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "DerivePolicyObligation",
               attributes,
               obligation.scope_iri,
               revisions,
               [target],
               [{:subject_absent, control_graph, obligation.iri} | guards]
             ),
             options
           ) do
      {:ok, %{command: command, obligation: obligation}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:derive_policy_obligation_command)
    end
  end

  def derive_command(_obligation, _attributes, _options),
    do: invalid(:derive_policy_obligation_command)

  @spec transition_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}}
          | {:error, Error.t()}
  def transition_command(resolution, attributes, options \\ [])

  def transition_command(%{domain: :obligation} = resolution, attributes, options) do
    with {:ok, transition} <- next_transition(resolution, attributes),
         {:ok, target} <-
           Graph.target(
             attributes[:control_graph_iri],
             attributes[:expected_control_revision],
             attributes[:scope_iri],
             attributes[:command_iri],
             attributes[:recorded_at],
             Transition.statements(transition)
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionObligation",
               attributes,
               attributes[:scope_iri],
               %{attributes[:control_graph_iri] => attributes[:expected_control_revision]},
               [target],
               [Transition.guard(transition, attributes[:control_graph_iri])]
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_obligation_command)
    end
  end

  def transition_command(_resolution, _attributes, _options),
    do: invalid(:transition_obligation_command)

  defp initial_transition(iri, attributes) do
    Transition.new(%{
      subject_iri: iri,
      domain: :obligation,
      prior_state: nil,
      next_state: :proposed,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:cause_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp next_transition(resolution, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: :obligation,
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

  defp source_guards(obligation, attributes) do
    locations = attributes[:evidence_locations]

    if is_map(locations) do
      required = [
        obligation.policy_iri,
        obligation.applicability_evidence_iri,
        obligation.gap_iri
      ]

      Enum.reduce_while(required, {:ok, []}, fn resource, {:ok, guards} ->
        case Map.fetch(locations, resource) do
          {:ok, graph} ->
            if Enum.any?(obligation.graph_references, &(&1.graph_iri == graph)) do
              {:cont, {:ok, [{:subject_present, graph, resource} | guards]}}
            else
              {:halt, invalid(:obligation_evidence_location)}
            end

          :error ->
            {:halt, invalid(:obligation_evidence_location)}
        end
      end)
    else
      invalid(:obligation_evidence_location)
    end
  end

  defp graph_references(values)
       when is_map(values) and map_size(values) in 1..@max_graphs do
    Enum.reduce_while(values, {:ok, []}, fn {graph, revision}, {:ok, references} ->
      with {:ok, _family} <- GraphRegistry.identify(graph),
           true <- is_integer(revision) and revision > 0,
           {:ok, iri} <-
             ResourceIdentity.deterministic(
               :graph_revision_reference,
               graph <> "\n" <> Integer.to_string(revision)
             ) do
        {:cont, {:ok, [%{iri: iri, graph_iri: graph, revision: revision} | references]}}
      else
        _invalid -> {:halt, invalid(:obligation_source_revisions)}
      end
    end)
    |> case do
      {:ok, references} -> {:ok, Enum.sort_by(references, & &1.graph_iri)}
      error -> error
    end
  end

  defp graph_references(_values), do: invalid(:obligation_source_revisions)

  defp obligation_identity(attributes, references) do
    material =
      [
        attributes[:policy_iri],
        attributes[:scope_iri],
        attributes[:desired_outcome_iri],
        attributes[:dimension_iri]
      ] ++ Enum.flat_map(references, &[&1.graph_iri, Integer.to_string(&1.revision)])

    ResourceIdentity.deterministic(:policy_obligation, Enum.join(material, "\n"))
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

  defp resources(values, required?)
       when is_list(values) and length(values) <= @max_refs and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:obligation_references)
  end

  defp resources(_values, _required), do: invalid(:obligation_references)

  defp interval(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) == :lt,
      do: {:ok, DateTime.truncate(from, :microsecond), DateTime.truncate(to, :microsecond)},
      else: invalid(:obligation_interval)
  end

  defp interval(_from, _to), do: invalid(:obligation_interval)
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

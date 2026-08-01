defmodule JidoCode.Knowledge.Repositories.Enrollment do
  @moduledoc """
  Semantic command construction for conceptual repository enrollment.

  This module builds graph changes and transient command envelopes. It owns no
  durable enrollment record; accepted graph facts and transition history are
  the only source of truth.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :factory_iri,
    :repository_iri,
    :repository_scope_iri,
    :policy_boundary_iri,
    :policy_iris,
    :locator,
    :actor_iri,
    :valid_from,
    :valid_to,
    :transitions
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @max_policies 20

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    initial_state = Map.get(attributes, :initial_state, :active)

    with :ok <- validate_resource(attributes[:factory_iri]),
         :ok <- validate_resource(attributes[:repository_iri]),
         :ok <- validate_resource(attributes[:repository_scope_iri]),
         :ok <- validate_resource(attributes[:policy_boundary_iri]),
         :ok <- validate_resource(attributes[:actor_iri]),
         :ok <- validate_resource(attributes[:cause_iri]),
         %Locator{} = locator <- attributes[:locator],
         {:ok, policies} <- policies(attributes[:policy_iris]),
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         true <- initial_state in [:proposed, :active],
         {:ok, iri} <-
           ResourceIdentity.management_enrollment(
             attributes[:factory_iri],
             attributes[:repository_iri],
             attributes[:policy_boundary_iri]
           ),
         {:ok, transitions} <-
           initial_transitions(
             iri,
             initial_state,
             attributes[:actor_iri],
             attributes[:cause_iri],
             attributes[:reason],
             valid_from
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         factory_iri: attributes[:factory_iri],
         repository_iri: attributes[:repository_iri],
         repository_scope_iri: attributes[:repository_scope_iri],
         policy_boundary_iri: attributes[:policy_boundary_iri],
         policy_iris: policies,
         locator: locator,
         actor_iri: attributes[:actor_iri],
         valid_from: valid_from,
         valid_to: valid_to,
         transitions: transitions
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:management_enrollment)
    end
  rescue
    _error -> invalid(:management_enrollment)
  end

  def new(_attributes), do: invalid(:management_enrollment)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = enrollment) do
    [
      {enrollment.repository_iri, @rdf_type, RDF.iri(@jf <> "SoftwareRepository")},
      {enrollment.repository_iri, @jf <> "inScope", RDF.iri(enrollment.repository_scope_iri)},
      {enrollment.repository_iri, @jf <> "locatedBy", RDF.iri(enrollment.locator.iri)},
      {enrollment.factory_iri, @jf <> "enrolls", RDF.iri(enrollment.iri)},
      {enrollment.iri, @rdf_type, RDF.iri(@jf <> "ManagementEnrollment")},
      {enrollment.iri, @jf <> "manages", RDF.iri(enrollment.repository_iri)},
      {enrollment.iri, @jf <> "locatedBy", RDF.iri(enrollment.locator.iri)},
      {enrollment.iri, @jf <> "inScope", RDF.iri(enrollment.repository_scope_iri)},
      {enrollment.iri, @jf <> "governedBy", RDF.iri(enrollment.policy_boundary_iri)},
      {enrollment.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(enrollment.valid_from)},
      {enrollment.iri, @jf <> "validTo", RDF.XSD.DateTime.new(enrollment.valid_to)},
      {enrollment.iri, @prov <> "wasAttributedTo", RDF.iri(enrollment.actor_iri)}
    ] ++
      Enum.map(enrollment.policy_iris, fn policy_iri ->
        {enrollment.iri, @jf <> "governedBy", RDF.iri(policy_iri)}
      end) ++
      Locator.statements(enrollment.locator) ++
      Enum.flat_map(enrollment.transitions, &EnrollmentTransition.statements/1)
  end

  @spec enroll_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def enroll_command(enrollment, attributes, options \\ [])

  def enroll_command(%__MODULE__{} = enrollment, attributes, options)
      when is_map(attributes) and is_list(options) do
    with {:ok, :factory_catalog} <- GraphRegistry.identify(attributes[:catalog_graph_iri]),
         true <-
           is_integer(attributes[:expected_catalog_revision]) and
             attributes[:expected_catalog_revision] >= 0 do
      CommandEnvelope.new(
        %{
          command_type: "EnrollRepository",
          command_version: "1.1.0",
          command_iri: attributes[:command_iri],
          principal_iri: attributes[:principal_iri],
          actor_iri: enrollment.actor_iri,
          delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
          delegation_iri: Map.get(attributes, :delegation_iri),
          scope_iri: attributes[:factory_scope_iri],
          idempotency_key: attributes[:idempotency_key],
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: %{
            attributes[:catalog_graph_iri] => attributes[:expected_catalog_revision]
          },
          reason: attributes[:reason],
          payload: %{
            guards: [
              {:subject_absent, attributes[:catalog_graph_iri], enrollment.iri}
            ],
            changes: [
              %{
                family: :factory_catalog,
                graph_iri: attributes[:catalog_graph_iri],
                operation: :append,
                metadata: %{lifecycle_state: :open},
                additions: statements(enrollment),
                supersessions: [],
                invalidations: [],
                removals: []
              }
            ]
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enroll_repository_command)
    end
  end

  def enroll_command(_enrollment, _attributes, _options),
    do: invalid(:enroll_repository_command)

  @spec change_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: EnrollmentTransition.t()}}
          | {:error, Error.t()}
  def change_command(resolution, attributes, options \\ [])

  def change_command(resolution, attributes, options)
      when is_map(resolution) and is_map(attributes) and is_list(options) do
    change_kind = Map.get(attributes, :change_kind, :state)

    with :ok <- validate_resolution(resolution),
         {:ok, transition} <-
           EnrollmentTransition.new(%{
             enrollment_iri: resolution.enrollment_iri,
             prior_state: resolution.current_state,
             next_state: attributes[:next_state],
             revision: resolution.current_revision + 1,
             expected_predecessor: resolution.current_transition,
             actor_iri: attributes[:actor_iri],
             cause_iri: attributes[:command_iri],
             reason: attributes[:reason],
             recorded_at: attributes[:recorded_at],
             change_kind: change_kind
           }),
         {:ok, contextual} <- contextual_statements(transition, attributes),
         command_type <- command_type(transition.next_state),
         {:ok, command} <-
           CommandEnvelope.new(
             %{
               command_type: command_type,
               command_version: "1.1.0",
               command_iri: attributes[:command_iri],
               principal_iri: attributes[:principal_iri],
               actor_iri: attributes[:actor_iri],
               delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
               delegation_iri: Map.get(attributes, :delegation_iri),
               scope_iri: attributes[:factory_scope_iri],
               idempotency_key: attributes[:idempotency_key],
               correlation_iri: attributes[:correlation_iri],
               causation_iri: attributes[:causation_iri],
               ontology_version: "1.0.0",
               shape_version: "1.0.0",
               expected_dataset_revision: attributes[:expected_dataset_revision],
               expected_graph_revisions: %{
                 attributes[:catalog_graph_iri] => attributes[:expected_catalog_revision]
               },
               reason: attributes[:reason],
               payload: %{
                 guards: [
                   {:subject_present, attributes[:catalog_graph_iri], resolution.enrollment_iri},
                   {:subject_absent, attributes[:catalog_graph_iri], transition.iri},
                   {:triple_present, attributes[:catalog_graph_iri],
                    resolution.current_transition, @jf <> "nextState",
                    RDF.iri(EnrollmentTransition.state_iri(resolution.current_state))}
                 ],
                 changes: [
                   %{
                     family: :factory_catalog,
                     graph_iri: attributes[:catalog_graph_iri],
                     operation: :append,
                     metadata: %{lifecycle_state: :open},
                     additions: EnrollmentTransition.statements(transition) ++ contextual,
                     supersessions: [],
                     invalidations: [],
                     removals: []
                   }
                 ]
               }
             },
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:change_enrollment_command)
    end
  end

  def change_command(_resolution, _attributes, _options),
    do: invalid(:change_enrollment_command)

  @spec reconcile_locator_command(String.t(), Locator.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def reconcile_locator_command(repository_iri, locator, attributes, options \\ [])

  def reconcile_locator_command(repository_iri, %Locator{} = locator, attributes, options)
      when is_map(attributes) and is_list(options) do
    with :ok <- validate_resource(repository_iri),
         :ok <- validate_resource(attributes[:evidence_source_iri]),
         true <- valid_digest?(attributes[:evidence_digest]),
         {:ok, evidence_iri} <-
           ResourceIdentity.deterministic(
             :repository_reconciliation,
             Enum.join(
               [
                 repository_iri,
                 locator.iri,
                 attributes[:evidence_source_iri],
                 attributes[:evidence_digest]
               ],
               "\n"
             )
           ) do
      additions = [
        {repository_iri, @jf <> "locatedBy", RDF.iri(locator.iri)},
        {evidence_iri, @rdf_type, RDF.iri(@prov <> "Entity")},
        {evidence_iri, @jf <> "about", RDF.iri(locator.iri)},
        {evidence_iri, @jf <> "supports", RDF.iri(repository_iri)},
        {evidence_iri, @prov <> "wasDerivedFrom", RDF.iri(attributes[:evidence_source_iri])},
        {evidence_iri, @prov <> "wasAttributedTo", RDF.iri(attributes[:actor_iri])},
        {evidence_iri, @jf <> "contentDigest", RDF.XSD.String.new(attributes[:evidence_digest])},
        {evidence_iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(attributes[:recorded_at])}
      ]

      CommandEnvelope.new(
        %{
          command_type: "ReconcileRepositoryIdentity",
          command_version: "1.1.0",
          command_iri: attributes[:command_iri],
          principal_iri: attributes[:principal_iri],
          actor_iri: attributes[:actor_iri],
          delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
          delegation_iri: Map.get(attributes, :delegation_iri),
          scope_iri: attributes[:factory_scope_iri],
          idempotency_key: attributes[:idempotency_key],
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: %{
            attributes[:catalog_graph_iri] => attributes[:expected_catalog_revision]
          },
          reason: attributes[:reason],
          payload: %{
            guards: [
              {:subject_present, attributes[:catalog_graph_iri], repository_iri},
              {:subject_present, attributes[:catalog_graph_iri], locator.iri},
              {:subject_absent, attributes[:catalog_graph_iri], evidence_iri}
            ],
            changes: [
              %{
                family: :factory_catalog,
                graph_iri: attributes[:catalog_graph_iri],
                operation: :append,
                metadata: %{lifecycle_state: :open},
                additions: additions,
                supersessions: [],
                invalidations: [],
                removals: []
              }
            ]
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:reconcile_repository_identity)
    end
  rescue
    _error -> invalid(:reconcile_repository_identity)
  end

  def reconcile_locator_command(_repository_iri, _locator, _attributes, _options),
    do: invalid(:reconcile_repository_identity)

  defp initial_transitions(iri, initial_state, actor, cause, reason, recorded_at) do
    with {:ok, proposed} <-
           EnrollmentTransition.new(%{
             enrollment_iri: iri,
             prior_state: nil,
             next_state: :proposed,
             revision: 0,
             expected_predecessor: nil,
             actor_iri: actor,
             cause_iri: cause,
             reason: reason,
             recorded_at: recorded_at
           }),
         {:ok, transitions} <- maybe_activate(proposed, initial_state, actor, cause, reason) do
      {:ok, transitions}
    end
  end

  defp maybe_activate(proposed, :proposed, _actor, _cause, _reason), do: {:ok, [proposed]}

  defp maybe_activate(proposed, :active, actor, cause, reason) do
    with {:ok, active} <-
           EnrollmentTransition.new(%{
             enrollment_iri: proposed.enrollment_iri,
             prior_state: :proposed,
             next_state: :active,
             revision: 1,
             expected_predecessor: proposed.iri,
             actor_iri: actor,
             cause_iri: cause,
             reason: reason,
             recorded_at: proposed.recorded_at
           }) do
      {:ok, [proposed, active]}
    end
  end

  defp contextual_statements(transition, %{change_kind: :policy_reassignment} = attributes) do
    with :ok <- validate_resource(attributes[:policy_iri]) do
      {:ok,
       [
         {transition.iri, @jf <> "governedBy", RDF.iri(attributes[:policy_iri])},
         {transition.iri, @jf <> "supersedes", RDF.iri(transition.expected_predecessor)}
       ]}
    end
  end

  defp contextual_statements(
         transition,
         %{
           change_kind: :locator_change,
           locator: %Locator{} = locator,
           repository_iri: repository
         }
       ) do
    with :ok <- validate_resource(repository) do
      {:ok,
       Locator.statements(locator) ++
         [
           {repository, @jf <> "locatedBy", RDF.iri(locator.iri)},
           {transition.enrollment_iri, @jf <> "locatedBy", RDF.iri(locator.iri)},
           {transition.iri, @jf <> "locatedBy", RDF.iri(locator.iri)},
           {transition.iri, @jf <> "supersedes", RDF.iri(transition.expected_predecessor)}
         ]}
    end
  end

  defp contextual_statements(_transition, %{change_kind: :locator_change, locator: %Locator{}}),
    do: invalid(:change_enrollment_context)

  defp contextual_statements(_transition, %{change_kind: kind})
       when kind in [:policy_reassignment, :locator_change],
       do: invalid(:change_enrollment_context)

  defp contextual_statements(_transition, _attributes), do: {:ok, []}

  defp command_type(state) when state in [:retiring, :retired], do: "RetireEnrollment"
  defp command_type(_state), do: "ChangeEnrollment"

  defp validate_resolution(%{
         enrollment_iri: enrollment_iri,
         current_state: current_state,
         current_revision: current_revision,
         current_transition: current_transition
       }) do
    with :ok <- validate_resource(enrollment_iri),
         true <- current_state in [:proposed, :active, :suspended, :retiring],
         true <- is_integer(current_revision) and current_revision >= 0,
         :ok <- validate_resource(current_transition) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enrollment_resolution)
    end
  end

  defp validate_resolution(_resolution), do: invalid(:enrollment_resolution)

  defp policies(values) when is_list(values) and length(values) in 1..@max_policies do
    if length(values) == length(Enum.uniq(values)) and
         Enum.all?(values, &(validate_resource(&1) == :ok)) do
      {:ok, Enum.sort(values)}
    else
      invalid(:enrollment_policies)
    end
  end

  defp policies(_values), do: invalid(:enrollment_policies)

  defp interval(%DateTime{} = valid_from, %DateTime{} = valid_to) do
    valid_from = DateTime.truncate(valid_from, :microsecond)
    valid_to = DateTime.truncate(valid_to, :microsecond)

    if DateTime.before?(valid_from, valid_to),
      do: {:ok, valid_from, valid_to},
      else: invalid(:enrollment_validity)
  end

  defp interval(_valid_from, _valid_to), do: invalid(:enrollment_validity)

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

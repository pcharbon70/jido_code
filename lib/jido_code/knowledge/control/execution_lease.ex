defmodule JidoCode.Knowledge.Control.ExecutionLease do
  @moduledoc """
  Graph-native, exclusive execution leases with monotonic fencing.

  Lease and task transitions are appended atomically. Runtime mutations use
  `execution_guard/4` so a stale process cannot write after expiry or takeover.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Eligibility
  alias JidoCode.Knowledge.Control.Graph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :task_iri,
    :holder_iri,
    :capability_iri,
    :capability_declaration_iri,
    :eligibility_receipt_iri,
    :policy_iris,
    :fencing_token,
    :acquired_at,
    :expires_at,
    :max_expires_at,
    :transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @actions ~w[renew release cancel expire supersede]a

  @spec acquire_command(Eligibility.t(), map(), map(), keyword()) ::
          {:ok,
           %{
             command: CommandEnvelope.t(),
             lease: t(),
             lease_transitions: [Transition.t()],
             task_transitions: [Transition.t()]
           }}
          | {:error, Error.t()}
  def acquire_command(eligibility, task_resolution, attributes, options \\ [])

  def acquire_command(
        %Eligibility{eligible?: true} = eligibility,
        %{domain: :task} = task_resolution,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    with true <- eligibility.task_iri == task_resolution.subject_iri,
         true <- task_resolution.current_state in [:approved, :eligible],
         {:ok, provider} <- provider(eligibility, attributes),
         :ok <- validate_interval(attributes),
         true <- is_integer(attributes[:fencing_token]) and attributes.fencing_token > 0,
         {:ok, lease_iri} <-
           ResourceIdentity.deterministic(
             :execution_lease,
             eligibility.task_iri <> "\n" <> Integer.to_string(attributes.fencing_token)
           ),
         {:ok, lease_transitions} <- initial_lease_transitions(lease_iri, attributes),
         {:ok, task_transitions} <- lease_task_transitions(task_resolution, attributes),
         lease = build_lease(lease_iri, eligibility, provider, lease_transitions, attributes),
         {:ok, target} <-
           acquisition_target(
             lease,
             lease_transitions,
             eligibility,
             task_transitions,
             attributes
           ),
         {:ok, command} <-
           acquisition_envelope(lease, eligibility, task_resolution, target, attributes, options) do
      {:ok,
       %{
         command: command,
         lease: lease,
         lease_transitions: lease_transitions,
         task_transitions: task_transitions
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:acquire_execution_lease)
    end
  rescue
    _error -> invalid(:acquire_execution_lease)
  end

  def acquire_command(_eligibility, _task_resolution, _attributes, _options),
    do: invalid(:acquire_execution_lease)

  @spec transition_command(t(), map(), map(), map(), keyword()) ::
          {:ok,
           %{
             command: CommandEnvelope.t(),
             lease: t(),
             lease_transition: Transition.t(),
             task_transition: Transition.t() | nil
           }}
          | {:error, Error.t()}
  def transition_command(lease, lease_resolution, task_resolution, attributes, options \\ [])

  def transition_command(
        %__MODULE__{} = lease,
        %{domain: :lease, current_state: :active} = lease_resolution,
        %{domain: :task, current_state: :leased} = task_resolution,
        %{action: action} = attributes,
        options
      )
      when action in @actions and is_list(options) do
    with true <- lease_resolution.subject_iri == lease.iri,
         true <- task_resolution.subject_iri == lease.task_iri,
         true <- attributes[:fencing_token] == lease.fencing_token,
         true <- match?(%DateTime{}, attributes[:recorded_at]),
         :ok <- validate_action(lease, attributes),
         {:ok, lease_transition} <- next_lease_transition(lease_resolution, attributes),
         {:ok, task_transition} <- next_task_transition(task_resolution, attributes),
         updated_lease = update_expiry(lease, attributes),
         {:ok, target} <-
           transition_target(updated_lease, lease_transition, task_transition, attributes),
         {:ok, command} <-
           transition_envelope(updated_lease, lease_transition, target, attributes, options) do
      {:ok,
       %{
         command: command,
         lease: %{updated_lease | transition: lease_transition},
         lease_transition: lease_transition,
         task_transition: task_transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_execution_lease)
    end
  rescue
    _error -> invalid(:transition_execution_lease)
  end

  def transition_command(_lease, _lease_resolution, _task_resolution, _attributes, _options),
    do: invalid(:transition_execution_lease)

  @spec execution_guard(t(), String.t(), pos_integer(), DateTime.t()) :: tuple()
  def execution_guard(%__MODULE__{} = lease, control_graph_iri, fence, %DateTime{} = at)
      when is_integer(fence) and fence > 0 do
    {:current_lease_fence, control_graph_iri, lease.task_iri, lease.iri, fence,
     DateTime.truncate(at, :microsecond)}
  end

  defp provider(eligibility, attributes) do
    case Enum.find(eligibility.providers, &(&1.holder_iri == attributes[:holder_iri])) do
      %{capability_iri: capability} = provider ->
        if capability == attributes[:capability_iri],
          do: {:ok, provider},
          else: invalid(:lease_provider)

      _missing ->
        invalid(:lease_provider)
    end
  end

  defp validate_interval(attributes) do
    case {attributes[:acquired_at], attributes[:expires_at], attributes[:max_expires_at]} do
      {%DateTime{} = acquired, %DateTime{} = expires, %DateTime{} = maximum} ->
        if DateTime.compare(acquired, expires) == :lt and
             DateTime.compare(expires, maximum) in [:lt, :eq],
           do: :ok,
           else: invalid(:lease_interval)

      _invalid ->
        invalid(:lease_interval)
    end
  end

  defp validate_action(lease, %{action: :renew} = attributes) do
    with :ok <- validate_resource(attributes[:liveness_evidence_iri]),
         true <- attributes[:holder_iri] in [nil, lease.holder_iri],
         true <- attributes[:capability_iri] in [nil, lease.capability_iri],
         %DateTime{} = expires <- attributes[:expires_at],
         true <- DateTime.compare(attributes.recorded_at, lease.expires_at) == :lt,
         true <- DateTime.compare(lease.expires_at, expires) == :lt,
         true <- DateTime.compare(expires, lease.max_expires_at) in [:lt, :eq] do
      :ok
    else
      _invalid -> invalid(:renew_execution_lease)
    end
  end

  defp validate_action(lease, %{action: :expire, recorded_at: recorded_at}) do
    if DateTime.compare(recorded_at, lease.expires_at) in [:eq, :gt],
      do: :ok,
      else: invalid(:expire_execution_lease)
  end

  defp validate_action(_lease, %{action: action}) when action in [:release, :cancel, :supersede],
    do: :ok

  defp initial_lease_transitions(lease_iri, attributes) do
    with {:ok, proposed} <-
           Transition.new(%{
             subject_iri: lease_iri,
             domain: :lease,
             prior_state: nil,
             next_state: :proposed,
             revision: 0,
             expected_predecessor: nil,
             actor_iri: attributes[:actor_iri],
             cause_iri: attributes[:causation_iri],
             reason: attributes[:reason],
             recorded_at: attributes[:acquired_at]
           }),
         {:ok, active} <-
           Transition.new(%{
             subject_iri: lease_iri,
             domain: :lease,
             prior_state: :proposed,
             next_state: :active,
             revision: 1,
             expected_predecessor: proposed.iri,
             actor_iri: attributes[:actor_iri],
             cause_iri: attributes[:causation_iri],
             reason: attributes[:reason],
             recorded_at: attributes[:acquired_at]
           }) do
      {:ok, [proposed, active]}
    end
  end

  defp lease_task_transitions(%{current_state: :approved} = resolution, attributes) do
    with {:ok, eligible} <- task_transition(resolution, :eligible, attributes),
         {:ok, leased} <-
           task_transition(
             %{
               resolution
               | current_state: :eligible,
                 current_revision: eligible.revision,
                 current_transition: eligible.iri
             },
             :leased,
             attributes
           ) do
      {:ok, [eligible, leased]}
    end
  end

  defp lease_task_transitions(%{current_state: :eligible} = resolution, attributes) do
    with {:ok, leased} <- task_transition(resolution, :leased, attributes), do: {:ok, [leased]}
  end

  defp task_transition(resolution, next_state, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: :task,
      prior_state: resolution.current_state,
      next_state: next_state,
      revision: resolution.current_revision + 1,
      expected_predecessor: resolution.current_transition,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp next_lease_transition(resolution, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: :lease,
      prior_state: :active,
      next_state: lease_state(attributes.action),
      revision: resolution.current_revision + 1,
      expected_predecessor: resolution.current_transition,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp next_task_transition(_resolution, %{action: :renew}), do: {:ok, nil}

  defp next_task_transition(resolution, attributes) do
    task_transition(resolution, task_state(attributes.action), attributes)
  end

  defp acquisition_target(lease, lease_transitions, eligibility, task_transitions, attributes) do
    additions =
      eligibility_statements(eligibility) ++
        lease_statements(lease, lease_transitions) ++
        Enum.flat_map(task_transitions, &Transition.statements/1)

    Graph.target(
      attributes.control_graph_iri,
      attributes.expected_control_revision,
      attributes.repository_scope_iri,
      attributes.command_iri,
      attributes.recorded_at,
      additions
    )
  end

  defp transition_target(lease, lease_transition, task_transition, attributes) do
    additions =
      Transition.statements(lease_transition) ++
        transition_expiry_statements(lease_transition, lease, attributes) ++
        if(task_transition, do: Transition.statements(task_transition), else: [])

    Graph.target(
      attributes.control_graph_iri,
      attributes.expected_control_revision,
      attributes.repository_scope_iri,
      attributes.command_iri,
      attributes.recorded_at,
      additions
    )
  end

  defp build_lease(iri, eligibility, provider, [_proposed, active], attributes) do
    %__MODULE__{
      iri: iri,
      task_iri: eligibility.task_iri,
      holder_iri: provider.holder_iri,
      capability_iri: provider.capability_iri,
      capability_declaration_iri: provider.iri,
      eligibility_receipt_iri: eligibility.receipt_iri,
      policy_iris: eligibility.policy_iris,
      fencing_token: attributes.fencing_token,
      acquired_at: DateTime.truncate(attributes.acquired_at, :microsecond),
      expires_at: DateTime.truncate(attributes.expires_at, :microsecond),
      max_expires_at: DateTime.truncate(attributes.max_expires_at, :microsecond),
      transition: active
    }
  end

  defp eligibility_statements(eligibility) do
    [
      {eligibility.receipt_iri, @rdf_type, RDF.iri(@jf <> "EligibilityReceipt")},
      {eligibility.receipt_iri, @jf <> "about", RDF.iri(eligibility.task_iri)},
      {eligibility.receipt_iri, @jf <> "epistemicState", RDF.iri(@concept <> "Eligible")},
      {eligibility.receipt_iri, @jf <> "recordedAt",
       RDF.XSD.DateTime.new(eligibility.evaluated_at)},
      {eligibility.receipt_iri, @jf <> "priorityScore",
       RDF.XSD.Integer.new(eligibility.priority)},
      {eligibility.receipt_iri, @jf <> "fairnessScore",
       RDF.XSD.Integer.new(eligibility.fairness)},
      {eligibility.receipt_iri, @jf <> "riskLevel",
       RDF.XSD.NonNegativeInteger.new(eligibility.risk)}
    ] ++
      Enum.map(
        eligibility.policy_iris,
        &{eligibility.receipt_iri, @jf <> "governedBy", RDF.iri(&1)}
      ) ++
      Enum.map(eligibility.satisfied, fn condition ->
        {eligibility.receipt_iri, @jf <> "satisfies",
         RDF.iri(@concept <> "Eligibility" <> Macro.camelize(to_string(condition)))}
      end) ++ graph_reference_statements(eligibility)
  end

  defp graph_reference_statements(eligibility) do
    Enum.flat_map(eligibility.graph_revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          eligibility.receipt_iri <> "\n" <> graph <> "\n" <> Integer.to_string(revision)
        )

      [
        {eligibility.receipt_iri, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp lease_statements(lease, transitions) do
    [
      {lease.iri, @rdf_type, RDF.iri(@jf <> "Lease")},
      {lease.iri, @jf <> "leasesTask", RDF.iri(lease.task_iri)},
      {lease.iri, @jf <> "claimedBy", RDF.iri(lease.holder_iri)},
      {lease.iri, @jf <> "heldBy", RDF.iri(lease.holder_iri)},
      {lease.iri, @jf <> "about", RDF.iri(lease.capability_iri)},
      {lease.iri, @jf <> "validFor", RDF.iri(lease.capability_declaration_iri)},
      {lease.iri, @jf <> "eligibilityReceipt", RDF.iri(lease.eligibility_receipt_iri)},
      {lease.iri, @jf <> "fencingToken", RDF.XSD.NonNegativeInteger.new(lease.fencing_token)},
      {lease.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(lease.acquired_at)},
      {lease.iri, @jf <> "validTo", RDF.XSD.DateTime.new(lease.expires_at)},
      {lease.iri, @jf <> "maximumValidTo", RDF.XSD.DateTime.new(lease.max_expires_at)}
    ] ++
      Enum.map(lease.policy_iris, &{lease.iri, @jf <> "governedBy", RDF.iri(&1)}) ++
      Enum.flat_map(transitions, &Transition.statements/1) ++
      [{lease.transition.iri, @jf <> "validTo", RDF.XSD.DateTime.new(lease.expires_at)}]
  end

  defp transition_expiry_statements(transition, lease, %{action: :renew} = attributes) do
    [
      {transition.iri, @jf <> "validTo", RDF.XSD.DateTime.new(lease.expires_at)},
      {transition.iri, @jf <> "livenessEvidence", RDF.iri(attributes.liveness_evidence_iri)}
    ]
  end

  defp transition_expiry_statements(_transition, _lease, _attributes), do: []

  defp acquisition_envelope(lease, eligibility, task_resolution, target, attributes, options) do
    control = attributes.control_graph_iri

    revisions =
      Map.put(eligibility.graph_revisions, control, attributes.expected_control_revision)

    guards = [
      {:transition_endpoint, control, task_resolution.subject_iri,
       task_resolution.current_transition},
      {:no_active_lease, control, lease.task_iri, attributes.acquired_at},
      {:next_fence, control, lease.task_iri, lease.fencing_token}
    ]

    CommandEnvelope.new(
      envelope("AcquireExecutionLease", attributes, revisions, target, guards),
      options
    )
  end

  defp transition_envelope(lease, lease_transition, target, attributes, options) do
    control = attributes.control_graph_iri
    mode = if attributes.action == :expire, do: :expired, else: :current

    guards = [
      {:current_lease_fence, control, lease.task_iri, lease.iri, lease.fencing_token,
       attributes.recorded_at, mode},
      Transition.guard(lease_transition, control)
    ]

    CommandEnvelope.new(
      envelope(
        "TransitionExecutionLease",
        attributes,
        %{control => attributes.expected_control_revision},
        target,
        guards
      ),
      options
    )
  end

  defp envelope(type, attributes, revisions, target, guards) do
    %{
      command_type: type,
      command_version: "1.5.0",
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
      payload: %{changes: [target], guards: guards}
    }
  end

  defp update_expiry(lease, %{action: :renew, expires_at: expires_at}),
    do: %{lease | expires_at: DateTime.truncate(expires_at, :microsecond)}

  defp update_expiry(lease, _attributes), do: lease

  defp lease_state(:renew), do: :active
  defp lease_state(:release), do: :released
  defp lease_state(:cancel), do: :cancelled
  defp lease_state(:expire), do: :expired
  defp lease_state(:supersede), do: :superseded

  defp task_state(action) when action in [:release, :expire], do: :eligible
  defp task_state(:cancel), do: :cancelled
  defp task_state(:supersede), do: :superseded

  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

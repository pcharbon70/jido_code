defmodule JidoCode.Knowledge.Execution.Attempt do
  @moduledoc """
  Graph-native execution-attempt identity and fenced lifecycle commands.

  Run output is operational provenance only. Attempt completion transitions a
  task to awaiting evidence and never satisfies a goal.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :run_graph_iri,
    :context_iri,
    :instruction_iri,
    :enrollment_iri,
    :repository_iri,
    :goal_iri,
    :task_iri,
    :plan_iri,
    :lease_iri,
    :snapshot_iri,
    :actor_iri,
    :agent_iri,
    :capability_iri,
    :fencing_token,
    :context_digest,
    :runtime_version
  ]
  defstruct @enforce_keys ++ [:retry_of_iri]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @terminal_states ~w[completed failed timed_out abandoned cancelled superseded]a

  @spec new(map(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(context, attributes) when is_map(context) and is_map(attributes) do
    material =
      Enum.join(
        [
          context[:task_iri],
          context[:lease_iri],
          context[:fencing_token],
          attributes[:idempotency_key]
        ],
        "\n"
      )

    with :ok <- validate_context(context),
         :ok <- validate_agent(context, attributes[:authorized_agent]),
         true <- context.runtime_version in Map.get(attributes, :available_runtime_versions, []),
         key when is_binary(key) and byte_size(key) in 1..256 <- attributes[:idempotency_key],
         :ok <- optional_resource(attributes[:retry_of_iri]),
         {:ok, iri} <- ResourceIdentity.deterministic(:execution_attempt, material),
         {:ok, context_iri} <-
           ResourceIdentity.deterministic(:execution_context, iri <> "\n" <> context.digest),
         {:ok, instruction_iri} <-
           ResourceIdentity.deterministic(:execution_instruction, context_iri <> "\ninstruction"),
         {:ok, run_graph_iri} <- ExecutionGraph.run_graph(iri) do
      {:ok,
       %__MODULE__{
         iri: iri,
         run_graph_iri: run_graph_iri,
         context_iri: context_iri,
         instruction_iri: instruction_iri,
         enrollment_iri: context.enrollment_iri,
         repository_iri: context.repository_iri,
         goal_iri: context.goal_iri,
         task_iri: context.task_iri,
         plan_iri: context.plan_iri,
         lease_iri: context.lease_iri,
         snapshot_iri: context.snapshot_iri,
         actor_iri: context.actor_iri,
         agent_iri: context.agent_iri,
         capability_iri: context.capability_iri,
         fencing_token: context.fencing_token,
         context_digest: context.digest,
         runtime_version: context.runtime_version,
         retry_of_iri: attributes[:retry_of_iri]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_attempt)
    end
  rescue
    _error -> invalid(:execution_attempt)
  end

  def new(_context, _attributes), do: invalid(:execution_attempt)

  @spec start_command(t(), map(), ExecutionLease.t(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def start_command(attempt, context, lease, resolutions, attributes, options \\ [])

  def start_command(
        %__MODULE__{} = attempt,
        context,
        %ExecutionLease{} = lease,
        %{lease: lease_resolution, task: task_resolution, plan: _plan_resolution} = resolutions,
        attributes,
        options
      )
      when is_map(context) and is_map(attributes) and is_list(options) do
    with :ok <- validate_start(attempt, context, lease, resolutions, attributes),
         {:ok, prepared} <- attempt_transition(attempt, nil, :prepared, 0, nil, attributes),
         {:ok, starting} <-
           attempt_transition(attempt, :prepared, :starting, 1, prepared.iri, attributes),
         {:ok, lease_transition} <-
           control_transition(lease_resolution, :executing, attributes),
         {:ok, task_transition} <- control_transition(task_resolution, :executing, attributes),
         {:ok, run_target} <-
           ExecutionGraph.create_target(
             attempt.run_graph_iri,
             attributes.repository_scope_iri,
             attributes.command_iri,
             attributes.recorded_at,
             attempt_statements(attempt, context) ++
               Transition.statements(prepared) ++ Transition.statements(starting)
           ),
         {:ok, control_target} <-
           ControlGraph.target(
             attributes.control_graph_iri,
             attributes.expected_control_revision,
             attributes.repository_scope_iri,
             attributes.command_iri,
             attributes.recorded_at,
             Transition.statements(lease_transition) ++
               [
                 {lease_transition.iri, @jf <> "validTo", RDF.XSD.DateTime.new(lease.expires_at)},
                 {lease_transition.iri, @jf <> "executes", RDF.iri(attempt.iri)}
               ] ++ Transition.statements(task_transition)
           ),
         guards = start_guards(attempt, lease, resolutions, attributes),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordExecutionAttempt",
               attempt,
               context.source_graph_revisions,
               attributes,
               [run_target, control_target],
               guards
             ),
             options
           ) do
      {:ok,
       %{
         command: command,
         attempt: attempt,
         attempt_transitions: [prepared, starting],
         lease_transition: lease_transition,
         task_transition: task_transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:start_execution_attempt)
    end
  rescue
    _error -> invalid(:start_execution_attempt)
  end

  def start_command(_attempt, _context, _lease, _resolutions, _attributes, _options),
    do: invalid(:start_execution_attempt)

  @spec transition_command(t(), map(), ExecutionLease.t(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def transition_command(
        attempt,
        attempt_resolution,
        lease,
        task_resolution,
        attributes,
        options \\ []
      )

  def transition_command(
        %__MODULE__{} = attempt,
        %{domain: :execution_attempt} = attempt_resolution,
        %ExecutionLease{} = lease,
        %{domain: :task} = task_resolution,
        %{next_state: next_state} = attributes,
        options
      )
      when is_atom(next_state) and is_list(options) do
    with :ok <-
           validate_transition(attempt, attempt_resolution, lease, task_resolution, attributes),
         {:ok, transition} <-
           attempt_transition(
             attempt,
             attempt_resolution.current_state,
             next_state,
             attempt_resolution.current_revision + 1,
             attempt_resolution.current_transition,
             attributes
           ),
         {:ok, event_statements} <-
           event_statements(attempt, transition, attributes[:runtime_event]),
         {:ok, run_target} <-
           ExecutionGraph.append_target(
             attempt.run_graph_iri,
             attributes.expected_run_revision,
             attributes.repository_scope_iri,
             attributes.command_iri,
             attributes.recorded_at,
             Transition.statements(transition) ++ event_statements
           ),
         {:ok, task_transition} <-
           terminal_task_transition(task_resolution, next_state, attributes),
         {:ok, targets} <- transition_targets(run_target, task_transition, attributes),
         guards =
           transition_guards(
             attempt,
             attempt_resolution,
             lease,
             task_transition,
             task_resolution,
             attributes
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               command_type(next_state, attributes),
               attempt,
               %{},
               attributes,
               targets,
               guards
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition, task_transition: task_transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_execution_attempt)
    end
  rescue
    _error -> invalid(:transition_execution_attempt)
  end

  def transition_command(_attempt, _resolution, _lease, _task, _attributes, _options),
    do: invalid(:transition_execution_attempt)

  defp validate_context(context) do
    resources =
      ~w[enrollment_iri repository_iri goal_iri task_iri plan_iri lease_iri snapshot_iri actor_iri agent_iri capability_iri]a

    cond do
      not Enum.all?(resources, &(ResourceIdentity.validate(context[&1]) == :ok)) ->
        :error

      not is_integer(context[:fencing_token]) or context.fencing_token <= 0 ->
        :error

      not is_binary(context[:digest]) or not Regex.match?(~r/^[a-f0-9]{64}$/, context.digest) ->
        :error

      not is_binary(context[:runtime_version]) ->
        :error

      not is_binary(context[:instruction]) or byte_size(context.instruction) not in 1..16_384 ->
        :error

      not is_map(context[:source_graph_revisions]) ->
        :error

      true ->
        :ok
    end
  end

  defp validate_agent(context, authorized) do
    if is_map(authorized) and authorized[:agent_iri] == context.agent_iri and
         authorized[:capability_iri] == context.capability_iri and
         authorized[:available?] == true,
       do: :ok,
       else: invalid(:execution_attempt_agent)
  end

  defp validate_start(attempt, context, lease, resolutions, attributes) do
    control_revision = context.source_graph_revisions[attributes[:control_graph_iri]]

    cond do
      attempt.lease_iri != lease.iri or attempt.task_iri != lease.task_iri ->
        :error

      attempt.fencing_token != lease.fencing_token ->
        :error

      resolutions.lease.subject_iri != lease.iri or resolutions.lease.current_state != :active ->
        :error

      resolutions.task.subject_iri != attempt.task_iri or
          resolutions.task.current_state != :leased ->
        :error

      resolutions.plan.subject_iri != attempt.plan_iri or
          resolutions.plan.current_state != :approved ->
        :error

      attributes[:expected_control_revision] != control_revision ->
        :error

      attributes[:recorded_at] |> then(&DateTime.compare(&1, lease.expires_at)) != :lt ->
        :error

      true ->
        :ok
    end
  rescue
    _error -> invalid(:start_execution_attempt)
  end

  defp validate_transition(attempt, attempt_resolution, lease, task_resolution, attributes) do
    cond do
      attempt_resolution.subject_iri != attempt.iri ->
        :error

      task_resolution.subject_iri != attempt.task_iri ->
        :error

      attempt.lease_iri != lease.iri or attempt.fencing_token != lease.fencing_token ->
        :error

      attributes[:fencing_token] != attempt.fencing_token ->
        :error

      attributes[:origin] not in [:runtime, :control, :recovery] ->
        :error

      attributes.next_state in @terminal_states and task_resolution.current_state != :executing ->
        :error

      true ->
        :ok
    end
  end

  defp attempt_transition(attempt, prior, next, revision, predecessor, attributes) do
    Transition.new(%{
      subject_iri: attempt.iri,
      domain: :execution_attempt,
      prior_state: prior,
      next_state: next,
      revision: revision,
      expected_predecessor: predecessor,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp control_transition(resolution, next_state, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: resolution.domain,
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

  defp terminal_task_transition(_resolution, next, _attributes)
       when next not in @terminal_states,
       do: {:ok, nil}

  defp terminal_task_transition(resolution, next, attributes) do
    task_state =
      case next do
        :completed -> :awaiting_evidence
        :cancelled -> :cancelled
        :superseded -> :superseded
        _failure -> :blocked
      end

    control_transition(resolution, task_state, attributes)
  end

  defp transition_targets(run_target, nil, _attributes), do: {:ok, [run_target]}

  defp transition_targets(run_target, task_transition, attributes) do
    with {:ok, control_target} <-
           ControlGraph.target(
             attributes.control_graph_iri,
             attributes.expected_control_revision,
             attributes.repository_scope_iri,
             attributes.command_iri,
             attributes.recorded_at,
             Transition.statements(task_transition)
           ) do
      {:ok, [run_target, control_target]}
    end
  end

  defp attempt_statements(attempt, context) do
    [
      {attempt.iri, @rdf_type, RDF.iri(@jf <> "ExecutionAttempt")},
      {attempt.iri, @jf <> "executes", RDF.iri(attempt.task_iri)},
      {attempt.iri, @jf <> "attempts", RDF.iri(attempt.goal_iri)},
      {attempt.iri, @jf <> "enrollment", RDF.iri(attempt.enrollment_iri)},
      {attempt.iri, @jf <> "inScope", RDF.iri(attempt.repository_iri)},
      {attempt.iri, @jf <> "derivedFrom", RDF.iri(attempt.plan_iri)},
      {attempt.iri, @jf <> "validFor", RDF.iri(attempt.lease_iri)},
      {attempt.iri, @jf <> "sourceSnapshot", RDF.iri(attempt.snapshot_iri)},
      {attempt.iri, @jf <> "inputPackage", RDF.iri(attempt.context_iri)},
      {attempt.iri, @prov <> "wasAssociatedWith", RDF.iri(attempt.actor_iri)},
      {attempt.iri, @jf <> "delegatedAgent", RDF.iri(attempt.agent_iri)},
      {attempt.iri, @jf <> "requiresCapability", RDF.iri(attempt.capability_iri)},
      {attempt.iri, @jf <> "fencingToken", RDF.XSD.NonNegativeInteger.new(attempt.fencing_token)},
      {attempt.iri, @jf <> "runtimeVersion", RDF.XSD.String.new(attempt.runtime_version)},
      {attempt.iri, @jf <> "contextDigest", RDF.XSD.String.new(attempt.context_digest)},
      {attempt.iri, @jf <> "constraintPayload",
       RDF.XSD.String.new(Jason.encode!(context.constraints))},
      {attempt.context_iri, @rdf_type, RDF.iri(@jf <> "ExecutionContext")},
      {attempt.context_iri, @jf <> "contextDigest", RDF.XSD.String.new(attempt.context_digest)},
      {attempt.context_iri, @jf <> "constraintPayload",
       RDF.XSD.String.new(Jason.encode!(context.constraints))},
      {attempt.context_iri, @jf <> "instruction", RDF.iri(attempt.instruction_iri)},
      {attempt.instruction_iri, @rdf_type, RDF.iri(@jf <> "Instruction")},
      {attempt.instruction_iri, @jf <> "content", RDF.XSD.String.new(context.instruction)}
    ] ++
      Enum.map(context.allowed_effects, fn effect ->
        {attempt.context_iri, @jf <> "allowedEffectName", RDF.XSD.String.new(effect)}
      end) ++
      Enum.map(context.expected_artifacts, fn artifact ->
        {attempt.context_iri, @jf <> "expectedArtifactClass", RDF.XSD.String.new(artifact)}
      end) ++
      Enum.map(context.expected_evidence, fn evidence ->
        {attempt.context_iri, @jf <> "expectedEvidenceClass", RDF.XSD.String.new(evidence)}
      end) ++
      optional_iri(attempt.iri, @jf <> "retryOf", attempt.retry_of_iri) ++
      graph_reference_statements(attempt, context.source_graph_revisions) ++
      Enum.map(context.omissions, fn omission ->
        {attempt.context_iri, @jf <> "omittedBecause",
         RDF.XSD.String.new("#{omission.iri}|#{omission.reason}")}
      end)
  end

  defp graph_reference_statements(attempt, revisions) do
    Enum.flat_map(revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          attempt.context_iri <> "\n" <> graph <> "\n" <> Integer.to_string(revision)
        )

      [
        {attempt.context_iri, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp event_statements(_attempt, _transition, nil), do: {:ok, []}

  defp event_statements(attempt, transition, event) when is_map(event) do
    with true <- event[:attempt_iri] == attempt.iri,
         sequence when is_integer(sequence) and sequence >= 0 <- event[:sequence],
         outcome when outcome in ~w[pending success failure timeout cancelled rejected unknown]a <-
           event[:outcome_class],
         usage when is_map(usage) <- event[:usage],
         true <- byte_size(:erlang.term_to_binary(usage, [:deterministic])) <= 4_096,
         diagnostic when is_nil(diagnostic) or is_binary(diagnostic) <- event[:diagnostic],
         true <- is_nil(diagnostic) or byte_size(diagnostic) <= 1_024 do
      usage_digest = digest(usage)

      {:ok,
       [
         {transition.iri, @jf <> "runtimeSequence", RDF.XSD.NonNegativeInteger.new(sequence)},
         {transition.iri, @jf <> "outcomeClass",
          RDF.iri(@concept <> Macro.camelize(to_string(outcome)))},
         {transition.iri, @jf <> "usageDigest", RDF.XSD.String.new(usage_digest)}
       ] ++ optional_literal(transition.iri, @jf <> "diagnostic", diagnostic)}
    else
      _invalid -> invalid(:execution_runtime_event)
    end
  end

  defp event_statements(_attempt, _transition, _event), do: invalid(:execution_runtime_event)

  defp start_guards(attempt, lease, resolutions, attributes) do
    graph = attributes.control_graph_iri

    [
      {:current_lease_fence, graph, attempt.task_iri, lease.iri, attempt.fencing_token,
       attributes.recorded_at},
      {:transition_endpoint, graph, resolutions.lease.subject_iri,
       resolutions.lease.current_transition},
      {:transition_endpoint, graph, resolutions.task.subject_iri,
       resolutions.task.current_transition},
      {:transition_endpoint, graph, resolutions.plan.subject_iri,
       resolutions.plan.current_transition},
      {:no_active_attempt, attempt.task_iri}
    ]
  end

  defp transition_guards(
         attempt,
         attempt_resolution,
         lease,
         task_transition,
         task_resolution,
         attributes
       ) do
    base = [
      {:transition_endpoint, attempt.run_graph_iri, attempt.iri,
       attempt_resolution.current_transition},
      {:current_lease_fence, attributes.control_graph_iri, attempt.task_iri, lease.iri,
       attempt.fencing_token, attributes.recorded_at}
    ]

    if task_transition,
      do:
        base ++
          [
            {:transition_endpoint, attributes.control_graph_iri, attempt.task_iri,
             task_resolution.current_transition}
          ],
      else: base
  end

  defp envelope(type, attempt, context_revisions, attributes, targets, guards) do
    expected =
      context_revisions
      |> Map.put(attributes.control_graph_iri, attributes.expected_control_revision)
      |> Map.put(attempt.run_graph_iri, Map.get(attributes, :expected_run_revision, 0))

    %{
      command_type: type,
      command_version: "1.6.0",
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
      expected_graph_revisions: expected,
      reason: attributes[:reason],
      payload: %{changes: targets, guards: guards, attempt_iri: attempt.iri}
    }
  end

  defp command_type(:cancelling, %{origin: :control}), do: "RequestExecutionCancellation"
  defp command_type(_next_state, _attributes), do: "TransitionExecutionAttempt"

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, object), do: [{subject, predicate, RDF.iri(object)}]
  defp optional_literal(_subject, _predicate, nil), do: []

  defp optional_literal(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.String.new(value)}]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

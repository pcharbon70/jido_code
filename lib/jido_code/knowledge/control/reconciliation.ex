defmodule JidoCode.Knowledge.Control.Reconciliation do
  @moduledoc """
  Deterministic desired/observed comparison and graph change proposals.

  Results are bounded explanation resources. They may propose or reuse work,
  but this module never adopts a plan, grants authority, or acquires a lease.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [:iri, :package, :results, :gaps, :proposals, :transition, :recorded_at]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @states ~w[satisfied unsatisfied unknown contradictory]a
  @max_evaluations 100
  @max_refs 30

  @spec new(ReconciliationPackage.t(), [map()], map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%ReconciliationPackage{} = package, evaluations, attributes)
      when is_list(evaluations) and is_map(attributes) and
             length(evaluations) in 1..@max_evaluations do
    with true <- DateTime.compare(attributes[:recorded_at], package.deadline) == :lt,
         true <- attributes[:actor_iri] == package.actor_iri,
         {:ok, iri} <- ResourceIdentity.deterministic(:reconciliation_activity, package.iri),
         {:ok, results} <- evaluate_all(package, evaluations),
         true <- length(results) <= package.budget.max_changes,
         {:ok, transition} <- initial_transition(iri, package, attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         package: package,
         results: results,
         gaps: results |> Enum.flat_map(&List.wrap(&1.gap)) |> Enum.reject(&is_nil/1),
         proposals: Enum.map(results, & &1.proposal),
         transition: transition,
         recorded_at: DateTime.truncate(attributes[:recorded_at], :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:desired_state_reconciliation)
    end
  rescue
    _error -> invalid(:desired_state_reconciliation)
  end

  def new(_package, _evaluations, _attributes), do: invalid(:desired_state_reconciliation)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = reconciliation) do
    [
      {reconciliation.iri, @rdf_type, RDF.iri(@jf <> "ReconciliationActivity")},
      {reconciliation.iri, @jf <> "inputPackage", RDF.iri(reconciliation.package.iri)},
      {reconciliation.iri, @jf <> "validFor", RDF.iri(reconciliation.package.scope_iri)},
      {reconciliation.iri, @jf <> "about", RDF.iri(reconciliation.package.repository_iri)},
      {reconciliation.iri, @prov <> "wasAssociatedWith",
       RDF.iri(reconciliation.package.actor_iri)},
      {reconciliation.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(reconciliation.recorded_at)}
    ] ++
      ReconciliationPackage.statements(reconciliation.package) ++
      Enum.flat_map(reconciliation.results, &result_statements(reconciliation, &1)) ++
      Transition.statements(reconciliation.transition)
  end

  @spec record_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), reconciliation: t()}} | {:error, Error.t()}
  def record_command(reconciliation, attributes, options \\ [])

  def record_command(%__MODULE__{} = reconciliation, attributes, options)
      when is_map(attributes) and is_list(options) do
    package = reconciliation.package

    with {:ok, control_graph} <- Graph.repository_control(package.repository_iri),
         true <- control_graph == attributes[:control_graph_iri],
         revisions = ReconciliationPackage.graph_revisions(package),
         true <- revisions[control_graph] == attributes[:expected_control_revision],
         {:ok, target} <-
           Graph.target(
             control_graph,
             attributes[:expected_control_revision],
             package.scope_iri,
             attributes[:command_iri],
             reconciliation.recorded_at,
             statements(reconciliation)
           ),
         guards =
           [
             {:subject_absent, control_graph, reconciliation.iri},
             {:transition_endpoint, attributes[:catalog_graph_iri], package.enrollment.iri,
              package.enrollment.current_transition}
             | source_guards(package)
           ],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordReconciliation",
               attributes,
               package.scope_iri,
               revisions,
               [target],
               guards
             ),
             options
           ) do
      {:ok, %{command: command, reconciliation: reconciliation}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_reconciliation_command)
    end
  end

  def record_command(_reconciliation, _attributes, _options),
    do: invalid(:record_reconciliation_command)

  @spec transition_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}}
          | {:error, Error.t()}
  def transition_command(resolution, attributes, options \\ [])

  def transition_command(%{domain: :reconciliation} = resolution, attributes, options)
      when is_map(attributes) and is_list(options) do
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
               "TransitionReconciliation",
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
      _invalid -> invalid(:transition_reconciliation_command)
    end
  end

  def transition_command(_resolution, _attributes, _options),
    do: invalid(:transition_reconciliation_command)

  defp evaluate_all(package, evaluations) do
    Enum.reduce_while(evaluations, {:ok, []}, fn evaluation, {:ok, results} ->
      case evaluate(package, evaluation) do
        {:ok, result} -> {:cont, {:ok, [result | results]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.sort_by(results, & &1.desired_outcome_iri)}
      error -> error
    end
  end

  defp evaluate(package, evaluation) when is_map(evaluation) do
    with true <- evaluation[:desired_outcome_iri] in package.desired_outcome_iris,
         :ok <- validate_resource(evaluation[:dimension_iri]),
         state when state in @states <- evaluation[:observed_state],
         true <- is_boolean(evaluation[:complete?]),
         true <- state not in [:satisfied, :unsatisfied] or evaluation[:complete?],
         {:ok, evidence} <- resources(evaluation[:evidence_iris], true),
         {:ok, policies} <- resources(evaluation[:policy_iris], false),
         true <- Enum.all?(policies, &(&1 in package.policy_iris)),
         :ok <- optional_resource(evaluation[:applicability_iri]),
         :ok <- optional_resource(evaluation[:existing_goal_iri]),
         :ok <- optional_resource(evaluation[:existing_obligation_iri]),
         :ok <- optional_resource(evaluation[:obsolete_goal_iri]),
         true <- is_integer(evaluation[:risk]) and evaluation[:risk] in 0..10,
         true <- is_boolean(evaluation[:ambiguous?]),
         true <- is_boolean(evaluation[:human_approval_required?]),
         true <- is_boolean(evaluation[:policy_conflict?]),
         {:ok, superseded} <- resources(evaluation[:superseded_proposal_iris] || [], false),
         {:ok, result} <-
           build_result(
             package,
             Map.put(evaluation, :superseded_proposal_iris, superseded),
             state,
             evidence,
             policies
           ) do
      {:ok, result}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:reconciliation_evaluation)
    end
  end

  defp evaluate(_package, _evaluation), do: invalid(:reconciliation_evaluation)

  defp build_result(package, evaluation, state, evidence, policies) do
    classification = classify(evaluation, state)
    gap = gap(package, evaluation, state, evidence, policies, classification)

    with {:ok, proposal} <- proposal(package, evaluation, gap, classification) do
      {:ok,
       %{
         desired_outcome_iri: evaluation[:desired_outcome_iri],
         dimension_iri: evaluation[:dimension_iri],
         observed_state: state,
         classification: classification.result,
         requires_decision?: classification.requires_decision?,
         gap: gap,
         proposal: proposal
       }}
    end
  end

  defp classify(evaluation, :satisfied) do
    if evaluation[:obsolete_goal_iri],
      do: %{result: :work_superseded, action: :supersede, requires_decision?: false},
      else: %{result: :no_gap, action: :omit, requires_decision?: false}
  end

  defp classify(_evaluation, :unknown),
    do: %{result: :unknown, action: :omit, requires_decision?: false}

  defp classify(_evaluation, :contradictory),
    do: %{result: :contradiction, action: :decision, requires_decision?: true}

  defp classify(%{policy_conflict?: true}, :unsatisfied),
    do: %{result: :policy_conflict, action: :decision, requires_decision?: true}

  defp classify(%{existing_goal_iri: goal}, :unsatisfied) when is_binary(goal),
    do: %{result: :existing_work_reused, action: :reuse, requires_decision?: false}

  defp classify(evaluation, :unsatisfied) do
    decision? =
      evaluation[:risk] >= 7 or evaluation[:ambiguous?] or
        evaluation[:human_approval_required?]

    %{result: :proposal_pending, action: :propose, requires_decision?: decision?}
  end

  defp gap(_package, _evaluation, :satisfied, _evidence, _policies, _classification), do: nil

  defp gap(package, evaluation, state, evidence, policies, classification) do
    {:ok, iri} =
      ResourceIdentity.deterministic(
        :reconciliation_gap,
        Enum.join(
          [package.iri, evaluation.desired_outcome_iri, evaluation.dimension_iri, state],
          "\n"
        )
      )

    %{
      iri: iri,
      desired_outcome_iri: evaluation.desired_outcome_iri,
      dimension_iri: evaluation.dimension_iri,
      state: state,
      evidence_iris: evidence,
      policy_iris: policies,
      applicability_iri: evaluation[:applicability_iri],
      complete?: evaluation.complete?,
      classification: classification.result
    }
  end

  defp proposal(package, evaluation, gap, classification) do
    target = proposal_target(package, evaluation, gap, classification)
    identity_target = target || evaluation.desired_outcome_iri

    with {:ok, iri} <-
           ResourceIdentity.deterministic(
             :control_proposal,
             Enum.join(
               [
                 package.iri,
                 evaluation.desired_outcome_iri,
                 classification.action,
                 identity_target
               ],
               "\n"
             )
           ),
         {:ok, decision_iri} <- decision_identity(iri, classification.requires_decision?) do
      {:ok,
       %{
         iri: iri,
         action: classification.action,
         result: classification.result,
         target_iri: target,
         desired_outcome_iri: evaluation.desired_outcome_iri,
         obligation_iri: evaluation[:existing_obligation_iri],
         decision_iri: decision_iri,
         superseded_proposal_iris: Enum.take(evaluation[:superseded_proposal_iris] || [], 20)
       }}
    end
  end

  defp proposal_target(_package, evaluation, _gap, %{action: :reuse}),
    do: evaluation.existing_goal_iri

  defp proposal_target(_package, evaluation, _gap, %{action: :supersede}),
    do: evaluation.obsolete_goal_iri

  defp proposal_target(package, evaluation, gap, %{action: :propose}) do
    {:ok, iri} =
      ResourceIdentity.deterministic(
        :goal_proposal,
        Enum.join([package.repository_iri, gap.iri, evaluation.dimension_iri], "\n")
      )

    iri
  end

  defp proposal_target(_package, _evaluation, _gap, _classification), do: nil

  defp result_statements(reconciliation, result) do
    gap_statements(result.gap, reconciliation.package) ++
      proposal_statements(result.proposal, reconciliation)
  end

  defp gap_statements(nil, _package), do: []

  defp gap_statements(gap, package) do
    [
      {gap.iri, @rdf_type, RDF.iri(@jf <> "Gap")},
      {gap.iri, @jf <> "inputPackage", RDF.iri(package.iri)},
      {gap.iri, @jf <> "about", RDF.iri(gap.desired_outcome_iri)},
      {gap.iri, @jf <> "taskKind", RDF.iri(gap.dimension_iri)},
      {gap.iri, @jf <> "epistemicState",
       RDF.iri(@concept <> Macro.camelize(to_string(gap.state)))},
      {gap.iri, @jf <> "completenessState",
       RDF.iri(@concept <> if(gap.complete?, do: "Complete", else: "Incomplete"))}
    ] ++
      Enum.map(gap.evidence_iris, &{gap.iri, @jf <> "evidenceSource", RDF.iri(&1)}) ++
      Enum.map(gap.policy_iris, &{gap.iri, @jf <> "governedBy", RDF.iri(&1)}) ++
      if(gap.applicability_iri,
        do: [{gap.iri, @jf <> "applicabilityEvidence", RDF.iri(gap.applicability_iri)}],
        else: []
      )
  end

  defp proposal_statements(proposal, reconciliation) do
    base = [
      {proposal.iri, @rdf_type, RDF.iri(@jf <> "ControlProposal")},
      {proposal.iri, @jf <> "inputPackage", RDF.iri(reconciliation.package.iri)},
      {proposal.iri, @jf <> "governedProposal", RDF.iri(reconciliation.iri)},
      {proposal.iri, @jf <> "about", RDF.iri(proposal.desired_outcome_iri)},
      {proposal.iri, @jf <> "epistemicState",
       RDF.iri(@concept <> Macro.camelize(to_string(proposal.result)))}
    ]

    target =
      case proposal.action do
        :propose ->
          [{proposal.iri, @jf <> "proposes", RDF.iri(proposal.target_iri)}]

        :reuse ->
          [{proposal.iri, @jf <> "reuses", RDF.iri(proposal.target_iri)}]

        :supersede ->
          [{proposal.iri, @jf <> "supersedes", RDF.iri(proposal.target_iri)}]

        :omit ->
          [{proposal.iri, @jf <> "omittedBecause", RDF.iri(reason_iri(proposal.result))}]

        :decision ->
          [{proposal.iri, @jf <> "omittedBecause", RDF.iri(reason_iri(proposal.result))}]
      end

    obligation =
      if proposal.obligation_iri,
        do: [{proposal.iri, @jf <> "addresses", RDF.iri(proposal.obligation_iri)}],
        else: []

    decision =
      if proposal.decision_iri do
        [
          {proposal.iri, @jf <> "requiresDecision", RDF.iri(proposal.decision_iri)},
          {proposal.decision_iri, @rdf_type, RDF.iri(@jf <> "Decision")},
          {proposal.decision_iri, @jf <> "about", RDF.iri(proposal.iri)}
        ]
      else
        []
      end

    supersessions =
      Enum.map(
        proposal.superseded_proposal_iris,
        &{proposal.iri, @jf <> "supersedes", RDF.iri(&1)}
      )

    base ++ target ++ obligation ++ decision ++ supersessions
  end

  defp initial_transition(iri, package, attributes) do
    Transition.new(%{
      subject_iri: iri,
      domain: :reconciliation,
      prior_state: nil,
      next_state: :proposed,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: package.actor_iri,
      cause_iri: attributes[:cause_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp next_transition(resolution, attributes) do
    Transition.new(%{
      subject_iri: resolution.subject_iri,
      domain: :reconciliation,
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

  defp source_guards(package) do
    Enum.flat_map(package.required_subjects, fn {graph, resources} ->
      Enum.map(resources, &{:subject_present, graph, &1})
    end)
  end

  defp envelope(type, attributes, scope, revisions, changes, guards) do
    %{
      command_type: type,
      command_version: "1.4.0",
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

  defp decision_identity(_proposal_iri, false), do: {:ok, nil}

  defp decision_identity(proposal_iri, true),
    do: ResourceIdentity.deterministic(:control_decision, proposal_iri <> "\nrequired")

  defp resources(values, required?)
       when is_list(values) and length(values) <= @max_refs and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:reconciliation_references)
  end

  defp resources(_values, _required), do: invalid(:reconciliation_references)
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: validate_resource(value)
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp reason_iri(value), do: @concept <> Macro.camelize(to_string(value))
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

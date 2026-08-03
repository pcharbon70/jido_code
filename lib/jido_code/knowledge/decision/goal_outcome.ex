defmodule JidoCode.Knowledge.Decision.GoalOutcome do
  @moduledoc "Governed claim disposition and explicit outcome transition command."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Decision.FollowUp
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Evidence.Bundle
  alias JidoCode.Knowledge.Evidence.Graph, as: EvidenceGraph
  alias JidoCode.Knowledge.Evidence.Sufficiency
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :disposition,
    :mode,
    :outcome_stage,
    :risk,
    :actor_iri,
    :goal_iri,
    :task_iri,
    :policy_iri,
    :scope_iri,
    :assessment,
    :evidence_bundles,
    :claim_dispositions,
    :task_transitions,
    :goal_transitions,
    :related_transitions,
    :follow_ups,
    :rationale_refs,
    :confirmation_iris,
    :confirmation_sources,
    :recorded_at,
    :valid_from,
    :valid_to,
    :supersedes_iri,
    :supersedes_follow_up_iris
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @dispositions ~w[accept reject defer waive supersede request_more]a
  @modes ~w[human policy_automatic delegated_agent]a
  @stages ~w[
    attempt_completion patch_approval external_application post_change_verification final_goal
  ]a
  @risks ~w[low normal high critical]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @rdf_predicate "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"
  @rdf_object "http://www.w3.org/1999/02/22-rdf-syntax-ns#object"
  @jf "https://jido.run/ontology/factory#"
  @prov "http://www.w3.org/ns/prov#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(map(), [Bundle.t()], map(), map(), map()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(assessment, bundles, goal_resolution, task_resolution, attributes)
      when is_map(assessment) and is_list(bundles) and is_map(attributes) do
    with disposition when disposition in @dispositions <- attributes[:disposition],
         mode when mode in @modes <- attributes[:mode],
         stage when stage in @stages <- attributes[:outcome_stage],
         risk when risk in @risks <- attributes[:risk],
         :ok <- mode_allowed(mode, disposition, risk),
         {:ok, recomputed} <-
           Sufficiency.evaluate(
             bundles,
             attributes[:evidence_requirements],
             attributes[:evaluation_context]
           ),
         true <- recomputed == assessment,
         :ok <-
           decision_inputs(assessment, bundles, goal_resolution, task_resolution, attributes),
         :ok <- disposition_allowed(disposition, assessment.status),
         :ok <- actor_separation(disposition, bundles, attributes),
         true <- Map.get(attributes, :requested_effects, []) == [],
         {:ok, rationale_refs} <- resources(attributes[:rationale_refs], 30, true),
         {:ok, confirmations} <- resources(attributes[:confirmation_iris], 30, true),
         {:ok, confirmation_sources} <-
           confirmation_sources(attributes[:confirmation_sources], confirmations),
         :ok <- stage_requirements(stage, bundles, confirmations),
         recorded_at when is_struct(recorded_at, DateTime) <- attributes[:recorded_at],
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         {:ok, iri} <- identity(assessment, bundles, attributes),
         {:ok, claim_dispositions} <- claim_dispositions(iri, disposition, bundles),
         {:ok, task_transitions} <-
           task_transitions(iri, disposition, task_resolution, attributes),
         {:ok, goal_transitions} <-
           goal_transitions(iri, disposition, stage, goal_resolution, attributes),
         {:ok, related_transitions} <-
           related_transitions(iri, disposition, stage, attributes),
         {:ok, follow_ups} <- follow_ups(iri, disposition, attributes),
         {:ok, supersedes_follow_ups} <-
           resources(Map.get(attributes, :supersedes_follow_up_iris, []), 30, true),
         :ok <- optional_resource(attributes[:supersedes_iri]) do
      {:ok,
       %__MODULE__{
         iri: iri,
         disposition: disposition,
         mode: mode,
         outcome_stage: stage,
         risk: risk,
         actor_iri: attributes.actor_iri,
         goal_iri: goal_resolution.subject_iri,
         task_iri: task_resolution.subject_iri,
         policy_iri: attributes.policy_iri,
         scope_iri: attributes.scope_iri,
         assessment: assessment,
         evidence_bundles: bundles,
         claim_dispositions: claim_dispositions,
         task_transitions: task_transitions,
         goal_transitions: goal_transitions,
         related_transitions: related_transitions,
         follow_ups: follow_ups,
         rationale_refs: rationale_refs,
         confirmation_iris: confirmations,
         confirmation_sources: confirmation_sources,
         recorded_at: recorded_at,
         valid_from: valid_from,
         valid_to: valid_to,
         supersedes_iri: attributes[:supersedes_iri],
         supersedes_follow_up_iris: supersedes_follow_ups
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:goal_outcome_decision)
    end
  rescue
    _error -> invalid(:goal_outcome_decision)
  end

  def new(_assessment, _bundles, _goal, _task, _attributes),
    do: invalid(:goal_outcome_decision)

  @spec record_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(decision, attributes, options \\ [])

  def record_command(%__MODULE__{} = decision, attributes, options)
      when is_map(attributes) and is_list(options) do
    evidence_graph = attributes[:evidence_graph_iri]
    control_graph = attributes[:control_graph_iri]
    expected = attributes[:expected_graph_revisions]

    with true <- is_map(expected),
         evidence_revision when is_integer(evidence_revision) and evidence_revision > 0 <-
           expected[evidence_graph],
         control_revision when is_integer(control_revision) and control_revision > 0 <-
           expected[control_graph],
         true <- exact_revisions?(decision, attributes),
         recorded_at when is_struct(recorded_at, DateTime) <- attributes[:recorded_at],
         true <- recorded_at == decision.recorded_at,
         {:ok, evidence_target} <-
           EvidenceGraph.target(
             evidence_graph,
             evidence_revision,
             decision.scope_iri,
             decision.iri,
             recorded_at,
             evidence_statements(decision, recorded_at)
           ),
         {:ok, control_target} <-
           ControlGraph.target(
             control_graph,
             control_revision,
             decision.scope_iri,
             decision.iri,
             recorded_at,
             control_statements(decision)
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(decision, attributes, [evidence_target, control_target]),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:decide_goal_outcome)
    end
  rescue
    _error -> invalid(:decide_goal_outcome)
  end

  def record_command(_decision, _attributes, _options), do: invalid(:decide_goal_outcome)

  @spec evidence_statements(t(), DateTime.t()) :: [RDF.Triple.t()]
  def evidence_statements(decision, recorded_at) do
    [
      {decision.iri, @rdf_type, RDF.iri(@jf <> "Decision")},
      {decision.iri, @jf <> "decisionAuthority", RDF.iri(decision.actor_iri)},
      {decision.iri, @jf <> "addresses", RDF.iri(decision.goal_iri)},
      {decision.iri, @jf <> "governedBy", RDF.iri(decision.policy_iri)},
      {decision.iri, @jf <> "evaluates", RDF.iri(decision.assessment.iri)},
      {decision.iri, @jf <> "decisionMode",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.mode)))},
      {decision.iri, @jf <> "outcomeStage",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.outcome_stage)))},
      {decision.iri, @jf <> "decisionDisposition",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.disposition)))},
      {decision.iri, @jf <> "riskClass",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.risk)))},
      {decision.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(decision.valid_from)},
      {decision.iri, @jf <> "validTo", RDF.XSD.DateTime.new(decision.valid_to)},
      {decision.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(recorded_at)},
      {decision.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(recorded_at)},
      {decision.assessment.iri, @rdf_type, RDF.iri(@jf <> "EvidenceSufficiency")},
      {decision.assessment.iri, @jf <> "epistemicState",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.assessment.status)))},
      {decision.assessment.iri, @jf <> "governedBy", RDF.iri(decision.policy_iri)},
      {decision.assessment.iri, @jf <> "version",
       RDF.XSD.String.new(decision.assessment.policy_version)},
      {decision.assessment.iri, @jf <> "policyGraphRevision",
       RDF.XSD.NonNegativeInteger.new(decision.assessment.policy_graph_revision)},
      {decision.assessment.iri, @jf <> "planGraphRevision",
       RDF.XSD.NonNegativeInteger.new(decision.assessment.plan_graph_revision)},
      {decision.assessment.iri, @jf <> "evaluatedAt",
       RDF.XSD.DateTime.new(decision.assessment.evaluated_at)}
    ] ++
      disposition_statements(decision) ++
      Enum.flat_map(decision.claim_dispositions, &claim_disposition_statements(decision, &1)) ++
      assessment_revision_statements(decision) ++
      Enum.map(decision.evidence_bundles, fn bundle ->
        {decision.assessment.iri, @jf <> "consideredEvidence", RDF.iri(bundle.iri)}
      end) ++
      Enum.map(decision.rationale_refs, fn rationale ->
        {decision.iri, @jf <> "rationaleReference", RDF.iri(rationale)}
      end) ++
      Enum.map(decision.confirmation_iris, fn confirmation ->
        {decision.iri, @jf <> "confirmation", RDF.iri(confirmation)}
      end) ++
      optional_iri(decision.iri, @jf <> "supersedes", decision.supersedes_iri)
  end

  @spec control_statements(t()) :: [RDF.Triple.t()]
  def control_statements(decision) do
    [
      {decision.iri, @rdf_type, RDF.iri(@jf <> "Decision")},
      {decision.iri, @jf <> "decisionAuthority", RDF.iri(decision.actor_iri)},
      {decision.iri, @jf <> "addresses", RDF.iri(decision.goal_iri)},
      {decision.iri, @jf <> "governedBy", RDF.iri(decision.policy_iri)},
      {decision.iri, @jf <> "outcomeStage",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.outcome_stage)))},
      {decision.iri, @jf <> "decisionDisposition",
       RDF.iri(@concept <> Macro.camelize(to_string(decision.disposition)))}
    ] ++
      Enum.flat_map(
        decision.task_transitions ++ decision.goal_transitions ++ decision.related_transitions,
        &Transition.statements/1
      ) ++
      Enum.flat_map(decision.follow_ups, &FollowUp.statements/1) ++
      Enum.map(
        decision.task_transitions ++ decision.goal_transitions ++ decision.related_transitions,
        fn transition ->
          {decision.iri, @jf <> "accepts", RDF.iri(transition.iri)}
        end
      ) ++
      Enum.map(decision.follow_ups, fn follow_up ->
        {decision.iri, @jf <> "followUpGoal", RDF.iri(follow_up.goal_iri)}
      end) ++
      Enum.map(decision.supersedes_follow_up_iris, fn follow_up ->
        {decision.iri, @jf <> "supersedes", RDF.iri(follow_up)}
      end) ++
      [
        {reconciliation_iri(decision), @rdf_type, RDF.iri(@jf <> "ReconciliationActivity")},
        {reconciliation_iri(decision), @jf <> "causedBy", RDF.iri(decision.iri)},
        {reconciliation_iri(decision), @jf <> "about", RDF.iri(decision.goal_iri)},
        {reconciliation_iri(decision), @jf <> "epistemicState",
         RDF.iri(@concept <> "ReconciliationProposed")}
      ]
  end

  defp decision_inputs(assessment, bundles, goal, task, attributes) do
    cond do
      bundles == [] or not Enum.all?(bundles, &match?(%Bundle{}, &1)) -> :error
      assessment[:transition_authority?] != false -> :error
      assessment[:acceptance_authority?] != false -> :error
      not is_map(goal) or goal[:domain] != :goal -> :error
      not is_map(task) or task[:domain] != :task -> :error
      ResourceIdentity.validate(attributes[:actor_iri]) != :ok -> :error
      ResourceIdentity.validate(attributes[:scope_iri]) != :ok -> :error
      ResourceIdentity.validate(attributes[:policy_iri]) != :ok -> :error
      attributes[:policy_iri] != assessment[:policy_iri] -> :error
      attributes[:policy_version] != assessment[:policy_version] -> :error
      attributes[:goal_iri] != goal[:subject_iri] -> :error
      attributes[:task_iri] != task[:subject_iri] -> :error
      not evidence_scope?(bundles, attributes[:evidence_graph_iri]) -> :error
      true -> :ok
    end
  end

  defp disposition_allowed(:accept, :sufficient), do: :ok
  defp disposition_allowed(:waive, :waiver_required), do: :ok
  defp disposition_allowed(:reject, status) when status in [:contradicted, :insufficient], do: :ok
  defp disposition_allowed(:defer, _status), do: :ok
  defp disposition_allowed(:request_more, _status), do: :ok
  defp disposition_allowed(:supersede, _status), do: :ok
  defp disposition_allowed(_disposition, _status), do: :error

  defp mode_allowed(:human, _disposition, _risk), do: :ok
  defp mode_allowed(:policy_automatic, :waive, _risk), do: :error

  defp mode_allowed(:policy_automatic, _disposition, risk) when risk in [:high, :critical],
    do: :error

  defp mode_allowed(:policy_automatic, _disposition, _risk), do: :ok
  defp mode_allowed(:delegated_agent, :waive, _risk), do: :error
  defp mode_allowed(:delegated_agent, _disposition, :critical), do: :error
  defp mode_allowed(:delegated_agent, _disposition, _risk), do: :ok

  defp actor_separation(disposition, bundles, attributes)
       when disposition in [:accept, :waive, :supersede] do
    evaluators = Enum.map(bundles, & &1.activity.evaluator_iri)

    if attributes[:actor_iri] != attributes[:execution_actor_iri] and
         (not attributes[:independent_decider_required?] or
            attributes[:actor_iri] not in evaluators),
       do: :ok,
       else: :error
  end

  defp actor_separation(_disposition, _bundles, _attributes), do: :ok

  defp evidence_scope?(bundles, evidence_graph) do
    Enum.all?(bundles, fn bundle ->
      Enum.all?(bundle.claims, &(&1.graph_scope_iri == evidence_graph))
    end)
  end

  defp stage_requirements(:external_application, _bundles, confirmations),
    do: if(confirmations != [], do: :ok, else: :error)

  defp stage_requirements(stage, bundles, confirmations)
       when stage in [:post_change_verification, :final_goal] do
    if confirmations != [] and
         Enum.any?(bundles, &(not is_nil(&1.activity.post_change_snapshot_iri))),
       do: :ok,
       else: :error
  end

  defp stage_requirements(_stage, _bundles, _confirmations), do: :ok

  defp claim_dispositions(decision_iri, disposition, bundles) do
    state = claim_state(disposition)

    if is_nil(state) do
      {:ok, []}
    else
      claims = bundles |> Enum.flat_map(& &1.claims) |> Enum.uniq_by(& &1.iri)

      dispositions =
        Enum.map(claims, fn claim ->
          {:ok, iri} =
            ResourceIdentity.deterministic(
              :claim_disposition,
              Enum.join([decision_iri, claim.iri, Atom.to_string(state)], "\n")
            )

          %{iri: iri, prior: claim, state: state}
        end)

      {:ok, dispositions}
    end
  end

  defp claim_state(:accept), do: :accepted
  defp claim_state(:reject), do: :rejected
  defp claim_state(:waive), do: :waived
  defp claim_state(:supersede), do: :claim_superseded
  defp claim_state(_disposition), do: nil

  defp task_transitions(decision, disposition, resolution, attributes) do
    final_state =
      case disposition do
        :accept -> :satisfied
        :waive -> :satisfied
        :reject -> :rejected
        :supersede -> :superseded
        _other -> :awaiting_decision
      end

    transition_chain(resolution, final_state, decision, attributes)
  end

  defp goal_transitions(decision, disposition, :final_goal, resolution, attributes)
       when disposition in [:accept, :waive] do
    transition_chain(resolution, :satisfied, decision, attributes)
  end

  defp goal_transitions(
         decision,
         :supersede,
         _stage,
         %{current_state: :satisfied} = resolution,
         attributes
       ),
       do: transition_chain(resolution, :superseded, decision, attributes)

  defp goal_transitions(_decision, _disposition, _stage, _resolution, _attributes),
    do: {:ok, []}

  defp related_transitions(decision, disposition, :final_goal, attributes)
       when disposition in [:accept, :waive] do
    resolutions = Map.get(attributes, :related_resolutions, [])

    if is_list(resolutions) and length(resolutions) <= 20 and
         Enum.all?(resolutions, &(&1[:domain] in [:obligation, :desired_outcome])) do
      reduce_related(resolutions, decision, :satisfied, attributes)
    else
      :error
    end
  end

  defp related_transitions(decision, :supersede, _stage, attributes) do
    resolutions = Map.get(attributes, :related_resolutions, [])

    if is_list(resolutions) and length(resolutions) <= 20 and
         Enum.all?(resolutions, fn resolution ->
           resolution[:domain] in [:obligation, :desired_outcome] and
             resolution[:current_state] == :satisfied
         end) do
      reduce_related(resolutions, decision, :superseded, attributes)
    else
      :error
    end
  end

  defp related_transitions(_decision, _disposition, _stage, attributes) do
    if Map.get(attributes, :related_resolutions, []) == [], do: {:ok, []}, else: :error
  end

  defp reduce_related(resolutions, decision, state, attributes) do
    Enum.reduce_while(resolutions, {:ok, []}, fn resolution, {:ok, transitions} ->
      case transition_chain(resolution, state, decision, attributes) do
        {:ok, generated} -> {:cont, {:ok, transitions ++ generated}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp transition_chain(%{current_state: state}, state, _decision, _attributes), do: {:ok, []}

  defp transition_chain(resolution, final_state, decision, attributes) do
    states = transition_states(resolution, final_state)

    Enum.reduce_while(states, {:ok, [], resolution}, fn next_state, {:ok, transitions, current} ->
      transition_attributes = %{
        subject_iri: current.subject_iri,
        domain: current.domain,
        prior_state: current.current_state,
        next_state: next_state,
        revision: current.current_revision + 1,
        expected_predecessor: current.current_transition,
        actor_iri: attributes.actor_iri,
        cause_iri: decision,
        reason: "apply governed #{attributes.disposition} decision",
        recorded_at: attributes.recorded_at
      }

      case Transition.new(transition_attributes) do
        {:ok, transition} ->
          next = %{
            current
            | current_state: next_state,
              current_revision: transition.revision,
              current_transition: transition.iri
          }

          {:cont, {:ok, transitions ++ [transition], next}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, transitions, _resolution} -> {:ok, transitions}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp transition_states(%{domain: :goal, current_state: :approved}, :satisfied),
    do: [:eligible, :executing, :awaiting_evidence, :awaiting_decision, :satisfied]

  defp transition_states(%{domain: :goal, current_state: :eligible}, :satisfied),
    do: [:executing, :awaiting_evidence, :awaiting_decision, :satisfied]

  defp transition_states(%{domain: :goal, current_state: :leased}, :satisfied),
    do: [:executing, :awaiting_evidence, :awaiting_decision, :satisfied]

  defp transition_states(%{domain: :goal, current_state: :executing}, :satisfied),
    do: [:awaiting_evidence, :awaiting_decision, :satisfied]

  defp transition_states(%{current_state: :awaiting_evidence}, final_state)
       when final_state != :awaiting_decision,
       do: [:awaiting_decision, final_state]

  defp transition_states(_resolution, final_state), do: [final_state]

  defp follow_ups(decision, disposition, attributes) do
    kinds = Map.get(attributes, :follow_up_kinds, default_follow_ups(disposition))

    if is_list(kinds) and length(kinds) <= 10 do
      decoded =
        Enum.map(kinds, fn kind ->
          FollowUp.new(decision, kind, %{
            target_iri: attributes.goal_iri,
            scope_iri: attributes.scope_iri,
            actor_iri: attributes.actor_iri,
            recorded_at: attributes.recorded_at,
            reason_label: Atom.to_string(kind)
          })
        end)

      if Enum.all?(decoded, &match?({:ok, _}, &1)),
        do: {:ok, Enum.map(decoded, &elem(&1, 1))},
        else: :error
    else
      :error
    end
  end

  defp default_follow_ups(:accept), do: [:apply_patch]
  defp default_follow_ups(:reject), do: [:remediate_failure]
  defp default_follow_ups(:request_more), do: [:gather_evidence]
  defp default_follow_ups(:defer), do: [:monitor_outcome]
  defp default_follow_ups(_disposition), do: []

  defp claim_disposition_statements(decision, disposition) do
    claim = disposition.prior

    [
      {disposition.iri, @rdf_type, RDF.iri(@jf <> "Claim")},
      {disposition.iri, @rdf_subject, RDF.iri(claim.subject_iri)},
      {disposition.iri, @rdf_predicate, RDF.iri(claim.predicate_iri)},
      {disposition.iri, @rdf_object, claim.object},
      {disposition.iri, @jf <> "sourceActivity", RDF.iri(decision.iri)},
      {disposition.iri, @jf <> "graphScope", RDF.iri(claim.graph_scope_iri)},
      {disposition.iri, @jf <> "epistemicState", RDF.iri(claim_state_iri(disposition.state))},
      {disposition.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(decision.valid_from)},
      {disposition.iri, @jf <> "validTo", RDF.XSD.DateTime.new(decision.valid_to)},
      {disposition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(decision.recorded_at)},
      {disposition.iri, @jf <> "supersedes", RDF.iri(claim.iri)},
      {disposition.iri, @prov <> "wasGeneratedBy", RDF.iri(decision.iri)}
    ]
  end

  defp disposition_statements(decision) do
    predicate = disposition_predicate(decision.disposition)

    targets =
      case decision.claim_dispositions do
        [] -> Enum.map(decision.evidence_bundles, & &1.iri)
        dispositions -> Enum.map(dispositions, & &1.iri)
      end

    Enum.map(targets, &{decision.iri, @jf <> predicate, RDF.iri(&1)})
  end

  defp assessment_revision_statements(decision) do
    Enum.flat_map(decision.assessment.source_graph_revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          Enum.join(
            [decision.assessment.iri, graph, Integer.to_string(revision)],
            "\n"
          )
        )

      [
        {decision.assessment.iri, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp disposition_predicate(:accept), do: "accepts"
  defp disposition_predicate(:reject), do: "rejects"
  defp disposition_predicate(:waive), do: "waives"
  defp disposition_predicate(:defer), do: "defers"
  defp disposition_predicate(:request_more), do: "requestsMoreEvidence"
  defp disposition_predicate(:supersede), do: "supersedes"
  defp claim_state_iri(state), do: @concept <> Macro.camelize(to_string(state))

  defp exact_revisions?(decision, attributes) do
    expected = attributes.expected_graph_revisions
    assessment = decision.assessment

    confirmation_revisions = Map.new(decision.confirmation_sources, &{&1.graph_iri, &1.revision})

    required_graphs =
      (Map.keys(assessment.source_graph_revisions) ++
         Map.keys(confirmation_revisions) ++
         [
           attributes.policy_graph_iri,
           attributes.evidence_graph_iri,
           attributes.control_graph_iri
         ])
      |> Enum.uniq()
      |> Enum.sort()

    Map.keys(expected) |> Enum.sort() == required_graphs and
      Map.take(expected, Map.keys(assessment.source_graph_revisions)) ==
        assessment.source_graph_revisions and
      Map.take(expected, Map.keys(confirmation_revisions)) == confirmation_revisions and
      expected[attributes.policy_graph_iri] == assessment.policy_graph_revision and
      expected[attributes.evidence_graph_iri] > 0 and
      expected[attributes.control_graph_iri] > 0
  end

  defp envelope(decision, attributes, targets) do
    command = command_iri(decision)

    %{
      command_type: "DecideGoalOutcome",
      command_version: "1.7.0",
      command_iri: command,
      principal_iri: attributes[:principal_iri],
      actor_iri: decision.actor_iri,
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: decision.scope_iri,
      idempotency_key: command,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: attributes[:expected_graph_revisions],
      reason: attributes[:reason],
      payload: %{
        changes: targets,
        guards: guards(decision, attributes),
        decision_iri: decision.iri,
        outcome_stage: decision.outcome_stage,
        direct_side_effects: []
      }
    }
  end

  defp guards(decision, attributes) do
    first_task = List.first(decision.task_transitions)
    first_goal = List.first(decision.goal_transitions)

    first_related =
      decision.related_transitions
      |> Enum.group_by(& &1.subject_iri)
      |> Enum.map(fn {_subject, transitions} -> List.first(transitions) end)

    [
      {:subject_absent, attributes.evidence_graph_iri, decision.iri},
      {:subject_present, attributes.policy_graph_iri, decision.policy_iri}
    ] ++
      Enum.map(decision.evidence_bundles, fn bundle ->
        {:subject_present, attributes.evidence_graph_iri, bundle.iri}
      end) ++
      transition_guard(first_task, attributes.control_graph_iri) ++
      transition_guard(first_goal, attributes.control_graph_iri) ++
      Enum.flat_map(first_related, &transition_guard(&1, attributes.control_graph_iri)) ++
      Enum.map(decision.confirmation_sources, fn source ->
        {:subject_present, source.graph_iri, source.iri}
      end) ++
      Enum.map(decision.follow_ups, fn follow_up ->
        {:subject_absent, attributes.control_graph_iri, follow_up.iri}
      end)
  end

  defp transition_guard(nil, _graph), do: []

  defp transition_guard(transition, graph) do
    [
      {:transition_endpoint, graph, transition.subject_iri, transition.expected_predecessor}
    ]
  end

  defp identity(assessment, bundles, attributes) do
    material =
      {
        assessment.iri,
        Enum.map(bundles, & &1.iri) |> Enum.sort(),
        attributes[:actor_iri],
        attributes[:goal_iri],
        attributes[:task_iri],
        attributes[:disposition],
        attributes[:mode],
        attributes[:outcome_stage],
        attributes[:risk],
        attributes[:policy_iri],
        attributes[:recorded_at],
        attributes[:valid_from],
        attributes[:valid_to],
        attributes[:supersedes_iri],
        Map.get(attributes, :related_resolutions, [])
        |> Enum.map(& &1[:subject_iri])
        |> Enum.sort()
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:goal_outcome_decision, material)
  end

  defp reconciliation_iri(decision) do
    {:ok, iri} = ResourceIdentity.deterministic(:decision_reconciliation, decision.iri)
    iri
  end

  defp command_iri(decision) do
    {:ok, iri} =
      ResourceIdentity.deterministic(:command_request, decision.iri <> "\ndecide-goal-outcome")

    iri
  end

  defp resources(values, maximum, allow_empty?)
       when is_list(values) and length(values) <= maximum do
    values = values |> Enum.uniq() |> Enum.sort()

    if (allow_empty? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, values},
       else: :error
  end

  defp resources(_values, _maximum, _allow_empty?), do: :error

  defp confirmation_sources(values, confirmation_iris)
       when is_list(values) and length(values) <= 30 do
    valid? =
      Enum.all?(values, fn source ->
        is_map(source) and source[:iri] in confirmation_iris and
          ResourceIdentity.validate(source[:iri]) == :ok and
          match?(
            {:ok, family} when family in [:observation_batch, :source_revision],
            JidoCode.Knowledge.GraphRegistry.identify(source[:graph_iri])
          ) and is_integer(source[:revision]) and source[:revision] > 0
      end)

    if valid? and Enum.sort(Enum.map(values, & &1.iri)) == Enum.sort(confirmation_iris),
      do: {:ok, Enum.sort_by(values, & &1.iri)},
      else: :error
  end

  defp confirmation_sources(_values, _confirmation_iris), do: :error
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, object), do: [{subject, predicate, RDF.iri(object)}]

  defp interval(%DateTime{} = valid_from, %DateTime{} = valid_to) do
    if DateTime.compare(valid_from, valid_to) == :lt,
      do: {:ok, valid_from, valid_to},
      else: :error
  end

  defp interval(_valid_from, _valid_to), do: :error
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

defmodule JidoCode.Knowledge.Decision.FollowUp do
  @moduledoc "Deterministic follow-up work derived from a decision without performing its effect."

  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :goal_iri,
    :task_iri,
    :kind,
    :decision_iri,
    :target_iri,
    :scope_iri,
    :requires_lease?,
    :goal_transition,
    :task_transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @kinds ~w[
    apply_patch open_pull_request update_pull_request request_review remediate_failure
    gather_evidence rollback monitor_outcome
  ]a
  @effectful ~w[apply_patch open_pull_request update_pull_request rollback]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(String.t(), atom(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(decision_iri, kind, attributes) when kind in @kinds and is_map(attributes) do
    with :ok <- ResourceIdentity.validate(decision_iri),
         :ok <- ResourceIdentity.validate(attributes[:target_iri]),
         :ok <- ResourceIdentity.validate(attributes[:scope_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         recorded_at when is_struct(recorded_at, DateTime) <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :decision_follow_up,
             Enum.join([decision_iri, Atom.to_string(kind), attributes.target_iri], "\n")
           ),
         {:ok, goal_iri} <- ResourceIdentity.deterministic(:follow_up_goal, iri),
         {:ok, task_iri} <- ResourceIdentity.deterministic(:follow_up_task, iri),
         {:ok, goal_transition} <- initial_transition(:goal, goal_iri, decision_iri, attributes),
         {:ok, task_transition} <- initial_transition(:task, task_iri, decision_iri, attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         goal_iri: goal_iri,
         task_iri: task_iri,
         kind: kind,
         decision_iri: decision_iri,
         target_iri: attributes.target_iri,
         scope_iri: attributes.scope_iri,
         requires_lease?: kind in @effectful,
         goal_transition: goal_transition,
         task_transition: task_transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:decision_follow_up)
    end
  rescue
    _error -> invalid(:decision_follow_up)
  end

  def new(_decision_iri, _kind, _attributes), do: invalid(:decision_follow_up)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = follow_up) do
    [
      {follow_up.iri, @rdf_type, RDF.iri(@jf <> "DecisionFollowUp")},
      {follow_up.iri, @jf <> "causedBy", RDF.iri(follow_up.decision_iri)},
      {follow_up.iri, @jf <> "about", RDF.iri(follow_up.target_iri)},
      {follow_up.iri, @jf <> "validFor", RDF.iri(follow_up.scope_iri)},
      {follow_up.iri, @jf <> "followUpKind",
       RDF.iri(@concept <> Macro.camelize(to_string(follow_up.kind)))},
      {follow_up.iri, @jf <> "followUpGoal", RDF.iri(follow_up.goal_iri)},
      {follow_up.iri, @jf <> "followUpTask", RDF.iri(follow_up.task_iri)},
      {follow_up.iri, @jf <> "requiresLease", RDF.XSD.Boolean.new(follow_up.requires_lease?)},
      {follow_up.goal_iri, @rdf_type, RDF.iri(@jf <> "Goal")},
      {follow_up.goal_iri, @jf <> "causedBy", RDF.iri(follow_up.decision_iri)},
      {follow_up.goal_iri, @jf <> "addresses", RDF.iri(follow_up.target_iri)},
      {follow_up.goal_iri, @jf <> "decomposesInto", RDF.iri(follow_up.task_iri)},
      {follow_up.task_iri, @rdf_type, RDF.iri(@jf <> "Task")},
      {follow_up.task_iri, @jf <> "causedBy", RDF.iri(follow_up.decision_iri)},
      {follow_up.task_iri, @jf <> "requiresLease", RDF.XSD.Boolean.new(follow_up.requires_lease?)}
    ] ++
      Transition.statements(follow_up.goal_transition) ++
      Transition.statements(follow_up.task_transition)
  end

  defp initial_transition(domain, subject, decision, attributes) do
    Transition.new(%{
      subject_iri: subject,
      domain: domain,
      prior_state: nil,
      next_state: :proposed,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes.actor_iri,
      cause_iri: decision,
      reason: "derive #{attributes[:reason_label]} follow-up work",
      recorded_at: attributes.recorded_at
    })
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

defmodule JidoCode.Knowledge.Control.Transition do
  @moduledoc """
  Domain-specific accepted transition chains for desired outcomes and work.

  The returned struct is a transient command-building value. Durable state is
  always resolved from transition and decision RDF in the control graph.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :decision_iri,
    :subject_iri,
    :domain,
    :prior_state,
    :next_state,
    :revision,
    :expected_predecessor,
    :actor_iri,
    :cause_iri,
    :reason,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type domain :: :desired_outcome | :goal | :plan | :task
  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @states %{
    desired_outcome: ~w[proposed active suspended satisfied waived superseded retired]a,
    goal:
      ~w[proposed approved eligible blocked leased executing awaiting_evidence awaiting_decision satisfied rejected cancelled superseded]a,
    plan: ~w[proposed approved stale rejected superseded retired]a,
    task:
      ~w[proposed approved eligible blocked leased executing awaiting_evidence awaiting_decision satisfied rejected cancelled superseded]a
  }

  @edges %{
    desired_outcome: %{
      proposed: ~w[active suspended waived superseded retired]a,
      active: ~w[suspended satisfied waived superseded retired]a,
      suspended: ~w[active waived superseded retired]a,
      satisfied: ~w[superseded retired]a,
      waived: ~w[superseded retired]a,
      superseded: [:retired],
      retired: []
    },
    goal: %{
      proposed: ~w[approved rejected cancelled superseded]a,
      approved: ~w[eligible blocked cancelled superseded]a,
      eligible: ~w[blocked leased executing cancelled superseded]a,
      blocked: ~w[eligible cancelled superseded]a,
      leased: ~w[eligible executing cancelled superseded]a,
      executing: ~w[awaiting_evidence awaiting_decision blocked cancelled superseded]a,
      awaiting_evidence: ~w[awaiting_decision executing blocked cancelled superseded]a,
      awaiting_decision: ~w[satisfied rejected executing cancelled superseded]a,
      satisfied: [:superseded],
      rejected: [:superseded],
      cancelled: [:superseded],
      superseded: []
    },
    plan: %{
      proposed: ~w[approved rejected superseded]a,
      approved: ~w[stale superseded retired]a,
      stale: ~w[superseded retired]a,
      rejected: [:superseded],
      superseded: [:retired],
      retired: []
    },
    task: %{
      proposed: ~w[approved rejected cancelled superseded]a,
      approved: ~w[eligible blocked cancelled superseded]a,
      eligible: ~w[blocked leased executing cancelled superseded]a,
      blocked: ~w[eligible cancelled superseded]a,
      leased: ~w[eligible executing cancelled superseded]a,
      executing: ~w[awaiting_evidence awaiting_decision blocked cancelled superseded]a,
      awaiting_evidence: ~w[awaiting_decision executing blocked cancelled superseded]a,
      awaiting_decision: ~w[satisfied rejected executing cancelled superseded]a,
      satisfied: [:superseded],
      rejected: [:superseded],
      cancelled: [:superseded],
      superseded: []
    }
  }

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    domain = attributes[:domain]

    with true <- Map.has_key?(@states, domain),
         :ok <- ResourceIdentity.validate(attributes[:subject_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         true <- valid_reason?(attributes[:reason]),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         :ok <- validate_revision(domain, attributes),
         {:ok, iri} <- transition_identity(attributes),
         {:ok, decision_iri} <-
           ResourceIdentity.deterministic(:control_decision, iri <> "\naccepted") do
      {:ok,
       %__MODULE__{
         iri: iri,
         decision_iri: decision_iri,
         subject_iri: attributes[:subject_iri],
         domain: domain,
         prior_state: attributes[:prior_state],
         next_state: attributes[:next_state],
         revision: attributes[:revision],
         expected_predecessor: attributes[:expected_predecessor],
         actor_iri: attributes[:actor_iri],
         cause_iri: attributes[:cause_iri],
         reason: attributes[:reason],
         recorded_at: DateTime.truncate(recorded_at, :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:control_transition)
    end
  rescue
    _error -> invalid(:control_transition)
  end

  def new(_attributes), do: invalid(:control_transition)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = transition) do
    base = [
      {transition.iri, @rdf_type, RDF.iri(@jf <> "StateTransition")},
      {transition.iri, @jf <> "transitionSubject", RDF.iri(transition.subject_iri)},
      {transition.iri, @jf <> "transitionDomain",
       RDF.iri(@concept <> (transition.domain |> Atom.to_string() |> Macro.camelize()))},
      {transition.iri, @jf <> "nextState",
       RDF.iri(state_iri(transition.domain, transition.next_state))},
      {transition.iri, @jf <> "subjectRevision",
       RDF.XSD.NonNegativeInteger.new(transition.revision)},
      {transition.iri, @prov <> "wasAssociatedWith", RDF.iri(transition.actor_iri)},
      {transition.iri, @jf <> "cause", RDF.iri(transition.cause_iri)},
      {transition.iri, @jf <> "reason", RDF.XSD.String.new(transition.reason)},
      {transition.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(transition.recorded_at)},
      {transition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(transition.recorded_at)},
      {transition.decision_iri, @rdf_type, RDF.iri(@jf <> "Decision")},
      {transition.decision_iri, @jf <> "decisionAuthority", RDF.iri(transition.actor_iri)},
      {transition.decision_iri, @jf <> "accepts", RDF.iri(transition.iri)},
      {transition.decision_iri, @prov <> "generatedAtTime",
       RDF.XSD.DateTime.new(transition.recorded_at)}
    ]

    if transition.revision == 0 do
      base
    else
      [
        {transition.iri, @jf <> "priorState",
         RDF.iri(state_iri(transition.domain, transition.prior_state))},
        {transition.iri, @jf <> "expectedPredecessor", RDF.iri(transition.expected_predecessor)}
        | base
      ]
    end
  end

  @spec guard(t(), String.t()) :: tuple()
  def guard(%__MODULE__{revision: 0} = transition, graph_iri),
    do: {:subject_absent, graph_iri, transition.subject_iri}

  def guard(%__MODULE__{} = transition, graph_iri),
    do: {:transition_endpoint, graph_iri, transition.subject_iri, transition.expected_predecessor}

  @spec resolve([t()]) :: {:ok, map()} | {:error, Error.t()}
  def resolve([%__MODULE__{} | _rest] = transitions) do
    with [subject] <- transitions |> Enum.map(& &1.subject_iri) |> Enum.uniq(),
         [domain] <- transitions |> Enum.map(& &1.domain) |> Enum.uniq(),
         true <- unique_revisions?(transitions),
         ordered <- Enum.sort_by(transitions, & &1.revision),
         :ok <- contiguous?(domain, ordered) do
      endpoint = List.last(ordered)

      {:ok,
       %{
         subject_iri: subject,
         domain: domain,
         current_state: endpoint.next_state,
         current_revision: endpoint.revision,
         current_transition: endpoint.iri,
         history: ordered
       }}
    else
      _invalid -> invalid(:control_transition_chain)
    end
  end

  def resolve(_transitions), do: invalid(:control_transition_chain)

  @spec state_iri(domain(), atom()) :: String.t()
  def state_iri(domain, state) do
    @concept <>
      (domain |> Atom.to_string() |> Macro.camelize()) <>
      (state |> Atom.to_string() |> Macro.camelize())
  end

  @spec state_from_iri(domain(), String.t()) :: {:ok, atom()} | {:error, Error.t()}
  def state_from_iri(domain, iri) do
    case Enum.find(Map.get(@states, domain, []), &(state_iri(domain, &1) == iri)) do
      nil -> invalid(:control_state)
      state -> {:ok, state}
    end
  end

  @spec allowed_edge?(domain(), atom(), atom()) :: boolean()
  def allowed_edge?(domain, prior, next), do: next in get_in(@edges, [domain, prior])

  defp validate_revision(domain, attributes) do
    revision = attributes[:revision]
    prior = attributes[:prior_state]
    next = attributes[:next_state]
    predecessor = attributes[:expected_predecessor]

    cond do
      revision == 0 and is_nil(prior) and next == :proposed and is_nil(predecessor) ->
        :ok

      is_integer(revision) and revision > 0 and prior in Map.fetch!(@states, domain) and
        next in Map.fetch!(@states, domain) and allowed_edge?(domain, prior, next) ->
        ResourceIdentity.validate(predecessor)

      true ->
        invalid(:control_transition_edge)
    end
  end

  defp transition_identity(attributes) do
    ResourceIdentity.deterministic(
      :control_transition,
      Enum.join(
        [
          attributes.subject_iri,
          Atom.to_string(attributes.domain),
          Integer.to_string(attributes.revision),
          Atom.to_string(attributes.next_state)
        ],
        "\n"
      )
    )
  end

  defp contiguous?(domain, [first | rest]) do
    if first.revision == 0 and first.next_state == :proposed do
      Enum.reduce_while(rest, {:ok, first}, fn current, {:ok, prior} ->
        if current.revision == prior.revision + 1 and
             current.expected_predecessor == prior.iri and
             current.prior_state == prior.next_state and
             allowed_edge?(domain, prior.next_state, current.next_state) do
          {:cont, {:ok, current}}
        else
          {:halt, :error}
        end
      end)
      |> case do
        {:ok, _endpoint} -> :ok
        :error -> invalid(:control_transition_chain)
      end
    else
      invalid(:control_transition_chain)
    end
  end

  defp unique_revisions?(transitions) do
    revisions = Enum.map(transitions, & &1.revision)
    length(revisions) == length(Enum.uniq(revisions))
  end

  defp valid_reason?(value), do: is_binary(value) and byte_size(value) in 1..512
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

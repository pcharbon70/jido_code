defmodule JidoCode.Knowledge.Repositories.EnrollmentTransition do
  @moduledoc """
  Append-only management-enrollment lifecycle transitions.

  Accepted predecessor links and monotonic subject revisions establish order;
  timestamps are provenance and never resolve competing successors.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :decision_iri,
    :enrollment_iri,
    :prior_state,
    :next_state,
    :revision,
    :expected_predecessor,
    :actor_iri,
    :cause_iri,
    :reason,
    :recorded_at,
    :change_kind
  ]
  defstruct @enforce_keys

  @type state :: :proposed | :active | :suspended | :retiring | :retired | :invalidated
  @type change_kind :: :state | :policy_reassignment | :locator_change
  @type t :: %__MODULE__{}

  @states ~w[proposed active suspended retiring retired invalidated]a
  @change_kinds ~w[state policy_reassignment locator_change]a
  @edges %{
    proposed: [:active, :retired, :invalidated],
    active: [:suspended, :retiring, :invalidated],
    suspended: [:active, :retiring, :invalidated],
    retiring: [:retired, :invalidated],
    retired: [],
    invalidated: []
  }
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    change_kind = Map.get(attributes, :change_kind, :state)

    with :ok <- ResourceIdentity.validate(attributes[:enrollment_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         true <- attributes[:prior_state] in [nil | @states],
         true <- attributes[:next_state] in @states,
         true <- change_kind in @change_kinds,
         true <- valid_revision?(attributes, change_kind),
         true <- valid_reason?(attributes[:reason]),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.enrollment_transition(
             attributes[:enrollment_iri],
             attributes[:revision],
             attributes[:next_state]
           ),
         {:ok, decision_iri} <-
           ResourceIdentity.deterministic(:enrollment_decision, iri <> "\naccepted") do
      {:ok,
       %__MODULE__{
         iri: iri,
         decision_iri: decision_iri,
         enrollment_iri: attributes[:enrollment_iri],
         prior_state: attributes[:prior_state],
         next_state: attributes[:next_state],
         revision: attributes[:revision],
         expected_predecessor: attributes[:expected_predecessor],
         actor_iri: attributes[:actor_iri],
         cause_iri: attributes[:cause_iri],
         reason: attributes[:reason],
         recorded_at: DateTime.truncate(recorded_at, :microsecond),
         change_kind: change_kind
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enrollment_transition)
    end
  rescue
    _error -> invalid(:enrollment_transition)
  end

  def new(_attributes), do: invalid(:enrollment_transition)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = transition) do
    base = [
      {transition.iri, @rdf_type, RDF.iri(@prov <> "Activity")},
      {transition.iri, @jf <> "transitionSubject", RDF.iri(transition.enrollment_iri)},
      {transition.iri, @jf <> "nextState", RDF.iri(state_iri(transition.next_state))},
      {transition.iri, @jf <> "subjectRevision",
       RDF.XSD.NonNegativeInteger.new(transition.revision)},
      {transition.iri, @prov <> "wasAssociatedWith", RDF.iri(transition.actor_iri)},
      {transition.iri, @jf <> "cause", RDF.iri(transition.cause_iri)},
      {transition.iri, @jf <> "reason", RDF.literal(transition.reason)},
      {transition.iri, @jf <> "transitionKind",
       RDF.XSD.String.new(Atom.to_string(transition.change_kind))},
      {transition.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(transition.recorded_at)},
      {transition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(transition.recorded_at)},
      {transition.decision_iri, @rdf_type, RDF.iri(@prov <> "Activity")},
      {transition.decision_iri, @jf <> "decisionAuthority", RDF.iri(transition.actor_iri)},
      {transition.decision_iri, @jf <> "accepts", RDF.iri(transition.iri)},
      {transition.decision_iri, @prov <> "generatedAtTime",
       RDF.XSD.DateTime.new(transition.recorded_at)}
    ]

    if transition.revision == 0 do
      base
    else
      [
        {transition.iri, @jf <> "priorState", RDF.iri(state_iri(transition.prior_state))},
        {transition.iri, @jf <> "expectedPredecessor", RDF.iri(transition.expected_predecessor)}
        | base
      ]
    end
  end

  @spec resolve([t()]) :: {:ok, map()} | {:error, Error.t()}
  def resolve(transitions) when is_list(transitions) and transitions != [] do
    with true <- Enum.all?(transitions, &match?(%__MODULE__{}, &1)),
         [enrollment_iri] <- transitions |> Enum.map(& &1.enrollment_iri) |> Enum.uniq(),
         true <- unique_revisions?(transitions),
         ordered <- Enum.sort_by(transitions, & &1.revision),
         :ok <- contiguous_chain(ordered) do
      endpoint = List.last(ordered)

      {:ok,
       %{
         enrollment_iri: enrollment_iri,
         current_state: endpoint.next_state,
         current_revision: endpoint.revision,
         current_transition: endpoint.iri,
         admission: admission(endpoint.next_state),
         history: ordered
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enrollment_transition_chain)
    end
  end

  def resolve(_transitions), do: invalid(:enrollment_transition_chain)

  @spec admission(state()) :: :allowed | {:blocked, state()}
  def admission(:active), do: :allowed
  def admission(state) when state in @states, do: {:blocked, state}

  @spec state_iri(state()) :: String.t()
  def state_iri(state) when state in @states do
    @concept <> "Enrollment" <> (state |> Atom.to_string() |> Macro.camelize())
  end

  @spec state_from_iri(String.t()) :: {:ok, state()} | {:error, Error.t()}
  def state_from_iri(iri) when is_binary(iri) do
    case Enum.find(@states, &(state_iri(&1) == iri)) do
      nil -> invalid(:enrollment_state)
      state -> {:ok, state}
    end
  end

  def state_from_iri(_iri), do: invalid(:enrollment_state)

  defp valid_revision?(
         %{revision: 0, prior_state: nil, next_state: :proposed, expected_predecessor: nil},
         :state
       ),
       do: true

  defp valid_revision?(attributes, change_kind)
       when is_integer(attributes.revision) and attributes.revision > 0 do
    with :ok <- ResourceIdentity.validate(attributes[:expected_predecessor]),
         prior when prior in @states <- attributes[:prior_state],
         next when next in @states <- attributes[:next_state] do
      next in Map.fetch!(@edges, prior) or
        (change_kind in [:policy_reassignment, :locator_change] and next == prior and
           prior in [:active, :suspended])
    else
      _invalid -> false
    end
  end

  defp valid_revision?(_attributes, _change_kind), do: false

  defp valid_reason?(value), do: is_binary(value) and byte_size(value) in 1..512

  defp unique_revisions?(transitions) do
    revisions = Enum.map(transitions, & &1.revision)
    length(revisions) == length(Enum.uniq(revisions))
  end

  defp contiguous_chain([first | rest]) do
    with true <- first.revision == 0,
         true <- first.prior_state == nil,
         true <- first.next_state == :proposed do
      Enum.reduce_while(rest, {:ok, first}, fn transition, {:ok, previous} ->
        if transition.revision == previous.revision + 1 and
             transition.expected_predecessor == previous.iri and
             transition.prior_state == previous.next_state and
             valid_edge?(transition) do
          {:cont, {:ok, transition}}
        else
          {:halt, invalid(:enrollment_transition_chain)}
        end
      end)
      |> case do
        {:ok, _endpoint} -> :ok
        error -> error
      end
    else
      _invalid -> invalid(:enrollment_transition_chain)
    end
  end

  defp valid_edge?(transition) do
    transition.next_state in Map.fetch!(@edges, transition.prior_state) or
      (transition.change_kind in [:policy_reassignment, :locator_change] and
         transition.next_state == transition.prior_state and
         transition.prior_state in [:active, :suspended])
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

defmodule JidoCode.Knowledge.Memory.ExperienceTransition do
  @moduledoc "Immutable append-only lifecycle transition for an experience case."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :case_iri,
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

  @states ~w[candidate validated stale invalidated superseded]a
  @edges %{
    candidate: ~w[validated stale invalidated superseded]a,
    validated: ~w[stale invalidated superseded]a,
    stale: ~w[validated invalidated superseded]a,
    invalidated: [],
    superseded: []
  }
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec states() :: [atom()]
  def states, do: @states

  @spec new(map()) :: {:ok, struct()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    revision = attributes[:revision]
    prior = attributes[:prior_state]
    next = attributes[:next_state]

    with :ok <- ResourceIdentity.validate(attributes[:case_iri]),
         true <- next in @states,
         true <- valid_edge?(revision, prior, next, attributes[:expected_predecessor]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         reason when is_binary(reason) and byte_size(reason) in 1..512 <- attributes[:reason],
         true <- safe_text?(reason),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <- identity(attributes) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         case_iri: attributes.case_iri,
         prior_state: prior,
         next_state: next,
         revision: revision,
         expected_predecessor: attributes[:expected_predecessor],
         actor_iri: attributes.actor_iri,
         cause_iri: attributes.cause_iri,
         reason: reason,
         recorded_at: DateTime.truncate(recorded_at, :microsecond)
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:experience_transition)
    end
  rescue
    _error -> invalid(:experience_transition)
  end

  def new(_attributes), do: invalid(:experience_transition)

  @spec resolve([struct()]) :: {:ok, map()} | {:error, Error.t()}
  def resolve([%__MODULE__{} | _rest] = transitions) do
    ordered = Enum.sort_by(transitions, & &1.revision)

    with [case_iri] <- Enum.uniq(Enum.map(ordered, & &1.case_iri)),
         true <- Enum.map(ordered, & &1.revision) == Enum.to_list(0..(length(ordered) - 1)),
         true <- contiguous?(ordered) do
      endpoint = List.last(ordered)

      {:ok,
       %{
         case_iri: case_iri,
         state: endpoint.next_state,
         revision: endpoint.revision,
         transition_iri: endpoint.iri,
         history: ordered
       }}
    else
      _invalid -> invalid(:experience_transition_chain)
    end
  end

  def resolve(_transitions), do: invalid(:experience_transition_chain)

  @spec statements(struct()) :: [tuple()]
  def statements(%__MODULE__{} = transition) do
    [
      {transition.iri, @rdf_type, RDF.iri(@jf <> "ExperienceCaseTransition")},
      {transition.iri, @jf <> "transitionSubject", RDF.iri(transition.case_iri)},
      {transition.iri, @jf <> "nextState", state_iri(transition.next_state)},
      {transition.iri, @jf <> "subjectRevision",
       RDF.XSD.NonNegativeInteger.new(transition.revision)},
      {transition.iri, @prov <> "wasAssociatedWith", RDF.iri(transition.actor_iri)},
      {transition.iri, @jf <> "cause", RDF.iri(transition.cause_iri)},
      {transition.iri, @jf <> "reason", RDF.XSD.String.new(transition.reason)},
      {transition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(transition.recorded_at)}
    ] ++
      optional_state(transition) ++ optional_predecessor(transition)
  end

  @spec state_iri(atom()) :: RDF.IRI.t()
  def state_iri(state), do: RDF.iri(@concept <> "Experience" <> Macro.camelize(to_string(state)))

  defp valid_edge?(0, nil, :candidate, nil), do: true

  defp valid_edge?(revision, prior, next, predecessor)
       when is_integer(revision) and revision > 0 and prior in @states and next in @states do
    next in Map.fetch!(@edges, prior) and ResourceIdentity.validate(predecessor) == :ok
  end

  defp valid_edge?(_revision, _prior, _next, _predecessor), do: false

  defp contiguous?([first | rest]) do
    first.revision == 0 and
      Enum.reduce_while(rest, first, fn transition, previous ->
        if transition.prior_state == previous.next_state and
             transition.expected_predecessor == previous.iri do
          {:cont, transition}
        else
          {:halt, false}
        end
      end) != false
  end

  defp identity(attributes) do
    ResourceIdentity.deterministic(
      :experience_transition,
      :erlang.term_to_binary(
        {
          attributes[:case_iri],
          attributes[:revision],
          attributes[:prior_state],
          attributes[:next_state],
          attributes[:expected_predecessor],
          attributes[:actor_iri],
          attributes[:cause_iri],
          attributes[:reason],
          DateTime.to_iso8601(attributes[:recorded_at])
        },
        [:deterministic]
      )
    )
  end

  defp optional_state(%{prior_state: nil}), do: []

  defp optional_state(transition),
    do: [{transition.iri, @jf <> "priorState", state_iri(transition.prior_state)}]

  defp optional_predecessor(%{expected_predecessor: nil}), do: []

  defp optional_predecessor(transition),
    do: [
      {transition.iri, @jf <> "expectedPredecessor", RDF.iri(transition.expected_predecessor)}
    ]

  defp safe_text?(value), do: not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

defmodule JidoCode.Knowledge.Memory.StateTransition do
  @moduledoc "Immutable lifecycle transitions for durable knowledge assertions."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :subject_iri,
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

  @type state ::
          :still_valid | :under_review | :contradicted | :invalidated | :expired | :superseded
  @type t :: %__MODULE__{}

  @states ~w[still_valid under_review contradicted invalidated expired superseded]a
  @edges %{
    still_valid: ~w[under_review contradicted invalidated expired superseded]a,
    under_review: ~w[still_valid contradicted invalidated expired superseded]a,
    contradicted: ~w[under_review still_valid invalidated expired superseded]a,
    invalidated: [],
    expired: [:superseded],
    superseded: []
  }
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    revision = attributes[:revision]
    prior = attributes[:prior_state]
    next = attributes[:next_state]

    with :ok <- ResourceIdentity.validate(attributes[:subject_iri]),
         true <- next in @states,
         true <- valid_revision?(revision, prior, next, attributes[:expected_predecessor]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         reason when is_binary(reason) and byte_size(reason) in 1..240 <- attributes[:reason],
         recorded_at when is_struct(recorded_at, DateTime) <- attributes[:recorded_at],
         {:ok, iri} <- identity(attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         subject_iri: attributes.subject_iri,
         prior_state: prior,
         next_state: next,
         revision: revision,
         expected_predecessor: attributes[:expected_predecessor],
         actor_iri: attributes.actor_iri,
         cause_iri: attributes.cause_iri,
         reason: reason,
         recorded_at: DateTime.truncate(recorded_at, :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:knowledge_state_transition)
    end
  rescue
    _error -> invalid(:knowledge_state_transition)
  end

  def new(_attributes), do: invalid(:knowledge_state_transition)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(transition) do
    base = [
      {transition.iri, @rdf_type, RDF.iri(@jf <> "KnowledgeStateTransition")},
      {transition.iri, @jf <> "transitionSubject", RDF.iri(transition.subject_iri)},
      {transition.iri, @jf <> "nextState", RDF.iri(state_iri(transition.next_state))},
      {transition.iri, @jf <> "subjectRevision",
       RDF.XSD.NonNegativeInteger.new(transition.revision)},
      {transition.iri, @prov <> "wasAssociatedWith", RDF.iri(transition.actor_iri)},
      {transition.iri, @jf <> "cause", RDF.iri(transition.cause_iri)},
      {transition.iri, @jf <> "reason", RDF.XSD.String.new(transition.reason)},
      {transition.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(transition.recorded_at)},
      {transition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(transition.recorded_at)}
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
  def resolve([%__MODULE__{} | _rest] = transitions) do
    ordered = Enum.sort_by(transitions, & &1.revision)

    with [subject] <- transitions |> Enum.map(& &1.subject_iri) |> Enum.uniq(),
         true <- Enum.map(ordered, & &1.revision) == Enum.to_list(0..(length(ordered) - 1)),
         true <- contiguous?(ordered) do
      endpoint = List.last(ordered)

      {:ok,
       %{
         subject_iri: subject,
         current_state: endpoint.next_state,
         current_revision: endpoint.revision,
         current_transition: endpoint.iri,
         history: ordered
       }}
    else
      _invalid -> invalid(:knowledge_state_transition_chain)
    end
  end

  def resolve(_transitions), do: invalid(:knowledge_state_transition_chain)

  @spec state_iri(state()) :: String.t()
  def state_iri(state), do: @concept <> "Knowledge" <> Macro.camelize(to_string(state))

  @spec states() :: [state()]
  def states, do: @states

  defp valid_revision?(0, nil, :still_valid, nil), do: true

  defp valid_revision?(revision, prior, next, predecessor)
       when is_integer(revision) and revision > 0 and prior in @states and next in @states do
    next in Map.fetch!(@edges, prior) and ResourceIdentity.validate(predecessor) == :ok
  end

  defp valid_revision?(_revision, _prior, _next, _predecessor), do: false

  defp contiguous?([first | rest]) do
    first.revision == 0 and
      Enum.reduce_while(rest, first, fn transition, prior ->
        if transition.revision == prior.revision + 1 and
             transition.prior_state == prior.next_state and
             transition.expected_predecessor == prior.iri,
           do: {:cont, transition},
           else: {:halt, false}
      end) != false
  end

  defp identity(attributes) do
    material =
      Enum.join(
        [
          attributes.subject_iri,
          Integer.to_string(attributes.revision),
          to_string(attributes[:prior_state]),
          to_string(attributes.next_state),
          to_string(attributes[:expected_predecessor]),
          attributes.actor_iri,
          attributes.cause_iri,
          attributes.reason,
          DateTime.to_iso8601(attributes.recorded_at)
        ],
        "\n"
      )

    ResourceIdentity.deterministic(:knowledge_state_transition, material)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

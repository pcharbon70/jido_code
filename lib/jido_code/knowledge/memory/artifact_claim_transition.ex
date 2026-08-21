defmodule JidoCode.Knowledge.Memory.ArtifactClaimTransition do
  @moduledoc "Append-only freshness lifecycle for one artifact-grounded claim."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :claim_iri,
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

  @type t :: %__MODULE__{}
  @states ~w[fresh stale contradicted invalidated superseded]a
  @edges %{
    fresh: ~w[stale contradicted invalidated superseded]a,
    stale: ~w[fresh contradicted invalidated superseded]a,
    contradicted: ~w[fresh invalidated superseded]a,
    invalidated: [],
    superseded: []
  }
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def revision, do: @revision
  def states, do: @states

  def new(attributes) when is_map(attributes) do
    prior = attributes[:prior_state]
    next = attributes[:next_state]
    revision = attributes[:revision]

    with :ok <- ResourceIdentity.validate(attributes[:claim_iri]),
         true <- valid_edge?(revision, prior, next, attributes[:expected_predecessor]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         reason when is_binary(reason) and byte_size(reason) in 1..512 <- attributes[:reason],
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <- identity(attributes) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(attributes, %{
           iri: iri,
           recorded_at: DateTime.truncate(recorded_at, :microsecond)
         })
       )}
    else
      _invalid -> {:error, Error.new(:invalid_input, :artifact_claim_transition)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :artifact_claim_transition)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :artifact_claim_transition)}

  def resolve([%__MODULE__{} | _] = transitions) do
    ordered = Enum.sort_by(transitions, & &1.revision)

    if contiguous?(ordered) do
      endpoint = List.last(ordered)

      {:ok,
       %{
         state: endpoint.next_state,
         revision: endpoint.revision,
         transition_iri: endpoint.iri,
         history: ordered
       }}
    else
      {:error, Error.new(:invalid_input, :artifact_claim_transition_chain)}
    end
  end

  def resolve(_transitions),
    do: {:error, Error.new(:invalid_input, :artifact_claim_transition_chain)}

  def statements(transition) do
    [
      {transition.iri, @rdf_type, RDF.iri(@jf <> "ArtifactClaimTransition")},
      {transition.iri, @jf <> "transitionSubject", RDF.iri(transition.claim_iri)},
      {transition.iri, @jf <> "nextState", state_iri(transition.next_state)},
      {transition.iri, @jf <> "subjectRevision",
       RDF.XSD.NonNegativeInteger.new(transition.revision)},
      {transition.iri, @prov <> "wasAssociatedWith", RDF.iri(transition.actor_iri)},
      {transition.iri, @jf <> "cause", RDF.iri(transition.cause_iri)},
      {transition.iri, @jf <> "reason", RDF.XSD.String.new(transition.reason)},
      {transition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(transition.recorded_at)}
    ] ++ optional(transition)
  end

  defp valid_edge?(0, nil, :fresh, nil), do: true

  defp valid_edge?(revision, prior, next, predecessor) when is_integer(revision) and revision > 0,
    do:
      prior in @states and next in Map.get(@edges, prior, []) and
        ResourceIdentity.validate(predecessor) == :ok

  defp valid_edge?(_, _, _, _), do: false

  defp contiguous?([first | rest]) do
    first.revision == 0 and first.prior_state == nil and
      Enum.reduce_while(rest, first, fn item, prior ->
        if item.claim_iri == prior.claim_iri and item.revision == prior.revision + 1 and
             item.prior_state == prior.next_state and item.expected_predecessor == prior.iri,
           do: {:cont, item},
           else: {:halt, false}
      end) != false
  end

  defp identity(attributes),
    do:
      ResourceIdentity.deterministic(
        :artifact_claim_transition,
        :erlang.term_to_binary(attributes, [:deterministic])
      )

  defp state_iri(state),
    do: RDF.iri(@concept <> "ArtifactClaim" <> Macro.camelize(to_string(state)))

  defp optional(%{prior_state: nil}), do: []

  defp optional(item),
    do: [
      {item.iri, @jf <> "priorState", state_iri(item.prior_state)},
      {item.iri, @jf <> "expectedPredecessor", RDF.iri(item.expected_predecessor)}
    ]
end

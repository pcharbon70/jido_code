defmodule JidoCode.Knowledge.Memory.ContentLifecycleTransition do
  @moduledoc "Append-only exact-content availability and erasure lifecycle."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :content_iri,
    :prior_state,
    :next_state,
    :expected_predecessor,
    :actor_iri,
    :cause_iri,
    :reason,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @contract_revision "1.0.0"
  @states ~w[
    active cold unavailable provider_lost expired_pending erase_requested crypto_erased
    physically_deleted externally_attested externally_unverifiable
  ]a
  @terminal ~w[physically_deleted externally_attested externally_unverifiable]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def contract_revision, do: @contract_revision
  def states, do: @states

  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:content_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         true <- is_integer(attributes[:revision]) and attributes.revision >= 0,
         true <- attributes[:prior_state] in [nil | @states],
         true <- attributes[:next_state] in @states,
         true <- allowed?(attributes[:prior_state], attributes[:next_state]),
         :ok <- predecessor(attributes),
         true <- text?(attributes[:reason], 512),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :content_lifecycle_transition,
             Enum.join(
               [
                 attributes.content_iri,
                 Integer.to_string(attributes.revision),
                 to_string(attributes.next_state)
               ],
               "\n"
             )
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(Map.take(attributes, @enforce_keys), %{iri: iri, recorded_at: recorded_at})
       )}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_lifecycle_transition)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_lifecycle_transition)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :content_lifecycle_transition)}

  def resolve(transitions) when is_list(transitions) and transitions != [] do
    ordered = Enum.sort_by(transitions, & &1.revision)

    with true <- Enum.all?(ordered, &match?(%__MODULE__{}, &1)),
         [first | rest] <- ordered,
         true <- first.revision == 0 and is_nil(first.prior_state),
         true <- chain?(first, rest) do
      {:ok, %{state: List.last(ordered).next_state, transition: List.last(ordered)}}
    else
      _invalid -> {:error, Error.new(:corrupt, :content_lifecycle)}
    end
  end

  def resolve(_transitions), do: {:error, Error.new(:invalid_input, :content_lifecycle)}

  def statements(%__MODULE__{} = transition) do
    [
      {transition.iri, @rdf_type, RDF.iri(@jf <> "ContentLifecycleTransition")},
      {transition.iri, @jf <> "transitionSubject", RDF.iri(transition.content_iri)},
      {transition.iri, @jf <> "nextState",
       RDF.iri(@concept <> Macro.camelize(to_string(transition.next_state)))},
      {transition.iri, @jf <> "subjectRevision",
       RDF.XSD.NonNegativeInteger.new(transition.revision)},
      {transition.iri, @prov <> "wasAssociatedWith", RDF.iri(transition.actor_iri)},
      {transition.iri, @jf <> "cause", RDF.iri(transition.cause_iri)},
      {transition.iri, @jf <> "reason", RDF.XSD.String.new(transition.reason)},
      {transition.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(transition.recorded_at)}
    ] ++ optional_statements(transition)
  end

  defp allowed?(nil, :active), do: true

  defp allowed?(:active, next),
    do: next in ~w[cold unavailable provider_lost expired_pending erase_requested]a

  defp allowed?(:cold, next),
    do: next in ~w[active unavailable provider_lost expired_pending erase_requested]a

  defp allowed?(:unavailable, next),
    do: next in ~w[active erase_requested externally_unverifiable]a

  defp allowed?(:provider_lost, next),
    do: next in ~w[erase_requested externally_attested externally_unverifiable]a

  defp allowed?(:expired_pending, next), do: next in ~w[active erase_requested]a

  defp allowed?(:erase_requested, next),
    do: next in ~w[crypto_erased physically_deleted externally_attested externally_unverifiable]a

  defp allowed?(:crypto_erased, :physically_deleted), do: true
  defp allowed?(prior, _next) when prior in @terminal, do: false
  defp allowed?(_prior, _next), do: false

  defp predecessor(%{revision: 0, expected_predecessor: nil}), do: :ok

  defp predecessor(%{revision: revision, expected_predecessor: predecessor}) when revision > 0,
    do: ResourceIdentity.validate(predecessor)

  defp predecessor(_attributes), do: :error

  defp chain?(_previous, []), do: true

  defp chain?(previous, [current | rest]) do
    current.revision == previous.revision + 1 and
      current.prior_state == previous.next_state and
      current.expected_predecessor == previous.iri and
      allowed?(current.prior_state, current.next_state) and chain?(current, rest)
  end

  defp optional_statements(transition) do
    prior =
      if transition.prior_state,
        do: [
          {transition.iri, @jf <> "priorState",
           RDF.iri(@concept <> Macro.camelize(to_string(transition.prior_state)))}
        ],
        else: []

    predecessor =
      if transition.expected_predecessor,
        do: [
          {transition.iri, @jf <> "expectedPredecessor", RDF.iri(transition.expected_predecessor)}
        ],
        else: []

    prior ++ predecessor
  end

  defp text?(value, max), do: is_binary(value) and byte_size(value) in 1..max
end

defmodule JidoCode.Knowledge.Transitions do
  @moduledoc """
  Compiles state-transition proposals and validates accepted causal chains.

  A transition is accepted only through an explicit Decision relationship.
  Revisions and predecessor links establish order; timestamps never break ties.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Temporal

  @jf "https://jido.run/ontology/factory#"
  @jfc "https://jido.run/ontology/concept/"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_generated_at "http://www.w3.org/ns/prov#generatedAtTime"
  @states ~w[proposed eligible leased running verifying satisfied failed cancelled superseded]a
  @state_locals %{
    proposed: "Proposed",
    eligible: "Eligible",
    leased: "Leased",
    running: "Running",
    verifying: "Verifying",
    satisfied: "Satisfied",
    failed: "Failed",
    cancelled: "Cancelled",
    superseded: "Superseded"
  }
  @edges %{
    proposed: [:eligible, :cancelled, :superseded],
    eligible: [:leased, :cancelled, :superseded],
    leased: [:eligible, :running, :cancelled, :superseded],
    running: [:verifying, :failed, :cancelled, :superseded],
    verifying: [:running, :satisfied, :failed, :cancelled, :superseded],
    satisfied: [:superseded],
    failed: [:superseded],
    cancelled: [:superseded],
    superseded: []
  }
  @required [
    :transition_iri,
    :subject,
    :next_state,
    :revision,
    :actor,
    :cause,
    :reason,
    :generated_at,
    :recorded_at
  ]
  @max_transitions 10_000
  @max_reason_bytes 512

  @spec proposal(map()) :: {:ok, map()} | {:error, Error.t()}
  def proposal(attributes) when is_map(attributes) do
    with true <- Enum.all?(@required, &Map.has_key?(attributes, &1)),
         :ok <- validate_proposal(attributes) do
      projection =
        attributes
        |> Map.take(@required ++ [:prior_state, :expected_predecessor, :fencing_token])
        |> Map.put_new(:prior_state, nil)
        |> Map.put_new(:expected_predecessor, nil)
        |> Map.put_new(:fencing_token, nil)
        |> Map.put(:disposition, :proposed)

      {:ok,
       %{
         transition_iri: attributes.transition_iri,
         projection: projection,
         quads: proposal_quads(projection)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :transition_proposal)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :transition_proposal)}
  end

  def proposal(_attributes), do: {:error, Error.new(:invalid_input, :transition_proposal)}

  @spec decide(map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def decide(%{projection: projection}, attributes)
      when is_map(projection) and is_map(attributes) do
    required = [:decision_iri, :authority, :disposition, :decided_at]

    with true <- Enum.all?(required, &Map.has_key?(attributes, &1)),
         true <- attributes.disposition in [:accepted, :rejected, :superseded],
         :ok <- ResourceIdentity.validate(attributes.decision_iri),
         :ok <- ResourceIdentity.validate(attributes.authority),
         true <- match?(%DateTime{}, attributes.decided_at),
         :ok <- validate_superseder(attributes) do
      decided =
        projection
        |> Map.put(:disposition, attributes.disposition)
        |> Map.put(:decision_iri, attributes.decision_iri)

      {:ok,
       %{
         transition_iri: projection.transition_iri,
         projection: decided,
         quads: decision_quads(projection.transition_iri, attributes)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :transition_decision)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :transition_decision)}
  end

  def decide(_proposal, _attributes),
    do: {:error, Error.new(:invalid_input, :transition_decision)}

  @spec validate_chain([map()]) :: {:ok, map()} | {:error, Error.t()}
  def validate_chain(transitions)
      when is_list(transitions) and length(transitions) <= @max_transitions do
    with false <- transitions == [],
         {:ok, projections} <- normalize_projections(transitions),
         :ok <- unique_transition_iris(projections),
         :ok <- one_subject(projections),
         index = Map.new(projections, &{&1.transition_iri, &1}),
         :ok <- validate_predecessors(projections, index),
         {:ok, accepted} <- accepted_chain(projections, index) do
      endpoint = List.last(accepted)

      {:ok,
       %{
         subject: endpoint.subject,
         current_state: endpoint.next_state,
         current_revision: endpoint.revision,
         current_transition: endpoint.transition_iri,
         accepted: accepted,
         retained: Enum.reject(projections, &(&1.disposition == :accepted))
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :transition_chain)}
    end
  end

  def validate_chain(_transitions),
    do: {:error, Error.new(:invalid_input, :transition_chain)}

  @spec allowed_edge?(atom() | nil, atom()) :: boolean()
  def allowed_edge?(nil, :proposed), do: true
  def allowed_edge?(prior, next), do: next in Map.get(@edges, prior, [])

  defp validate_proposal(attributes) do
    with :ok <- ResourceIdentity.validate(attributes.transition_iri),
         :ok <- ResourceIdentity.validate(attributes.subject),
         :ok <- ResourceIdentity.validate(attributes.actor),
         :ok <- ResourceIdentity.validate(attributes.cause),
         true <- attributes.next_state in @states,
         true <- valid_revision?(attributes),
         true <- valid_fencing_token?(Map.get(attributes, :fencing_token)),
         true <- valid_reason?(attributes.reason),
         :ok <- Temporal.validate(attributes) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :transition_proposal)}
    end
  end

  defp valid_revision?(%{revision: 0} = attributes) do
    is_nil(Map.get(attributes, :prior_state)) and
      is_nil(Map.get(attributes, :expected_predecessor)) and attributes.next_state == :proposed
  end

  defp valid_revision?(%{revision: revision} = attributes)
       when is_integer(revision) and revision > 0 do
    Map.get(attributes, :prior_state) in @states and
      ResourceIdentity.validate(Map.get(attributes, :expected_predecessor)) == :ok and
      allowed_edge?(attributes.prior_state, attributes.next_state)
  end

  defp valid_revision?(_attributes), do: false

  defp valid_fencing_token?(nil), do: true
  defp valid_fencing_token?(value), do: is_integer(value) and value >= 0

  defp valid_reason?(value),
    do: is_binary(value) and byte_size(value) > 0 and byte_size(value) <= @max_reason_bytes

  defp validate_superseder(%{disposition: :superseded} = attributes) do
    ResourceIdentity.validate(Map.get(attributes, :superseded_by))
  end

  defp validate_superseder(_attributes), do: :ok

  defp proposal_quads(projection) do
    [
      triple(projection.transition_iri, @rdf_type, iri(@jf <> "StateTransition")),
      triple(projection.transition_iri, @jf <> "transitionSubject", iri(projection.subject)),
      triple(
        projection.transition_iri,
        @jf <> "nextState",
        iri(state_iri(projection.next_state))
      ),
      triple(
        projection.transition_iri,
        @jf <> "subjectRevision",
        RDF.XSD.NonNegativeInteger.new(projection.revision)
      ),
      triple(projection.transition_iri, @prov_associated, iri(projection.actor)),
      triple(projection.transition_iri, @jf <> "cause", iri(projection.cause)),
      triple(projection.transition_iri, @jf <> "reason", RDF.literal(projection.reason)),
      triple(projection.transition_iri, @prov_generated_at, RDF.literal(projection.generated_at)),
      triple(projection.transition_iri, @jf <> "recordedAt", RDF.literal(projection.recorded_at))
    ]
    |> maybe_add_prior(projection)
    |> maybe_add_fencing_token(projection)
  end

  defp maybe_add_prior(quads, %{revision: 0}), do: quads

  defp maybe_add_prior(quads, projection) do
    [
      triple(
        projection.transition_iri,
        @jf <> "priorState",
        iri(state_iri(projection.prior_state))
      ),
      triple(
        projection.transition_iri,
        @jf <> "expectedPredecessor",
        iri(projection.expected_predecessor)
      )
      | quads
    ]
  end

  defp maybe_add_fencing_token(quads, projection) do
    case Map.get(projection, :fencing_token) do
      nil ->
        quads

      token ->
        [
          triple(
            projection.transition_iri,
            @jf <> "fencingToken",
            RDF.XSD.NonNegativeInteger.new(token)
          )
          | quads
        ]
    end
  end

  defp decision_quads(transition_iri, attributes) do
    decision = attributes.decision_iri

    base = [
      triple(decision, @rdf_type, iri(@jf <> "Decision")),
      triple(decision, @jf <> "decisionAuthority", iri(attributes.authority)),
      triple(decision, @prov_generated_at, RDF.literal(attributes.decided_at)),
      triple(decision, disposition_predicate(attributes.disposition), iri(transition_iri))
    ]

    case attributes.disposition do
      :superseded ->
        [triple(attributes.superseded_by, @jf <> "supersedes", iri(transition_iri)) | base]

      _other ->
        base
    end
  end

  defp disposition_predicate(:accepted), do: @jf <> "accepts"
  defp disposition_predicate(:rejected), do: @jf <> "rejects"
  defp disposition_predicate(:superseded), do: @jf <> "rejects"

  defp normalize_projections(transitions) do
    projections =
      Enum.map(transitions, fn
        %{projection: projection} when is_map(projection) -> projection
        projection when is_map(projection) -> projection
        _invalid -> nil
      end)

    if Enum.all?(projections, &valid_projection?/1),
      do: {:ok, projections},
      else: {:error, Error.new(:invalid_input, :transition_chain)}
  end

  defp valid_projection?(projection) do
    is_map(projection) and
      Enum.all?(@required ++ [:disposition], &Map.has_key?(projection, &1)) and
      projection.disposition in [:proposed, :accepted, :rejected, :superseded] and
      validate_proposal(projection) == :ok
  end

  defp unique_transition_iris(projections) do
    if projections |> Enum.map(& &1.transition_iri) |> Enum.uniq() |> length() ==
         length(projections),
       do: :ok,
       else: {:error, Error.new(:conflict, :transition_chain)}
  end

  defp one_subject([first | rest]) do
    if Enum.all?(rest, &(&1.subject == first.subject)),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :transition_chain)}
  end

  defp validate_predecessors(projections, index) do
    Enum.reduce_while(projections, :ok, fn transition, :ok ->
      case validate_predecessor(transition, index) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_predecessor(%{revision: 0, prior_state: nil, expected_predecessor: nil}, _index),
    do: :ok

  defp validate_predecessor(%{revision: revision} = transition, index) when revision > 0 do
    case Map.get(index, transition.expected_predecessor) do
      %{subject: subject, revision: predecessor_revision, next_state: next_state}
      when subject == transition.subject and predecessor_revision + 1 == revision and
             next_state == transition.prior_state ->
        if allowed_edge?(transition.prior_state, transition.next_state),
          do: :ok,
          else: {:error, Error.new(:invalid_input, :transition_chain)}

      _missing_or_invalid ->
        {:error, Error.new(:conflict, :transition_chain)}
    end
  end

  defp validate_predecessor(_transition, _index),
    do: {:error, Error.new(:invalid_input, :transition_chain)}

  defp accepted_chain(projections, index) do
    accepted =
      projections
      |> Enum.filter(&(&1.disposition == :accepted))
      |> Enum.sort_by(& &1.revision)

    revisions = Enum.map(accepted, & &1.revision)

    with [_genesis | _rest] <- accepted,
         true <- revisions == Enum.to_list(0..(length(accepted) - 1)),
         true <- accepted_predecessors?(accepted, index) do
      {:ok, accepted}
    else
      _invalid -> {:error, Error.new(:conflict, :transition_chain)}
    end
  end

  defp accepted_predecessors?([%{revision: 0, next_state: :proposed} | rest], index) do
    Enum.all?(rest, fn transition ->
      case Map.get(index, transition.expected_predecessor) do
        %{disposition: :accepted, revision: revision} -> revision + 1 == transition.revision
        _not_accepted -> false
      end
    end)
  end

  defp accepted_predecessors?(_accepted, _index), do: false

  defp state_iri(state), do: @jfc <> Map.fetch!(@state_locals, state)
  defp triple(subject, predicate, object), do: RDF.triple(subject, predicate, object)
  defp iri(value), do: RDF.iri(value)
end

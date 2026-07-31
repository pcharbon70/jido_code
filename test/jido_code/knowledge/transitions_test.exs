defmodule JidoCode.Knowledge.TransitionsTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Transitions

  setup do
    {:ok, subject} = ResourceIdentity.repository("transition-subject")
    {:ok, other_subject} = ResourceIdentity.repository("other-transition-subject")
    {:ok, actor} = ResourceIdentity.repository("transition-actor")
    {:ok, cause} = ResourceIdentity.local(:goal, 10, <<1::80>>)

    %{subject: subject, other_subject: other_subject, actor: actor, cause: cause}
  end

  test "selects the endpoint of the unique accepted chain and retains losing proposals",
       context do
    genesis = proposal!(context, 20, 0, nil, nil, :proposed)
    accepted = proposal!(context, 21, 1, genesis.transition_iri, :proposed, :eligible)
    rejected = proposal!(context, 22, 1, genesis.transition_iri, :proposed, :cancelled)

    decided_genesis = decide!(genesis, context, 30, :accepted)
    decided_accepted = decide!(accepted, context, 31, :accepted)
    decided_rejected = decide!(rejected, context, 32, :rejected)

    assert {:ok, chain} =
             Transitions.validate_chain([
               decided_rejected.projection,
               decided_accepted.projection,
               decided_genesis.projection
             ])

    assert chain.current_state == :eligible
    assert chain.current_revision == 1
    assert chain.current_transition == accepted.transition_iri
    assert Enum.map(chain.retained, & &1.transition_iri) == [rejected.transition_iri]
  end

  test "rejects illegal edges and missing or cross-subject predecessors", context do
    genesis = proposal!(context, 40, 0, nil, nil, :proposed)

    assert {:error, %Error{operation: :transition_proposal}} =
             Transitions.proposal(
               attributes(context, 41, 1, genesis.transition_iri, :proposed, :running)
             )

    missing = proposal!(context, 42, 1, id!(:transition, 99), :proposed, :eligible)

    assert {:error, %Error{kind: :conflict}} =
             Transitions.validate_chain([
               decide!(genesis, context, 50, :accepted).projection,
               decide!(missing, context, 51, :accepted).projection
             ])

    other_context = %{context | subject: context.other_subject}
    cross_subject = proposal!(other_context, 43, 1, genesis.transition_iri, :proposed, :eligible)

    assert {:error, %Error{operation: :transition_chain}} =
             Transitions.validate_chain([
               decide!(genesis, context, 52, :accepted).projection,
               decide!(cross_subject, other_context, 53, :accepted).projection
             ])
  end

  test "rejects revision gaps and never resolves concurrent acceptance by wall time", context do
    genesis = proposal!(context, 60, 0, nil, nil, :proposed)
    first = proposal!(context, 61, 1, genesis.transition_iri, :proposed, :eligible)
    second = proposal!(context, 62, 1, genesis.transition_iri, :proposed, :cancelled)
    gap = proposal!(context, 63, 2, genesis.transition_iri, :proposed, :eligible)

    accepted_genesis = decide!(genesis, context, 70, :accepted)

    assert {:error, %Error{kind: :conflict}} =
             Transitions.validate_chain([
               accepted_genesis.projection,
               decide!(first, context, 71, :accepted).projection,
               decide!(second, context, 72, :accepted).projection
             ])

    assert {:error, %Error{kind: :conflict}} =
             Transitions.validate_chain([
               accepted_genesis.projection,
               decide!(gap, context, 73, :accepted).projection
             ])
  end

  test "requires explicit decisions and emits revision, fencing, actor, cause, reason, and time",
       context do
    genesis =
      context
      |> attributes(80, 0, nil, nil, :proposed)
      |> Map.put(:fencing_token, 7)

    assert {:ok, proposal} = Transitions.proposal(genesis)
    assert proposal.projection.disposition == :proposed

    assert predicates(proposal.quads)
           |> MapSet.member?("https://jido.run/ontology/factory#fencingToken")

    assert {:error, %Error{operation: :transition_decision}} =
             Transitions.decide(proposal, %{})
  end

  defp proposal!(context, timestamp, revision, predecessor, prior, next) do
    assert {:ok, proposal} =
             Transitions.proposal(
               attributes(context, timestamp, revision, predecessor, prior, next)
             )

    proposal
  end

  defp attributes(context, timestamp, revision, predecessor, prior, next) do
    %{
      transition_iri: id!(:transition, timestamp),
      subject: context.subject,
      prior_state: prior,
      next_state: next,
      expected_predecessor: predecessor,
      revision: revision,
      actor: context.actor,
      cause: context.cause,
      reason: "validated causal transition",
      generated_at: ~U[2026-07-31 12:00:00Z],
      recorded_at: ~U[2026-07-31 12:00:00Z]
    }
  end

  defp decide!(proposal, context, timestamp, disposition) do
    assert {:ok, decided} =
             Transitions.decide(proposal, %{
               decision_iri: id!(:decision, timestamp),
               authority: context.actor,
               disposition: disposition,
               decided_at: ~U[2026-07-31 12:00:00Z]
             })

    decided
  end

  defp id!(kind, timestamp) do
    {:ok, iri} = ResourceIdentity.local(kind, timestamp, <<timestamp::80>>)
    iri
  end

  defp predicates(triples) do
    MapSet.new(triples, fn {_subject, %RDF.IRI{value: predicate}, _object} -> predicate end)
  end
end

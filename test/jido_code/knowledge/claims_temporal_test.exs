defmodule JidoCode.Knowledge.ClaimsTemporalTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Claims
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Temporal

  @jf "https://jido.run/ontology/factory#"

  setup do
    {:ok, repository} = ResourceIdentity.repository("claims-repository")
    {:ok, graph} = GraphRegistry.graph_iri(:evidence, %{repository: repository})
    {:ok, activity} = ResourceIdentity.local(:activity, 100, <<1::80>>)
    {:ok, decision} = ResourceIdentity.local(:decision, 101, <<2::80>>)
    {:ok, decision_authority} = ResourceIdentity.repository("claim-decision-authority")

    %{
      repository: repository,
      graph: graph,
      activity: activity,
      decision: decision,
      decision_authority: decision_authority
    }
  end

  test "uses graph-level provenance only for uncomplicated immutable statements" do
    immutable = %{
      family: :source_revision,
      lifecycle_state: :closed,
      completeness_state: :complete
    }

    mutable = %{family: :evidence, lifecycle_state: :open, completeness_state: :complete}

    assert {:ok, :direct} = Claims.representation(immutable, %{})
    assert {:ok, :claim} = Claims.representation(immutable, %{disputable?: true})

    assert {:ok, :claim} =
             Claims.representation(immutable, %{valid_from: ~U[2026-01-01 00:00:00Z]})

    assert {:ok, :claim} = Claims.representation(mutable, %{})
  end

  test "compiles a first-class claim and requires a decision for acceptance", context do
    {:ok, claim_iri} = ResourceIdentity.local(:claim, 102, <<3::80>>)

    attributes =
      claim_attributes(context, claim_iri, :accepted)
      |> Map.put(:confidence_value, 0.99)
      |> Map.put(:confidence_band, :high)

    assert {:error, %Error{operation: :claim_decision}} = Claims.build(attributes)

    decided =
      Map.merge(attributes, %{
        decision: context.decision,
        decision_authority: context.decision_authority,
        decision_at: ~U[2026-07-31 12:00:00Z]
      })

    assert {:ok, built} = Claims.build(decided)
    assert built.projection.epistemic_state == :accepted
    assert built.projection.confidence_value == 0.99
    assert has_predicate?(built.quads, @jf <> "accepts")
    assert has_predicate?(built.quads, @jf <> "recordedAt")
    assert has_predicate?(built.quads, @jf <> "confidenceBand")
    assert has_predicate?(built.quads, @jf <> "decisionAuthority")
  end

  test "confidence does not promote a proposal and conflicting claims are preserved", context do
    {:ok, first_iri} = ResourceIdentity.local(:claim, 103, <<4::80>>)
    {:ok, second_iri} = ResourceIdentity.local(:claim, 104, <<5::80>>)

    {:ok, first} =
      context
      |> claim_attributes(first_iri, :proposed)
      |> Map.put(:confidence_value, 1.0)
      |> Claims.build()

    {:ok, second} =
      context
      |> claim_attributes(second_iri, :contradicted)
      |> Map.put(:contradicts, [first_iri])
      |> Claims.build()

    assert first.projection.epistemic_state == :proposed
    assert second.projection.epistemic_state == :contradicted
    assert has_object?(second.quads, first_iri)
    assert length(first.quads ++ second.quads) == length(first.quads) + length(second.quads)
  end

  test "queries transaction time separately from valid time", context do
    {:ok, old_iri} = ResourceIdentity.local(:claim, 105, <<6::80>>)
    {:ok, correction_iri} = ResourceIdentity.local(:claim, 106, <<7::80>>)
    {:ok, policy_iri} = ResourceIdentity.local(:claim, 107, <<8::80>>)

    {:ok, old} =
      context
      |> claim_attributes(old_iri, :observed)
      |> Map.merge(%{
        source_observed_at: ~U[2026-06-01 08:00:00Z],
        recorded_at: ~U[2026-06-03 10:00:00Z],
        valid_from: ~U[2026-06-01 08:00:00Z],
        invalidated_at: ~U[2026-06-04 12:00:00Z]
      })
      |> Claims.build()

    {:ok, correction} =
      context
      |> claim_attributes(correction_iri, :asserted)
      |> Map.merge(%{
        recorded_at: ~U[2026-06-04 12:00:00Z],
        valid_from: ~U[2026-06-01 08:00:00Z],
        supersedes: [old_iri]
      })
      |> Claims.build()

    {:ok, policy} =
      context
      |> claim_attributes(policy_iri, :asserted)
      |> Map.merge(%{
        recorded_at: ~U[2026-06-02 00:00:00Z],
        valid_from: ~U[2026-06-10 00:00:00Z]
      })
      |> Claims.build()

    claims = [old.projection, correction.projection, policy.projection]
    valid_point = ~U[2026-06-01 09:00:00Z]

    assert Temporal.status_at(old.projection, valid_point, ~U[2026-06-02 00:00:00Z]) == :unknown
    assert Temporal.status_at(old.projection, valid_point, ~U[2026-06-03 12:00:00Z]) == :valid

    assert Temporal.status_at(old.projection, valid_point, ~U[2026-06-05 00:00:00Z]) ==
             :superseded

    assert Temporal.status_at(correction.projection, valid_point, ~U[2026-06-05 00:00:00Z]) ==
             :valid

    assert Temporal.status_at(
             policy.projection,
             ~U[2026-06-05 00:00:00Z],
             ~U[2026-06-05 00:00:00Z]
           ) ==
             :recorded

    assert {:ok, valid_claims} =
             Temporal.query(claims, %{
               valid_at: valid_point,
               recorded_as_of: ~U[2026-06-05 00:00:00Z],
               status: :valid,
               limit: 10
             })

    assert Enum.map(valid_claims, & &1.claim_iri) == [correction_iri]
  end

  test "rejects inverted validity and future source-observation times", context do
    {:ok, claim_iri} = ResourceIdentity.local(:claim, 108, <<9::80>>)

    inverted =
      context
      |> claim_attributes(claim_iri, :observed)
      |> Map.put(:valid_from, ~U[2026-07-02 00:00:00Z])
      |> Map.put(:valid_to, ~U[2026-07-01 00:00:00Z])

    assert {:error, %Error{operation: :temporal_contract}} = Claims.build(inverted)

    future_observation =
      context
      |> claim_attributes(claim_iri, :observed)
      |> Map.put(:source_observed_at, ~U[2026-08-01 00:00:00Z])

    assert {:error, %Error{operation: :temporal_contract}} = Claims.build(future_observation)

    assert {:error, %Error{operation: :temporal_query}} =
             Temporal.query([%{}], %{
               valid_at: ~U[2026-07-31 00:00:00Z],
               recorded_as_of: ~U[2026-07-31 00:00:00Z]
             })
  end

  defp claim_attributes(context, claim_iri, state) do
    %{
      claim_iri: claim_iri,
      graph_iri: context.graph,
      subject: context.repository,
      predicate: @jf <> "governedBy",
      object: RDF.iri("https://jido.run/id/policy/factory"),
      source_activity: context.activity,
      epistemic_state: state,
      recorded_at: ~U[2026-07-31 12:00:00Z]
    }
  end

  defp has_predicate?(triples, predicate) do
    Enum.any?(triples, fn {_subject, %RDF.IRI{value: value}, _object} -> value == predicate end)
  end

  defp has_object?(triples, object) do
    Enum.any?(triples, fn
      {_subject, _predicate, %RDF.IRI{value: value}} -> value == object
      _other -> false
    end)
  end
end

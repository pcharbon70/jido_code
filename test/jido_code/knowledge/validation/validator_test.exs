defmodule JidoCode.Knowledge.Validation.ValidatorTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Validation.Validator

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @rdf_predicate "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"
  @rdf_object "http://www.w3.org/1999/02/22-rdf-syntax-ns#object"

  setup do
    {:ok, repository} = ResourceIdentity.repository("validator-repository")
    {:ok, graph} = GraphRegistry.graph_iri(:evidence, %{repository: repository})
    {:ok, owner_scope} = ResourceIdentity.scope(:repository, "validator-repository")
    {:ok, activity} = ResourceIdentity.local(:activity, 100, <<1::80>>)
    {:ok, claim} = ResourceIdentity.local(:claim, 101, <<2::80>>)

    {:ok, metadata} =
      GraphMetadata.new(graph, %{
        owner_scope: owner_scope,
        ontology_version: "https://jido.run/ontology/release/1.0.0",
        creation_activity: activity,
        created_at: ~U[2026-07-31 12:00:00Z],
        lifecycle_state: :open,
        completeness_state: :complete
      })

    {:ok, metadata_quads} = GraphMetadata.quads(metadata)

    %{
      repository: repository,
      graph: graph,
      activity: activity,
      claim: claim,
      metadata: metadata,
      metadata_quads: metadata_quads
    }
  end

  test "admits a complete claim against the effective dataset", context do
    claim_quads = claim_quads(context)
    change = change(context, context.metadata_quads ++ claim_quads)

    assert {:ok, report} = Validator.validate(change)
    assert report.conforms?
    assert report.issue_count == 0
    assert report.validator_version == "1.0.0"

    split = length(claim_quads) - 1
    {existing, proposed} = Enum.split(claim_quads, split)

    effective_change =
      change(context, context.metadata_quads ++ proposed)
      |> Map.put(:existing, existing)

    assert {:ok, effective_report} = Validator.validate(effective_change)
    assert effective_report.conforms?
  end

  test "returns stable bounded result resources for shape and controlled-state failures",
       context do
    incomplete =
      claim_quads(context)
      |> Enum.reject(fn {_subject, %RDF.IRI{value: predicate}, _object, _graph} ->
        predicate in [@rdf_object, @jf <> "epistemicState"]
      end)

    change = change(context, context.metadata_quads ++ incomplete)

    assert {:error, %Error{operation: :semantic_validation}, first} = Validator.validate(change)
    assert {:error, %Error{}, second} = Validator.validate(change)
    refute first.conforms?
    assert first.report_iri == second.report_iri
    assert first.issues == second.issues
    assert first.issue_count == 2
    assert Enum.all?(first.issues, &(byte_size(&1.safe_message) <= 160))
    assert Enum.all?(first.issues, &String.starts_with?(&1.result_iri, ResourceIdentity.base()))
  end

  test "rejects wrong graph-family classes, invalid datatypes, and secret-like literals",
       context do
    wrong_class = [quad(context, context.claim, @rdf_type, iri("ExecutionAttempt"))]

    assert {:error, %Error{}, class_report} =
             Validator.validate(change(context, context.metadata_quads ++ wrong_class))

    assert Enum.any?(class_report.issues, &(&1.issue_code == "class_not_allowed"))

    transition = transition_with_string_revision(context)

    assert {:error, %Error{}, datatype_report} =
             Validator.validate(change(context, context.metadata_quads ++ transition))

    assert Enum.any?(datatype_report.issues, &(&1.issue_code == "datatype"))

    secret = [
      quad(context, context.claim, @jf <> "credentialKey", "ghp_abcdefghijklmnopqrstuvwxyz")
    ]

    assert {:error, %Error{}, secret_report} =
             Validator.validate(change(context, context.metadata_quads ++ secret))

    assert Enum.any?(secret_report.issues, &(&1.issue_code == "secret_literal"))
    refute inspect(secret_report) =~ "ghp_abcdefghijklmnopqrstuvwxyz"
  end

  test "fails closed for unknown versions and expired validation deadlines", context do
    unknown =
      context
      |> change(context.metadata_quads ++ claim_quads(context))
      |> Map.put(:shape_version, "9.9.9")

    assert {:error, %Error{}, report} = Validator.validate(unknown)
    assert Enum.any?(report.issues, &(&1.issue_code == "unknown_semantic_version"))

    assert {:error, %Error{kind: :timeout, operation: :semantic_validation}} =
             Validator.validate(change(context, context.metadata_quads),
               deadline_monotonic_ms: System.monotonic_time(:millisecond) - 1
             )
  end

  defp claim_quads(context) do
    [
      quad(context, context.claim, @rdf_type, iri("Claim")),
      quad(context, context.claim, @rdf_subject, RDF.iri(context.repository)),
      quad(context, context.claim, @rdf_predicate, RDF.iri(@jf <> "governedBy")),
      quad(context, context.claim, @rdf_object, RDF.literal("policy applies")),
      quad(context, context.claim, @jf <> "sourceActivity", RDF.iri(context.activity)),
      quad(context, context.claim, @jf <> "graphScope", RDF.iri(context.graph)),
      quad(
        context,
        context.claim,
        @jf <> "epistemicState",
        RDF.iri("https://jido.run/ontology/concept/Observed")
      ),
      quad(context, context.claim, @jf <> "confidenceValue", RDF.XSD.Decimal.new("0.8"))
    ]
  end

  defp transition_with_string_revision(context) do
    {:ok, transition} = ResourceIdentity.local(:transition, 102, <<3::80>>)

    [
      quad(context, transition, @rdf_type, iri("StateTransition")),
      quad(context, transition, @jf <> "transitionSubject", RDF.iri(context.repository)),
      quad(
        context,
        transition,
        @jf <> "nextState",
        RDF.iri("https://jido.run/ontology/concept/Eligible")
      ),
      quad(context, transition, @jf <> "subjectRevision", RDF.literal("1")),
      quad(
        context,
        transition,
        "http://www.w3.org/ns/prov#wasAssociatedWith",
        RDF.iri(context.activity)
      ),
      quad(
        context,
        transition,
        "http://www.w3.org/ns/prov#generatedAtTime",
        RDF.literal(~U[2026-07-31 12:00:00Z])
      )
    ]
  end

  defp change(context, additions) do
    %{
      operation: :create,
      family: :evidence,
      graph_iri: context.graph,
      metadata: context.metadata,
      additions: additions,
      existing: [],
      shape_version: "1.0.0"
    }
  end

  defp quad(context, subject, predicate, object),
    do: RDF.quad(subject, predicate, object, context.graph)

  defp iri(local), do: RDF.iri(@jf <> local)
end

defmodule JidoCode.Knowledge.Ontology.EvaluationGraphOntologyTest do
  use ExUnit.Case, async: true

  @root "priv/ontology/evaluation/1.0.0"
  @jfe "https://jido.run/ontology/evaluation#"
  @jfec "https://jido.run/ontology/evaluation/concept/"
  @jfes "https://jido.run/ontology/evaluation/shapes#"
  @jf "https://jido.run/ontology/factory#"
  @jfc "https://jido.run/ontology/concept/"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdfs_subclass "http://www.w3.org/2000/01/rdf-schema#subClassOf"
  @owl_class "http://www.w3.org/2002/07/owl#Class"
  @owl_object_property "http://www.w3.org/2002/07/owl#ObjectProperty"
  @owl_datatype_property "http://www.w3.org/2002/07/owl#DatatypeProperty"
  @owl_imports "http://www.w3.org/2002/07/owl#imports"
  @sh_target_class "http://www.w3.org/ns/shacl#targetClass"
  @sh_path "http://www.w3.org/ns/shacl#path"
  @sh_property "http://www.w3.org/ns/shacl#property"
  @sh_closed "http://www.w3.org/ns/shacl#closed"
  @sh_sparql "http://www.w3.org/ns/shacl#sparql"
  @sh_select "http://www.w3.org/ns/shacl#select"

  setup_all do
    {:ok, ontology} = RDF.Turtle.read_file(ontology_path("evaluation.ttl"))
    {:ok, shapes} = RDF.Turtle.read_file(ontology_path("shapes.ttl"))

    %{ontology: ontology, shapes: shapes}
  end

  test "is a versioned, blank-node-free module over the immutable factory ontology", %{
    ontology: ontology,
    shapes: shapes
  } do
    refute Enum.any?(RDF.Graph.triples(ontology), &RDF.Triple.has_bnode?/1)
    refute Enum.any?(RDF.Graph.triples(shapes), &RDF.Triple.has_bnode?/1)

    assert statement?(
             ontology,
             "https://jido.run/ontology/evaluation/1.0.0",
             @owl_imports,
             iri("https://jido.run/ontology/factory/1.0.0")
           )

    assert statement?(
             shapes,
             "https://jido.run/ontology/evaluation/shapes/1.0.0",
             @owl_imports,
             iri("https://jido.run/ontology/shapes/1.0.0")
           )
  end

  test "models catalog and run lifecycle boundaries without a graph per trial", %{
    ontology: ontology
  } do
    for graph_class <- ~w[EvaluationCatalogGraph EvaluationRunGraph] do
      assert statement?(
               ontology,
               @jfe <> graph_class,
               @rdfs_subclass,
               iri(@jf <> "NamedGraph")
             )
    end

    refute statement?(
             ontology,
             @jfe <> "EvaluationTrial",
             @rdfs_subclass,
             iri(@jf <> "NamedGraph")
           )

    assert statement?(
             ontology,
             @jfe <> "EvaluationCatalogFamilyContract",
             @jfe <> "familyName",
             RDF.literal("evaluation_catalog")
           )

    assert values(
             ontology,
             @jfe <> "EvaluationCatalogFamilyContract",
             @jfe <> "scopeKey"
           ) == MapSet.new([RDF.literal("catalog"), RDF.literal("revision")])

    assert statement?(
             ontology,
             @jfe <> "EvaluationRunFamilyContract",
             @jfe <> "writerCapabilityName",
             RDF.literal("evaluation_run_writer")
           )

    assert statement?(
             ontology,
             @jfe <> "EvaluationRunFamilyContract",
             @jfe <> "mutability",
             iri(@jfec <> "Closeable")
           )

    assert values(
             ontology,
             @jfe <> "EvaluationCatalogFamilyContract",
             @jfe <> "allowsLinkToGraphKind"
           ) ==
             iri_set([
               @jfc <> "FactoryCatalogGraph",
               @jfc <> "FactoryPolicyGraph",
               @jfc <> "SourceGraph"
             ])

    assert values(
             ontology,
             @jfe <> "EvaluationRunFamilyContract",
             @jfe <> "allowsLinkToGraphKind"
           ) ==
             iri_set([
               @jfec <> "EvaluationCatalogGraph",
               @jfc <> "FactoryPolicyGraph",
               @jfc <> "SourceGraph",
               @jfc <> "RunGraph"
             ])

    refute ontology
           |> objects(@jfe <> "allowedGraphKind")
           |> MapSet.member?(iri(@jfc <> "MemoryGraph"))

    assert statement?(
             ontology,
             @jfe <> "RolloutDecisionPlacement",
             @jfe <> "canonicalGraphKind",
             iri(@jfc <> "EvidenceGraph")
           )
  end

  test "defines the records needed to reconstruct evaluations and decisions", %{
    ontology: ontology,
    shapes: shapes
  } do
    classes = ~w[
      GraphPlacementRule EvaluationProfile EvaluationTarget CorpusRevision EvaluationTask OracleRevision
      RubricRevision VerifierPolicyRevision ReviewerPolicy StatisticalPlan EvaluationTrack
      MetricDefinition ReviewFindingCategory AnalysisClaimType ProtectedArtifactReference
      EvaluationRun EvaluationTrial TrialObservation GraderResult ReviewFinding AnalysisClaim
      HumanGrade Adjudication EvaluatorHealth MetricObservation AggregateResult
      EvaluationEvidenceBundle RolloutDecision ProductionOutcome
    ]

    Enum.each(classes, fn class ->
      assert statement?(ontology, @jfe <> class, @rdf_type, iri(@owl_class)),
             "missing ontology class #{class}"
    end)

    shaped_classes = ~w[
      GraphPlacementRule EvaluationProfile EvaluationTarget CorpusRevision EvaluationTask OracleRevision
      RubricRevision VerifierPolicyRevision ReviewerPolicy StatisticalPlan ProtectedArtifactReference
      EvaluationRun EvaluationTrial TrialObservation GraderResult ReviewFinding AnalysisClaim
      HumanGrade Adjudication EvaluatorHealth MetricObservation AggregateResult
      EvaluationEvidenceBundle RolloutDecision ProductionOutcome
    ]

    targets = objects(shapes, @sh_target_class)

    Enum.each(shaped_classes, fn class ->
      assert MapSet.member?(targets, iri(@jfe <> class)), "missing shape for #{class}"
    end)
  end

  test "declares every evaluation predicate used by its SHACL paths", %{
    ontology: ontology,
    shapes: shapes
  } do
    declared =
      ontology
      |> RDF.Graph.triples()
      |> Enum.reduce(MapSet.new(), fn
        {subject, predicate, object}, acc ->
          if RDF.Term.equal_value?(predicate, iri(@rdf_type)) and
               Enum.any?(
                 [@owl_object_property, @owl_datatype_property],
                 &RDF.Term.equal_value?(object, iri(&1))
               ) do
            MapSet.put(acc, subject)
          else
            acc
          end
      end)

    evaluation_paths =
      shapes
      |> objects(@sh_path)
      |> Enum.filter(fn
        %RDF.IRI{value: @jfe <> _local} -> true
        _term -> false
      end)
      |> MapSet.new()

    assert MapSet.subset?(evaluation_paths, declared)
  end

  test "closes protected references and denies decision authority to measurements", %{
    shapes: shapes
  } do
    assert statement?(
             shapes,
             @jfes <> "ProtectedArtifactReferenceShape",
             @sh_closed,
             RDF.literal(true)
           )

    assert values(
             shapes,
             @jfes <> "ProtectedArtifactReferenceShape",
             @sh_property
           ) ==
             iri_set([
               @jfes <> "ContentDigestProperty",
               @jfes <> "ArtifactRoleProperty",
               @jfes <> "AccessPolicyRevisionProperty"
             ])

    aggregate_properties =
      values(shapes, @jfes <> "AggregateResultShape", @sh_property)

    assert MapSet.subset?(
             iri_set([
               @jfes <> "AggregatesRunProperty",
               @jfes <> "IncludesTrialProperty",
               @jfes <> "AnalysisRevisionProperty",
               @jfes <> "FrozenInclusionDigestProperty",
               @jfes <> "ContainsMetricProperty"
             ]),
             aggregate_properties
           )

    authority_constraint = iri(@jfes <> "NoMeasurementAuthorityConstraint")

    for shape <- ~w[
          GraderResultShape ReviewFindingShape AnalysisClaimShape HumanGradeShape AdjudicationShape
          EvaluatorHealthShape MetricObservationShape AggregateResultShape
        ] do
      assert statement?(shapes, @jfes <> shape, @sh_sparql, authority_constraint)
    end

    [select] =
      shapes
      |> values(@jfes <> "NoMeasurementAuthorityConstraint", @sh_select)
      |> MapSet.to_list()

    query = RDF.Literal.value(select)
    assert query =~ @jf <> "accepts"
    assert query =~ @jf <> "transitionSubject"
    assert query =~ @jfe <> "rolloutDisposition"
  end

  defp ontology_path(file) do
    Application.app_dir(:jido_code, Path.join(@root, file))
  end

  defp statement?(graph, subject, predicate, object) do
    RDF.Graph.include?(graph, {iri(subject), iri(predicate), object})
  end

  defp objects(graph, predicate) do
    graph
    |> RDF.Graph.triples()
    |> Enum.reduce(MapSet.new(), fn {_, stored_predicate, object}, acc ->
      if RDF.Term.equal_value?(stored_predicate, iri(predicate)),
        do: MapSet.put(acc, object),
        else: acc
    end)
  end

  defp values(graph, subject, predicate) do
    graph
    |> RDF.Graph.triples()
    |> Enum.reduce(MapSet.new(), fn {stored_subject, stored_predicate, object}, acc ->
      if RDF.Term.equal_value?(stored_subject, iri(subject)) and
           RDF.Term.equal_value?(stored_predicate, iri(predicate)),
         do: MapSet.put(acc, object),
         else: acc
    end)
  end

  defp iri(value), do: RDF.iri(value)
  defp iri_set(values), do: MapSet.new(values, &iri/1)
end

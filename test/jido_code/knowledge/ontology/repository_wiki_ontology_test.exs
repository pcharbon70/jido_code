defmodule JidoCode.Knowledge.Ontology.RepositoryWikiOntologyTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.RepositoryWiki.Vocabulary
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @jf "https://jido.run/ontology/factory#"
  @jfc "https://jido.run/ontology/concept/"
  @jfs "https://jido.run/ontology/shapes#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @owl_class "http://www.w3.org/2002/07/owl#Class"
  @sh_closed "http://www.w3.org/ns/shacl#closed"
  @sh_node_shape "http://www.w3.org/ns/shacl#NodeShape"

  test "release 1.5.0 adds the closed repository wiki resources and graph kind" do
    assert {:ok, dataset} = Release.dataset("1.5.0")
    quads = RDF.Dataset.quads(dataset)

    classes = ~w[
      RepositoryWiki RepositoryWikiEnrollment WikiGenerationProfile WikiEdition WikiPage
      WikiSection WikiSource WikiCitation WikiLink WikiGap WikiDriftFinding WikiLintReport
      WikiPreview WikiMaintainer WikiBudget WikiReservation WikiUsageRecord WikiCompilationAttempt
    ]

    for class <- classes do
      assert quad?(quads, @jf <> class, @rdf_type, @owl_class)
    end

    for class <- ~w[
          RepositoryWiki WikiEdition WikiPage WikiSection WikiSource WikiCitation WikiLink WikiGap
          WikiDriftFinding WikiLintReport WikiPreview WikiCompilationAttempt
        ] do
      assert ShapeCatalog.allowed_class?(:repository_wiki, @jf <> class)
    end

    assert quad?(quads, @jfc <> "RepositoryWikiGraph", @rdf_type, skos_concept())
  end

  test "key wiki resource shapes are closed and version compatibility is additive" do
    assert {:ok, dataset} = Release.dataset("1.5.0")
    quads = RDF.Dataset.quads(dataset)

    for shape <- ~w[
          RepositoryWikiEnrollmentShape WikiGenerationProfileShape WikiEditionShape WikiPageShape
          WikiSourceShape WikiPreviewShape WikiMaintainerShape WikiBudgetShape WikiReservationShape
          WikiUsageRecordShape
        ] do
      subject = @jfs <> shape
      assert quad?(quads, subject, @rdf_type, @sh_node_shape)
      assert quad?(quads, subject, @sh_closed, "true")
    end

    assert ShapeCatalog.version() == "1.5.0"
    assert ShapeCatalog.ontology_version() == "1.5.0"
    assert ShapeCatalog.known_versions?("1.5.0", "1.5.0")
    assert ShapeCatalog.known_versions?("1.4.0", "1.5.0")
    assert ShapeCatalog.known_versions?("1.4.0", "1.4.0")
    refute ShapeCatalog.known_versions?("1.5.0", "1.4.0")
  end

  test "wiki protocol vocabulary is finite and synthesis remains only a closed value" do
    assert Vocabulary.protocol_version() == "1.0.0"
    assert Vocabulary.values(:enrollment_state) == {:ok, [:off, :manual, :automatic]}
    assert Vocabulary.valid?(:generation_mode, :deterministic_only)
    assert Vocabulary.valid?(:generation_mode, :synthesis_allowed)
    refute Vocabulary.valid?(:generation_mode, :caller_selected_model)
    refute Vocabulary.valid?(:unknown, :off)
    assert :candidate_preview in elem(Vocabulary.values(:edition_purpose), 1)
    assert :developer_guide in elem(Vocabulary.values(:page_kind), 1)
  end

  defp quad?(quads, subject, predicate, object) do
    Enum.any?(quads, fn {quad_subject, quad_predicate, quad_object, _graph} ->
      to_string(quad_subject) == subject and to_string(quad_predicate) == predicate and
        to_string(quad_object) == object
    end)
  end

  defp skos_concept, do: "http://www.w3.org/2004/02/skos/core#Concept"
end

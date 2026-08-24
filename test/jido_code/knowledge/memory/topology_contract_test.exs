defmodule JidoCode.Knowledge.Memory.TopologyContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @jf "https://jido.run/ontology/factory#"

  setup do
    {:ok, repository} = ResourceIdentity.repository("memory-topology")
    {:ok, attempt} = ResourceIdentity.local(:attempt, 1_000, <<3::80>>)
    {:ok, content} = ResourceIdentity.local(:claim, 1_001, <<4::80>>)
    %{repository: repository, attempt: attempt, content: content}
  end

  test "registers the MG6 content families at the accepted graph-native branch", ids do
    expected = %{
      run_event_segment: %{
        scopes: %{attempt: ids.attempt, segment: 12},
        capability: :execution_writer,
        mutability: :closeable,
        completeness: :building,
        retention: :run_history
      },
      experience: %{
        scopes: %{repository: ids.repository},
        capability: :experience_writer,
        mutability: :append_supersede,
        completeness: :complete,
        retention: :experience_history
      },
      content_lifecycle: %{
        scopes: %{repository: ids.repository},
        capability: :content_lifecycle_writer,
        mutability: :append_supersede,
        completeness: :complete,
        retention: :content_lifecycle
      },
      episode_content: %{
        scopes: %{repository: ids.repository, content: ids.content},
        capability: :content_writer,
        mutability: :immutable,
        completeness: :complete,
        retention: :governed_content
      }
    }

    assert GraphRegistry.revision() == "2.4.0"

    Enum.each(expected, fn {family, expected_contract} ->
      assert {:ok, graph} = GraphRegistry.graph_iri(family, expected_contract.scopes)
      assert {:ok, ^family} = GraphRegistry.identify(graph)
      assert {:ok, contract} = GraphRegistry.fetch(family)
      assert contract.enabled
      assert contract.capability == expected_contract.capability
      assert contract.mutability == expected_contract.mutability
      assert contract.completeness == expected_contract.completeness
      assert contract.retention == expected_contract.retention

      assert GraphRegistry.write_allowed?(family, :create)

      assert {:ok, %{family: ^family}} =
               GraphRegistry.validate_target(graph, expected_contract.capability)
    end)
  end

  test "admits memory classes only in their declared graph families" do
    assert ShapeCatalog.version() == "1.3.0"
    assert ShapeCatalog.known_versions?("1.0.0", "1.0.0")
    assert ShapeCatalog.known_versions?("1.1.0", "1.1.0")
    assert ShapeCatalog.known_versions?("1.2.0", "1.2.0")
    assert ShapeCatalog.known_versions?("1.3.0", "1.3.0")
    assert ShapeCatalog.known_versions?("1.0.0", "1.3.0")
    refute ShapeCatalog.known_versions?("1.1.0", "1.0.0")
    refute ShapeCatalog.known_versions?("1.3.0", "1.2.0")

    assert ShapeCatalog.allowed_class?(:run_attempt, @jf <> "CaptureManifest")
    assert ShapeCatalog.allowed_class?(:run_event_segment, @jf <> "SegmentManifest")
    assert ShapeCatalog.allowed_class?(:run_event_segment, @jf <> "ContentCapture")
    assert ShapeCatalog.allowed_class?(:experience, @jf <> "ExperienceCase")
    assert ShapeCatalog.allowed_class?(:experience, @jf <> "ProcedureRevision")
    assert ShapeCatalog.allowed_class?(:experience, @jf <> "ArtifactClaim")
    assert ShapeCatalog.allowed_class?(:experience, @jf <> "RetrievalActivity")

    assert ShapeCatalog.allowed_class?(
             :content_lifecycle,
             @jf <> "ContentLifecycleActivity"
           )

    assert ShapeCatalog.allowed_class?(:content_lifecycle, @jf <> "ContentAccessPermit")
    assert ShapeCatalog.allowed_class?(:episode_content, @jf <> "EpisodeContent")
    assert ShapeCatalog.allowed_class?(:episode_content, @jf <> "ContentChunk")

    refute ShapeCatalog.allowed_class?(:memory, @jf <> "ProcedureRevision")
    refute ShapeCatalog.allowed_class?(:episode_content, @jf <> "KnowledgeAssertion")
  end

  test "permits only the accepted memory link directions" do
    assert GraphRegistry.allowed_link?(:run_attempt, :run_event_segment)
    assert GraphRegistry.allowed_link?(:run_event_segment, :episode_content)
    assert GraphRegistry.allowed_link?(:experience, :run_event_segment)
    assert GraphRegistry.allowed_link?(:content_lifecycle, :episode_content)
    assert GraphRegistry.allowed_link?(:security_audit, :content_lifecycle)

    refute GraphRegistry.allowed_link?(:episode_content, :evidence)
    refute GraphRegistry.allowed_link?(:episode_content, :memory)
    refute GraphRegistry.allowed_link?(:observation_batch, :experience)
  end

  test "rejects malformed segment and content scopes", ids do
    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:run_event_segment, %{attempt: ids.attempt, segment: -1})

    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:run_event_segment, %{
               attempt: ids.attempt,
               segment: 1_000_000
             })

    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:episode_content, %{repository: ids.repository})
  end
end

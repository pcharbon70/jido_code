defmodule JidoCode.Knowledge.GraphRegistryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  setup do
    {:ok, repository} = ResourceIdentity.repository("repo:canonical-1")
    {:ok, batch} = ResourceIdentity.local(:activity, 100, <<0::80>>)
    {:ok, revision} = ResourceIdentity.git_object(:sha1, String.duplicate("a", 40))
    {:ok, attempt} = ResourceIdentity.local(:attempt, 200, <<1::80>>)
    {:ok, content} = ResourceIdentity.local(:claim, 300, <<2::80>>)
    {:ok, cohort} = ResourceIdentity.deterministic(:repository_cohort, "cohort-1")
    {:ok, dataset} = ResourceIdentity.deterministic(:memory_dataset_manifest, "dataset-1")

    %{
      repository: repository,
      batch: batch,
      revision: revision,
      attempt: attempt,
      content: content,
      cohort: cohort,
      dataset: dataset
    }
  end

  test "constructs and recognizes every registered graph family", ids do
    inputs = [
      ontology: %{version: "1.0.0"},
      factory_catalog: %{},
      factory_policy: %{},
      observation_batch: %{repository: ids.repository, batch: ids.batch},
      source_revision: %{repository: ids.repository, revision: ids.revision},
      repository_control: %{repository: ids.repository},
      run_attempt: %{attempt: ids.attempt},
      run_event_segment: %{attempt: ids.attempt, segment: 0},
      evidence: %{repository: ids.repository},
      memory: %{repository: ids.repository},
      memory_dataset: %{cohort: ids.cohort, dataset: ids.dataset},
      experience: %{repository: ids.repository},
      content_lifecycle: %{repository: ids.repository},
      episode_content: %{repository: ids.repository, content: ids.content},
      security_audit: %{period: "2026-07"},
      derived: %{rule_set: "eligibility-v1", revision: 7}
    ]

    assert Enum.sort(Keyword.keys(inputs)) == GraphRegistry.families()

    Enum.each(inputs, fn {family, scopes} ->
      assert {:ok, iri} = GraphRegistry.graph_iri(family, scopes)
      assert {:ok, ^family} = GraphRegistry.identify(iri)
      assert {:ok, contract} = GraphRegistry.fetch(family)
      assert Enum.sort(contract.required_scopes) == Enum.sort(Map.keys(scopes))
      assert is_atom(contract.capability)
      assert is_atom(contract.mutability)
      assert is_atom(contract.retention)
      assert is_boolean(contract.enabled)
    end)
  end

  test "enforces writer capabilities, lifecycle, and cross-family links", ids do
    assert {:ok, catalog} = GraphRegistry.graph_iri(:factory_catalog, %{})
    assert {:ok, _contract} = GraphRegistry.validate_target(catalog, :catalog_writer)

    assert {:error, %Error{kind: :unauthorized}} =
             GraphRegistry.validate_target(catalog, :execution_writer)

    assert GraphRegistry.write_allowed?(:ontology, :create, nil)
    refute GraphRegistry.write_allowed?(:ontology, :append, %{lifecycle_state: :closed})
    assert GraphRegistry.write_allowed?(:run_attempt, :append, %{lifecycle_state: :open})
    refute GraphRegistry.write_allowed?(:run_attempt, :append, %{lifecycle_state: :closed})
    assert GraphRegistry.write_allowed?(:derived, :replace, %{lifecycle_state: :closed})

    assert GraphRegistry.allowed_link?(:repository_control, :evidence)
    refute GraphRegistry.allowed_link?(:observation_batch, :repository_control)

    assert {:ok, segment} =
             GraphRegistry.graph_iri(:run_event_segment, %{
               attempt: ids.attempt,
               segment: 0
             })

    assert {:ok, %{family: :run_event_segment}} =
             GraphRegistry.validate_target(segment, :execution_writer)

    assert GraphRegistry.write_allowed?(:run_event_segment, :create, nil)
    assert GraphRegistry.allowed_link?(:run_attempt, :run_event_segment)
    refute GraphRegistry.allowed_link?(:episode_content, :memory)
  end

  test "rejects unknown graphs and malformed scope maps", ids do
    assert {:error, %Error{operation: :graph_identity}} =
             GraphRegistry.identify("https://jido.run/graph/repo/ad-hoc")

    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:repository_control, %{
               repository: ids.repository,
               extra: ids.batch
             })

    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:security_audit, %{period: "2026-13"})
  end
end

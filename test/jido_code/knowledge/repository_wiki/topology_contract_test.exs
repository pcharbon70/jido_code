defmodule JidoCode.Knowledge.RepositoryWiki.TopologyContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Retention.Policy, as: RetentionPolicy
  alias JidoCode.Security.DataPolicy

  setup do
    {:ok, first_repository} = ResourceIdentity.repository("wiki-topology-first")
    {:ok, second_repository} = ResourceIdentity.repository("wiki-topology-second")
    root = String.duplicate("d", 64)
    {:ok, first_edition} = ResourceIdentity.wiki_edition(first_repository, root)
    {:ok, second_edition} = ResourceIdentity.wiki_edition(second_repository, root)

    %{
      first_repository: first_repository,
      second_repository: second_repository,
      first_edition: first_edition,
      second_edition: second_edition
    }
  end

  test "publishes graph registry 2.5.0 with one closed repository-edition family", ids do
    assert GraphRegistry.revision() == "2.5.0"

    assert {:ok, first} =
             GraphRegistry.graph_iri(:repository_wiki, %{
               repository: ids.first_repository,
               edition: ids.first_edition
             })

    assert {:ok, replay} =
             GraphRegistry.graph_iri(:repository_wiki, %{
               repository: ids.first_repository,
               edition: ids.first_edition
             })

    assert {:ok, second} =
             GraphRegistry.graph_iri(:repository_wiki, %{
               repository: ids.second_repository,
               edition: ids.second_edition
             })

    assert first == replay
    refute first == second
    assert {:ok, :repository_wiki} = GraphRegistry.identify(first)

    assert {:ok, contract} = GraphRegistry.fetch(:repository_wiki)
    assert contract.required_scopes == [:repository, :edition]
    assert contract.capability == :wiki_writer
    assert contract.mutability == :closeable
    assert contract.completeness == :building
    assert contract.retention == :wiki_edition
    assert contract.enabled
    assert contract.owner_scope == :repository
    assert :WikiEdition in contract.resource_roots
    assert contract.backup == :application_owned
    assert contract.restore_order == :after_repository_control
    assert contract.read_profile == :reviewed_repository_wiki
    assert :ok = GraphRegistry.verify()
  end

  test "fails closed for caller graphs, missing scopes, and wrong capabilities", ids do
    assert {:error, %Error{operation: :graph_identity}} =
             GraphRegistry.identify("https://jido.run/graph/repo/caller/wiki/current")

    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:repository_wiki, %{repository: ids.first_repository})

    assert {:error, %Error{operation: :graph_scope}} =
             GraphRegistry.graph_iri(:repository_wiki, %{
               repository: ids.first_repository,
               edition: ids.first_edition,
               graph: "caller"
             })

    assert {:ok, graph} =
             GraphRegistry.graph_iri(:repository_wiki, %{
               repository: ids.first_repository,
               edition: ids.first_edition
             })

    assert {:error, %Error{kind: :unauthorized}} =
             GraphRegistry.validate_target(graph, :control_writer)
  end

  test "covers repository wiki graphs with data and retention policy", _ids do
    assert DataPolicy.revision() == "2.2.0"
    assert DataPolicy.durable_allowed?(:internal, :repository_wiki)
    refute DataPolicy.durable_allowed?(:secret_value, :repository_wiki)
    refute DataPolicy.durable_allowed?(:source_body, :repository_wiki)

    assert {:ok, :wiki_edition} = RetentionPolicy.class_for_family(:repository_wiki)

    assert {:ok, %{minimum_days: 365, disposition: :archive}} =
             Map.fetch(RetentionPolicy.classes(), :wiki_edition)

    assert :ok = DataPolicy.verify()
    assert :ok = RetentionPolicy.verify()
  end
end

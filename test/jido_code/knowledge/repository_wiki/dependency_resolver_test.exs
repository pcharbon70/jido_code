defmodule JidoCode.Knowledge.RepositoryWiki.DependencyResolverTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.DependencyResolver
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixReconciler
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.ResourceIdentity

  @checksum String.duplicate("a", 64)
  @outer_checksum String.duplicate("b", 64)
  @revision String.duplicate("c", 40)

  test "builds the exact cycle-safe closure with stable identities and classifications" do
    {reconciliation, attributes} = fixture()

    assert {:ok, first} = DependencyResolver.resolve(reconciliation, attributes)
    assert {:ok, second} = DependencyResolver.resolve(reconciliation, attributes)
    assert first == second
    assert first.profile_digest == DependencyResolver.profile().digest

    assert first.node_count == 11
    assert first.edge_count == 3
    assert first.completeness.expected_lock_nodes == 8
    assert first.completeness.represented_lock_nodes == 8
    assert first.completeness.represented_edges == 3
    assert first.maximum_depth == 1
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0
    assert first.usage_cost_microunits == 0

    assert node(first, "alpha").classification == :resolved
    assert node(first, "beta").classification == :locked_only
    assert node(first, "ghost").classification == :unverifiable
    assert node(first, "missing").classification == :missing_lock
    assert node(first, "moving").classification == :declared_only
    assert node(first, "orphan").classification == :orphaned_lock
    assert node(first, "future").classification == :unsupported

    assert node(first, "beta").parents == ["alpha"]
    assert node(first, "beta").canonical_path == ["alpha", "beta"]
    assert ["alpha", "beta"] in node(first, "beta").root_paths
    assert node(first, "alpha").parents == ["beta"]
    assert node(first, "alpha").cycle
    assert node(first, "beta").cycle
    assert first.cycles == [%{from: "alpha", to: "beta"}, %{from: "beta", to: "alpha"}]

    assert node(first, "source_dep").source_options["sparse"] == "apps/source"
    assert node(first, "alpha").optional
    refute node(first, "alpha").runtime
    assert node(first, "alpha").environments == ["dev", "test"]
    assert Enum.find(first.edges, &(&1.child == "ghost")).optional
    assert Enum.any?(first.gaps, &(&1.kind == :unverifiable_edge and &1.dependency == "ghost"))
    assert first.completeness.state == :partial
  end

  test "rejects source-fence drift and caller-raised traversal limits" do
    {reconciliation, attributes} = fixture()

    assert {:error, %{kind: :conflict}} =
             DependencyResolver.resolve(reconciliation, %{attributes | source_fence: "other"})

    raised = %{DependencyResolver.profile().limits | nodes: 2_049}

    assert {:error, %{kind: :invalid_input}} =
             DependencyResolver.resolve(reconciliation, Map.put(attributes, :limits, raised))
  end

  test "represents every node and supported edge in this repository lock" do
    {:ok, static} = MixStatic.extract(File.read!("mix.exs"))
    {:ok, lock} = LockParser.parse(File.read!("mix.lock"))
    reconciliation_attributes = reconciliation_attributes(static, lock, "current-repository")

    assert {:ok, reconciliation} =
             MixReconciler.reconcile(static, lock, nil, [], reconciliation_attributes)

    assert {:ok, catalog} =
             DependencyResolver.resolve(reconciliation, resolver_attributes("current-repository"))

    assert catalog.completeness.expected_lock_nodes == lock.entry_count
    assert catalog.completeness.represented_lock_nodes == lock.entry_count
    assert catalog.completeness.represented_edges == lock.edge_count
    assert catalog.node_count >= lock.entry_count

    assert Enum.all?(catalog.edges, fn edge ->
             node(catalog, edge.parent) && node(catalog, edge.child)
           end)
  end

  defp fixture do
    source = ~S'''
    defmodule Resolver.MixProject do
      def project do
        [
          app: :resolver,
          version: "1.0.0",
          deps: [
            {:alpha, "~> 1.0", only: [:dev, :test], optional: true, runtime: false},
            {:missing, "~> 1.0"},
            {:source_dep, git: "https://github.com/example/source.git", ref: "cccccccccccccccccccccccccccccccccccccccc", sparse: "apps/source"},
            {:moving, git: "https://github.com/example/moving.git", branch: "main"},
            {:local_child, path: "apps/local_child", override: true}
          ]
        ]
      end
    end
    '''

    lock_source = """
    %{
      "alpha" => {:hex, :alpha, "1.2.0", "#{@checksum}", [:mix], [{:beta, "~> 2.0", [hex: :beta, repo: "hexpm", optional: false]}, {:ghost, "~> 1.0", [hex: :ghost, repo: "hexpm", optional: true]}], "hexpm", "#{@outer_checksum}"},
      "beta" => {:hex, :beta, "2.1.0", "#{@outer_checksum}", [:rebar3], [{:alpha, "~> 1.0", [hex: :alpha, repo: "hexpm", optional: false]}], "hexpm", "#{@checksum}"},
      "source_dep" => {:git, "https://github.com/example/source.git", "#{@revision}", [ref: "#{@revision}", sparse: "apps/source"]},
      "local_child" => {:path, "apps/local_child", [app: false]},
      "orphan" => {:hex, :orphan, "3.0.0", "#{@checksum}", [:make], [], "hexpm", "#{@outer_checksum}"},
      "future" => {:workspace_v2, "opaque", []},
      "private_source" => {:git, "https://private.example/repo.git", "#{@revision}", []},
      "credentialed" => {:git, "https://token@github.com/example/secret.git", "#{@revision}", []}
    }
    """

    {:ok, static} = MixStatic.extract(source)
    {:ok, lock} = LockParser.parse(lock_source)
    reconciliation_attributes = reconciliation_attributes(static, lock, "fixture")

    {:ok, reconciliation} =
      MixReconciler.reconcile(static, lock, nil, [], reconciliation_attributes)

    {reconciliation, resolver_attributes("fixture")}
  end

  defp reconciliation_attributes(static, lock, suffix) do
    %{
      source_digest: static.source_digest,
      lock_digest: lock.source_digest,
      source_fence: "source-fence:#{suffix}",
      toolchain_digest: "toolchain:#{suffix}",
      policy_revision: 2
    }
  end

  defp resolver_attributes(suffix) do
    {:ok, repository_iri} =
      ResourceIdentity.conceptual_repository("dependency-resolver-#{suffix}")

    {:ok, tenant_iri} = ResourceIdentity.deterministic(:control_constraint, "tenant-#{suffix}")
    {:ok, edition_iri} = ResourceIdentity.deterministic(:wiki_edition, "edition-#{suffix}")

    %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      edition_iri: edition_iri,
      source_fence: "source-fence:#{suffix}"
    }
  end

  defp node(catalog, name), do: Enum.find(catalog.nodes, &(&1.name == name))
end

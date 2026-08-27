defmodule JidoCode.Factory.RepositoryWiki.DependencySourcesTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.RepositoryWiki.DependencySources
  alias JidoCode.Knowledge.RepositoryWiki.DependencyResolver
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixReconciler
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.ResourceIdentity

  @checksum String.duplicate("a", 64)
  @outer_checksum String.duplicate("b", 64)
  @revision String.duplicate("c", 40)

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "wiki-dependency-sources-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(root, "apps/local_child/lib"))
    File.mkdir_p!(Path.join(root, "apps/umbrella_child/lib"))

    File.write!(
      Path.join(root, "apps/local_child/mix.exs"),
      "defmodule Local.MixProject do\nend\n"
    )

    File.write!(Path.join(root, "apps/local_child/lib/local.ex"), "defmodule Local do\nend\n")

    File.write!(
      Path.join(root, "apps/umbrella_child/mix.exs"),
      "defmodule Umbrella.MixProject do\nend\n"
    )

    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  test "classifies admitted local, immutable public, moving, private, and credentialed sources",
       %{
         root: root
       } do
    catalog = catalog()
    attributes = source_attributes()

    assert {:ok, first} = DependencySources.classify(catalog, root, attributes)
    assert {:ok, second} = DependencySources.classify(catalog, root, attributes)
    assert first == second

    local = node(first, "local_child")
    assert local.source.state == :available
    assert local.source.relative == "apps/local_child"
    assert local.source.entry_count == 3
    refute local.source.external_link_eligible
    assert local.override

    umbrella = node(first, "umbrella_child")
    assert umbrella.scm == "umbrella"
    assert umbrella.optional
    assert umbrella.source.state == :available
    assert umbrella.source.relative == "apps/umbrella_child"

    assert node(first, "outside").source.state == :unavailable
    assert node(first, "outside").source.reason == :missing_or_unsafe

    public = node(first, "public_source")
    assert public.source.state == :verified
    assert public.source.canonical_url == "https://github.com/example/public.git"
    assert public.source.revision == @revision
    assert public.source_options["sparse"] == "apps/public"

    assert node(first, "moving_source").source.state == :moving
    assert node(first, "moving_source").source.reason == :missing_immutable_revision
    refute node(first, "moving_source").source.external_link_eligible

    assert node(first, "private_source").source.display == "[private source]"
    assert node(first, "private_source").source.state == :private
    refute inspect(node(first, "private_source")) =~ "private.example"
    assert node(first, "credentialed").source.display == "[redacted source]"
    assert node(first, "credentialed").source.state == :redacted
    refute inspect(node(first, "credentialed")) =~ "token@"
    assert first.completeness.source_unavailable >= 3
  end

  test "denies traversal, unregistered paths, internal symlinks, and open host registries", %{
    root: root
  } do
    attributes = source_attributes()
    catalog = catalog()

    symlink = Path.join(root, "apps/local_child/lib/outside")
    File.ln_s!(System.tmp_dir!(), symlink)

    assert {:ok, classified} = DependencySources.classify(catalog, root, attributes)
    assert node(classified, "local_child").source.state == :unavailable
    assert node(classified, "local_child").source.reason == :path_source_symlink

    open_hosts = %{attributes | public_git_hosts: ["packages.example"]}

    assert {:error, %{kind: :invalid_input}} =
             DependencySources.classify(catalog, root, open_hosts)

    assert {:error, %{kind: :invalid_input}} =
             DependencySources.classify(catalog, "relative-workspace", attributes)
  end

  defp catalog do
    source = ~S'''
    defmodule Sources.MixProject do
      def project do
        [
          app: :sources,
          version: "1.0.0",
          deps: [
            {:local_child, path: "apps/local_child", override: true},
            {:umbrella_child, in_umbrella: true, optional: true},
            {:outside, path: "../outside"},
            {:public_source, git: "https://github.com/example/public.git", ref: "cccccccccccccccccccccccccccccccccccccccc", sparse: "apps/public"},
            {:moving_source, git: "https://github.com/example/moving.git", branch: "main"}
          ]
        ]
      end
    end
    '''

    lock_source = """
    %{
      "local_child" => {:path, "apps/local_child", [app: false]},
      "public_source" => {:git, "https://github.com/example/public.git", "#{@revision}", [ref: "#{@revision}", sparse: "apps/public"]},
      "private_source" => {:git, "https://private.example/repo.git", "#{@revision}", []},
      "credentialed" => {:git, "https://token@github.com/example/secret.git", "#{@revision}", []},
      "hex_dep" => {:hex, :hex_dep, "1.0.0", "#{@checksum}", [:mix, :rebar3], [], "hexpm", "#{@outer_checksum}"}
    }
    """

    {:ok, static} = MixStatic.extract(source)
    {:ok, lock} = LockParser.parse(lock_source)

    reconciliation_attributes = %{
      source_digest: static.source_digest,
      lock_digest: lock.source_digest,
      source_fence: "source-fence:sources",
      toolchain_digest: "toolchain:sources",
      policy_revision: 2
    }

    {:ok, reconciliation} =
      MixReconciler.reconcile(static, lock, nil, [], reconciliation_attributes)

    {:ok, repository_iri} = ResourceIdentity.conceptual_repository("dependency-sources")
    {:ok, tenant_iri} = ResourceIdentity.deterministic(:control_constraint, "tenant-sources")
    {:ok, edition_iri} = ResourceIdentity.deterministic(:wiki_edition, "edition-sources")

    resolver_attributes = %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      edition_iri: edition_iri,
      source_fence: "source-fence:sources"
    }

    {:ok, result} = DependencyResolver.resolve(reconciliation, resolver_attributes)
    result
  end

  defp source_attributes do
    %{
      registered_path_prefixes: ["apps"],
      public_git_hosts: ["github.com"],
      umbrella_children: %{"umbrella_child" => "apps/umbrella_child"}
    }
  end

  defp node(catalog, name), do: Enum.find(catalog.nodes, &(&1.name == name))
end

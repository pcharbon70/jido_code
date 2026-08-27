defmodule JidoCode.TestSupport.RepositoryWikiPhase2Fixture do
  alias JidoCode.Factory.RepositoryWiki.DependencySources
  alias JidoCode.Factory.RepositoryWiki.HexMetadata
  alias JidoCode.Knowledge.RepositoryWiki.Compiler
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLinks
  alias JidoCode.Knowledge.RepositoryWiki.DependencyResolver
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixReconciler
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory
  alias JidoCode.Knowledge.ResourceIdentity

  @checksum String.duplicate("a", 64)
  @outer_checksum String.duplicate("b", 64)
  @revision String.duplicate("c", 40)
  @created_at ~U[2026-08-27 12:00:00.000000Z]

  def build!(suffix) do
    root =
      Path.join(
        System.tmp_dir!(),
        "wiki-phase2-#{suffix}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(root, "lib/demo"))
    File.write!(Path.join(root, "README.md"), "# Dependency wiki fixture\n")
    File.write!(Path.join(root, "lib/demo/example.ex"), "defmodule Demo.Example do\nend\n")
    File.write!(Path.join(root, "mix.exs"), mix_source())
    File.write!(Path.join(root, "mix.lock"), lock_source())

    {:ok, repository_iri} = ResourceIdentity.conceptual_repository("wiki-phase2-#{suffix}")
    {:ok, tenant_iri} = ResourceIdentity.deterministic(:control_constraint, "wiki-phase2-tenant")

    {:ok, snapshot_iri} =
      ResourceIdentity.deterministic(:repository_snapshot, "wiki-phase2-#{suffix}")

    source_fence = "source-fence:wiki-phase2-#{suffix}"

    {:ok, inventory} =
      SourceInventory.scan(root, %{
        repository_iri: repository_iri,
        source_snapshot_iri: snapshot_iri,
        source_fence: source_fence,
        accepted_graph_sources: [],
        limits: SourceInventory.profile().limits
      })

    compilation_attributes = %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      created_at: @created_at,
      purpose: :current
    }

    {:ok, base_compilation} = Compiler.compile(inventory, compilation_attributes)
    {:ok, static} = MixStatic.extract(mix_source())
    {:ok, lock} = LockParser.parse(lock_source())

    reconciliation_attributes = %{
      source_digest: static.source_digest,
      lock_digest: lock.source_digest,
      source_fence: source_fence,
      toolchain_digest: "toolchain:wiki-phase2",
      policy_revision: 2
    }

    {:ok, reconciliation} =
      MixReconciler.reconcile(static, lock, nil, [], reconciliation_attributes)

    dependency_attributes = %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      edition_iri: base_compilation.edition_iri,
      source_fence: source_fence
    }

    {:ok, unresolved_catalog} = DependencyResolver.resolve(reconciliation, dependency_attributes)

    {:ok, catalog} =
      DependencySources.classify(unresolved_catalog, root, %{
        registered_path_prefixes: ["apps"],
        public_git_hosts: ["github.com"],
        umbrella_children: %{}
      })

    metadata_context = %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      authorization_class: :public_anonymous,
      retrieved_at: @created_at,
      cache: nil
    }

    {:ok, alpha_metadata} =
      HexMetadata.fetch("alpha", "1.2.3", metadata_context, fixture: metadata_fixture())

    metadata = %{"alpha" => alpha_metadata}

    link_sets =
      Map.new(catalog.nodes, fn node ->
        {:ok, links} =
          DependencyLinks.build(node, metadata[node.name], %{
            edition_iri: base_compilation.edition_iri
          })

        {node.name, links}
      end)

    {:ok, compilation} =
      Compiler.compile_dependencies(
        base_compilation,
        reconciliation,
        catalog,
        metadata,
        link_sets,
        dependency_attributes
      )

    %{
      root: root,
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      source_fence: source_fence,
      inventory: inventory,
      static: static,
      lock: lock,
      reconciliation: reconciliation,
      catalog: catalog,
      metadata: metadata,
      link_sets: link_sets,
      base_compilation: base_compilation,
      compilation: compilation,
      dependency_attributes: dependency_attributes,
      created_at: @created_at
    }
  end

  def cleanup!(fixture), do: File.rm_rf!(fixture.root)

  defp mix_source do
    ~S'''
    defmodule Demo.MixProject do
      def project do
        [
          app: :demo,
          version: "1.0.0",
          elixir: "~> 1.19",
          deps: [
            {:alpha, "~> 1.0", only: [:dev, :test], optional: true},
            {:missing, "~> 1.0"},
            {:source_dep, git: "https://github.com/example/source.git", ref: "cccccccccccccccccccccccccccccccccccccccc", sparse: "apps/source"}
          ]
        ]
      end

      def application do
        [extra_applications: [:logger, :runtime_tools]]
      end
    end
    '''
  end

  defp lock_source do
    """
    %{
      "alpha" => {:hex, :alpha, "1.2.3", "#{@checksum}", [:mix], [{:beta, "~> 2.0", [hex: :beta, repo: "hexpm", optional: false]}, {:ghost, "~> 1.0", [hex: :ghost, repo: "hexpm", optional: true]}], "hexpm", "#{@outer_checksum}"},
      "beta" => {:hex, :beta, "2.1.0", "#{@outer_checksum}", [:rebar3], [], "hexpm", "#{@checksum}"},
      "source_dep" => {:git, "https://github.com/example/source.git", "#{@revision}", [ref: "#{@revision}", sparse: "apps/source"]},
      "orphan" => {:hex, :orphan, "3.0.0", "#{@checksum}", [:make], [], "hexpm", "#{@outer_checksum}"}
    }
    """
  end

  defp metadata_fixture do
    %{
      package: %{
        status: 200,
        body: %{
          "meta" => %{
            "description" => "Alpha package metadata.",
            "licenses" => ["Apache-2.0"],
            "maintainers" => ["alpha-maintainer"],
            "links" => %{
              "GitHub" => "https://github.com/example/alpha",
              "Internal" => "https://service.internal/admin"
            }
          }
        }
      },
      release: %{
        status: 200,
        body: %{
          "version" => "1.2.3",
          "checksum" => @checksum,
          "inserted_at" => "2026-08-01T00:00:00Z",
          "requirements" => %{
            "beta" => %{"requirement" => "~> 2.0", "optional" => false, "app" => true}
          }
        }
      }
    }
  end
end

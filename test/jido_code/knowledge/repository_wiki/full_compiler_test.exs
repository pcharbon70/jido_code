defmodule JidoCode.Knowledge.RepositoryWiki.FullCompilerTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Compiler
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.FullCompiler
  alias JidoCode.Knowledge.RepositoryWiki.GuideDiscovery
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.RepositoryWikiPhase2Fixture

  setup context do
    fixture = RepositoryWikiPhase2Fixture.build!(to_string(context.test))
    on_exit(fn -> RepositoryWikiPhase2Fixture.cleanup!(fixture) end)

    File.mkdir_p!(Path.join(fixture.root, "docs/guides"))
    File.mkdir_p!(Path.join(fixture.root, "docs/architecture"))
    File.mkdir_p!(Path.join(fixture.root, "docs/operations"))

    File.write!(
      Path.join(fixture.root, "docs/guides/getting-started.md"),
      """
      ---
      title: Start here
      audience: user
      order: 10
      ---
      # Start here

      Install the project and read the [developer guide](developer.md).
      """
    )

    File.write!(
      Path.join(fixture.root, "docs/guides/developer.md"),
      """
      ---
      title: Developer workflow
      audience: developer
      ---
      # Developer workflow

      Run the checks before opening a change.
      """
    )

    File.write!(
      Path.join(fixture.root, "docs/architecture/overview.md"),
      "# Architecture\n\nThe system uses immutable editions.\n"
    )

    File.write!(
      Path.join(fixture.root, "docs/operations/runbook.md"),
      "# Operations runbook\n\nInspect freshness before activation.\n"
    )

    File.write!(
      Path.join(fixture.root, "docs/guides/#{String.duplicate("long-name-", 20)}.md"),
      "---\ntitle: Bounded path guide\naudience: developer\n---\n# Bounded path guide\n"
    )

    source_revision = digest("phase-3-full-source")

    {:ok, manifest} =
      GuideDiscovery.discover(fixture.root, %{
        repository_iri: fixture.repository_iri,
        tenant_iri: fixture.tenant_iri,
        source_snapshot_iri: fixture.inventory.source_snapshot_iri,
        source_revision: source_revision,
        limits: GuideDiscovery.profile().limits
      })

    known_paths = Enum.map(manifest.guides, & &1.path)

    rendered =
      Enum.map(manifest.guides, fn guide ->
        {:ok, source} = GuideDiscovery.read(fixture.root, guide)

        {:ok, render} =
          GuideRenderer.render(source, guide, %{
            known_paths: known_paths,
            limits: GuideRenderer.profile().limits
          })

        render
      end)

    {:ok, decision_iri} = ResourceIdentity.deterministic(:control_decision, "accepted-adr")

    documents = [
      %{
        document_iri: decision_iri,
        kind: :adr,
        stable_key: "adr-accepted-editions",
        title: "Accepted immutable editions",
        digest: digest("accepted-adr-content"),
        source_revision: digest("accepted-adr-revision"),
        status: :accepted,
        summary: "Current wiki editions are immutable.",
        facts: %{decision: :immutable_editions}
      }
    ]

    attributes = %{
      repository_iri: fixture.repository_iri,
      tenant_iri: fixture.tenant_iri,
      edition_iri: fixture.compilation.edition_iri,
      source_fence: fixture.source_fence,
      source_revision: source_revision,
      policy_revision: 3,
      policy_digest: digest("phase-3-policy")
    }

    {:ok, full} =
      Compiler.compile_full(fixture.compilation, manifest, rendered, documents, attributes)

    Map.merge(fixture, %{
      guide_manifest: manifest,
      rendered_guides: rendered,
      accepted_documents: documents,
      full_attributes: attributes,
      full_compilation: full
    })
  end

  test "assembles every required collection, authored guide, and accepted document", fixture do
    full = fixture.full_compilation

    for slug <- ~w[
          overview getting-started user-guides developer-guides architecture-index source-map
          project dependency-overview operations provenance freshness known-gaps
        ] do
      assert page(full, slug)
    end

    assert page(full, "guide-docs-guides-getting-started").audience == :user
    assert page(full, "guide-docs-guides-developer").audience == :developer
    assert page(full, "guide-docs-architecture-overview").kind == :architecture_overview
    assert page(full, "guide-docs-operations-runbook").kind == :operator_guide
    assert page(full, "accepted-adr-accepted-editions").kind == :adr

    developer = page(full, "guide-docs-guides-developer")

    assert Enum.any?(developer.backlinks, fn backlink ->
             backlink.source_slug == "guide-docs-guides-getting-started"
           end)

    architecture = page(full, "architecture-index")
    assert "guide-docs-architecture-overview" in architecture.facts.child_slugs
    assert "accepted-adr-accepted-editions" in architecture.facts.child_slugs
  end

  test "emits stable hierarchy, coverage, gaps, graph links, and complete digest identities",
       fixture do
    full = fixture.full_compilation
    extension = full.full_extension

    assert Enum.map(full.pages, & &1.order) == Enum.to_list(0..(full.page_count - 1))
    assert Enum.at(full.navigation, 0).slug == "overview"
    assert Enum.all?(full.pages, &Contract.digest?(&1.content_digest))
    assert length(full.pages) == length(Enum.uniq_by(full.pages, & &1.slug))
    assert length(full.sources) == length(Enum.uniq_by(full.sources, & &1.iri))
    assert Enum.all?(full.pages, &(byte_size(&1.slug) <= 160))
    assert Enum.all?(full.source_coverage, &is_boolean(&1.covered?))
    assert Enum.any?(full.source_coverage, &(&1.locator == "docs/guides/developer.md"))
    assert Enum.any?(full.gaps, &(&1[:category] == :dependency))

    assert Enum.any?(full.statements, fn {_subject, predicate, _object} ->
             predicate == "https://jido.run/ontology/factory#targetPage"
           end)

    for key <- ~w[
          profile_digest compiler_digest base_compilation_digest dependency_profile_digest
          parser_profile_digest lock_profile_digest sandbox_profile_digest resolver_profile_digest
          source_profile_digest guide_profile_digest guide_manifest_digest renderer_profile_digest
          accepted_document_digest policy_digest source_revision page_manifest_digest
          edition_content_digest page_graph_digest navigation_digest source_coverage_digest
          render_digest usage_record_digest
        ]a do
      assert Contract.digest?(extension[key]), "expected #{key} to be a digest"
    end
  end

  test "is byte-stable, zero-token, and rejects a changed render or source fence", fixture do
    assert {:ok, repeated} =
             FullCompiler.compile(
               fixture.compilation,
               fixture.guide_manifest,
               fixture.rendered_guides,
               fixture.accepted_documents,
               fixture.full_attributes
             )

    assert repeated == fixture.full_compilation
    assert repeated.generation_mode == :deterministic_only
    assert repeated.model_calls == 0
    assert repeated.model_input_tokens == 0
    assert repeated.model_output_tokens == 0
    assert repeated.usage_cost_microunits == 0
    assert repeated.full_extension.usage_record_iri == repeated.usage.usage_iri
    assert repeated.full_extension.model_cached_tokens == 0
    assert repeated.full_extension.model_reasoning_tokens == 0

    [first | rest] = fixture.rendered_guides
    tampered = [%{first | title: "changed"} | rest]

    assert {:error, %{kind: :invalid_input}} =
             FullCompiler.compile(
               fixture.compilation,
               fixture.guide_manifest,
               tampered,
               fixture.accepted_documents,
               fixture.full_attributes
             )

    wrong_fence = %{fixture.full_attributes | source_fence: "later-source"}

    assert {:error, %{kind: :conflict}} =
             FullCompiler.compile(
               fixture.compilation,
               fixture.guide_manifest,
               fixture.rendered_guides,
               fixture.accepted_documents,
               wrong_fence
             )
  end

  test "pins the accepted deterministic compiler rather than exposing a model capability" do
    profile = FullCompiler.profile()
    assert profile.compiler_profile == Protocol.compiler_profile()
    assert profile.compiler_digest == Protocol.compiler_digest()
    assert profile.generation_mode == :deterministic_only
    assert profile.model_calls == 0
  end

  defp page(compilation, slug), do: Enum.find(compilation.pages, &(&1.slug == slug))
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

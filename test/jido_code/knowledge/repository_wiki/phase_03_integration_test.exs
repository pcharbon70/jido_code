defmodule JidoCode.Knowledge.RepositoryWiki.Phase03IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.RepositoryWiki.Compiler
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GuideDiscovery
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.UpdateClassifier
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.RepositoryWikiPhase2Fixture

  setup context do
    fixture = RepositoryWikiPhase2Fixture.build!(to_string(context.test))
    on_exit(fn -> RepositoryWikiPhase2Fixture.cleanup!(fixture) end)

    File.mkdir_p!(Path.join(fixture.root, "docs/guides"))
    File.mkdir_p!(Path.join(fixture.root, "docs/architecture"))

    File.write!(
      Path.join(fixture.root, "docs/guides/getting-started.md"),
      """
      ---
      title: Débuter safely
      audience: user
      order: 10
      ---
      # Débuter safely

      Read the [developer guide](developer.md), [unsafe](javascript:alert(1)),
      and [missing section](#does-not-exist).

      <img src=x onerror=alert(1)>
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

      Run `mix precommit` before publishing.
      """
    )

    File.write!(
      Path.join(fixture.root, "docs/guides/secret.md"),
      """
      # Credential example

      password = "this-is-a-high-risk-password"
      token: ghp_1234567890abcdefghijklmnop
      -----BEGIN PRIVATE KEY-----
      """
    )

    File.write!(
      Path.join(fixture.root, "docs/architecture/wiki.md"),
      "# Repository wiki\n\nCurrent editions are immutable.\n"
    )

    {:ok, manifest} =
      GuideDiscovery.discover(fixture.root, %{
        repository_iri: fixture.repository_iri,
        tenant_iri: fixture.tenant_iri,
        source_snapshot_iri: fixture.inventory.source_snapshot_iri,
        source_revision: digest("phase-03-source"),
        limits: GuideDiscovery.profile().limits
      })

    known_paths = Enum.map(manifest.guides, & &1.path)

    rendered =
      Enum.map(manifest.guides, fn guide ->
        {:ok, source} = GuideDiscovery.read(fixture.root, guide)

        {:ok, result} =
          GuideRenderer.render(source, guide, %{
            known_paths: known_paths,
            limits: GuideRenderer.profile().limits
          })

        result
      end)

    {:ok, decision_iri} = ResourceIdentity.deterministic(:control_decision, "phase-03-adr")

    documents = [
      %{
        document_iri: decision_iri,
        kind: :adr,
        stable_key: "adr-repository-wiki",
        title: "Repository wiki editions",
        digest: digest("phase-03-adr-content"),
        source_revision: digest("phase-03-adr-revision"),
        status: :accepted,
        summary: "Repository wiki editions are immutable and reviewed.",
        facts: %{activation: :reviewed_compare_and_swap}
      }
    ]

    attributes = %{
      repository_iri: fixture.repository_iri,
      tenant_iri: fixture.tenant_iri,
      edition_iri: fixture.compilation.edition_iri,
      source_fence: fixture.source_fence,
      source_revision: digest("phase-03-source"),
      policy_revision: 3,
      policy_digest: digest("phase-03-policy")
    }

    Map.merge(fixture, %{
      guide_manifest: manifest,
      rendered_guides: rendered,
      accepted_documents: documents,
      full_attributes: attributes
    })
  end

  test "RW3 compiles a useful byte-stable wiki while preserving hostile-guide findings",
       fixture do
    assert {:ok, first} =
             Compiler.compile_full(
               fixture.compilation,
               fixture.guide_manifest,
               fixture.rendered_guides,
               fixture.accepted_documents,
               fixture.full_attributes
             )

    assert {:ok, repeated} =
             Knowledge.compile_full_repository_wiki(
               fixture.compilation,
               fixture.guide_manifest,
               fixture.rendered_guides,
               fixture.accepted_documents,
               fixture.full_attributes
             )

    assert first == repeated

    for slug <- ~w[
          overview getting-started user-guides developer-guides architecture-index project
          dependency-overview source-map provenance freshness known-gaps
        ] do
      assert Enum.any?(first.pages, &(&1.slug == slug)), "missing #{slug}"
    end

    getting_started = Enum.find(first.pages, &(&1.slug == "guide-docs-guides-getting-started"))
    secret = Enum.find(fixture.rendered_guides, &(&1.source_path == "docs/guides/secret.md"))
    rendered_output = inspect(fixture.rendered_guides)

    assert getting_started.audience == :user
    assert Enum.any?(getting_started.backlinks, &is_map/1) or getting_started.backlinks == []
    assert Enum.any?(fixture.rendered_guides, &(:raw_html_escaped in &1.warnings))

    assert Enum.any?(fixture.rendered_guides, fn render ->
             Enum.any?(render.links, &(&1.reason == :unsafe_scheme))
           end)

    refute secret.activation_allowed?
    assert secret.counts.secrets == 3
    refute rendered_output =~ "this-is-a-high-risk-password"
    refute rendered_output =~ "ghp_1234567890abcdefghijklmnop"
    refute rendered_output =~ "<img src=x"
    assert rendered_output =~ "&lt;img src=x onerror=alert(1)&gt;"
    assert Enum.any?(first.gaps, &(&1[:category] == :guide_secret))
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0
    assert first.usage_cost_microunits == 0
    assert first.full_extension.model_cached_tokens == 0
    assert first.full_extension.model_reasoning_tokens == 0
  end

  test "RW3 reclassifies exact immutable changes and retains stale current reads only by policy",
       fixture do
    values = Map.new(UpdateClassifier.profile().inputs, &{&1, digest("#{&1}-1")})
    {:ok, before} = UpdateClassifier.manifest(values)
    {:ok, unchanged} = UpdateClassifier.manifest(values)

    fence = %{
      enrollment_revision: 3,
      source_revision: digest("source-1"),
      compiler_digest: Protocol.compiler_digest(),
      policy_digest: digest("policy-1")
    }

    attributes = %{
      repository_iri: fixture.repository_iri,
      tenant_iri: fixture.tenant_iri,
      change_trigger: "observed-default-branch",
      causal_revisions: %{
        before_source_revision: digest("source-1"),
        after_source_revision: digest("source-1"),
        trigger_revision: digest("trigger-1")
      },
      requested_profile: Protocol.compiler_profile(),
      priority: :normal,
      retained_read_policy: :allow,
      classification_fence: fence,
      current_fence: fence,
      impact: %{
        profile: "wiki-impact-manifest/1.0.0",
        proven?: false,
        affected_page_iris: [],
        digest:
          Contract.digest(%{
            profile: "wiki-impact-manifest/1.0.0",
            proven?: false,
            affected_page_iris: []
          })
      }
    }

    assert {:ok, %{action: :no_change}} =
             UpdateClassifier.classify(before, unchanged, attributes)

    {:ok, compiler_changed} =
      UpdateClassifier.manifest(Map.put(values, :compiler, digest("compiler-2")))

    assert {:ok, %{action: :full_rebuild, current_stale?: true}} =
             UpdateClassifier.classify(before, compiler_changed, attributes)

    authoritative = %{fence | source_revision: digest("source-2")}

    assert {:ok, staleness} =
             UpdateClassifier.staleness(fence, authoritative, %{retained_read_policy: :allow})

    assert staleness.stale?
    assert staleness.previous_edition_readable?
    assert staleness.requires_reclassification?
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

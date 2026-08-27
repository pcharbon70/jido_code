defmodule JidoCode.Knowledge.RepositoryWiki.GuideDiscoveryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GuideDiscovery
  alias JidoCode.Knowledge.ResourceIdentity

  setup do
    root =
      Path.join(System.tmp_dir!(), "jido-wiki-guides-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "docs/architecture"))
    File.mkdir_p!(Path.join(root, "guides"))
    File.mkdir_p!(Path.join(root, "handbook"))

    File.write!(
      Path.join(root, "README.md"),
      """
      ---
      title: Product guide
      audience: user
      custom:
        - ignored
      ---
      # Product guide

      Start here.
      """
    )

    File.write!(Path.join(root, "CONTRIBUTING.md"), "# Contributing\n\nPlease help.\n")
    File.write!(Path.join(root, "docs/architecture/0001-runtime.md"), "# Runtime design\n")
    File.write!(Path.join(root, "docs/API.md"), "# API reference\n")
    File.write!(Path.join(root, "guides/operations.md"), "# Operations\n")
    File.write!(Path.join(root, "handbook/security.md"), "# Security policy\n")
    File.write!(Path.join(root, "docs/binary.md"), <<0, 1, 2>>)
    File.write!(Path.join(root, "docs/large.md"), String.duplicate("x", 262_145))
    File.ln_s!(Path.join(root, "README.md"), Path.join(root, "docs/readme-link.md"))

    {:ok, repository} = ResourceIdentity.conceptual_repository("phase-3-guides")
    {:ok, tenant} = ResourceIdentity.deterministic(:policy_version, "phase-3-guides-tenant")

    {:ok, snapshot} =
      ResourceIdentity.deterministic(:repository_snapshot, "phase-3-guides-source")

    on_exit(fn -> File.rm_rf!(root) end)

    %{root: root, repository: repository, tenant: tenant, snapshot: snapshot}
  end

  test "discovers and classifies exact guides deterministically", fixture do
    attributes = attributes(fixture) |> Map.put(:configured_roots, ["handbook"])

    assert {:ok, first} = GuideDiscovery.discover(fixture.root, attributes)
    assert {:ok, second} = GuideDiscovery.discover(fixture.root, attributes)

    assert first == second
    assert first.digest == Contract.digest(Map.delete(first, :digest))
    assert first.profile_digest == GuideDiscovery.profile().digest
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0
    assert first.usage_cost_microunits == 0

    readme = Enum.find(first.guides, &(&1.path == "README.md"))
    assert readme.title == "Product guide"
    assert readme.title_evidence == :front_matter
    assert readme.audience == :user
    refute readme.ambiguous_classification?
    assert [%{anchor: "product-guide", level: 1}] = readme.headings
    assert is_binary(readme.source_ref)

    assert %{audience: :contributor} =
             Enum.find(first.guides, &(&1.path == "CONTRIBUTING.md"))

    assert %{audience: :architecture} =
             Enum.find(first.guides, &(&1.path == "docs/architecture/0001-runtime.md"))

    assert %{audience: :developer} = Enum.find(first.guides, &(&1.path == "docs/API.md"))
    assert %{audience: :operator} = Enum.find(first.guides, &(&1.path == "guides/operations.md"))
    assert %{audience: :policy} = Enum.find(first.guides, &(&1.path == "handbook/security.md"))

    reasons = MapSet.new(first.gaps, & &1.reason)
    assert MapSet.subset?(MapSet.new([:binary, :oversized, :symlinked]), reasons)
  end

  test "proves exact content again when a guide is read", fixture do
    assert {:ok, manifest} = GuideDiscovery.discover(fixture.root, attributes(fixture))
    guide = Enum.find(manifest.guides, &(&1.path == "README.md"))

    assert {:ok, source} = GuideDiscovery.read(fixture.root, guide)
    assert digest(source) == guide.digest

    File.write!(Path.join(fixture.root, "README.md"), "# Changed after discovery\n")
    assert {:error, %{kind: :conflict}} = GuideDiscovery.read(fixture.root, guide)
  end

  test "derives renames, duplicates, title collisions, and moved anchors from manifests",
       fixture do
    File.write!(Path.join(fixture.root, "guides/a.md"), "# Shared\n\n# Target\n")
    File.write!(Path.join(fixture.root, "guides/copy.md"), "# Shared\n\n# Target\n")
    assert {:ok, prior} = GuideDiscovery.discover(fixture.root, attributes(fixture))

    File.rename!(
      Path.join(fixture.root, "guides/a.md"),
      Path.join(fixture.root, "guides/renamed.md")
    )

    File.write!(
      Path.join(fixture.root, "guides/copy.md"),
      "# Shared\n\n# Target\n\n# Target\n"
    )

    File.write!(Path.join(fixture.root, "guides/duplicate.md"), "# Product guide\n")

    assert {:ok, current} =
             GuideDiscovery.discover(
               fixture.root,
               attributes(fixture) |> Map.put(:predecessor, prior)
             )

    assert Enum.any?(current.changes.renamed, fn rename ->
             rename.from == "guides/a.md" and rename.to == "guides/renamed.md"
           end)

    assert "guides/copy.md" in current.changes.modified

    assert Enum.any?(current.changes.moved_anchors, fn finding ->
             finding.path == "guides/copy.md" and finding.title == "Target" and
               finding.from == "target" and finding.to == "target-2"
           end)

    assert Enum.any?(current.changes.title_collisions, fn collision ->
             collision.value == "Product guide" and
               collision.paths == ["README.md", "guides/duplicate.md"]
           end)
  end

  test "rejects traversal, raised limits, parser-selected roots, and symlink roots", fixture do
    assert {:error, %{kind: :invalid_input}} =
             GuideDiscovery.discover(
               fixture.root,
               attributes(fixture) |> Map.put(:configured_roots, ["../private"])
             )

    raised = %{GuideDiscovery.profile().limits | files: 513}

    assert {:error, %{kind: :invalid_input}} =
             GuideDiscovery.discover(
               fixture.root,
               attributes(fixture) |> Map.put(:limits, raised)
             )

    symlink = fixture.root <> "-link"
    File.ln_s!(fixture.root, symlink)
    on_exit(fn -> File.rm_rf!(symlink) end)

    assert {:error, %{kind: :invalid_input}} =
             GuideDiscovery.discover(symlink, attributes(fixture))
  end

  defp attributes(fixture) do
    %{
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      source_snapshot_iri: fixture.snapshot,
      source_revision: digest("phase-3-source-revision"),
      limits: GuideDiscovery.profile().limits
    }
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

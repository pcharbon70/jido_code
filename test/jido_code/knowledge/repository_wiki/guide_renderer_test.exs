defmodule JidoCode.Knowledge.RepositoryWiki.GuideRendererTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GuideDiscovery
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.ResourceIdentity

  setup do
    root =
      Path.join(System.tmp_dir!(), "jido-wiki-renderer-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "guides"))

    source = """
    ---
    title: Safe renderer
    audience: developer
    ---
    # Safe renderer

    Read the [other guide](other.md), [section](#details), and [Hex](https://hex.pm/packages/req).

    [Unsafe](javascript:alert(1)) [Traversal](../../private.md)

    <img src=x onerror=alert(1)>

    ## Details

    - one
    2. two

    | Name | Value |
    | --- | --- |
    | mode | deterministic |

    ```elixir
    IO.puts("shown as code, never executed")
    ```
    """

    File.write!(Path.join(root, "guides/safe.md"), source)
    File.write!(Path.join(root, "guides/other.md"), "# Other\n")

    {:ok, repository} = ResourceIdentity.conceptual_repository("phase-3-renderer")
    {:ok, tenant} = ResourceIdentity.deterministic(:policy_version, "phase-3-renderer-tenant")

    {:ok, snapshot} =
      ResourceIdentity.deterministic(:repository_snapshot, "phase-3-renderer-source")

    attributes = %{
      repository_iri: repository,
      tenant_iri: tenant,
      source_snapshot_iri: snapshot,
      source_revision: digest("phase-3-renderer-revision"),
      limits: GuideDiscovery.profile().limits
    }

    {:ok, manifest} = GuideDiscovery.discover(root, attributes)
    guide = Enum.find(manifest.guides, &(&1.path == "guides/safe.md"))
    {:ok, admitted_source} = GuideDiscovery.read(root, guide)

    on_exit(fn -> File.rm_rf!(root) end)

    %{
      root: root,
      guide: guide,
      source: admitted_source,
      known_paths: Enum.map(manifest.guides, & &1.path)
    }
  end

  test "renders a bounded structural subset with stable anchors and reviewed links", fixture do
    attributes = %{known_paths: fixture.known_paths, limits: GuideRenderer.profile().limits}

    assert {:ok, first} = GuideRenderer.render(fixture.source, fixture.guide, attributes)
    assert {:ok, second} = GuideRenderer.render(fixture.source, fixture.guide, attributes)
    assert first == second
    assert first.digest == Contract.digest(Map.delete(first, :digest))
    assert first.profile_digest == GuideRenderer.profile().digest
    assert first.activation_allowed?
    assert first.blocking_findings == []
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0

    assert Enum.map(first.table_of_contents, & &1.anchor) == ["safe-renderer", "details"]
    assert Enum.any?(first.blocks, &(&1.type == :code_block))
    assert Enum.any?(first.blocks, &(&1.type == :table_row))
    assert :raw_html_escaped in first.warnings

    html_block = Enum.find(first.blocks, &String.contains?(Map.get(&1, :text, ""), "img src"))
    refute html_block.text =~ "<img src=x"
    assert html_block.text == "&lt;img src=x onerror=alert(1)&gt;"

    assert Enum.any?(
             first.links,
             &(&1.status == :resolved and &1.source_path == "guides/other.md")
           )

    assert Enum.any?(first.links, &(&1.kind == :guide_anchor and &1.status == :resolved))
    assert Enum.any?(first.links, &(&1.status == :verified and &1.destination =~ "hex.pm"))
    assert Enum.any?(first.links, &(&1.status == :text_only and &1.reason == :unsafe_scheme))

    assert Enum.any?(first.links, fn link ->
             link.status == :text_only and link.reason == :unresolved_repository_reference
           end)
  end

  test "blocks activation and retains only redacted secret diagnostics", fixture do
    source = """
    # Credentials

    password = "this-is-a-high-risk-password"
    token: ghp_1234567890abcdefghijklmnop
    -----BEGIN PRIVATE KEY-----
    """

    File.write!(Path.join(fixture.root, "guides/secret.md"), source)

    {:ok, manifest} =
      GuideDiscovery.discover(fixture.root, %{
        repository_iri: resource(:repository_snapshot, "secret-repository"),
        tenant_iri: resource(:policy_version, "secret-tenant"),
        source_snapshot_iri: resource(:repository_snapshot, "secret-source"),
        source_revision: digest("secret-revision"),
        limits: GuideDiscovery.profile().limits
      })

    guide = Enum.find(manifest.guides, &(&1.path == "guides/secret.md"))
    assert {:ok, admitted_source} = GuideDiscovery.read(fixture.root, guide)

    assert {:ok, rendered} =
             GuideRenderer.render(admitted_source, guide, %{
               known_paths: Enum.map(manifest.guides, & &1.path),
               limits: GuideRenderer.profile().limits
             })

    refute rendered.activation_allowed?
    assert rendered.counts.secrets == 3

    assert Enum.all?(
             rendered.blocking_findings,
             &(&1.diagnostic == "redacted high-risk credential pattern")
           )

    assert Enum.all?(rendered.blocking_findings, &Contract.digest?(&1.fingerprint))

    output = inspect(rendered)
    refute output =~ "this-is-a-high-risk-password"
    refute output =~ "ghp_1234567890abcdefghijklmnop"
    assert output =~ "REDACTED HIGH-RISK CONTENT"
  end

  test "rejects parser extensions, source drift, and raised rendering limits", fixture do
    base = %{known_paths: fixture.known_paths, limits: GuideRenderer.profile().limits}

    assert {:error, %{kind: :invalid_input}} =
             GuideRenderer.render(
               fixture.source,
               fixture.guide,
               Map.put(base, :parser_extensions, ["unsafe"])
             )

    assert {:error, %{kind: :conflict}} =
             GuideRenderer.render(fixture.source <> "changed", fixture.guide, base)

    raised = %{GuideRenderer.profile().limits | links: 257}

    assert {:error, %{kind: :invalid_input}} =
             GuideRenderer.render(fixture.source, fixture.guide, %{base | limits: raised})
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

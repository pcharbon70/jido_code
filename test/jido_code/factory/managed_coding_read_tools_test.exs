defmodule JidoCode.Factory.ManagedCodingReadToolsTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.ReadRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Integrations.ManagedCodingReadTools
  alias JidoCode.Knowledge.ResourceIdentity

  setup context do
    root = Path.join(System.tmp_dir!(), "jido-code-managed-read-#{context.test}")
    File.rm_rf!(root)
    File.mkdir_p!(Path.join(root, "lib"))

    File.write!(
      Path.join(root, "lib/example.ex"),
      "defmodule Example do\n  def find_item(value), do: {:ok, value}\nend\n"
    )

    File.write!(
      Path.join(root, "lib/other.ex"),
      "defmodule Other do\n  def find_item, do: :ok\nend\n"
    )

    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, tree} =
      WorkspaceDigest.tree(root, %{file_count: 10, input_bytes: 32_768, disk_bytes: 65_536})

    %{root: root, request: request!(root, tree.digest)}
  end

  test "searches deterministically with scope-bound continuation", fixture do
    assert {:ok, first} =
             ManagedCodingReadTools.search_source(fixture.request, %{
               query: "find_item",
               max_results: 1
             })

    assert [%{path: "lib/example.ex", untrusted_data?: true}] = first.data.results
    assert first.data.omitted?
    assert %{offset: 1} = continuation = first.data.continuation

    assert {:ok, second} =
             ManagedCodingReadTools.search_source(fixture.request, %{
               query: "find_item",
               max_results: 1,
               continuation: continuation
             })

    assert [%{path: "lib/other.ex"}] = second.data.results
    assert second.data.continuation == nil

    other_actor = %{fixture.request | actor_iri: resource(:authorization_grant, "other-actor")}

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingReadTools.search_source(other_actor, %{
               query: "find_item",
               continuation: continuation
             })
  end

  test "inspects syntactic symbols only at the exact analysis revision", fixture do
    assert {:ok, result} =
             ManagedCodingReadTools.inspect_symbol(fixture.request, %{
               symbol: "find_item",
               expected_analysis_revision: fixture.request.analysis_revision
             })

    assert result.data.analysis_revision == fixture.request.analysis_revision
    assert Enum.map(result.data.matches, & &1.path) == ["lib/example.ex", "lib/other.ex"]
    assert result.data.uncertainty == :syntactic

    assert {:error, %{kind: :invalid_input}} =
             ManagedCodingReadTools.inspect_symbol(fixture.request, %{
               symbol: "find_item",
               expected_analysis_revision: digest("stale")
             })
  end

  test "reads exact digests with bounded ranges and rejects secrets", fixture do
    path = Path.join(fixture.root, "lib/example.ex")
    content = File.read!(path)
    expected = "sha256:" <> WorkspaceDigest.digest(content)

    assert {:ok, result} =
             ManagedCodingReadTools.read_file(fixture.request, %{
               path: "lib/example.ex",
               expected_digest: expected,
               max_bytes: 12,
               range: %{offset: 0, length: 12},
               classification: :internal
             })

    assert result.data.bytes == 12
    assert result.data.truncated?
    assert result.data.untrusted_data?
    assert result.authority.snapshot_iri == fixture.request.snapshot_iri

    assert {:error, %{kind: :invalid_input}} =
             ManagedCodingReadTools.read_file(fixture.request, %{
               path: "lib/example.ex",
               expected_digest: "sha256:" <> digest("stale")
             })

    secret_path = Path.join(fixture.root, "lib/secret.ex")
    File.write!(secret_path, "token = ghp_abcdefghijklmnop")
    secret_digest = "sha256:" <> WorkspaceDigest.digest(File.read!(secret_path))

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingReadTools.read_file(fixture.request, %{
               path: "lib/secret.ex",
               expected_digest: secret_digest
             })
  end

  defp request!(root, workspace_digest) do
    {:ok, request} =
      ReadRequest.new(%{
        repository_iri: resource(:repository_snapshot, "read-repository"),
        snapshot_iri: resource(:repository_snapshot, "read-snapshot"),
        actor_iri: resource(:authorization_grant, "read-actor"),
        workspace_iri: resource(:sandbox_instance, "read-workspace"),
        workspace_root: root,
        workspace_digest: workspace_digest,
        analysis_revision: digest("analysis"),
        allowed_paths: ["lib"],
        visible_classifications: [:public, :internal],
        max_results: 10,
        max_bytes: 32_768
      })

    request
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

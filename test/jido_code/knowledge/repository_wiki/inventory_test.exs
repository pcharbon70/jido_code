defmodule JidoCode.Knowledge.RepositoryWiki.InventoryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  setup do
    root =
      Path.join(System.tmp_dir!(), "jido-wiki-inventory-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "docs/architecture"))
    File.mkdir_p!(Path.join(root, "lib/demo"))
    File.mkdir_p!(Path.join(root, "test/demo"))
    File.mkdir_p!(Path.join(root, "guides"))

    File.write!(Path.join(root, "README.md"), "# Demo\r\n")
    File.write!(Path.join(root, "mix.exs"), "raise \"must never execute\"\n")
    File.write!(Path.join(root, "mix.lock"), "%{}\n")
    File.write!(Path.join(root, "docs/architecture/0001-demo.md"), "# ADR\n")
    File.write!(Path.join(root, "docs/naïve.md"), "# Unicode\n")
    File.write!(Path.join(root, "lib/demo/example.ex"), "defmodule Demo.Example do\nend\n")

    File.write!(
      Path.join(root, "test/demo/example_test.exs"),
      "defmodule Demo.ExampleTest do\nend\n"
    )

    File.write!(Path.join(root, "guides/user.md"), "# User guide\n")
    File.write!(Path.join(root, "docs/binary.md"), <<0, 1, 2>>)
    File.write!(Path.join(root, "docs/unsupported.png"), "not-an-image")
    File.write!(Path.join(root, "docs/large.md"), String.duplicate("x", 262_145))
    File.ln_s!(Path.join(root, "README.md"), Path.join(root, "docs/readme-link.md"))

    {:ok, repository} = ResourceIdentity.conceptual_repository("wiki-inventory-fixture")

    {:ok, snapshot} =
      ResourceIdentity.deterministic(:repository_snapshot, "wiki-inventory-snapshot")

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    on_exit(fn -> File.rm_rf!(root) end)

    %{root: root, repository: repository, snapshot: snapshot, control_graph: control_graph}
  end

  test "inventories exact text sources deterministically without evaluating repository code",
       fixture do
    attributes = attributes(fixture)

    assert {:ok, first} = SourceInventory.scan(fixture.root, attributes)
    assert {:ok, second} = SourceInventory.scan(fixture.root, attributes)

    assert first.digest == second.digest
    assert first.entries == second.entries
    assert first.module_names == ["Demo.Example", "Demo.ExampleTest"]
    assert first.model_calls == 0
    assert first.model_tokens == 0
    assert [%{family: :repository_control, revision: 7}] = first.graph_sources
    assert Enum.any?(first.entries, &(&1.path == "docs/naïve.md"))
    assert Enum.any?(first.entries, &(&1.kind == :mix_manifest))

    reasons = first.gaps |> Enum.map(& &1.reason) |> MapSet.new()
    assert MapSet.subset?(MapSet.new([:binary, :unsupported, :oversized, :symlinked]), reasons)
  end

  test "rejects traversal, caller-selected absolute roots, raised limits, and symlink roots",
       fixture do
    assert {:error, %{kind: :invalid_input}} =
             SourceInventory.scan(
               fixture.root,
               attributes(fixture) |> Map.put(:documentation_roots, ["../private"])
             )

    assert {:error, %{kind: :invalid_input}} =
             SourceInventory.scan(
               fixture.root,
               attributes(fixture) |> Map.put(:source_roots, [fixture.root])
             )

    raised = %{SourceInventory.profile().limits | files: 2_001}

    assert {:error, %{kind: :invalid_input}} =
             SourceInventory.scan(
               fixture.root,
               attributes(fixture) |> Map.put(:limits, raised)
             )

    link = fixture.root <> "-link"
    File.ln_s!(fixture.root, link)
    on_exit(fn -> File.rm_rf!(link) end)

    assert {:error, %{kind: :invalid_input}} =
             SourceInventory.scan(link, attributes(fixture))
  end

  test "records missing registered roots as explicit gaps", fixture do
    attributes =
      fixture
      |> attributes()
      |> Map.put(:guide_roots, ["missing-guides"])

    assert {:ok, inventory} = SourceInventory.scan(fixture.root, attributes)
    assert %{path: "missing-guides", reason: :missing} in inventory.gaps
  end

  defp attributes(fixture) do
    %{
      repository_iri: fixture.repository,
      source_snapshot_iri: fixture.snapshot,
      source_fence: "git:sha256:#{digest("source")}",
      accepted_graph_sources: [
        %{
          repository_iri: fixture.repository,
          graph_iri: fixture.control_graph,
          resource_iri: resource(:control_constraint, "accepted-wiki-fact"),
          revision: 7,
          digest: digest("accepted-wiki-fact")
        }
      ],
      limits: SourceInventory.profile().limits
    }
  end

  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

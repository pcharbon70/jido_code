defmodule JidoCode.Knowledge.Ontology.ReleaseTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  @graph "https://jido.run/graph/ontology/1.0.0"
  @canonical_sha "fe260c98204872ace7369728c4db13696f76c724cc5f06b4bfe7bf5b18569e41"
  @package_sha "5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903"

  test "verifies and canonicalizes the immutable ontology package deterministically" do
    assert {:ok, manifest} = Release.verify()
    assert manifest.version == "1.0.0"
    assert manifest.shape_version == "1.0.0"
    assert manifest.graph_iri == @graph
    assert manifest.package_sha256 == @package_sha
    assert manifest.canonical_nquads_sha256 == @canonical_sha

    assert {:ok, dataset} = Release.dataset()
    assert RDF.Dataset.graph_names(dataset) == [RDF.iri(@graph)]
    assert length(RDF.Dataset.quads(dataset)) == 971

    assert {:ok, first} = Release.canonical_nquads()
    assert {:ok, second} = Release.canonical_nquads()
    assert first == second

    assert {:ok, checksum} = Release.checksum()
    assert checksum.package_sha256 == @package_sha
    assert checksum.canonical_nquads_sha256 == @canonical_sha
    assert checksum.quad_count == 971
  end

  test "rejects changed sources before parsing or loading" do
    root = copy_release!()
    on_exit(fn -> File.rm_rf!(root) end)
    File.write!(Path.join(root, "factory.ttl"), "\n# changed\n", [:append])

    assert {:error, %Error{kind: :corrupt, operation: :verify_ontology_sources}} =
             Release.verify("1.0.0", root: root)
  end

  test "loads and replays the release only in its immutable ontology graph", context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{server: server, writer: writer} = start_substrate!(config)

    assert {:ok, loaded} = Release.load(store_server: server, writer: writer)
    refute loaded.receipt.replayed?
    assert loaded.graph_iri == @graph
    assert loaded.receipt.dataset_revision == 1

    assert {:ok, %{@graph => 971}} =
             StoreServer.request(server, {:graph_counts, [@graph]})

    assert {:ok, replayed} = Release.load(store_server: server, writer: writer)
    assert replayed.receipt.replayed?
    assert replayed.receipt.dataset_revision == 1
    assert StoreServer.summary(server).dataset_revision == 1
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [self()],
           write: [writer_name],
           maintenance: [self()]
         }}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    %{server: server, writer: writer}
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp await_health(server, expected, attempts \\ 500)
  defp await_health(server, _expected, 0), do: StoreServer.summary(server)

  defp await_health(server, expected, attempts) do
    summary = StoreServer.summary(server)

    if summary.health_state == expected do
      summary
    else
      Process.sleep(10)
      await_health(server, expected, attempts - 1)
    end
  end

  defp copy_release! do
    source = Application.app_dir(:jido_code, "priv/ontology/1.0.0")

    target =
      Path.join(
        System.tmp_dir!(),
        "jido-code-ontology-copy-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(target)

    source
    |> File.ls!()
    |> Enum.each(fn name -> File.cp!(Path.join(source, name), Path.join(target, name)) end)

    target
  end

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-ontology-#{name}-#{unique}")
  end
end

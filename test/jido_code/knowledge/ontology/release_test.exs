defmodule JidoCode.Knowledge.Ontology.ReleaseTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  @graph "https://jido.run/graph/ontology/1.3.0"
  @canonical_sha "2b2162ec5aa9cd145786ec99d2c3f9b7f3cd1f839541760c90c33d7acfb582d3"
  @package_sha "bf037bef8293f1aedf79f675db792286a330cff2a664e2d2d7766536601309cf"

  test "verifies and canonicalizes the immutable ontology package deterministically" do
    assert {:ok, manifest} = Release.verify()
    assert manifest.version == "1.3.0"
    assert manifest.shape_version == "1.3.0"
    assert manifest.graph_iri == @graph
    assert manifest.package_sha256 == @package_sha
    assert manifest.canonical_nquads_sha256 == @canonical_sha

    assert {:ok, dataset} = Release.dataset()
    assert RDF.Dataset.graph_names(dataset) == [RDF.iri(@graph)]
    assert length(RDF.Dataset.quads(dataset)) == 1_940

    assert {:ok, first} = Release.canonical_nquads()
    assert {:ok, second} = Release.canonical_nquads()
    assert first == second

    assert {:ok, checksum} = Release.checksum()
    assert checksum.package_sha256 == @package_sha
    assert checksum.canonical_nquads_sha256 == @canonical_sha
    assert checksum.quad_count == 1_940
  end

  test "retains deterministic read compatibility for immutable prior releases" do
    assert Release.versions() == ["1.3.0", "1.2.0", "1.1.0", "1.0.0"]
    assert {:ok, segmented} = Release.verify("1.2.0")
    assert segmented.version == "1.2.0"
    assert {:ok, prior} = Release.verify("1.1.0")
    assert prior.version == "1.1.0"
    assert prior.shape_version == "1.1.0"
    assert {:ok, legacy} = Release.verify("1.0.0")
    assert legacy.version == "1.0.0"
    assert legacy.shape_version == "1.0.0"
    assert legacy.graph_iri == "https://jido.run/graph/ontology/1.0.0"
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
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{server: server, writer: writer} = start_substrate!(config)

    on_exit(fn ->
      stop_process(writer)
      stop_process(server)
      File.rm_rf!(root)
    end)

    assert {:ok, loaded} = Release.load(store_server: server, writer: writer)
    refute loaded.receipt.replayed?
    assert loaded.graph_iri == @graph
    assert loaded.receipt.dataset_revision == 1

    assert {:ok, %{@graph => 1_940}} =
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

  defp stop_process(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  catch
    :exit, _reason -> :ok
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

defmodule JidoCode.Knowledge.Ontology.StartupGateTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  setup context do
    root = unique_root(context)
    on_exit(fn -> remove_root!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config}
  end

  test "reopens a complete current semantic dataset", %{config: config} do
    first = start_substrate!(config)
    assert {:ok, _loaded} = Release.load(store_server: first.server, writer: first.writer)
    stop_process(first.writer)
    stop_process(first.server)

    second = start_substrate!(config)
    assert StoreServer.summary(second.server).ready?
    assert StoreServer.summary(second.server).dataset_revision == 1
  end

  test "reopens the immutable legacy ontology for dual-read projections", %{config: config} do
    first = start_substrate!(config)

    assert {:ok, %{version: "1.0.0"}} =
             Release.load(version: "1.0.0", store_server: first.server, writer: first.writer)

    stop_process(first.writer)
    stop_process(first.server)

    second = start_substrate!(config)
    assert StoreServer.summary(second.server).ready?
    assert StoreServer.summary(second.server).dataset_revision == 1
  end

  test "blocks startup when a semantic dataset contains an unregistered graph", %{config: config} do
    first = start_substrate!(config)
    assert {:ok, _loaded} = Release.load(store_server: first.server, writer: first.writer)
    stop_process(first.writer)
    stop_process(first.server)

    {:ok, raw_store} = TripleStore.open(Config.active_store_path(config), schema: :quad)

    assert {:ok, 1} =
             TripleStore.update(raw_store, """
             INSERT DATA {
               GRAPH <https://jido.run/graph/unregistered/data> {
                 <https://jido.run/id/resource/invalid>
                   <https://jido.run/ontology/factory#displayId> "invalid" .
               }
             }
             """)

    :ok = TripleStore.close(raw_store)
    second = start_store!(config)
    summary = await_health(second, :incompatible)
    refute summary.ready?
    assert summary.failure.operation == :required_graph_migration
  end

  test "blocks startup when only an unknown ontology release is present", %{config: config} do
    first = start_substrate!(config)
    stop_process(first.writer)
    stop_process(first.server)

    {:ok, raw_store} = TripleStore.open(Config.active_store_path(config), schema: :quad)

    assert {:ok, 1} =
             TripleStore.update(raw_store, """
             INSERT DATA {
               GRAPH <https://jido.run/graph/ontology/9.9.9> {
                 <https://jido.run/id/resource/invalid>
                   <https://jido.run/ontology/factory#displayId> "invalid" .
               }
             }
             """)

    :ok = TripleStore.close(raw_store)
    second = start_store!(config)
    summary = await_health(second, :incompatible)
    refute summary.ready?
    assert summary.failure.operation == :required_graph_migration
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{read: [self()], write: [writer_name], maintenance: [self()]}}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    %{server: server, writer: writer}
  end

  defp start_store!(config) do
    readiness = start_child!({Readiness, name: nil})

    start_child!(
      {StoreServer,
       name: nil,
       readiness: readiness,
       config: config,
       authorized_callers: %{read: [self()], write: [self()], maintenance: [self()]}}
    )
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp stop_process(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  end

  defp remove_root!(root, attempts \\ 20)
  defp remove_root!(root, 0), do: File.rm_rf!(root)

  defp remove_root!(root, attempts) do
    case File.rm_rf(root) do
      {:ok, _paths} ->
        :ok

      {:error, _reason, _path} ->
        Process.sleep(25)
        remove_root!(root, attempts - 1)
    end
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

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-startup-gate-#{name}-#{unique}")
  end
end

defmodule JidoCode.Knowledge.StoreServerTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.TestSupport.UnavailableNative

  @moduletag capture_log: true

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config, root: root}
  end

  test "opens one quad store, bootstraps metadata, and exposes only bounded summaries", %{
    config: config,
    root: root
  } do
    {readiness, server} = start_store!(config, authorized_callers())
    summary = await_health(server, :ready)

    assert summary == %{
             dataset_revision: 0,
             durability: :sync,
             failure: nil,
             health_state: :ready,
             lineage_present?: true,
             ready?: true,
             schema: :quad,
             schema_version: 1,
             store_open?: true
           }

    refute inspect(summary) =~ root
    refute inspect(summary) =~ "dict_manager"

    assert {:ok,
            %{
              dataset_revision: 0,
              system_graph_revision: 0,
              store_schema_version: 1,
              backend_schema_version: 2,
              lineage_present?: true
            }} = StoreServer.request(server, :metadata)

    assert {:ok, %{graph_count: 1, quad_count: 6}} =
             StoreServer.request(server, :statistics)

    assert Readiness.snapshot(readiness).state == :ready
  end

  test "rejects unapproved callers and enforces controlled maintenance", %{config: config} do
    {_readiness, locked_server} = start_store!(config, %{})
    assert await_health(locked_server, :ready).ready?

    assert {:error, %Error{kind: :unauthorized, operation: :store_request}} =
             StoreServer.request(locked_server, :metadata)

    stop_supervised_process(locked_server)

    {_readiness, server} = start_store!(config, authorized_callers())
    assert await_health(server, :ready).ready?

    assert {:ok, %{health_state: :maintenance, reason: :restore}} =
             StoreServer.request(server, {:enter_maintenance, :restore})

    assert {:error, %Error{kind: :unavailable}} = StoreServer.request(server, :metadata)

    assert {:ok, %{health_state: :ready}} = StoreServer.request(server, :leave_maintenance)
    assert StoreServer.summary(server).ready?

    assert {:error, %Error{kind: :invalid_input, operation: :maintenance_reason}} =
             StoreServer.request(server, {:enter_maintenance, :unsupported})
  end

  test "closes deterministically and reopens the same lineage and revisions", %{config: config} do
    {_readiness, first} = start_store!(config, authorized_callers())
    assert await_health(first, :ready).ready?
    assert {:ok, first_metadata} = StoreServer.request(first, :metadata)

    stop_supervised_process(first)

    {_readiness, second} = start_store!(config, authorized_callers())
    assert await_health(second, :ready).ready?
    assert {:ok, second_metadata} = StoreServer.request(second, :metadata)
    assert second_metadata == first_metadata
  end

  test "a second owner remains alive but locked and never opens fallback state", %{config: config} do
    {_first_readiness, first} = start_store!(config, authorized_callers())
    assert await_health(first, :ready).ready?

    {second_readiness, second} = start_store!(config, authorized_callers())
    summary = await_health(second, :locked)

    assert Process.alive?(second)
    refute summary.store_open?
    refute summary.ready?
    assert summary.failure.kind == :locked
    assert Readiness.snapshot(second_readiness).state == :locked
  end

  test "missing native support fails before creating or opening a dataset", %{config: config} do
    {_readiness, server} =
      start_store!(config, authorized_callers(), native: UnavailableNative)

    summary = await_health(server, :unavailable)
    refute summary.store_open?
    assert summary.failure.operation == :load_native_backend
    refute File.exists?(Config.active_store_path(config))
  end

  test "incompatible persisted metadata fails closed", %{config: config} do
    {_readiness, first} = start_store!(config, authorized_callers())
    assert await_health(first, :ready).ready?
    stop_supervised_process(first)

    {:ok, raw_store} = TripleStore.open(Config.active_store_path(config), schema: :quad)

    assert {:ok, 2} =
             TripleStore.update(raw_store, """
             DELETE DATA {
               GRAPH <urn:jido-code:graph:system> {
                 <urn:jido-code:dataset> <urn:jido-code:vocab:storeSchemaVersion> 1 .
               }
             };
             INSERT DATA {
               GRAPH <urn:jido-code:graph:system> {
                 <urn:jido-code:dataset> <urn:jido-code:vocab:storeSchemaVersion> 999 .
               }
             }
             """)

    :ok = TripleStore.close(raw_store)

    {_readiness, incompatible} = start_store!(config, authorized_callers())
    summary = await_health(incompatible, :incompatible)
    refute summary.store_open?
    assert summary.failure.operation == :verify_store_metadata
  end

  test "a non-empty dataset without substrate metadata is never bootstrapped", %{config: config} do
    File.mkdir_p!(config.root)
    {:ok, raw_store} = TripleStore.open(Config.active_store_path(config), schema: :quad)

    assert {:ok, 1} =
             TripleStore.update(raw_store, """
             INSERT DATA {
               GRAPH <urn:jido-code:graph:unexpected> {
                 <urn:jido-code:subject> <urn:jido-code:predicate> <urn:jido-code:object> .
               }
             }
             """)

    :ok = TripleStore.close(raw_store)

    {_readiness, server} = start_store!(config, authorized_callers())
    summary = await_health(server, :incompatible)
    refute summary.store_open?
    assert summary.failure.operation == :bootstrap_store_metadata
  end

  test "a physical triple-schema database is rejected without replacement", %{config: config} do
    File.mkdir_p!(config.root)
    {:ok, raw_store} = TripleStore.open(Config.active_store_path(config), schema: :triple)
    :ok = TripleStore.close(raw_store)

    {_readiness, server} = start_store!(config, authorized_callers())
    summary = await_health(server, :incompatible)
    refute summary.store_open?
    assert summary.failure.operation == :open_store
  end

  defp start_store!(config, authorized_callers, options \\ []) do
    readiness =
      start_supervised!(
        Supervisor.child_spec({Readiness, name: nil}, id: make_ref(), restart: :temporary)
      )

    store_options =
      [
        name: nil,
        readiness: readiness,
        config: config,
        authorized_callers: authorized_callers
      ] ++ options

    server =
      start_supervised!(
        Supervisor.child_spec({StoreServer, store_options}, id: make_ref(), restart: :temporary)
      )

    {readiness, server}
  end

  defp authorized_callers do
    %{read: [self()], write: [self()], maintenance: [self()]}
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

  defp stop_supervised_process(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  end

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-store-server-#{name}-#{unique}")
  end
end

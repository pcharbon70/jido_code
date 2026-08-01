defmodule JidoCode.Knowledge.Phase02IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Supervisor, as: KnowledgeSupervisor
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.WriteReceipt
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.RestartGateNative

  @moduletag capture_log: true

  @graph "https://jido.code/tests/graphs/phase-02-integration"
  @external_graph "https://jido.code/tests/graphs/phase-02-crash"

  setup context do
    root = unique_root(context)
    on_exit(fn -> JidoCode.TestSupport.Filesystem.remove_root!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config}
  end

  test "supervision fails closed and replaces a killed store owner before accepting work", %{
    config: config
  } do
    :ok = RestartGateNative.configure(self())
    on_exit(&RestartGateNative.clear/0)

    substrate = start_substrate!(config, native: RestartGateNative)
    old_store = GenServer.whereis(substrate.store_server)
    old_monitor = Process.monitor(old_store)
    batch = batch!("queued-before-owner-death", Identity.commit_iri(), 0, 0)

    :ok = :sys.suspend(old_store)
    commit_task = Task.async(fn -> Writer.commit(substrate.writer, batch, []) end)
    assert eventually(fn -> message_queue_length(old_store) > 0 end)

    Process.exit(old_store, :kill)
    assert_receive {:DOWN, ^old_monitor, :process, ^old_store, :killed}
    assert_receive {:native_verification_blocked, replacement_store}, 5_000
    refute replacement_store == old_store

    assert Readiness.snapshot(substrate.readiness).state == :opening

    assert {:error, %Error{kind: :unavailable}} =
             Readiness.gate(substrate.readiness, :durable_command)

    assert {:error, %Error{kind: :unavailable}} = Task.await(commit_task, 5_000)
    send(replacement_store, :release_native_verification)
    assert await_ready(substrate.store_server).ready?

    assert {:ok, nil} = Writer.lookup(substrate.writer, batch.commit_id, [])

    assert {:ok, %{@graph => 0}} =
             StoreServer.request(substrate.store_server, {:graph_counts, [@graph]})
  end

  test "a BEAM killed before commit reopens with no fabricated receipt", %{config: config} do
    commit_id = Identity.commit_iri()
    port = start_external_writer(config.root, "before_commit", commit_id)
    assert_port_marker(port, "PHASE2_READY")
    kill_external_beam(port)

    substrate = start_substrate!(config)
    assert {:ok, nil} = Writer.lookup(substrate.writer, commit_id, [])

    assert {:ok, %{@external_graph => 0}} =
             StoreServer.request(
               substrate.store_server,
               {:graph_counts, [@external_graph]}
             )
  end

  test "a BEAM killed after commit recovers the durable receipt and graph revision", %{
    config: config
  } do
    commit_id = Identity.commit_iri()
    port = start_external_writer(config.root, "after_commit", commit_id)
    assert_port_marker(port, "PHASE2_COMMITTED #{commit_id}")
    kill_external_beam(port)

    substrate = start_substrate!(config)

    assert {:ok, %WriteReceipt{} = receipt} =
             Writer.lookup(substrate.writer, commit_id, [])

    assert receipt.dataset_revision == 1
    assert receipt.graph_revisions[@external_graph] == %{prior: 0, new: 1}

    assert {:ok, %{@external_graph => 1}} =
             StoreServer.request(
               substrate.store_server,
               {:graph_counts, [@external_graph]}
             )
  end

  test "checkpoint restore reproduces canonical asserted graph content and metadata", %{
    config: config
  } do
    substrate = start_substrate!(config)
    first = batch!("before-backup", Identity.commit_iri(), 0, 0)
    assert {:ok, first_receipt} = Writer.commit(substrate.writer, first, [])

    assert {:ok, before_export} = Maintenance.export(substrate.maintenance, :nquads, [])
    before_graph = exported_graph!(config, before_export.artifact_id, @graph)
    assert {:ok, backup} = Maintenance.backup(substrate.maintenance, [])

    second = batch!("after-backup", Identity.commit_iri(), 1, 1)
    assert {:ok, _second_receipt} = Writer.commit(substrate.writer, second, [])

    assert {:ok, restore_receipt} =
             Maintenance.restore(substrate.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert {:ok, after_export} = Maintenance.export(substrate.maintenance, :nquads, [])
    after_graph = exported_graph!(config, after_export.artifact_id, @graph)

    assert RDF.Graph.equal?(before_graph, after_graph)
    assert canonical_graph!(before_graph) == canonical_graph!(after_graph)
    assert backup.dataset_revision == first_receipt.dataset_revision
    assert restore_receipt.dataset_revision == backup.dataset_revision + 1
    assert StoreServer.summary(substrate.store_server).dataset_revision == 2
    assert StoreServer.summary(substrate.store_server).schema_compatible?
  end

  defp start_substrate!(config, options \\ []) do
    identity = System.unique_integer([:positive, :monotonic])
    readiness = {:global, {__MODULE__, :readiness, identity}}
    store_server = {:global, {__MODULE__, :store, identity}}
    writer = {:global, {__MODULE__, :writer, identity}}
    query_runner = {:global, {__MODULE__, :query_runner, identity}}
    maintenance = {:global, {__MODULE__, :maintenance, identity}}

    authorized_callers = %{
      read: [self(), query_runner],
      write: [writer],
      maintenance: [maintenance]
    }

    supervisor_options =
      [
        name: nil,
        readiness: readiness,
        store_server: store_server,
        writer: writer,
        query_runner: query_runner,
        maintenance: maintenance,
        config: config,
        authorized_callers: authorized_callers
      ] ++ options

    start_supervised!(
      Supervisor.child_spec(
        {KnowledgeSupervisor, supervisor_options},
        id: make_ref(),
        restart: :temporary
      )
    )

    assert await_ready(store_server).ready?

    %{
      readiness: readiness,
      store_server: store_server,
      writer: writer,
      query_runner: query_runner,
      maintenance: maintenance
    }
  end

  defp batch!(value, commit_id, dataset_revision, graph_revision) do
    quad =
      RDF.quad(
        "https://jido.code/tests/resources/#{value}",
        "https://jido.code/tests/vocab/value",
        value,
        @graph
      )

    {:ok, batch} =
      WriteBatch.new([quad],
        commit_id: commit_id,
        expected_dataset_revision: dataset_revision,
        expected_graph_revisions: %{@graph => graph_revision}
      )

    batch
  end

  defp exported_graph!(config, artifact_id, graph) do
    path = Path.join([config.backup_root, artifact_id, "dataset.nq"])
    {:ok, dataset} = path |> File.read!() |> RDF.NQuads.read_string()
    RDF.Dataset.graph(dataset, RDF.iri(graph))
  end

  defp canonical_graph!(graph) do
    graph
    |> RDF.Dataset.new()
    |> RDF.NQuads.write_string!(sort: true)
  end

  defp start_external_writer(root, mode, commit_id) do
    executable = System.find_executable("elixir") || raise "elixir executable not found"

    Port.open(
      {:spawn_executable, executable},
      [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args:
          Enum.map(
            ["-S", "mix", "run", "--no-start", "test/support/phase_02_crash_writer.exs"],
            &String.to_charlist/1
          ),
        cd: String.to_charlist(File.cwd!()),
        env: [
          {~c"MIX_ENV", ~c"test"},
          {~c"JIDO_PHASE2_CRASH_ROOT", String.to_charlist(root)},
          {~c"JIDO_PHASE2_CRASH_MODE", String.to_charlist(mode)},
          {~c"JIDO_PHASE2_COMMIT_ID", String.to_charlist(commit_id)}
        ]
      ]
    )
  end

  defp assert_port_marker(port, marker, output \\ "") do
    receive do
      {^port, {:data, data}} ->
        output = output <> data

        if String.contains?(output, marker) do
          :ok
        else
          assert_port_marker(port, marker, output)
        end

      {^port, {:exit_status, status}} ->
        flunk("external BEAM exited with #{status} before #{marker}: #{output}")
    after
      30_000 -> flunk("timed out waiting for #{marker}: #{output}")
    end
  end

  defp kill_external_beam(port) do
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    {_output, 0} = System.cmd("kill", ["-9", Integer.to_string(os_pid)])
    await_port_exit(port)
  end

  defp await_port_exit(port) do
    receive do
      {^port, {:exit_status, _status}} -> :ok
      {^port, {:data, _data}} -> await_port_exit(port)
    after
      5_000 -> flunk("external BEAM did not terminate")
    end
  end

  defp await_ready(server, attempts \\ 1_000)
  defp await_ready(server, 0), do: StoreServer.summary(server)

  defp await_ready(server, attempts) do
    summary = StoreServer.summary(server)

    if summary.ready? do
      summary
    else
      Process.sleep(10)
      await_ready(server, attempts - 1)
    end
  catch
    :exit, _reason ->
      Process.sleep(10)
      await_ready(server, attempts - 1)
  end

  defp eventually(callback, attempts \\ 500)
  defp eventually(callback, 0), do: callback.()

  defp eventually(callback, attempts) do
    if callback.() do
      true
    else
      Process.sleep(10)
      eventually(callback, attempts - 1)
    end
  end

  defp message_queue_length(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, length} -> length
      nil -> 0
    end
  end

  defp unique_root(context) do
    suffix = System.unique_integer([:positive, :monotonic])
    Path.join(System.tmp_dir!(), "jido-code-phase-02-#{context.test}-#{suffix}")
  end
end

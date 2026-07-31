defmodule JidoCode.Knowledge.BackupRestoreIntegrityTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.BackupReceipt
  alias JidoCode.Knowledge.Admin
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.DatasetSelector
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.IntegrityReport
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.Writer

  @moduletag capture_log: true

  @graph "https://jido.code/tests/graphs/backup"

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config}
  end

  test "creates private, checksummed checkpoint and standards-based export artifacts", %{
    config: config
  } do
    substrate = start_substrate!(config)
    commit_localized_data!(substrate.writer)

    assert {:ok, initial_health} =
             Admin.execute(:health, store_server: substrate.server)

    assert initial_health.schema_compatible?
    assert initial_health.dataset_revision == 1
    assert initial_health.last_integrity == nil
    assert initial_health.backup_age_seconds == nil

    assert {:error, %Error{kind: :invalid_input}} =
             Admin.execute(:backup, path: config.backup_root)

    assert {:ok, %BackupReceipt{artifact_kind: :checkpoint} = checkpoint} =
             Maintenance.backup(substrate.maintenance, [])

    assert checkpoint.dataset_revision == 1
    assert checkpoint.graph_count == 2
    assert checkpoint.quad_count > 2
    assert checkpoint.consistency == "exclusive_store_owner"

    assert {:ok, after_backup} =
             Admin.execute(:health, store_server: substrate.server)

    assert is_integer(after_backup.backup_age_seconds)
    assert after_backup.backup_age_seconds >= 0

    artifact_root = Path.join(config.backup_root, checkpoint.artifact_id)
    assert private_mode?(artifact_root, 0o700)
    assert private_mode?(Path.join(artifact_root, "manifest.json"), 0o600)
    assert File.dir?(Path.join(artifact_root, "checkpoint"))

    assert artifact_root
           |> Path.join("checkpoint/**/*")
           |> Path.wildcard(match_dot: true)
           |> Enum.all?(fn path ->
             private_mode?(path, if(File.dir?(path), do: 0o700, else: 0o600))
           end)

    assert {:ok, %BackupReceipt{artifact_kind: :nquads} = nquads_receipt} =
             Maintenance.export(substrate.maintenance, :nquads, [])

    assert {:ok, %BackupReceipt{artifact_kind: :trig} = trig_receipt} =
             Maintenance.export(substrate.maintenance, :trig, [])

    nquads =
      File.read!(Path.join([config.backup_root, nquads_receipt.artifact_id, "dataset.nq"]))

    trig = File.read!(Path.join([config.backup_root, trig_receipt.artifact_id, "dataset.trig"]))

    assert {:ok, nquads_dataset} = RDF.NQuads.read_string(nquads)
    assert {:ok, trig_dataset} = RDF.TriG.read_string(trig)
    assert RDF.Dataset.equal?(nquads_dataset, trig_dataset)
    assert nquads =~ ~s("bonjour"@fr)
    assert nquads =~ "http://www.w3.org/2001/XMLSchema#integer"

    assert {:ok, %IntegrityReport{status: :ok, issues: []}} =
             Admin.execute(:integrity, maintenance: substrate.maintenance)

    assert {:ok, after_integrity} =
             Admin.execute(:health, store_server: substrate.server)

    assert after_integrity.last_integrity.status == :ok
    assert after_integrity.last_integrity.dataset_revision == 1
    assert after_integrity.last_integrity.issue_count == 0

    assert {:ok, candidates} =
             Maintenance.retention_candidates(substrate.maintenance, 1, [])

    assert length(candidates) == 2

    assert Enum.all?(candidates, fn artifact_id ->
             File.dir?(Path.join(config.backup_root, artifact_id))
           end)
  end

  test "restores through an atomically selected candidate and remains writable after reopen", %{
    config: config
  } do
    first = start_substrate!(config)
    commit!(first.writer, [quad("before-backup", "before")], 0, 0)

    assert {:ok, backup} = Maintenance.backup(first.maintenance, [])
    commit!(first.writer, [quad("after-backup", "after")], 1, 1)

    assert {:ok, %{@graph => 2}} =
             StoreServer.request(first.server, {:graph_counts, [@graph]})

    assert {:error, %Error{operation: :confirm_restore}} =
             Maintenance.restore(first.maintenance, backup.artifact_id, [])

    assert {:ok, receipt} =
             Maintenance.restore(first.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert receipt.artifact_id == backup.artifact_id
    assert receipt.dataset_revision == 2
    assert receipt.integrity_status == :ok
    assert StoreServer.summary(first.server).health_state == :ready

    assert {:ok, %{@graph => 1}} =
             StoreServer.request(first.server, {:graph_counts, [@graph]})

    assert {:ok, %{id: restored_id}} = DatasetSelector.current(config)
    assert String.starts_with?(restored_id, "dataset-restore-")

    stop_substrate(first)
    reopened = start_substrate!(config)

    assert StoreServer.summary(reopened.server).dataset_revision == 2
    assert is_integer(StoreServer.summary(reopened.server).backup_age_seconds)

    assert {:ok, %{@graph => 1}} =
             StoreServer.request(reopened.server, {:graph_counts, [@graph]})

    commit!(reopened.writer, [quad("after-restore", "new")], 2, 1)
    assert StoreServer.summary(reopened.server).dataset_revision == 3
  end

  test "emits fixed spans for lifecycle, read, write, and maintenance operations", %{
    config: config
  } do
    handler = "knowledge-operation-coverage-#{System.unique_integer([:positive])}"
    test_pid = self()
    event = [:jido_code, :knowledge, :operation, :stop]

    :ok =
      :telemetry.attach(
        handler,
        event,
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:knowledge_operation, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    substrate = start_substrate!(config)
    commit!(substrate.writer, [quad("telemetry", "bounded")], 0, 0)

    assert {:ok, %{@graph => 1}} =
             StoreServer.request(substrate.server, {:graph_counts, [@graph]})

    assert {:ok, backup} = Maintenance.backup(substrate.maintenance, [])
    assert {:ok, _export} = Maintenance.export(substrate.maintenance, :nquads, [])
    assert {:ok, _report} = Maintenance.integrity(substrate.maintenance, [])

    assert {:ok, _receipt} =
             Maintenance.restore(substrate.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    events = collect_operation_events([])
    operations = MapSet.new(events, fn {_measurements, metadata} -> metadata.operation end)

    expected =
      MapSet.new([
        :open,
        :verify,
        :read,
        :write,
        :maintenance,
        :commit,
        :backup,
        :restore,
        :export,
        :integrity
      ])

    assert MapSet.subset?(expected, operations)

    assert Enum.all?(events, fn {measurements, metadata} ->
             Map.keys(measurements) -- JidoCode.Knowledge.Telemetry.allowed_measurements() == [] and
               Map.keys(metadata) -- JidoCode.Knowledge.Telemetry.allowed_keys() == []
           end)
  end

  test "rejects a corrupted artifact and keeps the prior dataset active", %{config: config} do
    substrate = start_substrate!(config)
    commit!(substrate.writer, [quad("kept", "kept")], 0, 0)
    assert {:ok, backup} = Maintenance.backup(substrate.maintenance, [])

    checkpoint_root = Path.join([config.backup_root, backup.artifact_id, "checkpoint"])

    checkpoint_file =
      checkpoint_root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Enum.find(&File.regular?/1)

    File.write!(checkpoint_file, "tampered", [:append])

    assert {:error, %Error{kind: :corrupt}} =
             Maintenance.restore(substrate.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert StoreServer.summary(substrate.server).health_state == :ready
    assert {:ok, %{id: "active"}} = DatasetSelector.current(config)

    assert {:ok, %{@graph => 1}} =
             StoreServer.request(substrate.server, {:graph_counts, [@graph]})
  end

  test "rolls back after a checksummed candidate fails semantic integrity", %{config: config} do
    substrate = start_substrate!(config)
    commit!(substrate.writer, [quad("rollback", "preserved")], 0, 0)
    assert {:ok, backup} = Maintenance.backup(substrate.maintenance, [])

    artifact_root = Path.join(config.backup_root, backup.artifact_id)
    checkpoint_root = Path.join(artifact_root, "checkpoint")
    {:ok, checkpoint_store} = TripleStore.open(checkpoint_root, schema: :quad)

    assert {:ok, 1} =
             TripleStore.update(
               checkpoint_store,
               "INSERT DATA { <https://jido.code/tests/invalid-candidate> " <>
                 "<https://jido.code/tests/value> \"unexpected\" . }"
             )

    :ok = TripleStore.close(checkpoint_store)
    rewrite_manifest_digest!(artifact_root, checkpoint_root)

    assert {:error, %Error{kind: :corrupt, operation: :restore_integrity}} =
             Maintenance.restore(substrate.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert StoreServer.summary(substrate.server).health_state == :ready
    assert {:ok, %{id: "active"}} = DatasetSelector.current(config)

    assert {:ok, %{@graph => 1}} =
             StoreServer.request(substrate.server, {:graph_counts, [@graph]})
  end

  test "reports default graph violations without mutating or repairing them", %{config: config} do
    first = start_substrate!(config)
    stop_substrate(first)

    {:ok, selection} = DatasetSelector.current(config)
    {:ok, raw_store} = TripleStore.open(selection.path, schema: :quad)
    partial_commit = Identity.commit_iri()

    assert {:ok, 2} =
             TripleStore.update(
               raw_store,
               """
               INSERT DATA {
                 <https://jido.code/tests/default>
                   <https://jido.code/tests/value> "unexpected" .

                 GRAPH <urn:jido-code:graph:system> {
                   <#{partial_commit}>
                     <urn:jido-code:vocab:status> <urn:jido-code:vocab:Committed> .
                 }
               }
               """
             )

    :ok = TripleStore.close(raw_store)
    reopened = start_substrate!(config)

    assert {:ok, %IntegrityReport{status: :error, issues: issues}} =
             Maintenance.integrity(reopened.maintenance, [])

    assert Enum.any?(issues, &(&1.code == :default_graph_not_empty))
    assert Enum.any?(issues, &(&1.code == :commit_receipt_corrupt))

    assert {:ok, %IntegrityReport{status: :error, issues: repeated_issues}} =
             Maintenance.integrity(reopened.maintenance, [])

    assert Enum.map(repeated_issues, & &1.code) == Enum.map(issues, & &1.code)
    stop_substrate(reopened)
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}
    maintenance_name = {:global, {__MODULE__, :maintenance, make_ref()}}

    authorized_callers = %{
      read: [self()],
      write: [writer_name],
      maintenance: [maintenance_name]
    }

    server =
      start_child!(
        {StoreServer,
         name: nil, readiness: readiness, config: config, authorized_callers: authorized_callers}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})

    maintenance =
      start_child!({Maintenance, name: maintenance_name, store_server: server})

    %{readiness: readiness, server: server, writer: writer, maintenance: maintenance}
  end

  defp stop_substrate(substrate) do
    stop_process(substrate.maintenance)
    stop_process(substrate.writer)
    stop_process(substrate.server)
    stop_process(substrate.readiness)
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp commit_localized_data!(writer) do
    quads = [
      RDF.quad(
        "https://jido.code/tests/resources/greeting",
        "https://jido.code/tests/vocab/value",
        RDF.literal("bonjour", language: "fr"),
        @graph
      ),
      RDF.quad(
        "https://jido.code/tests/resources/count",
        "https://jido.code/tests/vocab/value",
        RDF.literal(42),
        @graph
      )
    ]

    commit!(writer, quads, 0, 0)
  end

  defp commit!(writer, quads, dataset_revision, graph_revision) do
    {:ok, batch} =
      WriteBatch.new(quads,
        expected_dataset_revision: dataset_revision,
        expected_graph_revisions: %{@graph => graph_revision}
      )

    assert {:ok, receipt} = Writer.commit(writer, batch, [])
    receipt
  end

  defp quad(id, value) do
    RDF.quad(
      "https://jido.code/tests/resources/#{id}",
      "https://jido.code/tests/vocab/value",
      value,
      @graph
    )
  end

  defp private_mode?(path, expected) do
    case File.stat(path) do
      {:ok, stat} -> Bitwise.band(stat.mode, 0o777) == expected
      {:error, _reason} -> false
    end
  end

  defp rewrite_manifest_digest!(artifact_root, checkpoint_root) do
    files =
      checkpoint_root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&{Path.relative_to(&1, checkpoint_root), &1})
      |> Enum.sort()

    {hash, bytes} =
      Enum.reduce(files, {:crypto.hash_init(:sha256), 0}, fn {relative, path}, {hash, bytes} ->
        body = File.read!(path)
        file_digest = :crypto.hash(:sha256, body)

        {:crypto.hash_update(hash, [relative, <<0>>, file_digest, <<0>>]),
         bytes + byte_size(body)}
      end)

    digest = hash |> :crypto.hash_final() |> Base.encode16(case: :lower)
    manifest_path = Path.join(artifact_root, "manifest.json")

    manifest =
      manifest_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("payload_sha256", digest)
      |> Map.put("payload_bytes", bytes)
      |> Map.put("file_count", length(files))

    File.write!(manifest_path, Jason.encode!(manifest, pretty: true) <> "\n")
    File.chmod!(manifest_path, 0o600)
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
    suffix = System.unique_integer([:positive, :monotonic])
    timestamp = System.system_time(:nanosecond)
    Path.join(System.tmp_dir!(), "jido-code-backup-#{context.test}-#{timestamp}-#{suffix}")
  end

  defp stop_process(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
  catch
    :exit, _reason -> :ok
  end

  defp collect_operation_events(events) do
    receive do
      {:knowledge_operation, measurements, metadata} ->
        collect_operation_events([{measurements, metadata} | events])
    after
      100 -> events
    end
  end
end

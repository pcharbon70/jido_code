defmodule JidoCode.Knowledge.WriterTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.RevisionReceipt
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.WriteReceipt
  alias JidoCode.Knowledge.Writer

  @moduletag capture_log: true

  @graph_a "https://jido.code/tests/graphs/writer-a"
  @graph_b "https://jido.code/tests/graphs/writer-b"

  setup context do
    root = unique_root(context)
    on_exit(fn -> remove_root!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config}
  end

  test "commits assertions and immutable revision receipts in one replay-safe batch", %{
    config: config
  } do
    %{server: server, writer: writer} = start_substrate!(config)

    batch =
      batch!([quad("a1", @graph_a), quad("b1", @graph_b)], 0, %{
        @graph_a => 0,
        @graph_b => 0
      })

    assert {:ok, %WriteReceipt{} = receipt} = Writer.commit(writer, batch, [])
    refute receipt.replayed?
    assert receipt.commit_id == batch.commit_id
    assert receipt.batch_digest == batch.batch_digest
    assert receipt.prior_dataset_revision == 0
    assert receipt.dataset_revision == 1

    assert receipt.graph_revisions == %{
             @graph_a => %{prior: 0, new: 1},
             @graph_b => %{prior: 0, new: 1}
           }

    assert receipt.additions_count == 2
    assert receipt.removals_count == 0
    assert receipt.durability == :sync
    assert StoreServer.summary(server).dataset_revision == 1

    assert {:ok, %WriteReceipt{} = recovered} = Writer.lookup(writer, batch.commit_id, [])
    refute recovered.replayed?
    assert %{recovered | replayed?: receipt.replayed?} == receipt

    assert {:ok, replayed} = Writer.commit(writer, batch, [])
    assert replayed.replayed?
    assert replayed.dataset_revision == 1
    assert StoreServer.summary(server).dataset_revision == 1

    assert {:ok, %{@graph_a => 1, @graph_b => 1}} =
             StoreServer.request(server, {:graph_counts, [@graph_a, @graph_b]})

    conflicting =
      batch!([quad("different", @graph_a)], 1, %{@graph_a => 1}, commit_id: batch.commit_id)

    assert {:error, %Error{kind: :conflict, operation: :commit_identity_reuse}} =
             Writer.commit(writer, conflicting, [])

    assert {:error, %Error{kind: :unauthorized}} =
             StoreServer.request(server, {:atomic_update, batch})

    assert {:error, %Error{kind: :invalid_input}} =
             StoreServer.request(server, "INSERT DATA { <unsafe> <raw> <update> }")
  end

  test "increments dataset and affected graph revisions without regressing on reopen", %{
    config: config
  } do
    first = start_substrate!(config)

    first_batch = batch!([quad("a1", @graph_a)], 0, %{@graph_a => 0})
    assert {:ok, first_receipt} = Writer.commit(first.writer, first_batch, [])
    assert first_receipt.dataset_revision == 1

    second_batch = batch!([quad("a2", @graph_a)], 1, %{@graph_a => 1})
    assert {:ok, second_receipt} = Writer.commit(first.writer, second_batch, [])
    assert second_receipt.dataset_revision == 2
    assert second_receipt.graph_revisions[@graph_a] == %{prior: 1, new: 2}

    stop_process(first.writer)
    stop_process(first.server)

    reopened = start_substrate!(config)
    assert StoreServer.summary(reopened.server).dataset_revision == 2

    assert {:ok, recovered} = Writer.lookup(reopened.writer, second_batch.commit_id, [])
    assert recovered.dataset_revision == 2
    assert recovered.graph_revisions[@graph_a] == %{prior: 1, new: 2}

    third_batch = batch!([quad("a3", @graph_a)], 2, %{@graph_a => 2})
    assert {:ok, third_receipt} = Writer.commit(reopened.writer, third_batch, [])
    assert third_receipt.dataset_revision == 3
    assert third_receipt.graph_revisions[@graph_a] == %{prior: 2, new: 3}
  end

  test "returns bounded current revisions for stale preconditions and changes nothing", %{
    config: config
  } do
    %{server: server, writer: writer} = start_substrate!(config)

    accepted = batch!([quad("winner", @graph_a)], 0, %{@graph_a => 0})
    assert {:ok, _receipt} = Writer.commit(writer, accepted, [])

    stale = batch!([quad("stale", @graph_a)], 0, %{@graph_a => 0})

    assert {:error, %Error{kind: :stale_precondition}, %RevisionReceipt{} = current} =
             Writer.commit(writer, stale, [])

    assert current.dataset_revision == 1
    assert current.graph_revisions == %{@graph_a => 1}
    assert {:ok, nil} = Writer.lookup(writer, stale.commit_id, [])

    assert {:ok, %{@graph_a => 1}} =
             StoreServer.request(server, {:graph_counts, [@graph_a]})
  end

  test "serializes conflicting races so exactly one expected revision wins", %{config: config} do
    %{server: server, writer: writer} = start_substrate!(config)

    batches = [
      batch!([quad("racer-one", @graph_a)], 0, %{@graph_a => 0}),
      batch!([quad("racer-two", @graph_a)], 0, %{@graph_a => 0})
    ]

    results =
      batches
      |> Task.async_stream(
        fn batch -> Writer.commit(writer, batch, []) end,
        ordered: false,
        timeout: 10_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, %WriteReceipt{}}, &1)) == 1

    assert Enum.count(
             results,
             &match?(
               {:error, %Error{kind: :stale_precondition}, %RevisionReceipt{}},
               &1
             )
           ) == 1

    assert StoreServer.summary(server).dataset_revision == 1

    assert {:ok, %{@graph_a => 1}} =
             StoreServer.request(server, {:graph_counts, [@graph_a]})
  end

  test "expires queued work before mutation and recovers a lost caller by commit identity", %{
    config: config
  } do
    %{server: server, writer: writer} = start_substrate!(config)
    expired_batch = batch!([quad("expired", @graph_a)], 0, %{@graph_a => 0})

    :ok = :sys.suspend(writer)

    expired_task =
      Task.async(fn ->
        Writer.commit(writer, expired_batch, operation_timeout: 20, caller_timeout: 1_000)
      end)

    assert eventually(fn -> message_queue_length(writer) > 0 end)
    Process.sleep(30)
    :ok = :sys.resume(writer)

    assert {:error, %Error{kind: :timeout, operation: :atomic_commit}} =
             Task.await(expired_task, 2_000)

    assert {:ok, nil} = Writer.lookup(writer, expired_batch.commit_id, [])
    assert StoreServer.summary(server).dataset_revision == 0

    lost_batch = batch!([quad("lost-response", @graph_a)], 0, %{@graph_a => 0})
    :ok = :sys.suspend(writer)
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        send(parent, {:commit_calling, self()})
        Writer.commit(writer, lost_batch, [])
      end)

    assert_receive {:commit_calling, ^caller}
    assert eventually(fn -> message_queue_length(writer) > 0 end)
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :killed}
    :ok = :sys.resume(writer)

    assert eventually(fn ->
             match?(
               {:ok, %WriteReceipt{dataset_revision: 1}},
               Writer.lookup(writer, lost_batch.commit_id, [])
             )
           end)

    assert StoreServer.summary(server).dataset_revision == 1

    assert {:ok, %{@graph_a => 1}} =
             StoreServer.request(server, {:graph_counts, [@graph_a]})
  end

  test "ordinary atomic commits reject maintenance removals before writing", %{config: config} do
    %{server: server, writer: writer} = start_substrate!(config)

    {:ok, batch} =
      WriteBatch.new([quad("new", @graph_a)],
        removals: [quad("old", @graph_a)],
        removal_policy: :maintenance,
        expected_dataset_revision: 0,
        expected_graph_revisions: %{@graph_a => 0}
      )

    assert {:error, %Error{kind: :invalid_input, operation: :atomic_removal_not_supported}} =
             Writer.commit(writer, batch, [])

    assert StoreServer.summary(server).dataset_revision == 0

    assert {:ok, %{@graph_a => 0}} =
             StoreServer.request(server, {:graph_counts, [@graph_a]})
  end

  test "treats a partial receipt and unmanaged graph data as corruption, never absence", %{
    config: config
  } do
    :ok = Config.prepare_directories(config)
    {:ok, raw_store} = TripleStore.open(Config.active_store_path(config), schema: :quad)
    assert {:ok, _metadata} = Metadata.ensure(raw_store, 1, Identity.lineage_iri())

    commit_id = Identity.commit_iri()

    assert {:ok, 2} =
             TripleStore.update(raw_store, """
             INSERT DATA {
               GRAPH <urn:jido-code:graph:system> {
                 <#{commit_id}> <urn:jido-code:vocab:status> "partial" .
               }
               GRAPH <#{@graph_b}> {
                 <https://jido.code/tests/resources/unmanaged>
                   <https://jido.code/tests/vocab/value> "unmanaged" .
               }
             }
             """)

    :ok = TripleStore.close(raw_store)
    %{writer: writer} = start_substrate!(config)

    partial_receipt_batch =
      batch!([quad("partial", @graph_a)], 0, %{@graph_a => 0}, commit_id: commit_id)

    assert {:error, %Error{kind: :corrupt, operation: :read_commit_receipt}} =
             Writer.commit(writer, partial_receipt_batch, [])

    unmanaged_batch = batch!([quad("managed", @graph_b)], 0, %{@graph_b => 0})

    assert {:error, %Error{kind: :corrupt, operation: :verify_graph_revision}} =
             Writer.commit(writer, unmanaged_batch, [])
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, make_ref()}}

    authorized_callers = %{
      read: [self()],
      write: [writer_name],
      maintenance: [self()]
    }

    server =
      start_child!(
        {StoreServer,
         name: nil, readiness: readiness, config: config, authorized_callers: authorized_callers}
      )

    assert await_health(server, :ready).ready?

    writer = start_child!({Writer, name: writer_name, store_server: server})
    %{readiness: readiness, server: server, writer: writer}
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp batch!(additions, dataset_revision, graph_revisions, options \\ []) do
    {:ok, batch} =
      WriteBatch.new(
        additions,
        [
          expected_dataset_revision: dataset_revision,
          expected_graph_revisions: graph_revisions
        ] ++ options
      )

    batch
  end

  defp quad(id, graph) do
    RDF.quad(
      "https://jido.code/tests/resources/#{id}",
      "https://jido.code/tests/vocab/value",
      id,
      graph
    )
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

  defp eventually(callback, attempts \\ 200)
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

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-writer-#{name}-#{unique}")
  end
end

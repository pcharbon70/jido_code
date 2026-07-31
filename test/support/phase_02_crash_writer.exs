Application.ensure_all_started(:jido_code)

alias JidoCode.Knowledge.Config
alias JidoCode.Knowledge.Readiness
alias JidoCode.Knowledge.StoreServer
alias JidoCode.Knowledge.WriteBatch
alias JidoCode.Knowledge.Writer

root = System.fetch_env!("JIDO_PHASE2_CRASH_ROOT")
mode = System.fetch_env!("JIDO_PHASE2_CRASH_MODE")
commit_id = System.fetch_env!("JIDO_PHASE2_COMMIT_ID")
graph = "https://jido.code/tests/graphs/phase-02-crash"

{:ok, config} = Config.for_test(root, test_instance_id: "external-crash-writer")
{:ok, readiness} = Readiness.start_link(name: nil)
writer_name = {:global, {:phase_02_crash_writer, System.unique_integer([:positive])}}

{:ok, store_server} =
  StoreServer.start_link(
    name: nil,
    readiness: readiness,
    config: config,
    authorized_callers: %{read: [], write: [writer_name], maintenance: []}
  )

wait_until_ready = fn wait_until_ready ->
  if StoreServer.summary(store_server).ready? do
    :ok
  else
    Process.sleep(10)
    wait_until_ready.(wait_until_ready)
  end
end

:ok = wait_until_ready.(wait_until_ready)
{:ok, writer} = Writer.start_link(name: writer_name, store_server: store_server)
IO.puts("PHASE2_READY")

if mode == "after_commit" do
  quad =
    RDF.quad(
      "https://jido.code/tests/resources/external-crash",
      "https://jido.code/tests/vocab/value",
      "committed",
      graph
    )

  {:ok, batch} =
    WriteBatch.new([quad],
      commit_id: commit_id,
      expected_dataset_revision: 0,
      expected_graph_revisions: %{graph => 0}
    )

  {:ok, receipt} = Writer.commit(writer, batch, operation_timeout: 30_000)
  IO.puts("PHASE2_COMMITTED #{receipt.commit_id}")
end

Process.sleep(:infinity)

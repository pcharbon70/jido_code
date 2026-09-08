# Regression for persistent RocksDB iterators after completed real reads.
# Runs only inside the disposable production qualification instance.
fn credential ->
  alias JidoCode.Knowledge.{AuthorityContext, GraphRegistry, QueryRunner, StoreServer}

  true =
    Enum.any?(1..150, fn _ ->
      if JidoCode.Product.StreamCoordinator.stats().connections == 0,
        do: true,
        else:
          (
            Process.sleep(100)
            false
          )
    end)

  {:ok, authentication} = JidoCode.Identity.authenticate("local-proof@example.test", credential)
  human = "https://jido.run/id/human/#{authentication.subject_ref}"
  {:ok, authority} = AuthorityContext.new(%{principal_iri: human, actor_iri: human})
  surface = Application.fetch_env!(:jido_code, :product_surface)
  {:ok, graph} = GraphRegistry.graph_iri(:factory_catalog, %{})
  revision = StoreServer.summary().dataset_revision

  count = fn ->
    processes = Process.list()
    true = length(processes) <= 50_000

    Enum.count(processes, fn pid ->
      case :proc_lib.translate_initial_call(pid) do
        {TripleStore.Backend.RocksDB.Iterator, _, _} -> true
        _ -> false
      end
    end)
  end

  before = count.()

  for _ <- 1..50 do
    {:ok, _} =
      QueryRunner.authorize(
        :factory_repository_cohort,
        "2.11.0",
        %{graph: graph, resource: surface[:factory_iri]},
        authority,
        surface[:factory_scope_iri]
      )
  end

  Process.sleep(1_000)
  after_reads = count.()
  ^revision = StoreServer.summary().dataset_revision

  IO.puts(
    Jason.encode!(%{
      resource_cleanup: "completed authorization reads",
      iterations: 50,
      iterators_before: before,
      iterators_after: after_reads,
      graph_revision_unchanged: true
    })
  )

  if after_reads > before, do: raise("completed reads leaked RocksDB iterator processes")
  :ok
end

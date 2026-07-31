defmodule JidoCode.Knowledge.TripleStoreCompatibilityTest do
  use ExUnit.Case, async: false

  alias TripleStore.Dictionary.Manager
  alias TripleStore.Dictionary.SequenceCounter
  alias TripleStore.Exporter
  alias TripleStore.Loader
  alias TripleStore.QuadOperations
  alias TripleStore.Reasoner.{ReasoningProfile, SemiNaive}
  alias TripleStore.SPARQL.Authorization

  @moduletag :triple_store

  @ex "https://jido.code/compatibility/"
  @observed_graph @ex <> "graphs/observed"
  @policy_graph @ex <> "graphs/policy"
  @derived_graph @ex <> "graphs/derived"
  @change_graph @ex <> "graphs/change"
  @receipt_graph @ex <> "graphs/receipt"

  @dataset """
  @prefix ex: <https://jido.code/compatibility/> .

  <https://jido.code/compatibility/graphs/observed> {
    ex:repo ex:hasName "jido_code" .
    ex:repo ex:hasRevision "abc123" .
  }

  <https://jido.code/compatibility/graphs/policy> {
    ex:policy ex:appliesTo ex:repo .
  }
  """

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido_code_triple_store_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    store = open_store!(Path.join(root, "store"))

    %{root: root, store: store}
  end

  test "loads named graphs and executes bounded SELECT, ASK, and CONSTRUCT queries", %{
    store: store
  } do
    assert :error = Decimal.parse("1e1000000000")
    refute RDF.Literal.valid?(RDF.XSD.Decimal.new("1" <> String.duplicate("0", 1_000)))

    assert {:ok, 3} = load_dataset(store)
    assert {:ok, 0} = graph_count(store, :default)
    assert {:ok, 2} = graph_count(store, @observed_graph)
    assert {:ok, 1} = graph_count(store, @policy_graph)

    allow_public_reads(store, [@observed_graph, @policy_graph])

    assert {:ok, false} =
             TripleStore.query(store, """
             ASK { <#{@ex}repo> <#{@ex}hasName> ?name }
             """)

    assert {:ok, true} =
             TripleStore.query(store, """
             ASK {
               GRAPH <#{@observed_graph}> {
                 <#{@ex}repo> <#{@ex}hasName> ?name
               }
             }
             """)

    assert {:ok, [%{"graph" => graph, "subject" => subject}]} =
             TripleStore.query(store, """
             SELECT ?graph ?subject WHERE {
               GRAPH ?graph {
                 ?subject <#{@ex}appliesTo> <#{@ex}repo>
               }
             }
             """)

    assert graph == RDF.iri(@policy_graph)
    assert subject == {:named_node, @ex <> "policy"}

    assert {:ok, %RDF.Graph{} = graph} =
             TripleStore.query(store, """
             CONSTRUCT {
               <#{@ex}repo> <#{@ex}displayName> ?name
             }
             WHERE {
               GRAPH <#{@observed_graph}> {
                 <#{@ex}repo> <#{@ex}hasName> ?name
               }
             }
             """)

    assert RDF.Graph.triple_count(graph) == 1
  end

  test "commits a receipt with a multi-graph update and has atomic crash visibility", %{
    store: store
  } do
    update = committed_update()

    {before_pid, before_ref} =
      spawn_monitor(fn ->
        receive do
          :commit -> TripleStore.update(store, update)
        end
      end)

    Process.exit(before_pid, :kill)
    assert_receive {:DOWN, ^before_ref, :process, ^before_pid, :killed}
    assert {:ok, 0} = graph_count(store, @change_graph)
    assert {:ok, 0} = graph_count(store, @receipt_graph)

    parent = self()

    {after_pid, after_ref} =
      spawn_monitor(fn ->
        result = TripleStore.update(store, update)
        send(parent, {:committed, self(), result})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:committed, ^after_pid, {:ok, 2}}, 5_000
    Process.exit(after_pid, :kill)
    assert_receive {:DOWN, ^after_ref, :process, ^after_pid, :killed}

    assert {:ok, 1} = graph_count(store, @change_graph)
    assert {:ok, 1} = graph_count(store, @receipt_graph)

    assert {:error, _reason} = TripleStore.update(store, invalid_update())
    assert {:ok, 1} = graph_count(store, @change_graph)
    assert {:ok, 1} = graph_count(store, @receipt_graph)

    :ok = TripleStore.close(store)
    reopened = open_store!(store.path)

    assert {:ok, 1} = graph_count(reopened, @change_graph)
    assert {:ok, 1} = graph_count(reopened, @receipt_graph)
  end

  test "materializes OWL 2 RL facts and persists only the derived delta to its graph", %{
    store: store
  } do
    asserted_facts =
      MapSet.new([
        {
          {:iri, @ex <> "Student"},
          {:iri, "http://www.w3.org/2000/01/rdf-schema#subClassOf"},
          {:iri, @ex <> "Person"}
        },
        {
          {:iri, @ex <> "alice"},
          {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"},
          {:iri, @ex <> "Student"}
        }
      ])

    {:ok, rules} = ReasoningProfile.rules_for(:owl2rl)

    assert {:ok, materialized_facts, stats} =
             SemiNaive.materialize_in_memory(rules, asserted_facts,
               parallel: false,
               emit_telemetry: false
             )

    inferred_person =
      {
        {:iri, @ex <> "alice"},
        {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"},
        {:iri, @ex <> "Person"}
      }

    derived_facts = MapSet.difference(materialized_facts, asserted_facts)

    assert MapSet.member?(derived_facts, inferred_person)
    assert stats.total_derived > 0

    assert {:ok, 2} = load_reasoning_facts(store, asserted_facts, @observed_graph)
    assert {:ok, derived_count} = load_reasoning_facts(store, derived_facts, @derived_graph)
    assert derived_count == MapSet.size(derived_facts)

    assert {:ok, 2} = graph_count(store, @observed_graph)
    assert {:ok, ^derived_count} = graph_count(store, @derived_graph)

    refute quad_exists?(store, inferred_person, @observed_graph)
    assert quad_exists?(store, inferred_person, @derived_graph)
  end

  test "exports, backs up, restores, and reopens without changing graph or dictionary identity",
       %{
         root: root,
         store: store
       } do
    assert {:ok, 3} = load_dataset(store)

    identity_term = RDF.iri(@ex <> "repo")
    assert {:ok, identity_before} = Manager.lookup_id(store.dict_manager, identity_term)

    assert {:ok, expected_dataset} = Exporter.export_dataset(store.db)
    assert {:ok, nquads} = Exporter.export_nquads_string(store.db)
    assert {:ok, trig} = Exporter.export_trig_string(store.db)
    assert {:ok, nquads_dataset} = RDF.NQuads.read_string(nquads)
    assert {:ok, trig_dataset} = RDF.TriG.read_string(trig)
    assert RDF.Dataset.equal?(expected_dataset, nquads_dataset)
    assert RDF.Dataset.equal?(expected_dataset, trig_dataset)

    backup_path = Path.join(root, "checkpoint")
    restore_path = Path.join(root, "restored")

    assert :ok = checkpoint_store(store, backup_path)
    assert {:ok, :quad} = TripleStore.Backup.get_backup_schema(backup_path)

    :ok = TripleStore.close(store)
    assert {:ok, _copied_paths} = File.cp_r(backup_path, restore_path)
    restored = open_store!(restore_path)

    assert {:ok, restored_dataset} = Exporter.export_dataset(restored.db)
    assert RDF.Dataset.equal?(expected_dataset, restored_dataset)
    assert {:ok, ^identity_before} = Manager.lookup_id(restored.dict_manager, identity_term)

    :ok = TripleStore.close(restored)
    reopened = open_store!(restore_path)

    assert {:ok, reopened_dataset} = Exporter.export_dataset(reopened.db)
    assert RDF.Dataset.equal?(expected_dataset, reopened_dataset)
    assert {:ok, ^identity_before} = Manager.lookup_id(reopened.dict_manager, identity_term)
  end

  test "enforces one open handle while allowing concurrent bounded reads", %{store: store} do
    assert {:ok, 3} = load_dataset(store)
    allow_public_reads(store, [@observed_graph, @policy_graph])

    assert {:error, _reason} = TripleStore.open(store.path, schema: :quad)

    results =
      1..12
      |> Task.async_stream(
        fn _iteration ->
          TripleStore.query(store, """
          ASK {
            GRAPH <#{@observed_graph}> {
              <#{@ex}repo> <#{@ex}hasRevision> ?revision
            }
          }
          """)
        end,
        ordered: false,
        max_concurrency: 4,
        timeout: 5_000
      )
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, {:ok, true}}, &1))

    :ok = TripleStore.close(store)
    reopened = open_store!(store.path)

    assert {:ok, 2} = graph_count(reopened, @observed_graph)
  end

  test "releases the filesystem lock after an abrupt database owner exit", %{store: store} do
    monitor = Process.monitor(store.db)
    Process.exit(store.db, :kill)

    assert_receive {:DOWN, ^monitor, :process, _pid, :killed}, 5_000

    reopened = open_store!(store.path)
    assert {:ok, 0} = graph_count(reopened, :default)
  end

  defp open_store!(path) do
    {:ok, store} = TripleStore.open(path, schema: :quad)
    register_store(store)
    store
  end

  defp register_store(store) do
    on_exit(fn -> close_store(store) end)
    store
  end

  defp close_store(store) do
    if Process.alive?(store.dict_manager) do
      TripleStore.close(store)
    else
      :ok
    end
  catch
    :exit, _reason -> :ok
  end

  defp checkpoint_store(store, checkpoint_path) do
    with {:ok, counter} <- Manager.get_counter(store.dict_manager),
         :ok <- SequenceCounter.flush(counter) do
      %{db: rocksdb} = :sys.get_state(store.db)
      :rocksdb.checkpoint(rocksdb, String.to_charlist(checkpoint_path))
    end
  end

  defp load_dataset(store) do
    Loader.load_trig_string(store.db, store.dict_manager, @dataset,
      parallel: false,
      bulk_mode: false
    )
  end

  defp allow_public_reads(store, graph_iris) do
    context = %{db: store.db, dict_manager: store.dict_manager}
    Enum.each(graph_iris, fn graph_iri -> :ok = Authorization.set_public(context, graph_iri) end)
  end

  defp graph_count(store, :default) do
    QuadOperations.graph_quad_count(store.db, store.dict_manager, :default)
  end

  defp graph_count(store, graph_iri) do
    QuadOperations.graph_quad_count(store.db, store.dict_manager, RDF.iri(graph_iri))
  end

  defp committed_update do
    """
    INSERT DATA {
      GRAPH <#{@change_graph}> {
        <#{@ex}repo> <#{@ex}hasState> "ready" .
      }
      GRAPH <#{@receipt_graph}> {
        <#{@ex}commands/phase-1> <#{@ex}hasStatus> "committed" .
      }
    }
    """
  end

  defp invalid_update do
    """
    INSERT DATA {
      GRAPH <#{@change_graph}> {
        <#{@ex}repo> <#{@ex}hasState> "unterminated
      }
    }
    """
  end

  defp load_reasoning_facts(store, facts, graph_iri) do
    graph =
      facts
      |> Enum.map(&to_rdf_triple/1)
      |> RDF.Graph.new()

    Loader.load_graph(store.db, store.dict_manager, graph,
      graph: RDF.iri(graph_iri),
      parallel: false,
      bulk_mode: false
    )
  end

  defp quad_exists?(store, {subject, predicate, object}, graph_iri) do
    with {:ok, subject_id} <- Manager.lookup_id(store.dict_manager, to_rdf_term(subject)),
         {:ok, predicate_id} <- Manager.lookup_id(store.dict_manager, to_rdf_term(predicate)),
         {:ok, object_id} <- Manager.lookup_id(store.dict_manager, to_rdf_term(object)),
         {:ok, graph_id} <- Manager.lookup_id(store.dict_manager, RDF.iri(graph_iri)) do
      QuadOperations.quad_exists?(store.db, {subject_id, predicate_id, object_id, graph_id})
    else
      :not_found -> false
    end
  end

  defp to_rdf_triple({subject, predicate, object}) do
    {to_rdf_term(subject), to_rdf_term(predicate), to_rdf_term(object)}
  end

  defp to_rdf_term({:iri, value}), do: RDF.iri(value)
end

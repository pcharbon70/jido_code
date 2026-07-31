defmodule JidoCode.Knowledge.BackendCrashRecoveryTest do
  use JidoCode.GraphStoreCase

  alias JidoCode.TestSupport.DeterministicIdentity
  alias TripleStore.QuadOperations

  @ex "https://jido.code/integration/"
  @change_graph @ex <> "graphs/change"
  @receipt_graph @ex <> "graphs/receipt"

  test "a caller killed before commit leaves no visible state after abrupt reopen", %{
    store: store
  } do
    parent = self()

    {caller, caller_ref} =
      spawn_monitor(fn ->
        send(parent, {:ready, self()})

        receive do
          :commit -> TripleStore.update(store, accepted_update(1))
        end
      end)

    assert_receive {:ready, ^caller}
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^caller_ref, :process, ^caller, :killed}

    reopened = abrupt_reopen!(store)
    assert_atomic_counts(reopened, 0)
  end

  test "a completed commit survives immediate caller and database-owner death", %{store: store} do
    parent = self()

    {caller, caller_ref} =
      spawn_monitor(fn ->
        result = TripleStore.update(store, accepted_update(2))
        send(parent, {:command_result, self(), result})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:command_result, ^caller, {:ok, 2}}, 5_000
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^caller_ref, :process, ^caller, :killed}

    reopened = abrupt_reopen!(store)
    assert_atomic_counts(reopened, 1)
  end

  test "a graceful post-commit close and reopen preserves data and receipt together", %{
    store: store
  } do
    assert {:ok, 2} = TripleStore.update(store, accepted_update(3))
    :ok = TripleStore.close(store)

    reopened = open_store!(store.path)
    assert_atomic_counts(reopened, 1)
  end

  defp abrupt_reopen!(store) do
    monitor = Process.monitor(store.db)
    Process.exit(store.db, :kill)
    assert_receive {:DOWN, ^monitor, :process, _pid, :killed}, 5_000
    open_store!(store.path)
  end

  defp assert_atomic_counts(store, expected) do
    assert {:ok, ^expected} = graph_count(store, @change_graph)
    assert {:ok, ^expected} = graph_count(store, @receipt_graph)
  end

  defp graph_count(store, graph_iri) do
    QuadOperations.graph_quad_count(store.db, store.dict_manager, RDF.iri(graph_iri))
  end

  defp accepted_update(ordinal) do
    command_iri = DeterministicIdentity.iri("commands", ordinal, seed: 101, base: @ex)

    """
    INSERT DATA {
      GRAPH <#{@change_graph}> {
        <#{command_iri}> <#{@ex}changes> <#{@ex}repository> .
      }
      GRAPH <#{@receipt_graph}> {
        <#{command_iri}> <#{@ex}status> "committed" .
      }
    }
    """
  end
end

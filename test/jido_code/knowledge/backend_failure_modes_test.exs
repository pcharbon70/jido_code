defmodule JidoCode.Knowledge.BackendFailureModesTest do
  use JidoCode.GraphStoreCase

  @moduletag capture_log: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Telemetry
  alias TripleStore.Loader
  alias TripleStore.QuadOperations

  test "lock contention fails without exposing the backend path", %{root: root, store: store} do
    assert {:error, reason} = TripleStore.open(store.path, schema: :quad)

    error = Error.from_backend(:locked, :open_store, reason)
    assert_redacted(error, root, reason)
    assert Telemetry.for_error(error).error_kind == :locked
  end

  test "an incompatible schema refuses to open existing quad data", %{root: root, store: store} do
    :ok = TripleStore.close(store)
    assert {:error, reason} = TripleStore.open(store.path, schema: :triple)

    error = Error.from_backend(:incompatible, :open_store, reason)
    assert_redacted(error, root, reason)
  end

  test "invalid RDF and SPARQL leave the dataset unchanged", %{root: root, store: store} do
    assert {:error, rdf_reason} =
             Loader.load_trig_string(store.db, store.dict_manager, "<broken {",
               parallel: false,
               bulk_mode: false
             )

    assert {:error, query_reason} = TripleStore.query(store, "SELECT WHERE {")
    assert {:error, update_reason} = TripleStore.update(store, "INSERT DATA { <broken")
    assert {:ok, 0} = QuadOperations.graph_quad_count(store.db, store.dict_manager, :default)

    for reason <- [rdf_reason, query_reason, update_reason] do
      error = Error.from_backend(:invalid_input, :parse_input, reason)
      assert_redacted(error, root, reason)
    end
  end

  test "a permission failure is classified without retaining filesystem details", %{root: root} do
    readonly = Path.join(root, "readonly")
    File.mkdir_p!(readonly)
    File.chmod!(readonly, 0o500)
    on_exit(fn -> if File.exists?(readonly), do: File.chmod!(readonly, 0o700) end)

    assert {:error, reason} =
             TripleStore.open(Path.join(readonly, "store"), schema: :quad)

    error = Error.from_backend(:persistence_failure, :open_store, reason)
    assert_redacted(error, root, reason)
  end

  defp assert_redacted(error, root, backend_reason) do
    public = error |> Error.public() |> inspect()

    refute public =~ root
    refute public =~ Path.basename(root)
    refute public =~ inspect(backend_reason)
    refute public =~ "LOCK"
    refute public =~ "eacces"
    assert Map.keys(Error.public(error)) |> Enum.sort() == [:kind, :message, :operation, :retry]
  end
end

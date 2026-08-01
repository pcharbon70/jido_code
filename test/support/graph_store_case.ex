defmodule JidoCode.GraphStoreCase do
  @moduledoc false

  @temp_prefix "jido_code_graph_store_cases"

  defmacro __using__(opts) do
    if Keyword.get(opts, :async, false) do
      raise ArgumentError, "real graph-store cases must run with async: false"
    end

    quote do
      use ExUnit.Case, async: false

      import JidoCode.GraphStoreCase,
        only: [close_store: 1, directory_snapshot: 1, open_store!: 1, open_store!: 2]

      @moduletag :graph_store
      setup :setup_isolated_graph_store

      defp setup_isolated_graph_store(context) do
        JidoCode.GraphStoreCase.setup_store(context)
      end
    end
  end

  def setup_store(context) do
    root = unique_root(context)
    File.mkdir_p!(root)

    ExUnit.Callbacks.on_exit({:remove_graph_store_root, root}, fn -> cleanup_root!(root) end)

    store = open_store!(Path.join(root, "store"))
    %{root: root, store: store}
  end

  def open_store!(path, opts \\ []) do
    if Keyword.get(opts, :schema, :quad) != :quad do
      raise ArgumentError, "graph-store tests require schema: :quad"
    end

    deadline = System.monotonic_time(:millisecond) + 5_000
    {:ok, store} = open_store(path, Keyword.put(opts, :schema, :quad), deadline)

    ExUnit.Callbacks.on_exit({:close_graph_store, System.unique_integer([:positive])}, fn ->
      close_store(store)
    end)

    store
  end

  def close_store(store) do
    if Process.alive?(store.db) do
      TripleStore.close(store)
    else
      stop_process(store.dict_manager)
      :ok
    end
  catch
    :exit, _reason -> :ok
  end

  def directory_snapshot(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.take(25)
    |> Enum.map(fn path ->
      relative = Path.relative_to(path, root)

      case File.stat(path) do
        {:ok, %{type: type, size: size}} -> %{path: relative, type: type, size: size}
        {:error, reason} -> %{path: relative, error: reason}
      end
    end)
  end

  defp unique_root(context) do
    test_identity = {context.module, context.test, context[:seed]}

    digest =
      test_identity
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    unique = System.unique_integer([:positive, :monotonic])
    Path.join([System.tmp_dir!(), @temp_prefix, "#{digest}-#{unique}"])
  end

  defp open_store(path, opts, deadline) do
    case TripleStore.open(path, opts) do
      {:error, {:db_open, reason}} = error ->
        if transient_lock?(reason) and System.monotonic_time(:millisecond) < deadline do
          Process.sleep(20)
          open_store(path, opts, deadline)
        else
          error
        end

      result ->
        result
    end
  end

  defp transient_lock?(reason) do
    reason
    |> to_string()
    |> String.contains?(["/LOCK", "lock hold", "No locks available"])
  rescue
    _error -> false
  end

  defp cleanup_root!(root) do
    case File.rm_rf(root) do
      {:ok, _paths} ->
        :ok

      {:error, reason, path} ->
        snapshot = inspect(directory_snapshot(root), limit: 25, printable_limit: 2_000)

        raise "failed to remove isolated graph store #{Path.basename(root)} at " <>
                "#{Path.basename(path)}: #{inspect(reason)}; entries=#{snapshot}"
    end
  end

  defp stop_process(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
  catch
    :exit, _reason -> :ok
  end

  defp stop_process(_other), do: :ok
end

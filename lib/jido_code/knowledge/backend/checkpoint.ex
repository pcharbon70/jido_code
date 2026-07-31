defmodule JidoCode.Knowledge.Backend.Checkpoint do
  @moduledoc false

  @architecture_file_role :graph_backup

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias TripleStore.Backend.RocksDB.ErlangAdapter
  alias TripleStore.Dictionary.Manager
  alias TripleStore.Dictionary.SequenceCounter

  @spec create(TripleStore.store(), Path.t()) :: :ok | {:error, Error.t()}
  def create(store, destination) when is_binary(destination) do
    with {:ok, counter} <- Manager.get_counter(store.dict_manager),
         :ok <- SequenceCounter.flush(counter),
         :ok <- ErlangAdapter.flush_wal(store.db, true),
         :ok <- checkpoint(store.db, destination) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :create_checkpoint)}
    end
  catch
    :exit, reason -> {:error, BackendFailure.translate(reason, :create_checkpoint)}
  end

  defp checkpoint(adapter, destination) do
    %{db: rocksdb} = :sys.get_state(adapter)

    case :rocksdb.checkpoint(rocksdb, String.to_charlist(destination)) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    _error -> {:error, Error.new(:persistence_failure, :create_checkpoint)}
  end

  @doc false
  def architecture_file_role, do: @architecture_file_role
end

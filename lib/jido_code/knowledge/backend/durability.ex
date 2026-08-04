defmodule JidoCode.Knowledge.Backend.Durability do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias TripleStore.Backend.RocksDB.ErlangAdapter
  alias TripleStore.Dictionary.Manager
  alias TripleStore.Dictionary.SequenceCounter

  @spec sync(TripleStore.store(), atom()) :: :ok | {:error, Error.t()}
  def sync(store, operation) when is_atom(operation) do
    with {:ok, counter} <- Manager.get_counter(store.dict_manager),
         :ok <- SequenceCounter.flush(counter),
         :ok <- ErlangAdapter.flush_wal(store.db, true) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, BackendFailure.translate(reason, operation)}
    end
  catch
    :exit, reason -> {:error, BackendFailure.translate(reason, operation)}
  end
end

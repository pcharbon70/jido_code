defmodule JidoCode.Knowledge.Native do
  @moduledoc false

  alias JidoCode.Knowledge.Error

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    with {:module, TripleStore} <- Code.ensure_loaded(TripleStore),
         {:module, :rocksdb} <- :code.ensure_loaded(:rocksdb),
         true <- function_exported?(:rocksdb, :open, 2) do
      :ok
    else
      _reason -> {:error, Error.new(:unavailable, :load_native_backend)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :load_native_backend)}
  catch
    _kind, _reason -> {:error, Error.new(:unavailable, :load_native_backend)}
  end
end

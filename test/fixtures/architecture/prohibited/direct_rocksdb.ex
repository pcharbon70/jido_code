defmodule JidoCode.Factory.ArchitectureFixture.DirectRocksDB do
  def checkpoint(db, path), do: :rocksdb.checkpoint(db, path)
end

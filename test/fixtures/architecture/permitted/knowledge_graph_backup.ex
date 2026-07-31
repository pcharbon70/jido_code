defmodule JidoCode.Knowledge.Backend.ArchitectureFixture.GraphBackup do
  @architecture_file_role :graph_backup

  def role, do: @architecture_file_role
  def checkpoint(db, path), do: :rocksdb.checkpoint(db, path)
  def copy(source, destination), do: File.cp_r(source, destination)
end

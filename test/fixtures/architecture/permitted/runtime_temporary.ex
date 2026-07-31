defmodule JidoCode.Runtime.ArchitectureFixture.TemporaryFile do
  @architecture_file_role :temporary

  def role, do: @architecture_file_role
  def write(path, body), do: File.write!(path, body)
end

defmodule JidoCode.Integrations.ArchitectureFixture.ExternalWorktree do
  @architecture_file_role :external_worktree

  def role, do: @architecture_file_role
  def copy(source, destination), do: File.cp_r(source, destination)
end

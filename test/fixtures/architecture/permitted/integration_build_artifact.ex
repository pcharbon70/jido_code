defmodule JidoCode.Integrations.ArchitectureFixture.BuildArtifact do
  @architecture_file_role :build_artifact

  def role, do: @architecture_file_role
  def write(path, body), do: File.write!(path, body)
end

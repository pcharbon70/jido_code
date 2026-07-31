defmodule JidoCode.Factory.ArchitectureFixture.FileSnapshot do
  def save(path, state), do: File.write!(path, Jason.encode!(state))
end

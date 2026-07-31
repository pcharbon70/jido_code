defmodule JidoCode.Integrations.ArchitectureFixture.ExternalSecretReference do
  def fetch(reference) when is_binary(reference), do: System.fetch_env(reference)
end

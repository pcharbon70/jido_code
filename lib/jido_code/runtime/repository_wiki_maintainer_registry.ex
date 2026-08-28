defmodule JidoCode.Runtime.RepositoryWikiMaintainerRegistry do
  @moduledoc "Canonical tenant/repository runtime names for disposable wiki maintainers."

  @spec key(String.t(), String.t()) :: {String.t(), String.t()}
  def key(tenant_iri, repository_iri) when is_binary(tenant_iri) and is_binary(repository_iri),
    do: {tenant_iri, repository_iri}

  @spec via(module(), String.t(), String.t()) :: {:via, Registry, tuple()}
  def via(registry, tenant_iri, repository_iri) when is_atom(registry) do
    {:via, Registry, {registry, key(tenant_iri, repository_iri)}}
  end

  @spec lookup(module(), String.t(), String.t()) :: {:ok, pid()} | :error
  def lookup(registry, tenant_iri, repository_iri) when is_atom(registry) do
    case Registry.lookup(registry, key(tenant_iri, repository_iri)) do
      [{pid, _value}] -> if Process.alive?(pid), do: {:ok, pid}, else: :error
      [] -> :error
    end
  end
end

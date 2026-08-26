defmodule JidoCode.Runtime.DelegatedRuntimeRegistry do
  @moduledoc "Closed mapping from accepted delegated identities to compiled runtime code."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.Runtime.JidoHarness.ExecutableRegistry
  alias JidoCode.Runtime.JidoHarnessAdapter

  @spec resolve(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def resolve(selection) when is_map(selection) do
    with {:ok, resolved} <- lookup(selection),
         {:ok, executable} <- ExecutableRegistry.resolve("codex_cli") do
      {:ok, Map.put(resolved, :executable, executable)}
    end
  end

  def resolve(_selection),
    do: {:error, AdapterError.new(:invalid_input, :delegated_runtime_resolution)}

  @spec lookup(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def lookup(selection) when is_map(selection) do
    release = CodexRelease.manifest()
    release_digest = CodexRelease.digest()

    with :delegated_cli <- selection[:runtime_class],
         :codex <- selection[:provider],
         "codex_cli" <- selection[:adapter_key],
         "codex_cli" <- selection[:executable_registry_key],
         ^release_digest <- selection[:adapter_release_digest] do
      {:ok,
       %{
         adapter: JidoHarnessAdapter,
         profile: :codex_dga1,
         release: release
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unauthorized, :delegated_runtime_resolution)}
    end
  end

  def lookup(_selection),
    do: {:error, AdapterError.new(:invalid_input, :delegated_runtime_resolution)}
end

defmodule JidoCode.Integrations.ManagedCodingAdapterRegistry do
  @moduledoc "Fail-closed registration of one concrete adapter per ordinary coding tool."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.Definition

  @enabled ~w[
    search_source inspect_symbol read_file apply_edit create_file delete_file
    run_registered_check show_candidate_diff
  ]

  @modules %{
    "search_source" => JidoCode.Integrations.ManagedCodingAdapters.SearchSource,
    "inspect_symbol" => JidoCode.Integrations.ManagedCodingAdapters.InspectSymbol,
    "read_file" => JidoCode.Integrations.ManagedCodingAdapters.ReadFile,
    "apply_edit" => JidoCode.Integrations.ManagedCodingAdapters.ApplyEdit,
    "create_file" => JidoCode.Integrations.ManagedCodingAdapters.CreateFile,
    "delete_file" => JidoCode.Integrations.ManagedCodingAdapters.DeleteFile,
    "run_registered_check" => JidoCode.Integrations.ManagedCodingAdapters.RunRegisteredCheck,
    "show_candidate_diff" => JidoCode.Integrations.ManagedCodingAdapters.ShowCandidateDiff
  }

  @spec new(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def new(adapter_state) when is_map(adapter_state) do
    definitions = Enum.map(@enabled, &(Catalog.fetch(&1) |> elem(1)))
    tool_iris = Map.new(definitions, &{&1.name, &1.iri})
    adapter_state = Map.put(adapter_state, :tool_iris, tool_iris)

    with true <- Enum.all?(definitions, &match?(%Definition{}, &1)),
         registrations <- Enum.map(definitions, &registration(&1, adapter_state)),
         true <- Enum.all?(registrations, &match?({:ok, _}, &1)),
         values <- Enum.map(registrations, &elem(&1, 1)),
         true <- unique_modules?(values) do
      {:ok, Map.new(values, &{&1.name, &1})}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_adapter_registry)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_adapter_registry)}
  end

  def new(_adapter_state),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_adapter_registry)}

  @spec fetch(map(), Definition.t()) ::
          {:ok, {module(), map()}} | {:error, AdapterError.t()}
  def fetch(registry, %Definition{} = definition) when is_map(registry) do
    case Map.fetch(registry, definition.name) do
      {:ok, registration}
      when registration.version == definition.version and
             registration.adapter_digest == definition.adapter_digest and
             registration.adapter_identity == definition.adapter_identity ->
        {:ok, {registration.module, registration.state}}

      _missing_or_substituted ->
        {:error, AdapterError.new(:unauthorized, :managed_coding_adapter_registry)}
    end
  end

  def fetch(_registry, _definition),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_adapter_registry)}

  @spec enabled_names() :: [String.t()]
  def enabled_names, do: @enabled

  defp registration(definition, state) do
    module = Map.fetch!(@modules, definition.name)
    identity = Atom.to_string(module) <> "/1"

    if Code.ensure_loaded?(module) and function_exported?(module, :execute, 3) and
         definition.adapter_identity == identity do
      {:ok,
       %{
         name: definition.name,
         version: definition.version,
         module: module,
         state: state,
         adapter_identity: identity,
         adapter_digest: Definition.digest(identity)
       }}
    else
      :error
    end
  end

  defp unique_modules?(registrations) do
    modules = Enum.map(registrations, & &1.module)
    length(modules) == length(Enum.uniq(modules))
  end
end

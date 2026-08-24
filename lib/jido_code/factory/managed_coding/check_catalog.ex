defmodule JidoCode.Factory.ManagedCoding.CheckCatalog do
  @moduledoc "Closed registry of server-owned managed coding checks."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest

  @enforce_keys [:definitions, :revision]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new([CheckDefinition.t()]) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(definitions) when is_list(definitions) and definitions != [] do
    names = Enum.map(definitions, & &1.name)

    if Enum.all?(definitions, &match?(%CheckDefinition{}, &1)) and
         length(names) == length(Enum.uniq(names)) do
      indexed = Map.new(definitions, &{&1.name, &1})

      revision =
        WorkspaceDigest.digest(Enum.map(Enum.sort(definitions), &CheckDefinition.digest/1))

      {:ok, %__MODULE__{definitions: indexed, revision: revision}}
    else
      invalid()
    end
  end

  def new(_definitions), do: invalid()

  @spec fetch(t(), String.t()) :: {:ok, CheckDefinition.t()} | {:error, AdapterError.t()}
  def fetch(%__MODULE__{definitions: definitions}, name) when is_binary(name) do
    case Map.fetch(definitions, name) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, AdapterError.new(:unauthorized, :registered_check_catalog)}
    end
  end

  def fetch(_catalog, _name), do: invalid()
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :registered_check_catalog)}
end

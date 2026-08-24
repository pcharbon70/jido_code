defmodule JidoCode.Factory.ManagedCodingAdapterRegistryTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Integrations.ManagedCodingAdapterRegistry

  test "binds each enabled definition revision to exactly one concrete adapter" do
    assert {:ok, registry} = ManagedCodingAdapterRegistry.new(%{marker: :adapter_state})

    assert Map.keys(registry) |> Enum.sort() ==
             ManagedCodingAdapterRegistry.enabled_names() |> Enum.sort()

    modules =
      for name <- ManagedCodingAdapterRegistry.enabled_names() do
        {:ok, definition} = Catalog.fetch(name)
        assert {:ok, {module, state}} = ManagedCodingAdapterRegistry.fetch(registry, definition)
        assert function_exported?(module, :execute, 3)
        assert definition.adapter_identity == Atom.to_string(module) <> "/1"
        assert state.marker == :adapter_state
        assert state.tool_iris[name] == definition.iri
        module
      end

    assert length(modules) == length(Enum.uniq(modules))
  end

  test "fails closed for missing, substituted, and privileged adapters" do
    assert {:ok, registry} = ManagedCodingAdapterRegistry.new(%{})
    {:ok, definition} = Catalog.fetch("read_file")

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingAdapterRegistry.fetch(Map.delete(registry, "read_file"), definition)

    substituted = %{definition | adapter_digest: String.duplicate("0", 64)}

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingAdapterRegistry.fetch(registry, substituted)

    for name <- ["run_governed_command", "submit_candidate", "request_clarification"] do
      refute name in ManagedCodingAdapterRegistry.enabled_names()
      {:ok, privileged} = Catalog.fetch(name)

      assert {:error, %{kind: :unauthorized}} =
               ManagedCodingAdapterRegistry.fetch(registry, privileged)
    end
  end
end

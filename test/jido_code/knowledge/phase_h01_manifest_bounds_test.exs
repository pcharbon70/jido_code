defmodule JidoCode.Knowledge.PhaseH01ManifestBoundsTest do
  @moduledoc """
  Phase H01 Section 1.3 - context manifest and bounds contracts.

  Proves the host and delegated manifest content contracts, the accepted
  manifest bounds (source graphs, items, bytes, tokens, instruction, item
  size), truncation and omission recording, and honest reconstruction
  status with missing-class reporting.
  """

  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Execution.ContextManifest, as: Manifest
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture

  setup context do
    fixture = Phase08AttemptFixture.started!(context)
    %{fixture: fixture}
  end

  describe "host manifest content contract" do
    test "accepts a complete host manifest with pinned revisions and items", %{fixture: fixture} do
      assert {:ok, manifest} =
               Manifest.new(fixture.attempt.iri, %{
                 index: 1,
                 digest: String.duplicate("aa", 32),
                 kind: :host_context,
                 reconstruction: :exact,
                 source_graphs: [{fixture.control_graph, 3}],
                 items: [item(Phase04Fixture.local!(:activity, 81), 1_024)],
                 serialized_bytes: 1_024,
                 estimated_tokens: 256,
                 instruction_bytes: 512
               })

      statements = Manifest.statements(manifest)

      assert {manifest.iri, "https://jido.run/ontology/factory#serializedBytes",
              RDF.XSD.NonNegativeInteger.new(1_024)} in statements

      assert Enum.any?(statements, fn statement ->
               match?(
                 {_, "https://jido.run/ontology/factory#sourceGraphRevision", %RDF.IRI{}},
                 statement
               )
             end)

      assert Enum.any?(statements, fn statement ->
               elem(statement, 1) == "https://jido.run/ontology/factory#manifestItem" and
                 is_struct(elem(statement, 2), RDF.Literal)
             end)
    end

    test "rejects graph and item lists that skip their counterpart", %{fixture: fixture} do
      assert {:error, _error} =
               Manifest.new(fixture.attempt.iri, %{
                 index: 1,
                 digest: String.duplicate("aa", 32),
                 kind: :host_context,
                 reconstruction: :exact,
                 items: [item(Phase04Fixture.local!(:activity, 82), 64)],
                 serialized_bytes: 64,
                 estimated_tokens: 16
               })

      assert {:error, _error} =
               Manifest.new(fixture.attempt.iri, %{
                 index: 1,
                 digest: String.duplicate("aa", 32),
                 kind: :host_context,
                 reconstruction: :exact,
                 source_graphs: [{fixture.control_graph, 3}],
                 serialized_bytes: 0,
                 estimated_tokens: 0
               })
    end
  end

  describe "accepted bounds" do
    test "rejects more than twenty source graphs", %{fixture: fixture} do
      graphs = Enum.map(1..21, fn i -> {"https://jido.run/graph/factory/policy-#{i}", 1} end)

      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes() |> Map.put(:source_graphs, graphs)
               )
    end

    test "rejects more than two hundred items", %{fixture: fixture} do
      items = Enum.map(1..201, fn i -> item(Phase04Fixture.local!(:activity, 90 + i), 8) end)

      assert {:error, _error} =
               Manifest.new(fixture.attempt.iri, base_attributes() |> Map.put(:items, items))
    end

    test "rejects serialized bytes and token estimates above the ceiling", %{fixture: fixture} do
      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes() |> Map.put(:serialized_bytes, 262_145)
               )

      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes() |> Map.put(:estimated_tokens, 65_537)
               )
    end

    test "rejects items above the per-item byte cap", %{fixture: fixture} do
      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes()
                 |> Map.put(:items, [item(Phase04Fixture.local!(:activity, 91), 32_769)])
                 |> Map.put(:serialized_bytes, 32_769)
               )
    end

    test "rejects instructions above the byte cap", %{fixture: fixture} do
      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes() |> Map.put(:instruction_bytes, 16_385)
               )
    end

    test "records truncation and omissions as bounded classified reasons", %{fixture: fixture} do
      assert {:ok, manifest} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes()
                 |> Map.put(:omissions, [%{class: "source_graph", reason: "degree cap"}])
               )

      statements = Manifest.statements(manifest)

      assert Enum.any?(statements, fn statement ->
               elem(statement, 1) == "https://jido.run/ontology/factory#manifestOmission"
             end)
    end
  end

  describe "delegated-input manifests" do
    test "requires provider-internal fields to be explicitly unavailable", %{fixture: fixture} do
      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes() |> Map.put(:kind, :delegated_input)
               )

      assert {:ok, manifest} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes()
                 |> Map.put(:kind, :delegated_input)
                 |> Map.put(:unavailable_fields, [:prompts, :tool_manifests])
               )

      statements = Manifest.statements(manifest)

      assert Enum.any?(statements, fn statement ->
               elem(statement, 1) == "https://jido.run/ontology/factory#providerFieldUnavailable"
             end)
    end

    test "rejects unknown unavailable-field classes", %{fixture: fixture} do
      assert {:error, _error} =
               Manifest.new(
                 fixture.attempt.iri,
                 base_attributes()
                 |> Map.put(:kind, :delegated_input)
                 |> Map.put(:unavailable_fields, [:hidden_thoughts])
               )
    end
  end

  describe "reconstruction status" do
    test "non-exact statuses require missing-class reporting", %{fixture: fixture} do
      for status <- [:partial, :unavailable] do
        assert {:error, _error} =
                 Manifest.new(
                   fixture.attempt.iri,
                   base_attributes() |> Map.put(:reconstruction, status)
                 )

        assert {:ok, manifest} =
                 Manifest.new(
                   fixture.attempt.iri,
                   base_attributes()
                   |> Map.put(:reconstruction, status)
                   |> Map.put(:missing_classes, [:raw_prompt])
                 )

        assert Enum.any?(Manifest.statements(manifest), fn statement ->
                 elem(statement, 1) == "https://jido.run/ontology/factory#reconstructionMissing"
               end)
      end
    end

    test "a digest alone never implies replayability for the first manifest", %{fixture: fixture} do
      # The attempt-created first manifest is exact by construction; any
      # later non-exact manifest must name what cannot be reconstructed.
      assert {:ok, first} =
               Manifest.new(fixture.attempt.iri, %{
                 index: 0,
                 digest: fixture.attempt.context_digest,
                 kind: :host_context,
                 reconstruction: :exact
               })

      assert first.reconstruction == :exact
      assert first.missing_classes == []
    end
  end

  defp base_attributes do
    %{
      index: 1,
      digest: String.duplicate("aa", 32),
      kind: :host_context,
      reconstruction: :exact,
      source_graphs: [{"https://jido.run/graph/factory/policy", 2}],
      items: [],
      serialized_bytes: 0,
      estimated_tokens: 0
    }
  end

  defp item(iri, bytes),
    do: %{iri: iri, digest: String.duplicate("bb", 32), bytes: bytes}
end

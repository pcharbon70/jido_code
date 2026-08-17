defmodule JidoCode.Factory.Harness.PhaseH02ContextCompilerTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Harness.ContextCompiler
  alias JidoCode.TestSupport.Phase04Fixture

  @policy_graph "https://jido.run/graph/factory/policy"

  test "compiles reviewed results in the recommended order with exact provenance" do
    attributes = attributes([section(:task, 2), section(:system_contract, 1)])

    assert {:ok, compiled} = ContextCompiler.compile(attributes, query: &query/6)

    assert Enum.map(compiled.items, & &1.kind) == [:system_contract, :task]
    assert compiled.digest == compiled.manifest.digest
    assert compiled.manifest.reconstruction == :exact
    assert compiled.revision_pins.snapshot_iri == attributes.snapshot_iri
    assert Enum.all?(compiled.items, &(byte_size(&1.provenance_digest) == 64))

    manifest_items =
      compiled.manifest
      |> JidoCode.Knowledge.Execution.ContextManifest.statements()
      |> Enum.filter(&(elem(&1, 1) == "https://jido.run/ontology/factory#manifestItem"))

    assert length(manifest_items) == 2

    assert Enum.all?(manifest_items, fn {_subject, _predicate, literal} ->
             literal
             |> RDF.Literal.value()
             |> String.split("|")
             |> length() == 5
           end)
  end

  test "is deterministic across caller ordering" do
    forward = attributes([section(:system_contract, 1), section(:task, 2)])
    reverse = attributes(Enum.reverse(forward.sections))

    assert {:ok, first} = ContextCompiler.compile(forward, query: &query/6)
    assert {:ok, second} = ContextCompiler.compile(reverse, query: &query/6)

    assert first.serialized == second.serialized
    assert first.digest == second.digest
    assert first.manifest.items == second.manifest.items
  end

  test "rejects silently substituted dataset, graph, and snapshot revisions" do
    base = attributes([section(:source_excerpt, 3)])

    stale_dataset = fn name, version, parameters, authority, scope, options ->
      {:ok, result} = query(name, version, parameters, authority, scope, options)
      {:ok, %{result | dataset_revision: result.dataset_revision + 1}}
    end

    stale_graph = fn name, version, parameters, authority, scope, options ->
      {:ok, result} = query(name, version, parameters, authority, scope, options)
      {:ok, %{result | graph_revisions: %{@policy_graph => 8}}}
    end

    assert {:error, %{kind: :stale_precondition}} =
             ContextCompiler.compile(base, query: stale_dataset)

    assert {:error, %{kind: :stale_precondition}} =
             ContextCompiler.compile(base, query: stale_graph)

    substituted =
      put_in(base.sections, [
        %{List.first(base.sections) | snapshot_iri: Phase04Fixture.local!(:activity, 99)}
      ])

    assert {:error, %{kind: :invalid_input}} =
             ContextCompiler.compile(substituted, query: &query/6)
  end

  test "creates a linked lossy summary and just-in-time retrieval descriptor" do
    attributes =
      [section(:source_excerpt, 4)]
      |> attributes()
      |> put_in([:budget, :max_item_bytes], 512)

    large_query = fn name, version, parameters, authority, scope, options ->
      {:ok, result} = query(name, version, parameters, authority, scope, options)
      {:ok, %{result | data: %{payload: String.duplicate("source ", 2_000)}}}
    end

    assert {:ok, compiled} = ContextCompiler.compile(attributes, query: large_query)

    assert [%{summarized?: true} = item] = compiled.items
    assert byte_size(item.content) <= 512
    assert [%{reason: :lossy_summary, original_digest: original_digest}] = compiled.retrievals
    assert original_digest != item.digest
    assert [%{reason: :lossy_summary}] = compiled.omissions
    assert compiled.manifest.reconstruction == :partial
  end

  test "records optional budget omissions and never drops required context" do
    optional = attributes([section(:system_contract, 5), section(:task, 6)])
    optional = put_in(optional, [:budget, :max_items], 1)

    assert {:ok, compiled} = ContextCompiler.compile(optional, query: &query/6)
    assert length(compiled.items) == 1
    assert [%{kind: :task, reason: :item_budget}] = compiled.omissions
    assert [%{reason: :item_budget}] = compiled.retrievals

    required =
      update_in(optional.sections, fn sections ->
        Enum.map(sections, fn section ->
          if section.kind == :task, do: Map.put(section, :required?, true), else: section
        end)
      end)

    assert {:error, %{kind: :invalid_input}} =
             ContextCompiler.compile(required, query: &query/6)
  end

  defp attributes(sections) do
    %{
      attempt_iri: Phase04Fixture.local!(:attempt, 1),
      manifest_index: 1,
      repository_iri: Phase04Fixture.resource!("phase-h02-repository"),
      snapshot_iri: Phase04Fixture.local!(:activity, 2),
      analysis_profile: "elixir-ast/1.0.0",
      expected_dataset_revision: 44,
      source_graph_revisions: %{@policy_graph => 7},
      authority: :fixture_authority,
      scope_iri: Phase04Fixture.scope!(:factory, "phase-h02"),
      sections: sections,
      budget: %{
        max_items: 20,
        max_bytes: 65_536,
        max_tokens: 16_384,
        max_item_bytes: 4_096
      }
    }
  end

  defp section(kind, seed) do
    repository = Phase04Fixture.resource!("phase-h02-repository")
    snapshot = Phase04Fixture.local!(:activity, 2)

    %{
      kind: kind,
      query_name: :resource_description,
      query_version: "1.7.0",
      parameters: %{resource: Phase04Fixture.local!(:activity, 100 + seed)},
      item_iri: Phase04Fixture.local!(:activity, 200 + seed),
      classification: :internal,
      required?: false,
      graph_revisions: %{@policy_graph => 7},
      repository_iri: repository,
      snapshot_iri: snapshot,
      analysis_profile: "elixir-ast/1.0.0"
    }
  end

  defp query(:resource_description, "1.7.0", parameters, _authority, _scope, _options) do
    {:ok,
     %{
       query_name: :resource_description,
       query_version: "1.7.0",
       dataset_revision: 44,
       graph_revisions: %{@policy_graph => 7},
       completeness: %{complete?: true},
       freshness: :current,
       truncated?: false,
       data: %{resource: parameters.resource}
     }}
  end
end

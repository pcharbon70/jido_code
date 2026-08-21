defmodule JidoCode.Factory.Harness.PhaseH03MemoryContextTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Harness.ContextCompiler
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.EvidencePacket
  alias JidoCode.Knowledge.Memory.RetrievalTelemetry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.Phase04Fixture

  @policy_graph "https://jido.run/graph/factory/policy"

  test "strict no-memory mode is bit-identical to ordinary context compilation" do
    attributes = attributes()
    options = [query: &query/6]

    assert {:ok, ordinary} = ContextCompiler.compile(attributes, options)
    assert {:ok, disabled} = ContextCompiler.compile_with_memory(attributes, :disabled, options)
    assert {:ok, absent} = ContextCompiler.compile_with_memory(attributes, nil, options)

    assert disabled == ordinary
    assert absent == ordinary
    assert disabled.serialized == ordinary.serialized
    assert disabled.digest == ordinary.digest
    assert disabled.manifest == ordinary.manifest
  end

  test "keeps memory evidence structurally separate and pins its epistemic labels" do
    attributes = attributes()
    packet = packet(attributes)

    assert {:ok, base} = ContextCompiler.compile(attributes, query: &query/6)

    assert {:ok, compiled} =
             ContextCompiler.compile_with_memory(attributes, packet, query: &query/6)

    document = Jason.decode!(compiled.serialized)
    assert document["instruction_context"] == Jason.decode!(base.serialized)
    assert document["memory_evidence"]["boundary"] == "non_instructional_data"
    assert document["memory_evidence"]["authority"] == false
    assert compiled.manifest.retrieval_commitment.packet_digest == packet.digest
    assert compiled.manifest.retrieval_commitment.partition_digest == packet.partition_digest

    memory_item = Enum.find(compiled.items, &(&1.kind == :memory_evidence))
    assert memory_item.source_iri == List.first(packet.items).source_iri
    assert memory_item.classification == :internal
    assert memory_item.trust == :accepted
    assert memory_item.reconstruction == :recoverable_reference

    manifest_literal =
      compiled.manifest
      |> JidoCode.Knowledge.Execution.ContextManifest.statements()
      |> Enum.find_value(fn
        {_subject, "https://jido.run/ontology/factory#manifestItem", literal} ->
          value = RDF.Literal.value(literal)
          if String.contains?(value, "|memory_evidence|"), do: value

        _statement ->
          nil
      end)

    assert manifest_literal
    assert length(String.split(manifest_literal, "|")) == 10
    assert String.contains?(manifest_literal, "|accepted|recoverable_reference|")
  end

  test "emits bounded retrieval metrics without accepting payload metadata" do
    handler = "phase-h03-memory-telemetry-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        RetrievalTelemetry.event(),
        fn event, measurements, metadata, _config ->
          send(parent, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    measurements = %{
      latency_ms: 14,
      estimated_cost_microunits: 3,
      truncated_count: 1,
      unavailable_count: 2,
      source_count: 4,
      index_rebuild_count: 0
    }

    metadata = %{
      channel: :hybrid,
      outcome: :ok,
      query_version: "2.0.0",
      ranking_version: "1.0.0",
      index_version: "1.0.0"
    }

    assert :ok = RetrievalTelemetry.emit(measurements, metadata)
    assert_receive {:telemetry, [:jido_code, :memory, :retrieval], ^measurements, ^metadata}

    assert_raise ArgumentError, fn ->
      RetrievalTelemetry.emit(measurements, Map.put(metadata, :payload, "secret value"))
    end
  end

  defp attributes do
    %{
      attempt_iri: Phase04Fixture.local!(:attempt, 301),
      manifest_index: 1,
      repository_iri: Phase04Fixture.resource!("phase-h03-memory-repository"),
      snapshot_iri: Phase04Fixture.local!(:activity, 302),
      analysis_profile: "elixir-ast/1.0.0",
      expected_dataset_revision: 44,
      source_graph_revisions: %{@policy_graph => 7},
      authority: :fixture_authority,
      scope_iri: Phase04Fixture.scope!(:factory, "phase-h03-memory"),
      sections: [section()],
      budget: %{
        max_items: 20,
        max_bytes: 65_536,
        max_tokens: 16_384,
        max_item_bytes: 4_096
      }
    }
  end

  defp section do
    %{
      kind: :task,
      query_name: :resource_description,
      query_version: "1.7.0",
      parameters: %{resource: Phase04Fixture.local!(:activity, 303)},
      item_iri: Phase04Fixture.local!(:activity, 304),
      classification: :internal,
      required?: true,
      graph_revisions: %{@policy_graph => 7},
      repository_iri: Phase04Fixture.resource!("phase-h03-memory-repository"),
      snapshot_iri: Phase04Fixture.local!(:activity, 302),
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

  defp packet(attributes) do
    source = resource(:evidence_claim, "harness-memory-source")
    item = resource(:knowledge_assertion, "harness-memory-item")
    request = resource(:memory_retrieval_request, "harness-memory-request")
    packet = resource(:memory_evidence_packet, "harness-memory-packet")
    {:ok, graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: attributes.attempt_iri})

    %EvidencePacket{
      iri: packet,
      digest: String.duplicate("d", 64),
      request_iri: request,
      partition_digest: String.duplicate("e", 64),
      query_version: "2.0.0",
      ranking_version: "1.0.0",
      index_version: "1.0.0",
      items: [
        %{
          iri: item,
          selection_reason: %{features: ["current_source"]},
          source_iri: source,
          temporal_scope: %{recorded_at: "2026-08-20T12:00:00Z"},
          classification: :internal,
          trust: :accepted,
          evidence_strength: :independently_verified,
          freshness: :current,
          limitations: [],
          contradiction: :none_known,
          applicability: %{repository: attributes.repository_iri},
          recovery_handle: %{
            source_iri: source,
            graph_iri: graph,
            graph_revision: 2,
            exact_content_permit_required?: true
          },
          payload: %{
            kind: :non_instructional_data,
            value: %{summary: "Prior verified result"}
          },
          authority?: false
        }
      ],
      omissions: [%{iri: resource(:knowledge_assertion, "budget-omitted"), reason: :item_budget}],
      usage: %{items: 1, graphs: 1, bytes: 128, tokens: 32, time_ms: 2},
      non_authoritative?: true
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

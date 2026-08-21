defmodule JidoCode.Knowledge.Memory.Phase06GraphContentTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ContentBenchmark
  alias JidoCode.Knowledge.Memory.EpisodeContent
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @now ~U[2026-08-21 17:00:00Z]

  test "builds one complete immutable graph segment from bounded ciphertext only" do
    plaintext = "sensitive source payload"
    attributes = content_attributes(["ciphertext-0", "ciphertext-1"])

    assert {:ok, content} = Knowledge.episode_content(attributes)
    assert content.representation == :ciphertext
    assert content.encrypted_before_command?
    assert content.byte_count == byte_size("ciphertext-0ciphertext-1")
    assert Enum.map(content.chunks, & &1.index) == [0, 1]
    assert EpisodeContent.plaintext(content) == :unavailable

    serialized = inspect(EpisodeContent.statements(content), limit: :infinity)
    refute String.contains?(serialized, plaintext)
    assert String.contains?(serialized, Base.encode64("ciphertext-0"))

    assert {:ok, command} =
             Knowledge.store_episode_content(
               content,
               command_attributes(content),
               clock: fn -> @now end
             )

    assert command.command_type == "StoreEpisodeContent"
    assert command.command_version == CommandRegistry.content_version()
    assert command.payload.encrypted_before_command

    assert {:ok, definition} =
             CommandRegistry.resolve(command.command_type, command.command_version)

    assert definition.capability == :content_writer

    assert {:ok, contract} = GraphRegistry.fetch(:episode_content)
    refute contract.enabled
    refute GraphRegistry.write_allowed?(:episode_content, :create)
  end

  test "rejects malformed, reordered, oversized, mixed-policy, and plaintext-shaped chunks" do
    base = content_attributes([chunk(0, "ciphertext-0"), chunk(1, "ciphertext-1")])

    for chunks <- [
          [chunk(1, "ciphertext-1")],
          [chunk(0, "ciphertext-0"), chunk(0, "duplicate")],
          [chunk(1, "ciphertext-1"), chunk(0, "ciphertext-0")],
          [chunk(0, String.duplicate("x", 16_385))],
          [Map.put(chunk(0, "ciphertext"), :policy_revision, "wrong")],
          [Map.put(chunk(0, "ciphertext"), :classification, :secret_value)]
        ] do
      assert {:error, %{kind: :invalid_input}} =
               base |> Map.put(:ciphertext_chunks, chunks) |> Knowledge.episode_content()
    end

    assert {:error, %{kind: :invalid_input}} =
             base
             |> Map.put(:encrypted_before_command?, false)
             |> Map.put(:plaintext, "must never enter the content contract")
             |> Knowledge.episode_content()

    assert {:error, %{kind: :invalid_input}} =
             base |> Map.put(:classification, :secret_value) |> Knowledge.episode_content()
  end

  test "measures every pinned operation and signs an all-threshold graph-native decision" do
    baseline = %{
      capture: 100,
      query: 100,
      backup: 100,
      restore: 100,
      rebuild: 100,
      storage_bytes: 1_000
    }

    measured = %{
      capture: 150,
      query: 175,
      backup: 125,
      restore: 140,
      rebuild: 190,
      storage_bytes: 3_500
    }

    integrity = %{integrity_failures: 0, orphaned_objects: 0, unerased_objects: 0}

    assert {:ok, metrics} = Knowledge.measure_content_benchmark(baseline, measured, integrity)
    assert Guardrails.storage_decision(metrics) == :graph_native

    signer = &:crypto.mac(:hmac, :sha256, "phase-6-benchmark-signing-key", &1)
    assert {:ok, decision} = Knowledge.decide_content_storage(metrics, signer)
    assert decision.decision == :graph_native
    assert decision.corpus_digest == Guardrails.benchmark_corpus_digest()
    assert decision.thresholds == Guardrails.benchmark_thresholds()
    assert byte_size(Base.decode64!(decision.signature)) == 32
    assert ContentBenchmark.revision() == "1.0.0"

    failed = %{metrics | query_latency_ratio: 2.01}
    assert {:ok, blocked} = Knowledge.decide_content_storage(failed, signer)
    assert blocked.decision == :vault_adr_required

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.measure_content_benchmark(
               Map.delete(baseline, :restore),
               measured,
               integrity
             )
  end

  defp content_attributes(chunks) do
    %{
      repository_iri: resource(:repository_snapshot, "phase-6-repository"),
      source_event_iri: resource(:execution_event, "phase-6-source-event"),
      content_identity: digest("opaque-random-content-id"),
      segment_index: 0,
      policy_revision: DataPolicy.revision(),
      classification: :encrypted_content,
      media_type: "application/octet-stream",
      representation: :ciphertext,
      key_reference_iri: resource(:content_key_reference, "phase-6-content-key"),
      key_generation: 1,
      encryption_algorithm: :aes_256_gcm,
      nonce: String.duplicate(<<1>>, 12),
      authentication_tag: String.duplicate(<<2>>, 16),
      aad_digest: digest("authenticated-context"),
      ciphertext_chunks: chunks,
      closed_at: @now,
      encrypted_before_command?: true
    }
  end

  defp command_attributes(content) do
    {:ok, graph} =
      GraphRegistry.graph_iri(:episode_content, %{
        repository: content.repository_iri,
        content: content.iri
      })

    %{
      repository_scope_iri: resource(:execution_context, "phase-6-content-scope"),
      principal_iri: resource(:authorization_grant, "phase-6-content-principal"),
      actor_iri: resource(:authorization_grant, "phase-6-content-actor"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "phase-6-content-correlation"),
      causation_iri: content.source_event_iri,
      expected_dataset_revision: 1,
      expected_graph_revisions: %{graph => 0},
      recorded_at: @now,
      reason: "store complete encrypted episode content"
    }
  end

  defp chunk(index, ciphertext) do
    %{
      index: index,
      ciphertext: ciphertext,
      policy_revision: DataPolicy.revision(),
      classification: :encrypted_content,
      media_type: "application/octet-stream",
      key_reference_iri: resource(:content_key_reference, "phase-6-content-key")
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

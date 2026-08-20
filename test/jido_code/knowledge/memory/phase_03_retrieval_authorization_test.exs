defmodule JidoCode.Knowledge.Memory.Phase03RetrievalAuthorizationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.ContextManifest
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.CandidateAccess
  alias JidoCode.Knowledge.Memory.RetrievalActivity
  alias JidoCode.Knowledge.Memory.RetrievalRequest
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-20 12:00:00Z]

  test "derives the first-stage partition only from an allowed revisioned decision" do
    attributes = request_attributes()
    assert {:ok, request} = RetrievalRequest.new(attributes)

    assert request.query_version == "2.0.0"
    assert request.partition.authorization_revision == 7
    assert request.partition.erasure_generation == 3
    assert digest?(request.partition.partition_digest)
    assert digest?(request.digest)

    assert {:error, %{kind: :unauthorized, operation: :memory_retrieval_partition}} =
             attributes
             |> put_in([:authorization, :repository_iri], resource(:repository_snapshot, "other"))
             |> RetrievalRequest.new()

    assert {:error, %{kind: :unauthorized}} =
             attributes
             |> put_in([:authorization, :authorization_decision], :denied)
             |> RetrievalRequest.new()

    assert {:ok, changed} =
             attributes
             |> put_in([:authorization, :erasure_generation], 4)
             |> RetrievalRequest.new()

    refute request.partition.partition_digest == changed.partition.partition_digest
  end

  test "candidate generation receives the partition and excludes ineligible records before ranking" do
    assert {:ok, request} = RetrievalRequest.new(request_attributes())
    parent = self()
    eligible = candidate(request, "eligible")

    future = %{
      candidate(request, "future")
      | recorded_at: DateTime.add(@now, 1, :second)
    }

    erased = %{candidate(request, "erased") | erased?: true}

    cross_scope = %{
      candidate(request, "cross-scope")
      | repository_iri: resource(:repository_snapshot, "cross-scope-repository")
    }

    generator = fn partition ->
      send(parent, {:partition, partition})
      {:ok, [future, erased, cross_scope, eligible]}
    end

    assert {:ok, result} = CandidateAccess.generate(request, :lexical, generator)
    assert_receive {:partition, partition}
    assert partition.partition_digest == request.partition.partition_digest
    assert result.candidates == [eligible]
    assert result.eligible_count == 1
    assert result.omitted.future == 1
    assert result.omitted.erased == 1
    assert result.omitted.scope == 1
  end

  test "records retrieval start and outcome as exact predecessor-chained segment events" do
    assert {:ok, request} = RetrievalRequest.new(request_attributes())
    assert {:ok, start} = RetrievalActivity.start(request, @now)
    assert {:ok, segment, _opening} = EventSegment.open(request.attempt_iri, %{index: 0})

    assert {:ok, %{segment: started, command: start_command}} =
             RetrievalActivity.record_command(start, segment, command_attributes(segment, 1),
               clock: fn -> @now end
             )

    assert start_command.command_type == "RecordMemoryRetrievalStart"
    assert start_command.command_version == "2.0.0"
    assert started.open_effect_iris == [start.iri]

    selected = resource(:knowledge_assertion, "selected")
    omitted = resource(:knowledge_assertion, "omitted")

    assert {:ok, outcome} =
             RetrievalActivity.outcome(start, %{
               occurred_at: DateTime.add(@now, 1, :second),
               packet_digest: String.duplicate("a", 64),
               selected_iris: [selected],
               omitted_iris: [omitted],
               opened_iris: [selected],
               unavailable_iris: []
             })

    assert {:ok, %{segment: finished, command: outcome_command}} =
             RetrievalActivity.record_command(outcome, started, command_attributes(started, 2),
               clock: fn -> DateTime.add(@now, 1, :second) end
             )

    assert outcome_command.command_type == "RecordMemoryRetrievalOutcome"
    assert outcome_command.command_version == "2.0.0"
    assert finished.open_effect_iris == []

    assert {:ok, start_definition} =
             CommandRegistry.resolve("RecordMemoryRetrievalStart", "2.0.0")

    assert :before_candidate_generation in start_definition.preconditions

    assert {:ok, outcome_definition} =
             CommandRegistry.resolve("RecordMemoryRetrievalOutcome", "2.0.0")

    assert :packet_commitment_exact in outcome_definition.preconditions
  end

  test "binds the request, partition, algorithms, and packet digest to context" do
    assert {:ok, request} = RetrievalRequest.new(request_attributes())
    packet = resource(:memory_evidence_packet, "context-packet")
    packet_digest = String.duplicate("b", 64)

    assert {:ok, manifest} =
             ContextManifest.new(request.attempt_iri, %{
               index: 1,
               digest: String.duplicate("c", 64),
               kind: :host_context,
               reconstruction: :exact,
               source_graphs: [],
               items: [],
               serialized_bytes: 0,
               estimated_tokens: 0,
               omissions: [],
               retrieval_commitment: %{
                 request_iri: request.iri,
                 packet_iri: packet,
                 packet_digest: packet_digest,
                 partition_digest: request.partition.partition_digest,
                 query_version: request.query_version,
                 ranking_version: request.ranking_version,
                 index_version: request.index_version
               }
             })

    assert manifest.retrieval_commitment.packet_digest == packet_digest

    assert Enum.any?(ContextManifest.statements(manifest), fn statement ->
             {subject, predicate, object} = RDF.Triple.new(statement)

             to_string(subject) == manifest.iri and
               String.ends_with?(to_string(predicate), "evidencePacketDigest") and
               RDF.Literal.value(object) == packet_digest
           end)
  end

  defp request_attributes do
    attempt = resource(:execution_attempt, "request-attempt")
    actor = resource(:authorization_grant, "request-actor")
    repository = resource(:repository_snapshot, "request-repository")
    tenant = resource(:execution_context, "request-tenant")
    actor_scope = resource(:execution_context, "request-actor-scope")

    %{
      attempt_iri: attempt,
      actor_iri: actor,
      repository_iri: repository,
      tenant_iri: tenant,
      actor_scope_iri: actor_scope,
      task_iri: resource(:task_proposal, "request-task"),
      purpose: :managed_continuity,
      plan_phase: "memory-phase-03",
      effective_at: @now,
      provider_profile_iri: resource(:model_access_profile, "request-provider-profile"),
      data_ceiling: :internal,
      allowed_classifications: [:internal, :public],
      categories: [:attempt_history, :failure, :lineage],
      trust_levels: [:accepted, :observed, :verified],
      budgets: %{
        item_limit: 10,
        graph_limit: 4,
        byte_limit: 32_000,
        token_limit: 8_000,
        time_limit_ms: 1_000
      },
      query_version: QueryCatalog.history_version(),
      ranking_version: "1.0.0",
      index_version: "1.0.0",
      authorization: %{
        authorization_iri: resource(:authorization_grant, "request-authorization"),
        authorization_decision: :allowed,
        authorization_revision: 7,
        repository_iri: repository,
        tenant_iri: tenant,
        actor_scope_iri: actor_scope,
        purpose: :managed_continuity,
        data_ceiling: :internal,
        effective_time_generation: 12,
        erasure_generation: 3
      }
    }
  end

  defp candidate(request, seed) do
    source = resource(:evidence_claim, seed <> "-source")
    {:ok, graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: request.attempt_iri})

    %{
      iri: resource(:knowledge_assertion, seed),
      source_iri: source,
      source_graph_iri: graph,
      source_revision: 2,
      partition_digest: request.partition.partition_digest,
      repository_iri: request.repository_iri,
      tenant_iri: request.tenant_iri,
      actor_scope_iri: request.actor_scope_iri,
      purpose: request.purpose,
      classification: :internal,
      category: :attempt_history,
      trust: :accepted,
      recorded_at: @now,
      available?: true,
      erased?: false,
      invalidated?: false,
      compatible?: true
    }
  end

  defp command_attributes(segment, expected_revision) do
    %{
      command_iri: resource(:command_request, "command-#{expected_revision}"),
      principal_iri: resource(:authorization_grant, "principal"),
      actor_iri: resource(:authorization_grant, "principal"),
      repository_scope_iri: resource(:execution_context, "repository-scope"),
      correlation_iri: resource(:command_request, "correlation"),
      causation_iri: resource(:command_request, "causation"),
      expected_segment_revision: expected_revision,
      expected_dataset_revision: expected_revision,
      expected_graph_revisions: %{segment.graph_iri => expected_revision},
      recorded_at: DateTime.add(@now, expected_revision - 1, :second),
      reason: "record governed memory retrieval"
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
end

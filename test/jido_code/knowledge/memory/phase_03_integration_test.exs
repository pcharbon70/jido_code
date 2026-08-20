defmodule JidoCode.Knowledge.Memory.Phase03IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Memory.CandidateAccess
  alias JidoCode.Knowledge.Memory.RetrievalIndex
  alias JidoCode.Knowledge.Memory.RetrievalPipeline
  alias JidoCode.Knowledge.Memory.RetrievalRanker
  alias JidoCode.Knowledge.Memory.RetrievalRequest
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.Phase03RetrievalFixture

  setup context do
    %{fixture: Phase03RetrievalFixture.complete!(context)}
  end

  test "reads exact real-store event, capture, failure, and evidence lineage at temporal cutoffs",
       %{
         fixture: fixture
       } do
    assert {:ok, events} =
             query(fixture, :segment_event_range, %{
               graph: fixture.memory_segment_graph,
               resource: fixture.memory_attempt,
               sequence_start: 0,
               sequence_end: 10
             })

    assert events.scope_iri == fixture.repository_scope
    assert events.query_version == "2.0.0"
    refute events.truncated?
    assert Enum.map(events.data, &value(&1, "sequence")) |> Enum.uniq() == ["0", "1"]

    assert {:ok, captures} =
             query(fixture, :attempt_capture_completeness, %{
               graph: fixture.memory_segment_graph,
               resource: fixture.memory_attempt
             })

    assert length(captures.data) >= 1
    assert Enum.any?(captures.data, &(value(&1, "capture") == fixture.memory_capture.iri))
    assert Enum.any?(captures.data, &(iri_label(value(&1, "outcome")) == "Captured"))

    assert {:ok, current_failures} =
             query(fixture, :exact_failure_occurrences, %{
               graph: fixture.memory_segment_graph,
               resource: fixture.repository,
               signature: fixture.failure_signature,
               instant: fixture.issued_at
             })

    assert Enum.any?(current_failures.data, &(value(&1, "resource") == fixture.memory_event.iri))

    assert {:ok, historical_failures} =
             query(fixture, :exact_failure_occurrences, %{
               graph: fixture.memory_segment_graph,
               resource: fixture.repository,
               signature: fixture.failure_signature,
               instant: DateTime.add(fixture.issued_at, -1, :second)
             })

    assert historical_failures.data == []

    assert {:ok, lineage} =
             query(fixture, :issue_change_test_lineage, %{
               graph: fixture.evidence_graph,
               resource: fixture.evidence_resource,
               instant: fixture.issued_at
             })

    assert lineage.scope_iri == fixture.repository_scope
    refute lineage.truncated?
    assert lineage.data != []

    assert {:ok, historical_lineage} =
             query(fixture, :issue_change_test_lineage, %{
               graph: fixture.evidence_graph,
               resource: fixture.evidence_resource,
               instant: DateTime.add(fixture.issued_at, -1, :second)
             })

    assert historical_lineage.data == []

    assert {:ok, rationale} =
             query(fixture, :why_does_this_exist, %{
               graph: fixture.evidence_graph,
               resource: fixture.evidence_resource,
               instant: fixture.issued_at
             })

    assert Enum.any?(rationale.data, &(value(&1, "source") == fixture.goal))

    assert {:ok, historical_rationale} =
             query(fixture, :why_does_this_exist, %{
               graph: fixture.evidence_graph,
               resource: fixture.evidence_resource,
               instant: DateTime.add(fixture.issued_at, -1, :second)
             })

    assert historical_rationale.data == []
  end

  test "denies cross-scope queries and excludes every ineligible adversarial candidate", %{
    fixture: fixture
  } do
    {:ok, stranger} =
      AuthorityContext.new(%{
        principal_iri: resource(:authorization_grant, "phase-03-stranger"),
        actor_iri: resource(:authorization_grant, "phase-03-stranger"),
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.query(
               :segment_event_range,
               QueryCatalog.history_version(),
               %{
                 graph: fixture.memory_segment_graph,
                 resource: fixture.memory_attempt,
                 sequence_start: 0,
                 sequence_end: 10
               },
               stranger,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert {:ok, request} = RetrievalRequest.new(request_attributes(fixture))
    eligible = candidate(request, fixture, "eligible")

    candidates = [
      eligible,
      %{
        candidate(request, fixture, "future")
        | recorded_at: DateTime.add(fixture.issued_at, 1, :second)
      },
      %{candidate(request, fixture, "erased") | erased?: true},
      %{candidate(request, fixture, "unavailable") | available?: false},
      %{candidate(request, fixture, "invalidated") | invalidated?: true},
      %{candidate(request, fixture, "incompatible") | compatible?: false},
      Map.put(candidate(request, fixture, "stale"), :stale?, true),
      Map.put(candidate(request, fixture, "poisoned"), :poisoned?, true),
      candidate(request, fixture, "held")
      |> Map.put(:held?, true)
      |> Map.put(:hold_authorized?, false),
      %{candidate(request, fixture, "provider") | classification: :confidential},
      %{candidate(request, fixture, "purpose") | purpose: :failure_recovery},
      %{
        candidate(request, fixture, "scope")
        | repository_iri: resource(:repository_snapshot, "other")
      },
      %{
        candidate(request, fixture, "tenant")
        | tenant_iri: resource(:execution_context, "other")
      },
      %{
        candidate(request, fixture, "actor")
        | actor_iri: resource(:authorization_grant, "other")
      },
      %{
        candidate(request, fixture, "provider-profile")
        | provider_profile_iri: resource(:model_access_profile, "other")
      }
    ]

    assert {:ok, result} =
             CandidateAccess.generate(request, :lexical, fn _partition -> {:ok, candidates} end)

    assert result.candidates == [eligible]

    for reason <-
          ~w[future erased unavailable invalidated incompatible stale poisoned held classification purpose scope]a do
      assert result.omitted[reason] >= 1
    end

    assert result.omitted.scope >= 3
    assert result.omitted.provider_profile == 1

    malformed = Map.delete(eligible, :source_iri)

    assert {:error, %{kind: :unauthorized}} =
             CandidateAccess.generate(request, :lexical, fn _partition -> {:ok, [malformed]} end)
  end

  test "rebuilds indexes and compares retrieval ablations under one fixed budget", %{
    fixture: fixture
  } do
    assert {:ok, request} = RetrievalRequest.new(request_attributes(fixture))
    lexical = candidate(request, fixture, "ablation-lexical")
    graph = candidate(request, fixture, "ablation-graph")
    recent = candidate(request, fixture, "ablation-recent")

    assert {:ok, index, _receipt} =
             RetrievalIndex.build(request, :lexical, fn _partition -> {:ok, [lexical]} end)

    assert {:ok, indexed} = RetrievalIndex.lookup(index, request)
    assert :ok = RetrievalIndex.drop(index)

    assert {:ok, rebuilt, _receipt} =
             RetrievalIndex.build(request, :lexical, fn _partition -> {:ok, [lexical]} end)

    assert rebuilt.digest == index.digest
    assert rebuilt.entries == indexed

    modes = %{
      no_memory: %{},
      recent_context: %{recency: fn _partition -> {:ok, [recent]} end},
      full_eligible: %{recency: fn _partition -> {:ok, [recent, lexical, graph]} end},
      lexical: %{lexical: fn _partition -> {:ok, [lexical]} end},
      graph: %{temporal_graph: fn _partition -> {:ok, [graph]} end},
      hybrid: %{
        lexical: fn _partition -> {:ok, [lexical]} end,
        temporal_graph: fn _partition -> {:ok, [graph]} end
      }
    }

    reports =
      Map.new(modes, fn
        {:no_memory, %{}} ->
          {:no_memory, %{items: 0, budget: request.budgets}}

        {mode, generators} ->
          assert {:ok, result} = RetrievalPipeline.retrieve(request, generators)
          {mode, %{items: length(result.packet.items), budget: request.budgets}}
      end)

    assert reports.no_memory.items == 0
    assert reports.recent_context.items == 1
    assert reports.full_eligible.items == 3
    assert reports.lexical.items == 1
    assert reports.graph.items == 1
    assert reports.hybrid.items == 2
    assert reports |> Map.values() |> Enum.map(& &1.budget) |> Enum.uniq() == [request.budgets]

    oversized = %{candidate(request, fixture, "oversized") | payload_bytes: 32_001}

    assert {:ok, oversized_result} =
             RetrievalPipeline.retrieve(request, %{
               lexical: fn _partition -> {:ok, [oversized]} end
             })

    assert oversized_result.packet.items == []
    assert [%{reason: :byte_budget}] = oversized_result.packet.omissions

    contradicted =
      candidate(request, fixture, "contradicted")
      |> put_in([:signals, :contradicted], true)
      |> Map.put(:contradiction, :known)

    assert {:ok, contradicted_result} =
             RetrievalPipeline.retrieve(request, %{
               lexical: fn _partition -> {:ok, [contradicted]} end
             })

    assert [%{contradiction: :known, authority?: false}] =
             Enum.map(
               contradicted_result.packet.items,
               &Map.take(&1, [:contradiction, :authority?])
             )
  end

  defp query(fixture, name, parameters) do
    Knowledge.query(
      name,
      QueryCatalog.history_version(),
      parameters,
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp request_attributes(fixture) do
    tenant = resource(:execution_context, "phase-03-integration-tenant")
    actor_scope = resource(:execution_context, "phase-03-integration-actor-scope")

    %{
      attempt_iri: fixture.memory_attempt,
      actor_iri: fixture.actor,
      repository_iri: fixture.repository,
      tenant_iri: tenant,
      actor_scope_iri: actor_scope,
      task_iri: resource(:task_proposal, "phase-03-integration-task"),
      purpose: :managed_continuity,
      plan_phase: "memory-phase-03",
      effective_at: fixture.issued_at,
      provider_profile_iri: resource(:model_access_profile, "phase-03-integration-provider"),
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
      ranking_version: RetrievalRanker.revision(),
      index_version: RetrievalIndex.revision(),
      authorization: %{
        authorization_iri: resource(:authorization_grant, "phase-03-integration-authorization"),
        authorization_decision: :allowed,
        authorization_revision: 3,
        repository_iri: fixture.repository,
        tenant_iri: tenant,
        actor_scope_iri: actor_scope,
        purpose: :managed_continuity,
        data_ceiling: :internal,
        effective_time_generation: 8,
        erasure_generation: 2
      }
    }
  end

  defp candidate(request, fixture, seed) do
    %{
      iri: resource(:knowledge_assertion, seed),
      source_iri: resource(:evidence_claim, seed <> "-source"),
      source_graph_iri: fixture.memory_segment_graph,
      source_revision: 2,
      partition_digest: request.partition.partition_digest,
      repository_iri: request.repository_iri,
      tenant_iri: request.tenant_iri,
      actor_iri: request.actor_iri,
      actor_scope_iri: request.actor_scope_iri,
      provider_profile_iri: request.provider_profile_iri,
      purpose: request.purpose,
      classification: :internal,
      category: :attempt_history,
      trust: :accepted,
      recorded_at: fixture.issued_at,
      available?: true,
      erased?: false,
      invalidated?: false,
      compatible?: true,
      signals: %{
        relevance: 0.5,
        lexical_overlap: 0.5,
        symbol_overlap: 0.5,
        dependency_overlap: 0.5,
        compatibility: 1.0,
        phase_relevance: 1.0,
        trust: 0.8,
        evidence: 0.8,
        freshness: 1.0,
        delayed_outcome: 0.5,
        diversity: 0.5,
        negative_transfer: 0.0,
        historical_frequency: 0.5,
        current_policy: false,
        current_source: true,
        current_test: false,
        task_evidence: true,
        contradicted: false,
        diversity_key: seed
      },
      evidence_strength: :verified,
      freshness: :current,
      limitations: [],
      contradiction: :none_known,
      applicability: %{phase: request.plan_phase},
      exact_content?: false,
      payload: %{summary: seed},
      payload_bytes: 64,
      estimated_tokens: 16,
      retrieval_time_ms: 1
    }
  end

  defp value(row, key) do
    term =
      Map.get(row, key) ||
        Enum.find_value(row, fn
          {name, value} when is_atom(name) -> if Atom.to_string(name) == key, do: value
          _entry -> nil
        end)

    case term do
      %{value: value} -> value
      _missing -> nil
    end
  end

  defp iri_label(value) when is_binary(value),
    do: value |> String.split(["#", "/"]) |> List.last()

  defp iri_label(_value), do: nil

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

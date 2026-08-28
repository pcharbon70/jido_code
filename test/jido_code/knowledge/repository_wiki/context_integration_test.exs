defmodule JidoCode.Knowledge.RepositoryWiki.ContextIntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.Context, as: ManagedContext
  alias JidoCode.Factory.RepositoryWiki.ContextAssembler
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.EvidencePacket
  alias JidoCode.Knowledge.RepositoryWiki.ContextProfile
  alias JidoCode.Knowledge.RepositoryWiki.ContextSource
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 14:00:00Z]
  @policy_graph "https://jido.run/graph/factory/policy"

  setup do
    repository = resource(:repository_reconciliation, "rw5-context-repository")
    other_repository = resource(:repository_reconciliation, "rw5-context-other-repository")
    edition = resource(:wiki_edition, "rw5-context-edition")

    {:ok, wiki_graph} =
      GraphRegistry.graph_iri(:repository_wiki, %{repository: repository, edition: edition})

    %{
      actor: resource(:authorization_grant, "rw5-context-actor"),
      tenant: resource(:authorization_grant, "rw5-context-tenant"),
      repository: repository,
      other_repository: other_repository,
      task: resource(:task_proposal, "rw5-context-task"),
      session: resource(:interaction_session, "rw5-context-session"),
      attempt: resource(:execution_attempt, "rw5-context-attempt"),
      snapshot: resource(:repository_snapshot, "rw5-context-snapshot"),
      edition: edition,
      edition_root: digest("rw5-context-edition-root"),
      compiler_digest: digest("rw5-context-compiler"),
      wiki_graph: wiki_graph
    }
  end

  test "uses one immutable closed source profile", fixture do
    profile = Knowledge.repository_wiki_context_profile()

    assert profile == ContextProfile.profile()
    assert ContextProfile.valid?(profile)
    assert profile.preview_context? == false
    assert profile.authority? == false
    assert profile.maximum_fragments == 64
    assert profile.maximum_estimated_tokens == 16_384
    assert {:ok, :dependencies} = ContextProfile.page_class(:dependency)
    assert {:ok, :guides} = ContextProfile.page_class(:developer_guide)
    assert {:ok, :known_gaps} = ContextProfile.page_class(:known_gap)

    request = request(fixture)

    assert {:ok, packet} =
             Knowledge.repository_wiki_context(request,
               reader: fn received, received_profile ->
                 assert received == request
                 assert received_profile.digest == profile.digest
                 {:ok, projection(fixture, [fragment(fixture, :project_overview, "overview")])}
               end
             )

    assert packet.profile_digest == profile.digest
    assert packet.repository_iri == fixture.repository
    assert packet.task_iri == fixture.task
    assert packet.session_iri == fixture.session
    assert packet.attempt_iri == fixture.attempt
    assert packet.edition_iri == fixture.edition
    assert packet.non_authoritative?
    refute packet.preview_context?
    assert packet.usage == %{fragments: 1, bytes: 8, estimated_tokens: 2, omitted: 0}

    [selected] = packet.fragments
    assert selected.advisory?
    refute selected.authority?
    assert selected.provenance.edition_iri == fixture.edition
    assert selected.provenance.compiler_digest == fixture.compiler_digest
    assert selected.provenance.source_iris != []
  end

  test "omits ineligible fragments and fails closed on scope or edition drift", fixture do
    request = request(fixture)

    fragments = [
      fragment(fixture, :known_gap, "known gap"),
      fragment(fixture, :project_overview, "preview", preview?: true),
      fragment(fixture, :project_overview, "hidden", visible?: false),
      fragment(fixture, :project_overview, "stale", freshness: :stale),
      fragment(fixture, :project_overview, "weak", confidence_basis_points: 6_999),
      fragment(fixture, :project_overview, String.duplicate("x", 8_193)),
      fragment(fixture, :home, "superseded", superseded?: true)
    ]

    assert {:ok, packet} =
             ContextSource.load(request,
               reader: fn _, _ -> {:ok, projection(fixture, fragments)} end
             )

    assert Enum.map(packet.fragments, & &1.page_kind) == [:known_gap]

    assert Enum.sort(Enum.map(packet.omissions, & &1.reason)) ==
             Enum.sort([
               :preview_forbidden,
               :hidden,
               :stale,
               :confidence,
               :fragment_byte_limit,
               :superseded_edition
             ])

    cross_scope =
      fragment(fixture, :project_overview, "cross-scope",
        repository_iri: fixture.other_repository
      )

    assert {:error, %{kind: :unauthorized}} =
             ContextSource.load(request,
               reader: fn _, _ -> {:ok, projection(fixture, [cross_scope])} end
             )

    stale_projection = put_in(projection(fixture, []).edition.edition_root, digest("successor"))

    assert {:error, %{kind: :stale_precondition}} =
             ContextSource.load(request, reader: fn _, _ -> {:ok, stale_projection} end)
  end

  test "assembles direct, wiki, and memory evidence under one budget and by source identity",
       fixture do
    overview = fragment(fixture, :project_overview, "same display text")
    gap = fragment(fixture, :known_gap, "same display text")
    packet = packet(fixture, [overview, gap])
    memory = memory_packet(fixture, source: List.first(gap.source_iris))

    attributes =
      compiler_attributes(fixture)
      |> Map.put(:accepted_source_digests, overview.source_digests)

    assert {:ok, compiled} =
             ContextAssembler.compile(attributes, memory, packet, query: &query/6)

    document = Jason.decode!(compiled.serialized)
    assert document["contract"] == "jido-code-context/1.2.0"
    assert document["repository_wiki_evidence"]["authority"] == false
    assert document["repository_wiki_evidence"]["advisory"] == true

    assert document["repository_wiki_evidence"]["boundary"] ==
             "untrusted_non_instructional_data"

    assert [wiki_item] = document["repository_wiki_evidence"]["items"]
    assert wiki_item["page_kind"] == "known_gap"
    assert wiki_item["quoted_content"] == "same display text"
    assert document["memory_evidence"]["items"] == []

    reasons = Enum.map(compiled.omissions, & &1.reason)
    assert :source_digest_duplicate in reasons
    assert :source_relationship_duplicate in reasons

    manifest_wiki =
      Enum.find(compiled.manifest.items, &(&1.iri == List.first(packet.fragments).iri))

    assert manifest_wiki.digest
    refute Map.has_key?(manifest_wiki, :content)

    assert compiled.revision_pins.repository_wiki_context.edition_root == fixture.edition_root
    assert compiled.revision_pins.repository_wiki_context.session_iri == fixture.session

    current = current_pins(packet)
    refute ContextAssembler.stale?(compiled, current)
    assert ContextAssembler.stale?(compiled, %{current | edition_root: digest("changed")})
    assert ContextAssembler.stale?(compiled, %{current | enrollment_visible?: false})
  end

  test "managed coding captures wiki context immutably for one exact parallel session", fixture do
    packet = packet(fixture, [fragment(fixture, :developer_guide, "developer guide")])
    pins = managed_pins(fixture, packet)

    attributes = %{
      compiler: compiler_attributes(fixture),
      pins: pins,
      memory: :disabled,
      repository_wiki: %{
        authorized?: true,
        current?: true,
        source_complete?: true,
        enrollment_visible?: true,
        preview?: false,
        packet: packet
      }
    }

    assert {:ok, context} = ManagedContext.compile(attributes, query: &query/6)
    assert context.repository_wiki_mode == :authorized_advisory
    assert context.memory_mode == :disabled
    refute ManagedContext.recompile?(context, pins)
    assert ManagedContext.recompile?(context, %{pins | wiki_edition_root: digest("successor")})

    sibling = %{packet | session_iri: resource(:interaction_session, "rw5-sibling-session")}

    assert {:error, %{kind: :invalid_input}} =
             ManagedContext.compile(
               %{attributes | repository_wiki: %{attributes.repository_wiki | packet: sibling}},
               query: &query/6
             )
  end

  test "parallel repositories cannot share a wiki packet", fixture do
    packet = packet(fixture, [fragment(fixture, :architecture_overview, "architecture")])
    other = %{compiler_attributes(fixture) | repository_iri: fixture.other_repository}

    results =
      [compiler_attributes(fixture), other]
      |> Task.async_stream(
        fn attributes ->
          ContextAssembler.compile(attributes, :disabled, packet, query: &query/6)
        end,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, value} -> value end)

    assert [{:ok, _compiled}, {:error, %{kind: :unauthorized}}] = results
  end

  defp request(fixture) do
    %{
      actor_iri: fixture.actor,
      tenant_iri: fixture.tenant,
      repository_iri: fixture.repository,
      task_iri: fixture.task,
      session_iri: fixture.session,
      attempt_iri: fixture.attempt,
      source_snapshot_iri: fixture.snapshot,
      source_revision: digest("rw5-source"),
      enrollment_revision: 5,
      edition_iri: fixture.edition,
      edition_root: fixture.edition_root,
      compiler_profile: "wiki-deterministic-elixir/1.0.0",
      compiler_digest: fixture.compiler_digest,
      dataset_revision: 55,
      wiki_graph_iri: fixture.wiki_graph,
      wiki_graph_revision: 9,
      evaluated_at: @now,
      enrollment_visible?: true,
      task_authorized?: true
    }
  end

  defp projection(fixture, fragments) do
    request = request(fixture)

    %{
      edition: %{
        tenant_iri: request.tenant_iri,
        repository_iri: request.repository_iri,
        source_snapshot_iri: request.source_snapshot_iri,
        source_revision: request.source_revision,
        enrollment_revision: request.enrollment_revision,
        edition_iri: request.edition_iri,
        edition_root: request.edition_root,
        compiler_profile: request.compiler_profile,
        compiler_digest: request.compiler_digest,
        dataset_revision: request.dataset_revision,
        wiki_graph_iri: request.wiki_graph_iri,
        wiki_graph_revision: request.wiki_graph_revision,
        state: :closed,
        purpose: :current,
        freshness: :current,
        current?: true,
        preview?: false,
        visible?: true
      },
      fragments: fragments
    }
  end

  defp fragment(fixture, page_kind, content, overrides \\ []) do
    page = resource(:wiki_page, "rw5-page-#{page_kind}-#{content}")
    source = resource(:wiki_source, "rw5-source-#{page_kind}-#{content}")
    request = request(fixture)

    %{
      fragment_iri: resource(:wiki_section, "rw5-fragment-#{page_kind}-#{content}"),
      page_iri: page,
      page_kind: page_kind,
      content: content,
      content_digest: Contract.digest(content),
      source_iris: [source],
      source_digests: [Contract.digest({source, content})],
      authority_class: if(page_kind == :known_gap, do: :gap, else: :deterministic),
      confidence_basis_points: 9_000,
      freshness: :current,
      classification: :internal,
      dependency_iris: [],
      guide_iris: [],
      gap_iris: if(page_kind == :known_gap, do: [resource(:wiki_gap, "rw5-gap")], else: []),
      contradictory?: false,
      current?: true,
      preview?: false,
      visible?: true,
      superseded?: false,
      invalid?: false,
      tenant_iri: request.tenant_iri,
      repository_iri: request.repository_iri,
      source_snapshot_iri: request.source_snapshot_iri,
      source_revision: request.source_revision,
      enrollment_revision: request.enrollment_revision,
      edition_iri: request.edition_iri,
      edition_root: request.edition_root,
      compiler_profile: request.compiler_profile,
      compiler_digest: request.compiler_digest
    }
    |> Map.merge(Map.new(overrides))
  end

  defp packet(fixture, fragments) do
    assert {:ok, packet} =
             ContextSource.load(request(fixture),
               reader: fn _, _ -> {:ok, projection(fixture, fragments)} end
             )

    packet
  end

  defp compiler_attributes(fixture) do
    %{
      attempt_iri: fixture.attempt,
      manifest_index: 1,
      repository_iri: fixture.repository,
      snapshot_iri: fixture.snapshot,
      analysis_profile: "elixir-ast/1.0.0",
      expected_dataset_revision: 55,
      source_graph_revisions: %{@policy_graph => 7},
      authority: :fixture_authority,
      scope_iri: resource(:authorization_grant, "rw5-context-scope"),
      sections: [
        %{
          kind: :task,
          query_name: :resource_description,
          query_version: "1.7.0",
          parameters: %{resource: fixture.task},
          item_iri: resource(:evidence_claim, "rw5-context-direct-item"),
          classification: :internal,
          required?: true,
          graph_revisions: %{@policy_graph => 7},
          repository_iri: fixture.repository,
          snapshot_iri: fixture.snapshot,
          analysis_profile: "elixir-ast/1.0.0"
        }
      ],
      budget: %{
        max_items: 20,
        max_bytes: 65_536,
        max_tokens: 16_384,
        max_item_bytes: 4_096
      }
    }
  end

  defp query(:resource_description, "1.7.0", parameters, _authority, _scope, _options) do
    {:ok,
     %{
       query_name: :resource_description,
       query_version: "1.7.0",
       dataset_revision: 55,
       graph_revisions: %{@policy_graph => 7},
       completeness: %{complete?: true},
       freshness: :current,
       truncated?: false,
       data: %{resource: parameters.resource, authority: :accepted_task_source}
     }}
  end

  defp memory_packet(fixture, options) do
    source = Keyword.fetch!(options, :source)
    {:ok, graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: fixture.attempt})

    %EvidencePacket{
      iri: resource(:memory_evidence_packet, "rw5-memory-packet"),
      digest: digest("rw5-memory-packet"),
      request_iri: resource(:memory_retrieval_request, "rw5-memory-request"),
      partition_digest: digest("rw5-memory-partition"),
      query_version: "2.0.0",
      ranking_version: "1.0.0",
      index_version: "1.0.0",
      items: [
        %{
          iri: resource(:knowledge_assertion, "rw5-memory-item"),
          selection_reason: %{features: ["accepted"]},
          source_iri: source,
          temporal_scope: %{recorded_at: DateTime.to_iso8601(@now)},
          classification: :internal,
          trust: :accepted,
          evidence_strength: :independently_verified,
          freshness: :current,
          limitations: [],
          contradiction: :none_known,
          applicability: %{repository: fixture.repository},
          recovery_handle: %{
            source_iri: source,
            graph_iri: graph,
            graph_revision: 2,
            exact_content_permit_required?: true
          },
          payload: %{kind: :non_instructional_data, value: %{summary: "memory summary"}},
          authority?: false
        }
      ],
      omissions: [],
      usage: %{items: 1, graphs: 1, bytes: 64, tokens: 16, time_ms: 1},
      non_authoritative?: true
    }
  end

  defp managed_pins(fixture, packet) do
    %{
      task_iri: fixture.task,
      snapshot_iri: fixture.snapshot,
      lease_iri: resource(:execution_lease, "rw5-context-lease"),
      capability_iri: resource(:capability_declaration, "rw5-context-capability"),
      source_revision: packet.source_revision,
      workspace_revision: digest("rw5-workspace"),
      policy_revision: digest("rw5-policy"),
      prompt_revision: digest("rw5-prompt"),
      tool_revision: digest("rw5-tool"),
      profile_revision: digest("rw5-profile"),
      authority_revision: digest("rw5-authority"),
      graph_revisions: %{@policy_graph => 7},
      erasure_generation: 0,
      memory_partition_digest: nil,
      wiki_edition_root: packet.edition_root,
      wiki_context_profile_digest: packet.profile_digest,
      wiki_compiler_digest: packet.compiler_digest,
      wiki_session_iri: packet.session_iri
    }
  end

  defp current_pins(packet) do
    %{
      actor_iri: packet.actor_iri,
      tenant_iri: packet.tenant_iri,
      repository_iri: packet.repository_iri,
      task_iri: packet.task_iri,
      session_iri: packet.session_iri,
      attempt_iri: packet.attempt_iri,
      source_snapshot_iri: packet.source_snapshot_iri,
      source_revision: packet.source_revision,
      enrollment_revision: packet.enrollment_revision,
      edition_iri: packet.edition_iri,
      edition_root: packet.edition_root,
      compiler_profile: packet.compiler_profile,
      compiler_digest: packet.compiler_digest,
      dataset_revision: packet.dataset_revision,
      wiki_graph_revision: packet.wiki_graph_revision,
      profile_digest: packet.profile_digest,
      enrollment_visible?: true,
      task_authorized?: true
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: Contract.digest(value)
end

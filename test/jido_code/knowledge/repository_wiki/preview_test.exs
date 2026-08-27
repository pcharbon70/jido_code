defmodule JidoCode.Knowledge.RepositoryWiki.PreviewTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Edition
  alias JidoCode.Knowledge.RepositoryWiki.Preview
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-27 14:00:00Z]

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("preview-repository")
    tenant = resource(:authorization_grant, "preview-tenant")
    actor = resource(:authorization_grant, "preview-actor")
    reviewer = resource(:authorization_grant, "preview-reviewer")

    {:ok, profile} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{
        approved_at: @now,
        preview_mode: :allowed
      })

    {:ok, enrollment} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: repository,
        tenant_iri: tenant,
        revision: 4,
        state: :manual,
        generation_profile: profile,
        generation_mode: :deterministic_only,
        preview_mode: :allowed,
        read_visibility: :retained,
        cancellation_generation: 1,
        current_edition_iri: nil,
        recorded_at: @now
      })

    edition = edition(repository, tenant, :candidate_preview, nil, "candidate-a")

    attributes = %{
      session_iri: resource(:interaction_session, "preview-session-a"),
      attempt_iri: edition.attempt_iri,
      candidate_iri: resource(:generated_artifact, "preview-candidate-a"),
      candidate_digest: Contract.digest("candidate-a"),
      fencing_token: 7,
      actor_iri: actor,
      reviewer_iris: [reviewer],
      enrollment_revision: 4,
      created_at: @now,
      expires_at: DateTime.add(@now, 3_600, :second)
    }

    {:ok, preview} = Knowledge.repository_wiki_preview(edition, enrollment, attributes)

    %{
      repository: repository,
      tenant: tenant,
      actor: actor,
      reviewer: reviewer,
      enrollment: enrollment,
      edition: edition,
      attributes: attributes,
      preview: preview
    }
  end

  test "creates opaque preview facts and omits session/audience bindings from the graph",
       fixture do
    preview = fixture.preview
    statements = Preview.statements(preview)
    serialized = inspect(statements)

    assert String.starts_with?(preview.reference, "rwp1.")
    refute preview.reference =~ fixture.attributes.session_iri
    refute preview.reference =~ fixture.attributes.candidate_iri
    refute serialized =~ fixture.actor
    refute serialized =~ fixture.reviewer
    refute serialized =~ fixture.attributes.session_iri
    refute serialized =~ fixture.attributes.candidate_iri
    assert serialized =~ preview.iri
    assert serialized =~ preview.edition_iri
    refute Preview.context_eligible?(preview)
    refute Preview.activation_candidate?(preview)
  end

  test "publishes preview facts in its noncurrent edition graph at start", fixture do
    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: fixture.repository})

    attributes = %{
      control_graph_iri: control_graph,
      wiki_graph_iri: fixture.edition.graph_iri,
      expected_control_revision: 4,
      expected_wiki_revision: 0,
      expected_dataset_revision: 4,
      enrollment_revision: 4,
      principal_iri: resource(:authorization_grant, "preview-principal"),
      actor_iri: fixture.actor,
      scope_iri: fixture.repository,
      correlation_iri: resource(:authorization_grant, "preview-correlation"),
      causation_iri: resource(:authorization_grant, "preview-causation"),
      reason: "start exact session preview",
      recorded_at: @now,
      source_fence: fixture.edition.source_fence,
      preview: fixture.preview
    }

    assert {:ok, command} =
             Knowledge.start_repository_wiki_edition(fixture.edition, attributes,
               clock: fn -> @now end
             )

    change = hd(command.payload.changes)
    assert fixture.preview.iri in Enum.map(change.additions, &elem(&1, 0))
    assert change.graph_iri == fixture.edition.graph_iri

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.start_repository_wiki_edition(
               fixture.edition,
               Map.delete(attributes, :preview),
               clock: fn -> @now end
             )
  end

  test "authorizes only the exact participant or assigned reviewer reference", fixture do
    context = participant_context(fixture)

    assert {:ok, authorization} =
             Knowledge.authorize_repository_wiki_preview(fixture.preview, context)

    assert authorization.visibility == :candidate_preview
    assert authorization.cache_namespace == Preview.cache_namespace(fixture.preview)

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.authorize_repository_wiki_preview(
               fixture.preview,
               %{context | session_iri: resource(:interaction_session, "sibling-session")}
             )

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.authorize_repository_wiki_preview(
               fixture.preview,
               %{context | preview_reference: fixture.preview.reference <> "x"}
             )

    reviewer_context = %{
      actor_iri: fixture.reviewer,
      reviewer?: true,
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      edition_iri: fixture.edition.iri,
      preview_reference: fixture.preview.reference,
      now: @now
    }

    assert {:ok, %{preview_iri: preview_iri}} =
             Knowledge.authorize_repository_wiki_preview(fixture.preview, reviewer_context)

    assert preview_iri == fixture.preview.iri
  end

  test "isolates sibling caches and lifecycle transitions", fixture do
    sibling_edition =
      edition(fixture.repository, fixture.tenant, :candidate_preview, nil, "candidate-b")

    sibling_attributes = %{
      fixture.attributes
      | session_iri: resource(:interaction_session, "preview-session-b"),
        attempt_iri: sibling_edition.attempt_iri,
        candidate_iri: resource(:generated_artifact, "preview-candidate-b"),
        candidate_digest: Contract.digest("candidate-b"),
        fencing_token: 8
    }

    assert {:ok, sibling} =
             Knowledge.repository_wiki_preview(
               sibling_edition,
               fixture.enrollment,
               sibling_attributes
             )

    refute sibling.iri == fixture.preview.iri
    refute sibling.reference == fixture.preview.reference
    refute Preview.cache_namespace(sibling) == Preview.cache_namespace(fixture.preview)

    assert {:ok, invalidated} =
             Knowledge.transition_repository_wiki_preview(fixture.preview, :source_drift, @now)

    assert invalidated.state == :invalidated
    assert sibling.state == :active

    assert {:error, %{kind: :unauthorized}} =
             Knowledge.authorize_repository_wiki_preview(
               invalidated,
               participant_context(fixture)
             )
  end

  test "rejects preview creation when enrollment opted out", fixture do
    {:ok, disabled_profile} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{approved_at: @now})

    {:ok, disabled} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        revision: 5,
        state: :manual,
        generation_profile: disabled_profile,
        generation_mode: :deterministic_only,
        preview_mode: :disabled,
        read_visibility: :retained,
        cancellation_generation: 1,
        current_edition_iri: nil,
        recorded_at: @now
      })

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_preview(
               fixture.edition,
               disabled,
               %{fixture.attributes | enrollment_revision: 5}
             )
  end

  defp participant_context(fixture) do
    %{
      actor_iri: fixture.actor,
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      edition_iri: fixture.edition.iri,
      session_iri: fixture.attributes.session_iri,
      attempt_iri: fixture.attributes.attempt_iri,
      candidate_iri: fixture.attributes.candidate_iri,
      source_fence: fixture.edition.source_fence,
      fencing_token: fixture.attributes.fencing_token,
      preview_reference: fixture.preview.reference,
      now: @now
    }
  end

  defp edition(repository, tenant, purpose, expected_current, seed) do
    root = Contract.digest("root-#{seed}")
    {:ok, iri} = ResourceIdentity.wiki_edition(repository, root)
    {:ok, wiki_iri} = ResourceIdentity.repository_wiki(repository)

    {:ok, graph} =
      GraphRegistry.graph_iri(:repository_wiki, %{repository: repository, edition: iri})

    %Edition{
      iri: iri,
      repository_iri: repository,
      tenant_iri: tenant,
      wiki_iri: wiki_iri,
      graph_iri: graph,
      edition_root: root,
      source_snapshot_iri: resource(:repository_snapshot, "snapshot-#{seed}"),
      source_fence: "git:sha256:#{Contract.digest("source-#{seed}")}",
      input_manifest_digest: Contract.digest("manifest-#{seed}"),
      compiler_profile: "wiki-deterministic-elixir/1.0.0",
      compiler_digest: Contract.digest("wiki-deterministic-elixir/1.0.0"),
      purpose: purpose,
      predecessor_edition_iri: expected_current,
      expected_current_edition_iri: expected_current,
      attempt_iri: resource(:wiki_compilation_attempt, "attempt-#{seed}"),
      page_count: 2,
      section_count: 2,
      citation_count: 1,
      link_count: 1,
      gap_count: 0,
      segment_count: 1,
      statement_count: 20,
      content_bytes: 200,
      created_at: @now,
      compilation_digest: Contract.digest("compilation-#{seed}")
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

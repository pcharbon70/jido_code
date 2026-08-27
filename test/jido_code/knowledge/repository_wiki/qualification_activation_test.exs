defmodule JidoCode.Knowledge.RepositoryWiki.QualificationActivationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Edition
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-27 15:00:00Z]

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("qualified-wiki")
    tenant = resource(:authorization_grant, "qualified-tenant")
    prior = resource(:wiki_edition, "qualified-prior")
    edition = edition(repository, tenant, :current, prior, "qualified-current")

    {:ok, profile} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{approved_at: @now})

    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})
    {:ok, catalog_graph} = GraphRegistry.graph_iri(:factory_catalog, %{})

    review_attributes = %{
      lint_report_iri: resource(:wiki_lint_report, "qualified-lint"),
      lint_profile_digest: Contract.digest("lint-profile/1"),
      lint_result: :passed,
      render_profile_digest: Contract.digest("render-profile/1"),
      render_result_digest: Contract.digest("render-result/1"),
      render_result: :passed,
      source_coverage: :complete,
      blocking_warnings: [],
      review_profile_digest: Contract.digest("review-profile/1"),
      review_policy_revision: 9,
      reviewer_class: :independent_reviewer,
      reviewer_iri: resource(:authorization_grant, "qualified-reviewer"),
      reviewer_authority_revision: 4,
      decision: :approved,
      reason: "independent review accepted exact deterministic edition",
      recorded_at: @now
    }

    {:ok, review} = Knowledge.repository_wiki_review_decision(edition, review_attributes)

    current_enrollment = resource(:repository_wiki_enrollment, "qualified-enrollment")

    resolution = %{
      repository_iri: repository,
      tenant_iri: tenant,
      current_state: :manual,
      current_revision: 6,
      current_enrollment_iri: current_enrollment,
      current_transition_iri: resource(:control_transition, "qualified-transition"),
      cancellation_generation: 2,
      current_edition_iri: prior,
      read_visibility: :retained
    }

    graph_revisions = %{control_graph => 7, catalog_graph => 3, edition.graph_iri => 5}

    context = %{
      reviewer_authorized?: true,
      enrollment_revision: 6,
      current_enrollment_iri: current_enrollment,
      current_source_fence: edition.source_fence,
      policy_revision: 9,
      reviewer_authority_revision: 4,
      allowed_profile_iri: profile.iri,
      lint_report_iri: review.lint_report_iri,
      render_profile_digest: review.render_profile_digest,
      render_result_digest: review.render_result_digest,
      compiler_profile: edition.compiler_profile,
      compiler_digest: edition.compiler_digest,
      evaluated_at: @now,
      control_graph_iri: control_graph,
      expected_graph_revisions: graph_revisions,
      current_graph_revisions: graph_revisions
    }

    attributes = %{
      repository_iri: repository,
      catalog_graph_iri: catalog_graph,
      control_graph_iri: control_graph,
      wiki_graph_iri: edition.graph_iri,
      expected_catalog_revision: 3,
      expected_control_revision: 7,
      expected_wiki_revision: 5,
      expected_dataset_revision: 15,
      expected_graph_revisions: graph_revisions,
      enrollment_revision: 6,
      principal_iri: resource(:authorization_grant, "qualified-principal"),
      actor_iri: review.reviewer_iri,
      scope_iri: repository,
      correlation_iri: resource(:authorization_grant, "qualified-correlation"),
      causation_iri: resource(:authorization_grant, "qualified-causation"),
      reason: "activate independently reviewed repository wiki",
      recorded_at: @now,
      source_fence: edition.source_fence
    }

    %{
      repository: repository,
      tenant: tenant,
      prior: prior,
      edition: edition,
      profile: profile,
      control_graph: control_graph,
      review: review,
      review_attributes: review_attributes,
      resolution: resolution,
      context: context,
      attributes: attributes
    }
  end

  test "records exact review evidence and produces qualified CAS activation", fixture do
    assert {:ok, review_command} =
             Knowledge.record_repository_wiki_review(
               fixture.review,
               fixture.edition,
               fixture.attributes,
               clock: fn -> @now end
             )

    assert review_command.command_type == "RecordWikiReviewDecision"
    assert fixture.review.iri in subjects(hd(review_command.payload.changes).additions)

    assert {:subject_present, fixture.edition.graph_iri, fixture.review.lint_report_iri} in review_command.payload.guards

    qualification =
      Knowledge.qualify_repository_wiki_edition(
        fixture.edition,
        fixture.resolution,
        fixture.profile,
        fixture.review,
        fixture.context
      )

    assert qualification.outcome == :qualified
    assert qualification.activation_authorized?
    assert Contract.digest?(qualification.qualification_digest)

    assert {:ok, prepared} =
             Knowledge.activate_qualified_repository_wiki_edition(
               fixture.edition,
               fixture.resolution,
               fixture.profile,
               fixture.review,
               fixture.context,
               fixture.attributes,
               clock: fn -> @now end
             )

    assert prepared.outcome == :prepared
    assert prepared.command.command_type == "ActivateWikiEdition"

    assert {:subject_present, fixture.control_graph, fixture.review.iri} in prepared.command.payload.guards

    additions = hd(prepared.command.payload.changes).additions

    assert Enum.any?(additions, fn
             {prior, predicate, _object} ->
               prior == fixture.prior and String.ends_with?(predicate, "supersededBy")

             _statement ->
               false
           end)
  end

  test "returns closed outcomes for every late or competing activation fence", fixture do
    assess = fn resolution, context, review ->
      Knowledge.qualify_repository_wiki_edition(
        fixture.edition,
        resolution,
        fixture.profile,
        review,
        context
      )
    end

    assert assess.(
             fixture.resolution,
             %{fixture.context | reviewer_authorized?: false},
             fixture.review
           ).outcome ==
             :unauthorized

    assert assess.(%{fixture.resolution | current_state: :off}, fixture.context, fixture.review).outcome ==
             :disabled

    assert assess.(
             fixture.resolution,
             %{fixture.context | current_source_fence: "new-head"},
             fixture.review
           ).outcome ==
             :stale

    competing = %{fixture.resolution | current_edition_iri: resource(:wiki_edition, "winner")}
    assert assess.(competing, fixture.context, fixture.review).outcome == :competing

    duplicate = %{fixture.resolution | current_edition_iri: fixture.edition.iri}
    assert assess.(duplicate, fixture.context, fixture.review).outcome == :duplicate

    assert assess.(fixture.resolution, %{fixture.context | policy_revision: 10}, fixture.review).outcome ==
             :unqualified

    assert {:error, %{outcome: :stale, activation_authorized?: false}} =
             Knowledge.activate_qualified_repository_wiki_edition(
               fixture.edition,
               fixture.resolution,
               fixture.profile,
               fixture.review,
               %{fixture.context | current_source_fence: "new-head"},
               fixture.attributes,
               clock: fn -> @now end
             )
  end

  test "candidate previews cannot create review or activation authority", fixture do
    preview =
      edition(fixture.repository, fixture.tenant, :candidate_preview, fixture.prior, "preview")

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_review_decision(preview, %{
               fixture.review_attributes
               | lint_report_iri: resource(:wiki_lint_report, "preview-lint")
             })
  end

  test "invalidates disposable projections only after an accepted commit", fixture do
    committed = %CommandReceipt{outcome: :committed, retry: :never, dataset_revision: 18}
    duplicate = %CommandReceipt{outcome: :already_committed, retry: :never}
    conflicted = %CommandReceipt{outcome: :conflicted, retry: :refresh}

    assert Knowledge.repository_wiki_activation_outcome(committed) == :accepted
    assert Knowledge.repository_wiki_activation_outcome(duplicate) == :duplicate
    assert Knowledge.repository_wiki_activation_outcome(conflicted) == :competing

    assert {:invalidate, directive} =
             Knowledge.repository_wiki_activation_cache_directive(committed, fixture.edition)

    assert directive.projections == [:navigation, :search]
    assert directive.rebuild_from == :accepted_graph_state
    assert directive.dataset_revision == 18

    assert Knowledge.repository_wiki_activation_cache_directive(duplicate, fixture.edition) ==
             :retain

    assert Knowledge.repository_wiki_activation_cache_directive(conflicted, fixture.edition) ==
             :retain
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
      compiler_digest:
        :crypto.hash(:sha256, "wiki-deterministic-elixir/1.0.0")
        |> Base.encode16(case: :lower),
      purpose: purpose,
      predecessor_edition_iri: expected_current,
      expected_current_edition_iri: expected_current,
      attempt_iri: resource(:wiki_compilation_attempt, "attempt-#{seed}"),
      page_count: 3,
      section_count: 4,
      citation_count: 2,
      link_count: 2,
      gap_count: 0,
      segment_count: 1,
      statement_count: 25,
      content_bytes: 300,
      created_at: @now,
      compilation_digest: Contract.digest("compilation-#{seed}")
    }
  end

  defp subjects(statements), do: Enum.map(statements, &elem(&1, 0))

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

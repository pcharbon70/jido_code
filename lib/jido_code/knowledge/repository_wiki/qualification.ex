defmodule JidoCode.Knowledge.RepositoryWiki.Qualification do
  @moduledoc """
  Deterministic activation qualification for one immutable edition tuple.

  The assessment is pure and returns a closed outcome. Failed assessments keep
  the candidate and review identities attributable but never emit activation
  authority.
  """

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Edition
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile
  alias JidoCode.Knowledge.RepositoryWiki.ReviewDecision

  @outcomes [:qualified, :stale, :competing, :disabled, :unqualified, :duplicate, :unauthorized]

  @spec outcomes() :: [atom()]
  def outcomes, do: @outcomes

  @spec assess(Edition.t(), map(), GenerationProfile.t(), ReviewDecision.t(), map()) :: map()
  def assess(
        %Edition{} = edition,
        resolution,
        %GenerationProfile{} = profile,
        %ReviewDecision{} = review,
        context
      )
      when is_map(resolution) and is_map(context) do
    outcome = outcome(edition, resolution, profile, review, context)

    base = %{
      outcome: outcome,
      edition_iri: edition.iri,
      edition_root: edition.edition_root,
      review_iri: review.iri,
      review_digest: review.digest,
      source_fence: edition.source_fence,
      expected_current_edition_iri: edition.expected_current_edition_iri,
      candidate_history_retained?: true,
      activation_authorized?: outcome == :qualified
    }

    if outcome == :qualified do
      Map.merge(base, %{
        qualification_digest:
          Contract.digest(%{
            edition_root: edition.edition_root,
            review_digest: review.digest,
            profile_digest: profile.profile_digest,
            enrollment_revision: context.enrollment_revision,
            source_fence: context.current_source_fence,
            policy_revision: context.policy_revision,
            reviewer_authority_revision: context.reviewer_authority_revision,
            expected_current_edition_iri: resolution[:current_edition_iri],
            expected_graph_revisions: context.expected_graph_revisions
          }),
        expected_graph_revisions: context.expected_graph_revisions,
        guards: qualification_guards(edition, resolution, review, context)
      })
    else
      base
    end
  end

  def assess(_edition, _resolution, _profile, _review, _context) do
    %{
      outcome: :unqualified,
      activation_authorized?: false,
      candidate_history_retained?: true
    }
  end

  defp outcome(edition, resolution, profile, review, context) do
    cond do
      context[:reviewer_authorized?] != true ->
        :unauthorized

      resolution[:current_state] == :off ->
        :disabled

      resolution[:current_edition_iri] == edition.iri ->
        :duplicate

      resolution[:current_edition_iri] != edition.expected_current_edition_iri ->
        :competing

      context[:current_source_fence] != edition.source_fence ->
        :stale

      not exact_graph_revisions?(context) ->
        :competing

      qualified_members?(edition, resolution, profile, review, context) ->
        :qualified

      true ->
        :unqualified
    end
  end

  defp qualified_members?(edition, resolution, profile, review, context) do
    edition.purpose in [:current, :release, :recovery] and
      resolution[:current_state] in [:manual, :automatic] and
      profile.maintenance_mode == resolution[:current_state] and
      profile.generation_mode == :deterministic_only and
      profile.compiler_profile == edition.compiler_profile and
      profile.compiler_digest == edition.compiler_digest and
      profile_current?(profile, context[:evaluated_at]) and
      review.decision == :approved and review.edition_iri == edition.iri and
      review.edition_root == edition.edition_root and review.source_fence == edition.source_fence and
      review.compiler_profile == edition.compiler_profile and
      review.compiler_digest == edition.compiler_digest and review.lint_result == :passed and
      review.render_result == :passed and review.source_coverage == :complete and
      review.blocking_warnings == [] and
      review.review_policy_revision == context[:policy_revision] and
      review.reviewer_authority_revision == context[:reviewer_authority_revision] and
      resolution[:current_revision] == context[:enrollment_revision] and
      resolution[:current_enrollment_iri] == context[:current_enrollment_iri] and
      context[:allowed_profile_iri] == profile.iri and
      context[:lint_report_iri] == review.lint_report_iri and
      context[:render_profile_digest] == review.render_profile_digest and
      context[:render_result_digest] == review.render_result_digest and
      context[:compiler_profile] == edition.compiler_profile and
      context[:compiler_digest] == edition.compiler_digest
  end

  defp profile_current?(%GenerationProfile{expires_at: nil}, %DateTime{}), do: true

  defp profile_current?(%GenerationProfile{expires_at: expires_at}, %DateTime{} = evaluated_at),
    do: DateTime.compare(evaluated_at, expires_at) == :lt

  defp profile_current?(_profile, _evaluated_at), do: false

  defp exact_graph_revisions?(context) do
    expected = context[:expected_graph_revisions]
    current = context[:current_graph_revisions]

    is_map(expected) and map_size(expected) == 3 and expected == current and
      Enum.all?(expected, fn {graph, revision} ->
        is_binary(graph) and is_integer(revision) and revision > 0
      end)
  end

  defp qualification_guards(edition, resolution, review, context) do
    control_graph = context.control_graph_iri

    current_guard =
      case resolution[:current_edition_iri] do
        nil ->
          {:predicate_absent, control_graph, resolution.current_enrollment_iri,
           "https://jido.run/ontology/factory#currentWikiEdition"}

        current ->
          {:triple_present, control_graph, resolution.current_enrollment_iri,
           "https://jido.run/ontology/factory#currentWikiEdition", RDF.iri(current)}
      end

    [
      {:subject_present, control_graph, review.iri},
      {:subject_present, edition.graph_iri, review.lint_report_iri},
      {:triple_present, edition.graph_iri, edition.iri,
       "https://jido.run/ontology/factory#editionState", RDF.iri(Contract.concept(:wiki_closed))},
      {:triple_present, edition.graph_iri, edition.iri,
       "https://jido.run/ontology/factory#sourceFence", RDF.XSD.String.new(edition.source_fence)},
      current_guard
    ]
  end
end

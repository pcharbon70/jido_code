defmodule JidoCode.Knowledge.RepositoryWiki.ReviewDecision do
  @moduledoc "Immutable review evidence bound to one exact closed wiki edition root."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Edition
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :digest,
    :repository_iri,
    :tenant_iri,
    :edition_iri,
    :edition_root,
    :source_fence,
    :compiler_profile,
    :compiler_digest,
    :lint_report_iri,
    :lint_profile_digest,
    :lint_result,
    :render_profile_digest,
    :render_result_digest,
    :render_result,
    :source_coverage,
    :blocking_warnings,
    :review_profile_digest,
    :review_policy_revision,
    :reviewer_class,
    :reviewer_iri,
    :reviewer_authority_revision,
    :decision,
    :reason,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @reviewer_classes [:repository_maintainer, :independent_reviewer, :operator]
  @maximum_warnings 100

  @spec new(Edition.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%Edition{} = edition, attributes) when is_map(attributes) do
    warnings = attributes |> Map.get(:blocking_warnings, []) |> Enum.uniq() |> Enum.sort()
    recorded_at = attributes[:recorded_at]

    material = %{
      repository_iri: edition.repository_iri,
      tenant_iri: edition.tenant_iri,
      edition_iri: edition.iri,
      edition_root: edition.edition_root,
      source_fence: edition.source_fence,
      compiler_profile: edition.compiler_profile,
      compiler_digest: edition.compiler_digest,
      lint_report_iri: attributes[:lint_report_iri],
      lint_profile_digest: attributes[:lint_profile_digest],
      lint_result: attributes[:lint_result],
      render_profile_digest: attributes[:render_profile_digest],
      render_result_digest: attributes[:render_result_digest],
      render_result: attributes[:render_result],
      source_coverage: attributes[:source_coverage],
      blocking_warnings: warnings,
      review_profile_digest: attributes[:review_profile_digest],
      review_policy_revision: attributes[:review_policy_revision],
      reviewer_class: attributes[:reviewer_class],
      reviewer_iri: attributes[:reviewer_iri],
      reviewer_authority_revision: attributes[:reviewer_authority_revision],
      decision: attributes[:decision],
      reason: attributes[:reason],
      recorded_at: recorded_at
    }

    with true <- edition.purpose != :candidate_preview,
         :ok <- resources(material),
         true <- digests(material),
         true <- material.lint_result in [:passed, :failed],
         true <- material.render_result in [:passed, :failed],
         true <- material.source_coverage in [:complete, :degraded, :incomplete],
         true <- material.decision in [:approved, :rejected],
         true <- material.reviewer_class in @reviewer_classes,
         true <-
           is_integer(material.review_policy_revision) and material.review_policy_revision > 0,
         true <-
           is_integer(material.reviewer_authority_revision) and
             material.reviewer_authority_revision > 0,
         true <- valid_warnings?(warnings),
         true <- valid_reason?(material.reason),
         %DateTime{} <- recorded_at,
         true <- recorded_at == DateTime.truncate(recorded_at, :microsecond),
         true <- decision_consistent?(material),
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_review_decision, digest) do
      {:ok, struct!(__MODULE__, Map.merge(material, %{iri: iri, digest: digest}))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_review_decision)
    end
  rescue
    _error -> invalid(:repository_wiki_review_decision)
  end

  def new(_edition, _attributes), do: invalid(:repository_wiki_review_decision)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = review) do
    [
      {review.iri, @rdf_type, RDF.iri(@prov <> "Activity")},
      {review.iri, @jf <> "repositoryScope", RDF.iri(review.repository_iri)},
      {review.iri, @jf <> "tenantScope", RDF.iri(review.tenant_iri)},
      {review.iri, @jf <> "wikiEdition", RDF.iri(review.edition_iri)},
      {review.iri, @prov <> "wasAssociatedWith", RDF.iri(review.reviewer_iri)},
      {review.iri, @prov <> "used", RDF.iri(review.lint_report_iri)},
      {review.iri, @jf <> "sourceFence", RDF.XSD.String.new(review.source_fence)},
      {review.iri, @jf <> "contentDigest", RDF.XSD.String.new(review.digest)},
      {review.iri, @jf <> "profileDigest", RDF.XSD.String.new(review.review_profile_digest)},
      {review.iri, @prov <> "value", RDF.XSD.String.new(Atom.to_string(review.decision))},
      {review.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(review.recorded_at)}
      | Enum.map(review.blocking_warnings, fn warning ->
          {review.iri, @jf <> "warningCode", RDF.XSD.String.new(warning)}
        end)
    ]
  end

  @spec record_command(t(), Edition.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(review, edition, attributes, options \\ [])

  def record_command(%__MODULE__{} = review, %Edition{} = edition, attributes, options)
      when is_map(attributes) and is_list(options) do
    control_graph = attributes[:control_graph_iri]
    control_revision = attributes[:expected_control_revision]
    wiki_revision = attributes[:expected_wiki_revision]

    with true <- review.edition_iri == edition.iri,
         true <- exact_control_graph?(control_graph, edition.repository_iri),
         true <- is_integer(control_revision) and control_revision > 0,
         true <- is_integer(wiki_revision) and wiki_revision > 0,
         {:ok, command_iri} <- Command.identity("RecordWikiReviewDecision", review.iri),
         {:ok, target} <-
           ControlGraph.target(
             control_graph,
             control_revision,
             edition.repository_iri,
             command_iri,
             review.recorded_at,
             statements(review)
           ),
         guards = [
           {:subject_absent, control_graph, review.iri},
           {:subject_present, edition.graph_iri, edition.iri},
           {:subject_present, edition.graph_iri, review.lint_report_iri},
           {:triple_present, edition.graph_iri, edition.iri, @jf <> "editionState",
            RDF.iri(Contract.concept(:wiki_closed))},
           {:triple_present, edition.graph_iri, edition.iri, @jf <> "sourceFence",
            RDF.XSD.String.new(edition.source_fence)}
         ],
         command_attributes <-
           attributes
           |> Map.put(:repository_iri, edition.repository_iri)
           |> Map.put(:scope_iri, edition.repository_iri)
           |> Map.put(:source_fence, edition.source_fence)
           |> Map.put(:expected_graph_revisions, %{
             control_graph => control_revision,
             edition.graph_iri => wiki_revision
           }),
         {:ok, command} <-
           Command.build(
             "RecordWikiReviewDecision",
             review.iri,
             [target],
             guards,
             command_attributes,
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_repository_wiki_review_decision)
    end
  end

  def record_command(_review, _edition, _attributes, _options),
    do: invalid(:record_repository_wiki_review_decision)

  defp resources(material) do
    values = [
      material.repository_iri,
      material.tenant_iri,
      material.edition_iri,
      material.lint_report_iri,
      material.reviewer_iri
    ]

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: :ok,
      else: invalid(:repository_wiki_review_identity)
  end

  defp digests(material) do
    Enum.all?(
      [
        material.edition_root,
        material.compiler_digest,
        material.lint_profile_digest,
        material.render_profile_digest,
        material.render_result_digest,
        material.review_profile_digest
      ],
      &Contract.digest?/1
    )
  end

  defp valid_warnings?(warnings) do
    length(warnings) <= @maximum_warnings and
      Enum.all?(warnings, fn warning ->
        is_binary(warning) and byte_size(warning) in 1..64 and
          Regex.match?(~r/^[a-z0-9_]+$/u, warning)
      end)
  end

  defp valid_reason?(reason), do: is_binary(reason) and byte_size(reason) in 1..500

  defp decision_consistent?(%{decision: :approved} = material) do
    material.lint_result == :passed and material.render_result == :passed and
      material.source_coverage == :complete and material.blocking_warnings == []
  end

  defp decision_consistent?(%{decision: :rejected}), do: true

  defp exact_control_graph?(graph, repository_iri) do
    case GraphRegistry.graph_iri(:repository_control, %{repository: repository_iri}) do
      {:ok, expected} -> expected == graph
      {:error, %Error{}} -> false
    end
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

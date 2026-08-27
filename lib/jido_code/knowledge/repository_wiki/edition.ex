defmodule JidoCode.Knowledge.RepositoryWiki.Edition do
  @moduledoc "Immutable segmented wiki edition lifecycle and activation commands."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Enrollment
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile
  alias JidoCode.Knowledge.RepositoryWiki.Graph
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.Preview
  alias JidoCode.Knowledge.RepositoryWiki.Segment
  alias JidoCode.Knowledge.RepositoryWiki.SemanticContract
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :repository_iri,
    :tenant_iri,
    :wiki_iri,
    :graph_iri,
    :edition_root,
    :source_snapshot_iri,
    :source_fence,
    :input_manifest_digest,
    :compiler_profile,
    :compiler_digest,
    :purpose,
    :predecessor_edition_iri,
    :expected_current_edition_iri,
    :attempt_iri,
    :page_count,
    :section_count,
    :citation_count,
    :link_count,
    :gap_count,
    :segment_count,
    :statement_count,
    :content_bytes,
    :created_at,
    :compilation_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"

  @spec new(map(), [Segment.t()]) :: {:ok, t()} | {:error, Error.t()}
  def new(compilation, segments) when is_map(compilation) and is_list(segments) do
    with true <- compilation[:protocol] == "1.0.0",
         true <- compilation[:compiler_profile] == Protocol.compiler_profile(),
         true <- compilation[:compiler_digest] == Protocol.compiler_digest(),
         true <- contiguous_segments?(segments, compilation.edition_iri),
         {:ok, graph_iri} <-
           JidoCode.Knowledge.GraphRegistry.graph_iri(:repository_wiki, %{
             repository: compilation.repository_iri,
             edition: compilation.edition_iri
           }),
         edition <-
           struct!(__MODULE__, %{
             iri: compilation.edition_iri,
             repository_iri: compilation.repository_iri,
             tenant_iri: compilation.tenant_iri,
             wiki_iri: compilation.wiki_iri,
             graph_iri: graph_iri,
             edition_root: compilation.edition_root,
             source_snapshot_iri: compilation.source_snapshot_iri,
             source_fence: compilation.source_fence,
             input_manifest_digest: compilation.input_manifest_digest,
             compiler_profile: compilation.compiler_profile,
             compiler_digest: compilation.compiler_digest,
             purpose: compilation.purpose,
             predecessor_edition_iri: compilation.predecessor_edition_iri,
             expected_current_edition_iri: compilation.expected_current_edition_iri,
             attempt_iri: compilation.attempt_iri,
             page_count: compilation.page_count,
             section_count: compilation.section_count,
             citation_count: compilation.citation_count,
             link_count: compilation.link_count,
             gap_count: compilation.gap_count,
             segment_count: length(segments),
             statement_count: Enum.sum(Enum.map(segments, & &1.statement_count)),
             content_bytes: Enum.sum(Enum.map(segments, & &1.content_bytes)),
             created_at: compilation.created_at,
             compilation_digest: compilation.compilation_digest
           }),
         :ok <- SemanticContract.validate(:edition, semantic_map(edition)) do
      {:ok, edition}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_edition)
    end
  rescue
    _error -> invalid(:wiki_edition)
  end

  def new(_compilation, _segments), do: invalid(:wiki_edition)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = edition) do
    [
      {edition.iri, @rdf_type, RDF.iri(@jf <> "WikiEdition")},
      {edition.iri, @jf <> "repositoryScope", RDF.iri(edition.repository_iri)},
      {edition.iri, @jf <> "tenantScope", RDF.iri(edition.tenant_iri)},
      {edition.iri, @jf <> "repositoryWiki", RDF.iri(edition.wiki_iri)},
      {edition.iri, @jf <> "editionRoot", RDF.XSD.String.new(edition.edition_root)},
      {edition.iri, @jf <> "editionState", RDF.iri(Contract.concept(:wiki_building))},
      {edition.iri, @jf <> "editionPurpose", RDF.iri(purpose_concept(edition.purpose))},
      {edition.iri, @jf <> "sourceSnapshot", RDF.iri(edition.source_snapshot_iri)},
      {edition.iri, @jf <> "sourceFence", RDF.XSD.String.new(edition.source_fence)},
      {edition.iri, @jf <> "compilerProfile", RDF.XSD.String.new(edition.compiler_profile)},
      {edition.iri, @jf <> "compilerDigest", RDF.XSD.String.new(edition.compiler_digest)},
      {edition.iri, @jf <> "inputManifestDigest",
       RDF.XSD.String.new(edition.input_manifest_digest)},
      {edition.iri, @jf <> "freshnessState", RDF.iri(Contract.concept(:wiki_fresh))},
      {edition.iri, @jf <> "completenessState", RDF.iri(Contract.concept(:building))},
      {edition.iri, @jf <> "wikiRetentionClass",
       RDF.iri(Contract.concept(:wiki_incomplete_retention))},
      {edition.iri, @jf <> "pageCount", RDF.XSD.NonNegativeInteger.new(edition.page_count)},
      {edition.iri, @jf <> "sectionCount", RDF.XSD.NonNegativeInteger.new(edition.section_count)},
      {edition.iri, @jf <> "citationCount",
       RDF.XSD.NonNegativeInteger.new(edition.citation_count)},
      {edition.iri, @jf <> "linkCount", RDF.XSD.NonNegativeInteger.new(edition.link_count)},
      {edition.iri, @jf <> "gapCount", RDF.XSD.NonNegativeInteger.new(edition.gap_count)},
      {edition.iri, @jf <> "segmentCount", RDF.XSD.NonNegativeInteger.new(edition.segment_count)},
      {edition.iri, @jf <> "statementCount",
       RDF.XSD.NonNegativeInteger.new(edition.statement_count)},
      {edition.iri, @jf <> "contentBytes", RDF.XSD.NonNegativeInteger.new(edition.content_bytes)},
      {edition.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(edition.created_at)}
      | optional_iris(edition)
    ]
  end

  @spec admit_command(t(), map(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def admit_command(%__MODULE__{} = edition, enrollment, attributes, options \\ [])
      when is_map(enrollment) and is_map(attributes) and is_list(options) do
    graph = attributes[:control_graph_iri]
    revision = attributes[:expected_control_revision]
    material = edition.attempt_iri <> "\nadmit"

    with true <- exact_control_graph?(graph, edition.repository_iri),
         true <- enrollment[:state] in [:manual, :automatic],
         true <- enrollment[:revision] == attributes[:enrollment_revision],
         true <- enrollment[:repository_iri] == edition.repository_iri,
         true <- enrollment[:tenant_iri] == edition.tenant_iri,
         true <- trigger_allowed?(enrollment.state, attributes[:trigger]),
         true <- is_integer(revision) and revision > 0,
         {:ok, command_iri} <- Command.identity("AdmitDeterministicWikiCompilation", material),
         {:ok, target} <-
           ControlGraph.target(
             graph,
             revision,
             edition.repository_iri,
             command_iri,
             attributes.recorded_at,
             attempt_statements(edition, :admitted, attributes.recorded_at)
           ),
         guards = [
           {:subject_present, graph, enrollment.current_enrollment_iri},
           {:triple_present, graph, enrollment.current_enrollment_iri,
            @jf <> "enrollmentRevision", RDF.XSD.NonNegativeInteger.new(enrollment.revision)},
           {:subject_absent, graph, edition.attempt_iri}
         ],
         {:ok, command} <-
           Command.build(
             "AdmitDeterministicWikiCompilation",
             material,
             [target],
             guards,
             base_attributes(attributes, edition, %{graph => revision}),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:admit_deterministic_wiki_compilation)
    end
  end

  @spec start_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def start_command(%__MODULE__{} = edition, attributes, options \\ []) do
    material = edition.iri <> "\nstart"

    with true <- exact_control_graph?(attributes[:control_graph_iri], edition.repository_iri),
         true <- attributes[:wiki_graph_iri] == edition.graph_iri,
         true <- attributes[:expected_wiki_revision] == 0,
         {:ok, preview_statements} <- preview_statements(edition, attributes[:preview]),
         {:ok, command_iri} <- Command.identity("StartWikiEdition", material),
         {:ok, target} <-
           Graph.create_target(
             edition.graph_iri,
             edition.repository_iri,
             command_iri,
             attributes.recorded_at,
             statements(edition) ++
               preview_statements ++
               attempt_statements(edition, :building, attributes.recorded_at)
           ),
         guards = [
           {:subject_present, attributes.control_graph_iri, edition.attempt_iri},
           {:subject_absent, edition.graph_iri, edition.iri}
         ],
         revisions = %{
           attributes.control_graph_iri => attributes.expected_control_revision,
           edition.graph_iri => 0
         },
         {:ok, command} <-
           Command.build(
             "StartWikiEdition",
             material,
             [target],
             guards,
             base_attributes(attributes, edition, revisions),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:start_wiki_edition)
    end
  end

  @spec finalize_command(t(), [Segment.t()], map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def finalize_command(%__MODULE__{} = edition, segments, attributes, options \\ []) do
    graph = edition.graph_iri
    revision = attributes[:expected_wiki_revision]

    with true <- contiguous_segments?(segments, edition.iri),
         true <- length(segments) == edition.segment_count,
         true <- is_integer(revision) and revision > 0,
         closure_digest <- closure_digest(edition, segments),
         additions =
           [
             {edition.iri, @jf <> "closureDigest", RDF.XSD.String.new(closure_digest)},
             {edition.attempt_iri, @jf <> "closureDigest", RDF.XSD.String.new(closure_digest)}
           ] ++
             Enum.map(segments, fn segment ->
               {edition.attempt_iri, @jf <> "orderedWikiSegment", RDF.iri(segment.iri)}
             end),
         {:ok, target} <- Graph.append_target(graph, revision, additions),
         guards =
           [
             {:predicate_absent, graph, edition.iri, @jf <> "closureDigest"},
             {:triple_present, graph, edition.iri, @jf <> "sourceFence",
              RDF.XSD.String.new(edition.source_fence)}
           ] ++ Enum.map(segments, &{:subject_present, graph, &1.iri}),
         {:ok, command} <-
           Command.build(
             "FinalizeWikiEdition",
             edition.iri <> "\n" <> closure_digest,
             [target],
             guards,
             base_attributes(attributes, edition, %{graph => revision}),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:finalize_wiki_edition)
    end
  end

  @spec lint_command(t(), [map()], map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def lint_command(%__MODULE__{} = edition, findings, attributes, options \\ [])
      when is_list(findings) and length(findings) <= 200 do
    graph = edition.graph_iri
    revision = attributes[:expected_wiki_revision]
    normalized = Enum.sort_by(findings, &{&1[:severity], &1[:code], &1[:resource_iri]})
    blocking = Enum.count(normalized, &(&1[:severity] == :blocking))
    digest = Contract.digest(normalized)

    profile_digest =
      attributes[:lint_profile_digest] || Contract.digest(%{revision: "wiki-lint/1.0.0"})

    with true <- Enum.all?(normalized, &valid_finding?/1),
         true <- is_integer(revision) and revision > 0,
         true <- Contract.digest?(profile_digest),
         {:ok, report_iri} <-
           ResourceIdentity.deterministic(:wiki_lint_report, edition.iri <> digest),
         report = %{
           iri: report_iri,
           edition_iri: edition.iri,
           profile: "wiki-lint/1.0.0",
           profile_digest: profile_digest,
           digest: digest,
           blocking_count: blocking,
           findings: normalized,
           recorded_at: attributes.recorded_at
         },
         additions =
           lint_statements(report) ++
             [{edition.iri, @jf <> "wikiLintReport", RDF.iri(report_iri)}],
         {:ok, target} <- Graph.append_target(graph, revision, additions),
         guards = [
           {:predicate_absent, graph, edition.iri, @jf <> "wikiLintReport"},
           {:subject_present, graph, edition.iri}
         ],
         {:ok, command} <-
           Command.build(
             "RecordWikiLintResult",
             report_iri,
             [target],
             guards,
             base_attributes(attributes, edition, %{graph => revision}),
             options
           ) do
      {:ok, %{report: report, command: command}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_wiki_lint_result)
    end
  end

  @spec close_command(t(), map(), map(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def close_command(%__MODULE__{} = edition, report, metadata, attributes, options \\ []) do
    graph = edition.graph_iri
    revision = attributes[:expected_wiki_revision]
    building = {edition.iri, @jf <> "editionState", RDF.iri(Contract.concept(:wiki_building))}

    with true <- report[:edition_iri] == edition.iri and report[:blocking_count] == 0,
         true <- metadata[:graph_iri] == graph and metadata[:graph_revision] == revision,
         {:ok, target} <-
           Graph.close_target(
             metadata,
             edition.repository_iri,
             attributes.recorded_at,
             [
               {edition.iri, @jf <> "editionState", RDF.iri(Contract.concept(:wiki_closed))},
               {edition.iri, @jf <> "completenessState", RDF.iri(Contract.concept(:complete))},
               {edition.iri, @jf <> "wikiRetentionClass",
                RDF.iri(Contract.concept(:wiki_current_retention))},
               {edition.attempt_iri, @prov <> "endedAtTime",
                RDF.XSD.DateTime.new(attributes.recorded_at)}
             ],
             [
               building,
               {edition.iri, @jf <> "completenessState", RDF.iri(Contract.concept(:building))},
               {edition.iri, @jf <> "wikiRetentionClass",
                RDF.iri(Contract.concept(:wiki_incomplete_retention))}
             ]
           ),
         guards = [
           {:subject_present, graph, report.iri},
           {:triple_present, graph, edition.iri, @jf <> "editionState", elem(building, 2)},
           {:triple_present, graph, edition.iri, @jf <> "sourceFence",
            RDF.XSD.String.new(edition.source_fence)},
           {:predicate_absent, graph, edition.iri, @jf <> "invalidatedBy"}
         ],
         {:ok, command} <-
           Command.build(
             "CloseWikiEdition",
             edition.iri <> "\nclose\n" <> report.digest,
             [target],
             guards,
             base_attributes(attributes, edition, %{graph => revision}),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:close_wiki_edition)
    end
  end

  @spec activate_command(t(), map(), GenerationProfile.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def activate_command(edition, resolution, profile, attributes, options \\ [])

  def activate_command(
        %__MODULE__{} = edition,
        resolution,
        %GenerationProfile{} = profile,
        attributes,
        options
      )
      when is_map(resolution) and is_map(attributes) and is_list(options) do
    control_graph = attributes[:control_graph_iri]
    catalog_graph = attributes[:catalog_graph_iri]
    wiki_graph = edition.graph_iri
    next_revision = resolution[:current_revision] + 1

    with true <- exact_control_graph?(control_graph, edition.repository_iri),
         true <- exact_catalog_graph?(catalog_graph),
         true <- resolution[:repository_iri] == edition.repository_iri,
         true <- resolution[:tenant_iri] == edition.tenant_iri,
         true <- resolution[:current_state] in [:manual, :automatic],
         true <- profile_matches_state?(profile, resolution.current_state),
         true <- attributes[:source_fence] == edition.source_fence,
         {:ok, enrollment} <-
           Enrollment.new(%{
             repository_iri: edition.repository_iri,
             tenant_iri: edition.tenant_iri,
             revision: next_revision,
             state: resolution.current_state,
             generation_profile: profile,
             generation_mode: :deterministic_only,
             preview_mode: profile.preview_mode,
             read_visibility: resolution[:read_visibility],
             cancellation_generation: resolution[:cancellation_generation],
             current_edition_iri: edition.iri,
             recorded_at: attributes.recorded_at
           }),
         {:ok, transition} <-
           Transition.new(%{
             subject_iri: enrollment.wiki_iri,
             domain: :repository_wiki_enrollment,
             prior_state: resolution.current_state,
             next_state: resolution.current_state,
             revision: next_revision,
             expected_predecessor: resolution.current_transition_iri,
             actor_iri: attributes.actor_iri,
             cause_iri: attributes.causation_iri,
             reason: attributes.reason,
             recorded_at: attributes.recorded_at
           }),
         material = activation_material(edition, next_revision, attributes),
         {:ok, command_iri} <- Command.identity("ActivateWikiEdition", material),
         {:ok, target} <-
           ControlGraph.target(
             control_graph,
             attributes.expected_control_revision,
             edition.repository_iri,
             command_iri,
             attributes.recorded_at,
             Enrollment.statements(enrollment) ++
               Transition.statements(transition) ++
               activation_statements(command_iri, edition, resolution, attributes.recorded_at)
           ),
         guards = activation_guards(edition, resolution, enrollment, profile, attributes),
         revisions = %{
           control_graph => attributes.expected_control_revision,
           catalog_graph => attributes.expected_catalog_revision,
           wiki_graph => attributes.expected_wiki_revision
         },
         {:ok, command} <-
           Command.build(
             "ActivateWikiEdition",
             material,
             [target],
             guards,
             base_attributes(attributes, edition, revisions),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:activate_wiki_edition)
    end
  rescue
    _error -> invalid(:activate_wiki_edition)
  end

  def activate_command(_edition, _resolution, _profile, _attributes, _options),
    do: invalid(:activate_wiki_edition)

  @spec mark_stale_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def mark_stale_command(%__MODULE__{} = edition, attributes, options \\ []) do
    lifecycle_observation_command(
      "MarkWikiEditionStale",
      :wiki_stale,
      edition,
      attributes,
      options
    )
  end

  @spec invalidate_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def invalidate_command(%__MODULE__{} = edition, attributes, options \\ []) do
    lifecycle_observation_command(
      "InvalidateWikiEdition",
      :wiki_invalidated,
      edition,
      attributes,
      options
    )
  end

  defp lifecycle_observation_command(type, state, edition, attributes, options) do
    graph = attributes[:control_graph_iri]
    revision = attributes[:expected_control_revision]
    material = Enum.join([edition.iri, type, attributes[:source_fence]], "\n")

    with true <- exact_control_graph?(graph, edition.repository_iri),
         true <- is_integer(revision) and revision > 0,
         {:ok, finding_iri} <- ResourceIdentity.deterministic(:wiki_drift_finding, material),
         {:ok, command_iri} <- Command.identity(type, material),
         additions = [
           {finding_iri, @rdf_type, RDF.iri(@jf <> "WikiDriftFinding")},
           {finding_iri, @jf <> "repositoryScope", RDF.iri(edition.repository_iri)},
           {finding_iri, @jf <> "tenantScope", RDF.iri(edition.tenant_iri)},
           {finding_iri, @jf <> "wikiEdition", RDF.iri(edition.iri)},
           {finding_iri, @jf <> "editionState", RDF.iri(Contract.concept(state))},
           {finding_iri, @jf <> "sourceFence", RDF.XSD.String.new(attributes.source_fence)},
           {finding_iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(attributes.recorded_at)}
         ],
         {:ok, target} <-
           ControlGraph.target(
             graph,
             revision,
             edition.repository_iri,
             command_iri,
             attributes.recorded_at,
             additions
           ),
         {:ok, command} <-
           Command.build(
             type,
             material,
             [target],
             [
               {:subject_absent, graph, finding_iri},
               {:subject_present, edition.graph_iri, edition.iri}
             ],
             base_attributes(attributes, edition, %{
               graph => revision,
               edition.graph_iri => attributes.expected_wiki_revision
             }),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_edition_lifecycle_observation)
    end
  end

  defp activation_guards(edition, resolution, enrollment, profile, attributes) do
    current_guard =
      case resolution[:current_edition_iri] do
        nil ->
          {:predicate_absent, attributes.control_graph_iri, resolution.current_enrollment_iri,
           @jf <> "currentWikiEdition"}

        current ->
          {:triple_present, attributes.control_graph_iri, resolution.current_enrollment_iri,
           @jf <> "currentWikiEdition", RDF.iri(current)}
      end

    [
      {:subject_present, attributes.control_graph_iri, resolution.current_enrollment_iri},
      {:subject_present, attributes.control_graph_iri, resolution.current_transition_iri},
      {:subject_absent, attributes.control_graph_iri, enrollment.iri},
      {:subject_present, attributes.catalog_graph_iri, profile.iri},
      {:triple_present, edition.graph_iri, edition.iri, @jf <> "editionState",
       RDF.iri(Contract.concept(:wiki_closed))},
      {:triple_present, edition.graph_iri, edition.iri, @jf <> "sourceFence",
       RDF.XSD.String.new(edition.source_fence)},
      current_guard
      | Map.get(attributes, :qualification_guards, [])
    ]
  end

  defp activation_material(edition, next_revision, attributes) do
    base = [edition.iri, "activate", Integer.to_string(next_revision)]

    case attributes[:qualification_digest] do
      digest when is_binary(digest) -> Enum.join(base ++ [digest], "\n")
      _missing -> Enum.join(base, "\n")
    end
  end

  defp activation_statements(command_iri, edition, resolution, recorded_at) do
    [
      {command_iri, @rdf_type, RDF.iri(@prov <> "Activity")},
      {command_iri, @jf <> "repositoryScope", RDF.iri(edition.repository_iri)},
      {command_iri, @jf <> "tenantScope", RDF.iri(edition.tenant_iri)},
      {command_iri, @jf <> "wikiEdition", RDF.iri(edition.iri)},
      {edition.iri, @jf <> "activatedBy", RDF.iri(command_iri)},
      {command_iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(recorded_at)}
      | supersession_statements(resolution[:current_edition_iri], command_iri)
    ]
  end

  defp supersession_statements(nil, _command_iri), do: []

  defp supersession_statements(current_edition_iri, command_iri),
    do: [{current_edition_iri, @jf <> "supersededBy", RDF.iri(command_iri)}]

  defp lint_statements(report) do
    [
      {report.iri, @rdf_type, RDF.iri(@jf <> "WikiLintReport")},
      {report.iri, @jf <> "wikiEdition", RDF.iri(report.edition_iri)},
      {report.iri, @jf <> "lintProfile", RDF.XSD.String.new(report.profile)},
      {report.iri, @jf <> "lintProfileDigest", RDF.XSD.String.new(report.profile_digest)},
      {report.iri, @jf <> "contentDigest", RDF.XSD.String.new(report.digest)},
      {report.iri, @jf <> "blockingFindingCount",
       RDF.XSD.NonNegativeInteger.new(report.blocking_count)},
      {report.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(report.recorded_at)}
      | Enum.map(report.findings, fn finding ->
          {report.iri, @jf <> "warningCode", RDF.XSD.String.new(finding.code)}
        end)
    ]
  end

  defp attempt_statements(edition, state, recorded_at) do
    [
      {edition.attempt_iri, @rdf_type, RDF.iri(@jf <> "WikiCompilationAttempt")},
      {edition.attempt_iri, @jf <> "repositoryScope", RDF.iri(edition.repository_iri)},
      {edition.attempt_iri, @jf <> "tenantScope", RDF.iri(edition.tenant_iri)},
      {edition.attempt_iri, @jf <> "wikiEdition", RDF.iri(edition.iri)},
      {edition.attempt_iri, @jf <> "sourceSnapshot", RDF.iri(edition.source_snapshot_iri)},
      {edition.attempt_iri, @jf <> "sourceFence", RDF.XSD.String.new(edition.source_fence)},
      {edition.attempt_iri, @jf <> "compilerProfile",
       RDF.XSD.String.new(edition.compiler_profile)},
      {edition.attempt_iri, @jf <> "compilerDigest", RDF.XSD.String.new(edition.compiler_digest)},
      {edition.attempt_iri, @jf <> "editionState", RDF.iri(Contract.concept(wiki_state(state)))},
      {edition.attempt_iri, @prov <> "startedAtTime", RDF.XSD.DateTime.new(recorded_at)}
    ]
  end

  defp optional_iris(edition) do
    optional_iri(edition.iri, @jf <> "predecessorWikiEdition", edition.predecessor_edition_iri) ++
      optional_iri(
        edition.iri,
        @jf <> "expectedCurrentWikiEdition",
        edition.expected_current_edition_iri
      )
  end

  defp semantic_map(edition) do
    %{
      edition_iri: edition.iri,
      repository_iri: edition.repository_iri,
      tenant_iri: edition.tenant_iri,
      wiki_iri: edition.wiki_iri,
      graph_iri: edition.graph_iri,
      source_snapshot_iri: edition.source_snapshot_iri,
      source_fence: edition.source_fence,
      compiler_profile: edition.compiler_profile,
      compiler_digest: edition.compiler_digest,
      input_manifest_digest: edition.input_manifest_digest,
      edition_root: edition.edition_root,
      purpose: edition.purpose,
      state: :building,
      completeness: :building,
      freshness: :current,
      retention_class: :incomplete,
      current?: false,
      page_count: edition.page_count,
      segment_count: edition.segment_count,
      statement_count: edition.statement_count,
      content_bytes: edition.content_bytes,
      created_at: edition.created_at,
      predecessor_edition_iri: edition.predecessor_edition_iri,
      lint_report_iri: nil,
      closure_digest: nil
    }
  end

  defp base_attributes(attributes, edition, revisions) do
    attributes
    |> Map.put(:expected_graph_revisions, revisions)
    |> Map.put(:repository_iri, edition.repository_iri)
    |> Map.put(:scope_iri, edition.repository_iri)
    |> Map.put(:source_fence, edition.source_fence)
  end

  defp closure_digest(edition, segments) do
    Contract.digest(%{
      edition_root: edition.edition_root,
      compilation_digest: edition.compilation_digest,
      segment_digests: Enum.map(segments, & &1.digest),
      segment_counts: Enum.map(segments, &{&1.statement_count, &1.content_bytes})
    })
  end

  defp contiguous_segments?(segments, edition_iri) when segments != [] do
    Enum.with_index(segments)
    |> Enum.all?(fn
      {%Segment{edition_iri: ^edition_iri, index: 0, predecessor_iri: nil}, 0} ->
        true

      {%Segment{edition_iri: ^edition_iri} = segment, index} ->
        prior = Enum.at(segments, index - 1)
        segment.index == index and segment.predecessor_iri == prior.iri

      _invalid ->
        false
    end)
  end

  defp contiguous_segments?(_segments, _edition_iri), do: false

  defp valid_finding?(finding) when is_map(finding) do
    finding[:severity] in [:blocking, :warning] and is_binary(finding[:code]) and
      byte_size(finding.code) in 1..64 and
      (is_nil(finding[:resource_iri]) or ResourceIdentity.validate(finding.resource_iri) == :ok)
  end

  defp valid_finding?(_finding), do: false

  defp trigger_allowed?(:manual, :manual_request), do: true

  defp trigger_allowed?(:automatic, trigger)
       when trigger in [:manual_request, :automatic_reconciliation], do: true

  defp trigger_allowed?(_state, _trigger), do: false

  defp profile_matches_state?(%GenerationProfile{profile_key: :manual_deterministic}, :manual),
    do: true

  defp profile_matches_state?(
         %GenerationProfile{profile_key: :automatic_deterministic},
         :automatic
       ),
       do: true

  defp profile_matches_state?(_profile, _state), do: false

  defp exact_control_graph?(graph, repository_iri) do
    case GraphRegistry.graph_iri(:repository_control, %{repository: repository_iri}) do
      {:ok, expected} -> expected == graph
      {:error, %Error{}} -> false
    end
  end

  defp exact_catalog_graph?(graph) do
    case GraphRegistry.graph_iri(:factory_catalog, %{}) do
      {:ok, expected} -> expected == graph
      {:error, %Error{}} -> false
    end
  end

  defp purpose_concept(:current), do: Contract.concept(:wiki_current_purpose)
  defp purpose_concept(:release), do: Contract.concept(:wiki_release_purpose)
  defp purpose_concept(:candidate_preview), do: Contract.concept(:wiki_candidate_preview_purpose)
  defp purpose_concept(:recovery), do: Contract.concept(:wiki_recovery_purpose)

  defp preview_statements(
         %__MODULE__{purpose: :candidate_preview} = edition,
         %Preview{} = preview
       ) do
    if preview.edition_iri == edition.iri and preview.repository_iri == edition.repository_iri and
         preview.tenant_iri == edition.tenant_iri and preview.source_fence == edition.source_fence do
      {:ok, Preview.statements(preview)}
    else
      invalid(:start_wiki_preview)
    end
  end

  defp preview_statements(%__MODULE__{purpose: :candidate_preview}, _preview),
    do: invalid(:start_wiki_preview)

  defp preview_statements(%__MODULE__{}, nil), do: {:ok, []}
  defp preview_statements(%__MODULE__{}, _preview), do: invalid(:start_wiki_edition)

  defp wiki_state(:admitted), do: :wiki_building
  defp wiki_state(:building), do: :wiki_building

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, iri), do: [{subject, predicate, RDF.iri(iri)}]
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

defmodule JidoCode.Knowledge.Commands.PublishSourceGraph do
  @moduledoc """
  Validates and builds an immutable exact-snapshot source graph command.

  Analyzer output is treated as untrusted input. This boundary admits only a
  closed source vocabulary, canonical snapshot-scoped entities, bounded
  literals and counts, and analyzer provenance matching the command identity.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @max_source_statements 400
  @max_literal_bytes 512
  @allowed_warnings MapSet.new([
                      "file_limit_reached",
                      "parse_error",
                      "source_expression_limit",
                      "source_file_size",
                      "source_statement_limit",
                      "source_symbol_limit",
                      "source_total_bytes",
                      "symlink_skipped",
                      "unsupported_file_type_skipped"
                    ])
  @allowed_predicates MapSet.new([
                        @rdf_type,
                        @prov <> "wasDerivedFrom",
                        @prov <> "wasGeneratedBy",
                        @prov <> "used",
                        @jf <> "sourceSnapshot",
                        @jf <> "relativePath",
                        @jf <> "contentDigest",
                        @jf <> "byteCount",
                        @jf <> "language",
                        @jf <> "containsSymbol",
                        @jf <> "inArtifact",
                        @jf <> "symbolKind",
                        @jf <> "identityKind",
                        @jf <> "displayName",
                        @jf <> "arity",
                        @jf <> "visibility",
                        @jf <> "defines",
                        @jf <> "calls",
                        @jf <> "dependsOn",
                        @jf <> "otpPattern",
                        @jf <> "analyzerVersion",
                        @jf <> "configurationDigest",
                        @jf <> "inputTreeDigest"
                      ])
  @count_predicates %{
    files: "resourceCountFiles",
    modules: "resourceCountModules",
    functions: "resourceCountFunctions",
    references: "resourceCountReferences",
    expressions: "resourceCountExpressions",
    triples: "resourceCountTriples"
  }

  @spec build(map(), keyword()) ::
          {:ok,
           %{
             command: CommandEnvelope.t(),
             graph_iri: String.t(),
             activity_iri: String.t(),
             dataset_digest: String.t()
           }}
          | {:error, Error.t()}
  def build(attributes, options \\ [])

  def build(attributes, options) when is_map(attributes) and is_list(options) do
    analysis = attributes[:analysis]

    with :ok <- validate_resources(attributes),
         true <- is_map(analysis),
         %DateTime{} = analyzed_at <- attributes[:analyzed_at],
         true <- valid_text?(analysis[:analyzer_version], 128),
         true <- digest?(analysis[:configuration_digest]),
         true <- git_digest?(analysis[:input_tree_digest]),
         true <- analysis[:input_tree_digest] == String.downcase(attributes[:tree_digest]),
         {:ok, coverage} <- validate_coverage(analysis[:coverage]),
         {:ok, warnings} <- validate_warnings(analysis[:warnings]),
         {:ok, counts} <- validate_counts(analysis[:resource_counts]),
         true <- counts_match_coverage?(counts, coverage),
         {:ok, graph_iri} <-
           GraphRegistry.graph_iri(:source_revision, %{
             repository: attributes[:repository_iri],
             revision: attributes[:snapshot_iri]
           }),
         {:ok, activity_iri} <-
           ResourceIdentity.source_analysis(
             attributes[:snapshot_iri],
             analysis[:analyzer_version],
             analysis[:configuration_digest]
           ),
         %RDF.Dataset{} = dataset <- analysis[:dataset],
         source_quads <- RDF.Dataset.quads(dataset),
         :ok <-
           validate_dataset(
             source_quads,
             graph_iri,
             attributes[:snapshot_iri],
             activity_iri,
             analysis
           ),
         dataset_digest <- canonical_digest(source_quads),
         true <- counts.triples == length(source_quads),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(
             :command_request,
             "PublishSourceGraph\n" <> activity_iri
           ),
         {:ok, metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: attributes[:repository_scope_iri],
             ontology_version: "https://jido.run/ontology/release/1.0.0",
             creation_activity: command_iri,
             created_at: analyzed_at,
             lifecycle_state: :closed,
             completeness_state: :complete,
             closed_at: analyzed_at,
             source_revision: attributes[:snapshot_iri],
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata),
         additions <-
           metadata_quads ++
             source_quads ++
             publication_quads(
               graph_iri,
               attributes[:snapshot_iri],
               activity_iri,
               analysis,
               coverage,
               warnings,
               counts,
               dataset_digest
             ),
         {:ok, tree_iri} <- tree_identity(attributes[:tree_digest]),
         {:ok, command} <-
           command(
             attributes,
             command_iri,
             graph_iri,
             activity_iri,
             tree_iri,
             metadata,
             additions,
             analysis[:configuration_digest],
             options
           ) do
      {:ok,
       %{
         command: command,
         graph_iri: graph_iri,
         activity_iri: activity_iri,
         dataset_digest: dataset_digest
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:publish_source_graph)
    end
  rescue
    _error -> invalid(:publish_source_graph)
  end

  def build(_attributes, _options), do: invalid(:publish_source_graph)

  defp command(
         attributes,
         command_iri,
         graph_iri,
         activity_iri,
         tree_iri,
         metadata,
         additions,
         idempotency_key,
         options
       ) do
    observation_graph = attributes[:observation_graph_iri]
    snapshot = attributes[:snapshot_iri]

    CommandEnvelope.new(
      %{
        command_type: "PublishSourceGraph",
        command_version: "1.1.0",
        command_iri: command_iri,
        principal_iri: attributes[:principal_iri],
        actor_iri: attributes[:actor_iri],
        delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
        delegation_iri: Map.get(attributes, :delegation_iri),
        scope_iri: attributes[:repository_scope_iri],
        idempotency_key: idempotency_key,
        correlation_iri: attributes[:correlation_iri],
        causation_iri: attributes[:causation_iri],
        ontology_version: "1.0.0",
        shape_version: "1.0.0",
        expected_dataset_revision: attributes[:expected_dataset_revision],
        expected_graph_revisions: %{
          graph_iri => 0,
          observation_graph => attributes[:observation_graph_revision]
        },
        reason: attributes[:reason],
        payload: %{
          guards: [
            {:triple_present, observation_graph, snapshot, @rdf_type,
             RDF.iri(@jf <> "RepositorySnapshot")},
            {:triple_present, observation_graph, snapshot, @jf <> "about",
             RDF.iri(attributes[:repository_iri])},
            {:triple_present, observation_graph, snapshot, @jf <> "treeIdentity",
             RDF.iri(tree_iri)},
            {:subject_absent, graph_iri, activity_iri}
          ],
          changes: [
            %{
              family: :source_revision,
              graph_iri: graph_iri,
              operation: :create,
              metadata: metadata,
              additions: additions,
              supersessions: [],
              invalidations: [],
              removals: []
            }
          ]
        }
      },
      options
    )
  end

  defp validate_dataset(quads, graph, snapshot, activity, analysis)
       when is_list(quads) and length(quads) in 1..@max_source_statements do
    with true <- Enum.all?(quads, &valid_quad?(&1, graph)),
         true <- Enum.all?(quads, &allowed_statement?/1),
         true <- Enum.all?(quads, &bounded_terms?/1),
         :ok <- validate_entities(quads, snapshot, activity),
         :ok <- validate_activity(quads, activity, snapshot, analysis) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:source_analysis_dataset)
    end
  end

  defp validate_dataset(_quads, _graph, _snapshot, _activity, _analysis),
    do: invalid(:source_analysis_limit)

  defp validate_entities(quads, snapshot, activity) do
    artifacts = typed_subjects(quads, @jf <> "SourceArtifact")
    symbols = typed_subjects(quads, @jf <> "CodeSymbol")
    activities = typed_subjects(quads, @prov <> "Activity")
    admitted = MapSet.new([activity | artifacts ++ symbols])

    subjects =
      quads
      |> Enum.map(fn {%RDF.IRI{value: subject}, _, _, _} -> subject end)
      |> MapSet.new()

    with true <- activities == [activity],
         true <- MapSet.equal?(subjects, admitted),
         true <- Enum.all?(artifacts, &canonical_artifact?(&1, quads, snapshot, activity)),
         true <- Enum.all?(symbols, &canonical_symbol?(&1, quads, snapshot, artifacts)),
         true <- source_snapshot?(quads, activity, snapshot) do
      :ok
    else
      _invalid -> invalid(:source_entity_scope)
    end
  end

  defp canonical_artifact?(artifact, quads, snapshot, activity) do
    with [path] <- literal_values(quads, artifact, @jf <> "relativePath"),
         [digest] <- literal_values(quads, artifact, @jf <> "contentDigest"),
         [bytes] when is_integer(bytes) and bytes >= 0 <-
           literal_values(quads, artifact, @jf <> "byteCount"),
         ["Elixir"] <- literal_values(quads, artifact, @jf <> "language"),
         [^activity] <- iri_values(quads, artifact, @prov <> "wasGeneratedBy"),
         true <- source_snapshot?(quads, artifact, snapshot),
         {:ok, expected} <- ResourceIdentity.source_artifact(snapshot, path, digest) do
      artifact == expected
    else
      _invalid -> false
    end
  end

  defp canonical_symbol?(symbol, quads, snapshot, artifacts) do
    with [identity_kind] <- literal_values(quads, symbol, @jf <> "identityKind"),
         [name] <- literal_values(quads, symbol, @jf <> "displayName"),
         [symbol_kind] <- iri_values(quads, symbol, @jf <> "symbolKind"),
         true <- symbol_kind == expected_symbol_kind(identity_kind),
         true <- valid_symbol_name?(identity_kind, name),
         [artifact] <- iri_values(quads, symbol, @jf <> "inArtifact"),
         true <- artifact in artifacts,
         true <- source_snapshot?(quads, symbol, snapshot),
         {:ok, expected} <- ResourceIdentity.code_symbol(snapshot, identity_kind, name) do
      symbol == expected
    else
      _invalid -> false
    end
  end

  defp validate_activity(quads, activity, snapshot, analysis) do
    valid? =
      source_snapshot?(quads, activity, snapshot) and
        iri_values(quads, activity, @prov <> "used") == [snapshot] and
        literal_values(quads, activity, @jf <> "analyzerVersion") == [
          analysis[:analyzer_version]
        ] and
        literal_values(quads, activity, @jf <> "configurationDigest") == [
          analysis[:configuration_digest]
        ] and
        literal_values(quads, activity, @jf <> "inputTreeDigest") == [
          analysis[:input_tree_digest]
        ]

    if valid?, do: :ok, else: invalid(:source_analyzer_provenance)
  end

  defp publication_quads(
         graph,
         snapshot,
         activity,
         analysis,
         coverage,
         warnings,
         counts,
         dataset_digest
       ) do
    base = [
      quad(graph, @jf <> "sourceSnapshot", RDF.iri(snapshot), graph),
      quad(graph, @jf <> "sourceAnalysis", RDF.iri(activity), graph),
      quad(
        graph,
        @jf <> "analyzerVersion",
        RDF.XSD.String.new(analysis[:analyzer_version]),
        graph
      ),
      quad(
        graph,
        @jf <> "configurationDigest",
        RDF.XSD.String.new(analysis[:configuration_digest]),
        graph
      ),
      quad(
        graph,
        @jf <> "inputTreeDigest",
        RDF.XSD.String.new(analysis[:input_tree_digest]),
        graph
      ),
      quad(
        graph,
        @jf <> "analysisDatasetDigest",
        RDF.XSD.String.new(dataset_digest),
        graph
      ),
      quad(
        graph,
        @jf <> "coverageStatus",
        RDF.iri(@concept <> coverage_concept(coverage.status)),
        graph
      )
    ]

    warning_quads =
      Enum.map(warnings, &quad(graph, @jf <> "analysisWarning", RDF.XSD.String.new(&1), graph))

    count_quads =
      Enum.map(counts, fn {name, value} ->
        quad(
          graph,
          @jf <> Map.fetch!(@count_predicates, name),
          RDF.XSD.NonNegativeInteger.new(value),
          graph
        )
      end)

    base ++ warning_quads ++ count_quads
  end

  defp validate_resources(attributes) do
    Enum.reduce_while(
      [
        :repository_iri,
        :repository_scope_iri,
        :snapshot_iri,
        :principal_iri,
        :actor_iri,
        :correlation_iri,
        :causation_iri
      ],
      :ok,
      fn key, :ok ->
        case ResourceIdentity.validate(attributes[key]) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end
    )
    |> then(fn
      :ok ->
        with {:ok, :observation_batch} <-
               GraphRegistry.identify(attributes[:observation_graph_iri]),
             true <-
               is_integer(attributes[:observation_graph_revision]) and
                 attributes[:observation_graph_revision] > 0,
             true <-
               is_integer(attributes[:expected_dataset_revision]) and
                 attributes[:expected_dataset_revision] >= 0,
             true <- git_digest?(attributes[:tree_digest]) do
          :ok
        else
          _invalid -> invalid(:source_publication_scope)
        end

      error ->
        error
    end)
  end

  defp validate_coverage(%{status: status} = coverage)
       when status in [:complete, :partial, :incomplete] do
    expected_keys = [:analyzed_bytes, :analyzed_files, :discovered_files, :expressions, :status]

    if Enum.sort(Map.keys(coverage)) == expected_keys and
         Enum.all?(coverage, fn
           {:status, _status} -> true
           {_key, value} -> is_integer(value) and value >= 0
         end),
       do: {:ok, coverage},
       else: invalid(:source_analysis_coverage)
  end

  defp validate_coverage(_coverage), do: invalid(:source_analysis_coverage)

  defp validate_warnings(warnings) when is_list(warnings) and length(warnings) <= 100 do
    if Enum.all?(warnings, &MapSet.member?(@allowed_warnings, &1)),
      do: {:ok, Enum.uniq(warnings)},
      else: invalid(:source_analysis_warnings)
  end

  defp validate_warnings(_warnings), do: invalid(:source_analysis_warnings)

  defp validate_counts(counts) when is_map(counts) do
    if Map.keys(counts) |> Enum.sort() == Map.keys(@count_predicates) |> Enum.sort() and
         Enum.all?(counts, fn {_name, value} -> is_integer(value) and value >= 0 end),
       do: {:ok, counts},
       else: invalid(:source_analysis_counts)
  end

  defp validate_counts(_counts), do: invalid(:source_analysis_counts)

  defp counts_match_coverage?(counts, coverage) do
    counts.files == coverage.analyzed_files and counts.expressions == coverage.expressions and
      coverage.analyzed_files <= coverage.discovered_files
  end

  defp valid_quad?({_, _, _, %RDF.IRI{value: graph}}, graph), do: true
  defp valid_quad?(_quad, _graph), do: false

  defp allowed_statement?({%RDF.IRI{value: subject}, %RDF.IRI{value: predicate}, object, _}) do
    MapSet.member?(@allowed_predicates, predicate) and
      not String.starts_with?(subject, "https://jido.run/ontology/") and
      safe_object?(predicate, object)
  end

  defp allowed_statement?(_quad), do: false

  defp bounded_terms?({_subject, _predicate, %RDF.Literal{} = object, _graph}) do
    object |> RDF.Literal.lexical() |> byte_size() <= @max_literal_bytes
  end

  defp bounded_terms?({_subject, _predicate, %RDF.IRI{value: object}, _graph}),
    do: byte_size(object) <= 512

  defp bounded_terms?(_quad), do: false

  defp safe_object?(@rdf_type, %RDF.IRI{value: class}),
    do: class in [@jf <> "SourceArtifact", @jf <> "CodeSymbol", @prov <> "Activity"]

  defp safe_object?(predicate, %RDF.IRI{})
       when predicate in [
              @prov <> "wasDerivedFrom",
              @prov <> "wasGeneratedBy",
              @prov <> "used",
              @jf <> "sourceSnapshot",
              @jf <> "containsSymbol",
              @jf <> "inArtifact",
              @jf <> "symbolKind",
              @jf <> "defines",
              @jf <> "calls",
              @jf <> "dependsOn"
            ],
       do: true

  defp safe_object?(@jf <> "relativePath", %RDF.Literal{} = value) do
    literal = RDF.Literal.value(value)

    is_binary(literal) and Regex.match?(~r/^[A-Za-z0-9_.\/-]+$/, literal) and
      not String.contains?(literal, ["/../", "/./"])
  end

  defp safe_object?(predicate, %RDF.Literal{} = value)
       when predicate in [@jf <> "contentDigest", @jf <> "configurationDigest"] do
    digest?(RDF.Literal.value(value))
  end

  defp safe_object?(@jf <> "inputTreeDigest", %RDF.Literal{} = value),
    do: git_digest?(RDF.Literal.value(value))

  defp safe_object?(predicate, %RDF.Literal{} = value)
       when predicate in [@jf <> "byteCount", @jf <> "arity"] do
    number = RDF.Literal.value(value)
    is_integer(number) and number >= 0 and number <= 50_000_000
  end

  defp safe_object?(@jf <> "language", %RDF.Literal{} = value),
    do: RDF.Literal.value(value) == "Elixir"

  defp safe_object?(@jf <> "identityKind", %RDF.Literal{} = value),
    do: RDF.Literal.value(value) in ["module", "def", "defp", "reference", "module_reference"]

  defp safe_object?(@jf <> "displayName", %RDF.Literal{} = value) do
    name = RDF.Literal.value(value)
    is_binary(name) and valid_text?(name, 160) and not String.contains?(name, ["\n", "\r"])
  end

  defp safe_object?(@jf <> "visibility", %RDF.Literal{} = value),
    do: RDF.Literal.value(value) in ["def", "defp"]

  defp safe_object?(@jf <> "otpPattern", %RDF.Literal{} = value),
    do: RDF.Literal.value(value) in ["GenServer", "Supervisor", "Application"]

  defp safe_object?(@jf <> "analyzerVersion", %RDF.Literal{} = value) do
    version = RDF.Literal.value(value)
    is_binary(version) and Regex.match?(~r/^[a-z0-9][a-z0-9._\/-]{0,127}$/, version)
  end

  defp safe_object?(_predicate, _object), do: false

  defp typed_subjects(quads, class) do
    quads
    |> Enum.flat_map(fn
      {%RDF.IRI{value: subject}, %RDF.IRI{value: @rdf_type}, %RDF.IRI{value: ^class}, _graph} ->
        [subject]

      _other ->
        []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp source_snapshot?(quads, subject, snapshot) do
    iri_values(quads, subject, @jf <> "sourceSnapshot") == [snapshot]
  end

  defp expected_symbol_kind("module"), do: @concept <> "Module"
  defp expected_symbol_kind(kind) when kind in ["def", "defp"], do: @concept <> "Function"

  defp expected_symbol_kind(kind) when kind in ["reference", "module_reference"],
    do: @concept <> "Reference"

  defp expected_symbol_kind(_kind), do: nil

  defp valid_symbol_name?(kind, name) when kind in ["module", "module_reference"] do
    is_binary(name) and Regex.match?(~r/^[A-Z][A-Za-z0-9_.]{0,159}$/, name)
  end

  defp valid_symbol_name?(kind, name) when kind in ["def", "defp", "reference"] do
    is_binary(name) and Regex.match?(~r/^[A-Za-z0-9_.!?+*<>=-]+\/\d+$/, name)
  end

  defp valid_symbol_name?(_kind, _name), do: false

  defp iri_values(quads, subject, predicate) do
    quads
    |> Enum.flat_map(fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: ^predicate}, %RDF.IRI{value: value}, _graph} ->
        [value]

      _other ->
        []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp literal_values(quads, subject, predicate) do
    quads
    |> Enum.flat_map(fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: ^predicate}, %RDF.Literal{} = value, _graph} ->
        [RDF.Literal.value(value)]

      _other ->
        []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp canonical_digest(quads) do
    quads
    |> RDF.Dataset.new()
    |> RDF.NQuads.write_string!(sort: true)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp tree_identity(digest) do
    algorithm = if byte_size(digest) == 40, do: :sha1, else: :sha256
    ResourceIdentity.git_object(algorithm, digest)
  end

  defp coverage_concept(:complete), do: "Complete"
  defp coverage_concept(:partial), do: "Incomplete"
  defp coverage_concept(:incomplete), do: "Incomplete"

  defp valid_text?(value, maximum) when is_binary(value) do
    byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/, value)
  end

  defp valid_text?(_value, _maximum), do: false
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp git_digest?(value) do
    is_binary(value) and byte_size(value) in [40, 64] and Regex.match?(~r/^[a-f0-9]+$/, value)
  end

  defp quad(subject, predicate, object, graph), do: RDF.quad(subject, predicate, object, graph)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

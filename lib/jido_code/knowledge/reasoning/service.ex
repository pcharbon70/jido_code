defmodule JidoCode.Knowledge.Reasoning.Service do
  @moduledoc "Bounded isolated materialization followed by governed derived-graph publication."

  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Reasoning.Profiles
  alias JidoCode.Knowledge.ResourceIdentity
  alias TripleStore.Reasoner.SemiNaive

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @forbidden_predicates MapSet.new([
                          @jf <> "grantsCapability",
                          @jf <> "accepts",
                          @jf <> "rejects",
                          @jf <> "waives",
                          @jf <> "satisfies",
                          @jf <> "leasesTask",
                          @jf <> "heldBy",
                          @jf <> "epistemicState"
                        ])
  @forbidden_types MapSet.new([
                     @jf <> "AuthorizationGrant",
                     @jf <> "Delegation",
                     @jf <> "Decision",
                     @jf <> "StateTransition",
                     @jf <> "KnowledgeStateTransition",
                     @jf <> "Lease",
                     @jf <> "Command",
                     @jf <> "KnowledgeAssertion"
                   ])
  @required_bounds ~w[max_input_facts max_derived_facts max_iterations timeout_ms max_bytes]a

  @spec materialize(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def materialize(attributes, options \\ [])

  def materialize(attributes, options) when is_map(attributes) and is_list(options) do
    with {:ok, bounds} <- bounds(attributes[:bounds]),
         true <- attributes[:profile] in Profiles.names(),
         {:ok, rules} <- Profiles.rules(attributes.profile),
         {:ok, input} <- input_facts(attributes[:source_statements], bounds),
         {:ok, all_facts, stats} <- run(rules, input, bounds),
         derived <- MapSet.difference(all_facts, input),
         true <- MapSet.size(derived) <= bounds.max_derived_facts,
         true <- :erlang.external_size(derived) <= bounds.max_bytes,
         {:ok, statements} <- derived_statements(derived),
         :ok <- no_authority_effects(statements),
         {:ok, activity_iri, report_iri} <- identities(attributes),
         annotations <-
           annotations(
             activity_iri,
             report_iri,
             attributes,
             bounds,
             stats,
             MapSet.size(input),
             statements
           ),
         request <-
           attributes
           |> Map.take([
             :command_iri,
             :authority,
             :scope_iri,
             :idempotency_key,
             :correlation_iri,
             :causation_iri,
             :ontology_version,
             :shape_version,
             :target_graph_iri,
             :rule_set_iri,
             :rule_set_slug,
             :rule_revision,
             :query_version,
             :source_graph_revisions,
             :expected_prior_derivation,
             :reason
           ])
           |> Map.merge(%{operation: :publish, statements: statements ++ annotations}),
         {:ok, receipt} <- DerivedGraphManager.publish(request, options) do
      {:ok,
       %{
         receipt: receipt,
         target_graph_iri: attributes.target_graph_iri,
         activity_iri: activity_iri,
         validation_report_iri: report_iri,
         profile: attributes.profile,
         rule_revision: attributes.rule_revision,
         query_version: attributes.query_version,
         source_graph_revisions: attributes.source_graph_revisions,
         derived_classifications:
           classifications(
             statements,
             attributes.target_graph_iri,
             activity_iri,
             attributes.rule_revision,
             attributes.source_graph_revisions
           ),
         input_count: MapSet.size(input),
         derived_count: length(statements),
         stats: normalize_stats(stats),
         bounds: bounds,
         acceptance_authority?: false,
         command_authority?: false
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, _reason} -> invalid(:reasoning_materialization)
      _invalid -> invalid(:reasoning_materialization)
    end
  rescue
    _error -> invalid(:reasoning_materialization)
  end

  def materialize(_attributes, _options), do: invalid(:reasoning_materialization)

  defp bounds(value) when is_map(value) do
    if Enum.all?(@required_bounds, &Map.has_key?(value, &1)) and
         is_integer(value.max_input_facts) and value.max_input_facts in 1..2_000 and
         is_integer(value.max_derived_facts) and value.max_derived_facts in 1..800 and
         is_integer(value.max_iterations) and value.max_iterations in 1..50 and
         is_integer(value.timeout_ms) and value.timeout_ms in 10..10_000 and
         is_integer(value.max_bytes) and value.max_bytes in 1_024..5_000_000 do
      {:ok, Map.take(value, @required_bounds)}
    else
      invalid(:reasoning_bounds)
    end
  end

  defp bounds(_value), do: invalid(:reasoning_bounds)

  defp input_facts(statements, bounds)
       when is_list(statements) and length(statements) <= bounds.max_input_facts do
    facts = Enum.map(statements, &fact/1)

    if Enum.all?(facts, &match?({:ok, _}, &1)) do
      set = facts |> Enum.map(&elem(&1, 1)) |> MapSet.new()

      if :erlang.external_size(set) <= bounds.max_bytes,
        do: {:ok, set},
        else: invalid(:reasoning_input)
    else
      invalid(:reasoning_input)
    end
  end

  defp input_facts(_statements, _bounds), do: invalid(:reasoning_input)

  defp fact(statement) do
    case RDF.Triple.new(statement) do
      {%RDF.IRI{} = subject, %RDF.IRI{} = predicate, object} = triple ->
        if RDF.Triple.valid?(triple) and not RDF.Triple.has_bnode?(triple),
          do: {:ok, {reasoner_term(subject), reasoner_term(predicate), reasoner_term(object)}},
          else: invalid(:reasoning_input)

      _invalid ->
        invalid(:reasoning_input)
    end
  rescue
    _error -> invalid(:reasoning_input)
  end

  defp reasoner_term(%RDF.IRI{value: value}), do: {:iri, value}

  defp reasoner_term(%RDF.Literal{} = literal) do
    lexical = RDF.Literal.lexical(literal)

    case RDF.Literal.language(literal) do
      nil -> {:literal, :typed, lexical, literal |> RDF.Literal.datatype_id() |> to_string()}
      language -> {:literal, :lang, lexical, language}
    end
  end

  defp run(rules, input, bounds) do
    task =
      Task.async(fn ->
        SemiNaive.materialize_in_memory(rules, input,
          max_iterations: bounds.max_iterations,
          max_facts: bounds.max_input_facts + bounds.max_derived_facts,
          emit_telemetry: true,
          parallel: true
        )
      end)

    case Task.yield(task, bounds.timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, all_facts, stats}} -> {:ok, all_facts, stats}
      {:ok, {:error, _reason}} -> invalid(:reasoning_materialization)
      nil -> {:error, Error.new(:timeout, :reasoning_materialization)}
    end
  end

  defp derived_statements(facts) do
    decoded = Enum.map(facts, &statement/1)

    if Enum.all?(decoded, &match?({:ok, _}, &1)) do
      statements =
        decoded
        |> Enum.map(&elem(&1, 1))
        |> Enum.uniq()
        |> Enum.sort_by(&canonical/1)

      {:ok, statements}
    else
      invalid(:reasoning_output)
    end
  end

  defp statement({{:iri, subject}, {:iri, predicate}, {:iri, object}}),
    do: {:ok, {subject, predicate, RDF.iri(object)}}

  defp statement({{:iri, subject}, {:iri, predicate}, {:literal, :typed, lexical, datatype}}),
    do: {:ok, {subject, predicate, RDF.literal(lexical, datatype: datatype)}}

  defp statement({{:iri, subject}, {:iri, predicate}, {:literal, :lang, lexical, language}}),
    do: {:ok, {subject, predicate, RDF.literal(lexical, language: language)}}

  defp statement(_fact), do: invalid(:reasoning_output)

  defp no_authority_effects(statements) do
    forbidden? =
      Enum.any?(statements, fn {subject, predicate, object} ->
        predicate = to_string(predicate)
        object = if match?(%RDF.IRI{}, object), do: to_string(object), else: nil

        MapSet.member?(@forbidden_predicates, predicate) or
          (predicate == @rdf_type and MapSet.member?(@forbidden_types, object)) or
          String.starts_with?(to_string(subject), ResourceIdentity.base() <> "command/")
      end)

    if forbidden?, do: invalid(:reasoning_authority), else: :ok
  end

  defp identities(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:command_iri]),
         {:ok, :derived} <- GraphRegistry.identify(attributes[:target_graph_iri]),
         {:ok, activity} <-
           ResourceIdentity.deterministic(
             :reasoning_activity,
             attributes.command_iri <> "\n" <> attributes.target_graph_iri
           ),
         {:ok, report} <- ResourceIdentity.deterministic(:reasoning_validation_report, activity) do
      {:ok, activity, report}
    end
  end

  defp annotations(activity, report, attributes, bounds, stats, input_count, statements) do
    [
      {activity, @rdf_type, RDF.iri(@jf <> "ReasoningActivity")},
      {activity, @jf <> "targetGraph", RDF.iri(attributes.target_graph_iri)},
      {activity, @jf <> "ruleSet", RDF.iri(attributes.rule_set_iri)},
      {activity, @jf <> "reasoningProfile",
       RDF.iri(@concept <> Macro.camelize(to_string(attributes.profile)))},
      {activity, @jf <> "ruleRevision", RDF.XSD.NonNegativeInteger.new(attributes.rule_revision)},
      {activity, @jf <> "derivationQueryVersion", RDF.XSD.String.new(attributes.query_version)},
      {activity, @jf <> "inputCount", RDF.XSD.NonNegativeInteger.new(input_count)},
      {activity, @jf <> "derivedCount", RDF.XSD.NonNegativeInteger.new(length(statements))},
      {activity, @jf <> "iterationCount", RDF.XSD.NonNegativeInteger.new(stats.iterations)},
      {activity, @jf <> "durationMilliseconds",
       RDF.XSD.NonNegativeInteger.new(stats.duration_ms)},
      {activity, @jf <> "maxFactCount",
       RDF.XSD.NonNegativeInteger.new(bounds.max_input_facts + bounds.max_derived_facts)},
      {activity, @jf <> "maxIterations", RDF.XSD.NonNegativeInteger.new(bounds.max_iterations)},
      {activity, @jf <> "maxDurationMilliseconds",
       RDF.XSD.NonNegativeInteger.new(bounds.timeout_ms)},
      {activity, @jf <> "maxByteCount", RDF.XSD.NonNegativeInteger.new(bounds.max_bytes)},
      {activity, @jf <> "validationReport", RDF.iri(report)},
      {activity, @jf <> "authorityEffects", RDF.XSD.Boolean.new(false)},
      {activity, @prov <> "wasAssociatedWith", RDF.iri(attributes.authority.actor_iri)},
      {report, @rdf_type, RDF.iri(@jf <> "ReasoningValidationReport")},
      {report, @jf <> "completenessState", RDF.iri(@concept <> "Complete")},
      {report, @jf <> "issueCount", RDF.XSD.NonNegativeInteger.new(0)},
      {report, @jf <> "validatedResource", RDF.iri(attributes.target_graph_iri)}
    ]
  end

  defp normalize_stats(stats) do
    %{
      iterations: stats.iterations,
      total_derived: stats.total_derived,
      duration_ms: stats.duration_ms,
      rules_applied: stats.rules_applied
    }
  end

  defp classifications(statements, graph, activity, rule_revision, source_revisions) do
    statements
    |> Enum.flat_map(fn
      {subject, @rdf_type, %RDF.IRI{value: class}} ->
        [
          %{
            subject_iri: to_string(subject),
            class_iri: class,
            graph_iri: graph,
            activity_iri: activity,
            rule_revision: rule_revision,
            source_graph_revisions: source_revisions,
            state: :current,
            authority?: false
          }
        ]

      _statement ->
        []
    end)
    |> Enum.sort_by(&{&1.subject_iri, &1.class_iri})
  end

  defp canonical(statement) do
    statement
    |> RDF.Triple.new()
    |> List.wrap()
    |> RDF.Graph.new()
    |> RDF.NTriples.write_string!(sort: true)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

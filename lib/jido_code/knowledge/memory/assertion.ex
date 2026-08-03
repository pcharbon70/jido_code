defmodule JidoCode.Knowledge.Memory.Assertion do
  @moduledoc "An accepted, provenance-complete proposition prepared for a repository memory graph."

  alias JidoCode.Knowledge.Decision.GoalOutcome
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.StateTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :activity_iri,
    :repository_iri,
    :repository_scope_iri,
    :memory_graph_iri,
    :scope_kind,
    :scope_iri,
    :classification,
    :subject_iri,
    :predicate_iri,
    :object,
    :source_claim_iris,
    :source_evidence_iris,
    :source_decision_iri,
    :source_snapshot_iris,
    :source_actor_iris,
    :source_graph_revisions,
    :policy_iri,
    :policy_version,
    :adoption_actor_iri,
    :confidence,
    :limitations,
    :related_resource_iris,
    :supporting_assertion_iris,
    :cohort_evidence_iris,
    :supersedes_iris,
    :valid_from,
    :valid_to,
    :recorded_at,
    :transition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @classifications ~w[
    fact convention decision lesson pattern known_issue risk workaround preference open_question
  ]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @rdf_predicate "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"
  @rdf_object "http://www.w3.org/1999/02/22-rdf-syntax-ns#object"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @secret ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i
  @raw_predicate ~r/(?:prompt|transcript|toolOutput|rawOutcome|privateReasoning)$/i

  @spec new(GoalOutcome.t(), [map()], map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%GoalOutcome{} = decision, dispositions, attributes)
      when is_list(dispositions) and is_map(attributes) do
    recorded_at = attributes[:recorded_at]

    with true <- decision.disposition == :accept and decision.assessment.status == :sufficient,
         true <- attributes[:source_kind] == :accepted_decision,
         true <- valid_at?(decision.valid_from, decision.valid_to, recorded_at),
         {:ok, claims} <- accepted_claims(dispositions),
         {:ok, proposition} <- one_proposition(claims),
         true <- source_evidence_valid?(decision, recorded_at),
         true <- safe_proposition?(proposition),
         {:ok, :memory} <- GraphRegistry.identify(attributes[:memory_graph_iri]),
         :ok <- ResourceIdentity.validate(attributes[:repository_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         true <- attributes[:policy_iri] == decision.policy_iri,
         true <- attributes[:policy_version] == decision.assessment.policy_version,
         classification when classification in @classifications <- attributes[:classification],
         confidence when is_integer(confidence) and confidence in 0..100 <-
           attributes[:confidence],
         {:ok, limitations} <- safe_texts(attributes[:limitations], 30),
         {:ok, related} <- resources(attributes[:related_resource_iris], 50, true),
         {:ok, supporting} <- resources(attributes[:supporting_assertion_iris], 30, true),
         {:ok, supersedes} <- resources(attributes[:supersedes_iris], 30, true),
         {:ok, scope_kind, scope_iri, cohort_evidence, scope_revisions} <-
           scope(decision, attributes),
         {:ok, valid_from, valid_to} <- validity(decision, claims, attributes),
         {:ok, iri} <- identity(decision, claims, attributes, proposition),
         {:ok, activity_iri} <-
           ResourceIdentity.deterministic(
             :adoption_activity,
             iri <> "\n" <> attributes.actor_iri
           ),
         {:ok, transition} <-
           StateTransition.new(%{
             subject_iri: iri,
             prior_state: nil,
             next_state: :still_valid,
             revision: 0,
             expected_predecessor: nil,
             actor_iri: attributes.actor_iri,
             cause_iri: decision.iri,
             reason: "adopt accepted knowledge assertion",
             recorded_at: recorded_at
           }) do
      {:ok,
       %__MODULE__{
         iri: iri,
         activity_iri: activity_iri,
         repository_iri: attributes.repository_iri,
         repository_scope_iri: decision.scope_iri,
         memory_graph_iri: attributes.memory_graph_iri,
         scope_kind: scope_kind,
         scope_iri: scope_iri,
         classification: classification,
         subject_iri: proposition.subject_iri,
         predicate_iri: proposition.predicate_iri,
         object: proposition.object,
         source_claim_iris: Enum.map(claims, & &1.iri),
         source_evidence_iris: Enum.map(decision.evidence_bundles, & &1.iri),
         source_decision_iri: decision.iri,
         source_snapshot_iris: source_snapshots(decision),
         source_actor_iris: source_actors(decision),
         source_graph_revisions:
           decision |> adoption_source_revisions() |> Map.merge(scope_revisions),
         policy_iri: decision.policy_iri,
         policy_version: decision.assessment.policy_version,
         adoption_actor_iri: attributes.actor_iri,
         confidence: confidence,
         limitations: limitations,
         related_resource_iris: related,
         supporting_assertion_iris: supporting,
         cohort_evidence_iris: cohort_evidence,
         supersedes_iris: supersedes,
         valid_from: valid_from,
         valid_to: valid_to,
         recorded_at: recorded_at,
         transition: transition
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:knowledge_assertion)
    end
  rescue
    _error -> invalid(:knowledge_assertion)
  end

  def new(_decision, _dispositions, _attributes), do: invalid(:knowledge_assertion)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(assertion) do
    [
      {assertion.iri, @rdf_type, RDF.iri(@jf <> "KnowledgeAssertion")},
      {assertion.iri, @rdf_subject, RDF.iri(assertion.subject_iri)},
      {assertion.iri, @rdf_predicate, RDF.iri(assertion.predicate_iri)},
      {assertion.iri, @rdf_object, assertion.object},
      {assertion.iri, @jf <> "sourceActivity", RDF.iri(assertion.activity_iri)},
      {assertion.iri, @jf <> "graphScope", RDF.iri(assertion.memory_graph_iri)},
      {assertion.iri, @jf <> "epistemicState", RDF.iri(StateTransition.state_iri(:still_valid))},
      {assertion.iri, @jf <> "knowledgeClassification",
       RDF.iri(classification_iri(assertion.classification))},
      {assertion.iri, @jf <> "about", RDF.iri(assertion.repository_iri)},
      {assertion.iri, @jf <> "validFor", RDF.iri(assertion.scope_iri)},
      {assertion.iri, @jf <> "confidenceScore",
       RDF.XSD.NonNegativeInteger.new(assertion.confidence)},
      {assertion.iri, @jf <> "governedBy", RDF.iri(assertion.policy_iri)},
      {assertion.iri, @jf <> "version", RDF.XSD.String.new(assertion.policy_version)},
      {assertion.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(assertion.valid_from)},
      {assertion.iri, @jf <> "validTo", RDF.XSD.DateTime.new(assertion.valid_to)},
      {assertion.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(assertion.recorded_at)},
      {assertion.iri, @prov <> "wasDerivedFrom", RDF.iri(assertion.source_decision_iri)},
      {assertion.activity_iri, @rdf_type, RDF.iri(@jf <> "AdoptionActivity")},
      {assertion.activity_iri, @prov <> "wasAssociatedWith",
       RDF.iri(assertion.adoption_actor_iri)},
      {assertion.activity_iri, @prov <> "used", RDF.iri(assertion.source_decision_iri)},
      {assertion.activity_iri, @prov <> "generated", RDF.iri(assertion.iri)},
      {assertion.activity_iri, @jf <> "governedBy", RDF.iri(assertion.policy_iri)},
      {assertion.activity_iri, @prov <> "generatedAtTime",
       RDF.XSD.DateTime.new(assertion.recorded_at)},
      {assertion.activity_iri, @jf <> "accepts", RDF.iri(assertion.transition.iri)}
    ] ++
      StateTransition.statements(assertion.transition) ++
      iri_statements(assertion.iri, @jf <> "sourceClaim", assertion.source_claim_iris) ++
      iri_statements(assertion.iri, @jf <> "evidenceSource", assertion.source_evidence_iris) ++
      iri_statements(assertion.iri, @jf <> "sourceSnapshot", assertion.source_snapshot_iris) ++
      iri_statements(assertion.iri, @prov <> "wasAttributedTo", assertion.source_actor_iris) ++
      iri_statements(assertion.iri, @jf <> "addresses", assertion.related_resource_iris) ++
      iri_statements(assertion.iri, @jf <> "supports", assertion.supporting_assertion_iris) ++
      iri_statements(
        assertion.iri,
        @jf <> "applicabilityEvidence",
        assertion.cohort_evidence_iris
      ) ++
      iri_statements(assertion.iri, @jf <> "supersedes", assertion.supersedes_iris) ++
      literal_statements(assertion.iri, @jf <> "limitation", assertion.limitations) ++
      source_revision_statements(assertion)
  end

  @spec classification_iri(atom()) :: String.t()
  def classification_iri(classification),
    do: @concept <> "Knowledge" <> Macro.camelize(to_string(classification))

  @spec classifications() :: [atom()]
  def classifications, do: @classifications

  defp accepted_claims(dispositions) when dispositions != [] and length(dispositions) <= 20 do
    if Enum.all?(dispositions, fn
         %{state: :accepted, iri: iri, prior: %{}} -> ResourceIdentity.validate(iri) == :ok
         _other -> false
       end) do
      {:ok, dispositions}
    else
      :error
    end
  end

  defp accepted_claims(_dispositions), do: :error

  defp one_proposition([first | rest]) do
    proposition = %{
      subject_iri: first.prior.subject_iri,
      predicate_iri: first.prior.predicate_iri,
      object: first.prior.object
    }

    if Enum.all?(rest, fn disposition ->
         claim = disposition.prior

         claim.subject_iri == proposition.subject_iri and
           claim.predicate_iri == proposition.predicate_iri and
           RDF.Term.equal_value?(claim.object, proposition.object)
       end),
       do: {:ok, proposition},
       else: :error
  end

  defp source_evidence_valid?(decision, recorded_at) do
    decision.evidence_bundles != [] and
      Enum.all?(decision.evidence_bundles, fn bundle ->
        valid_at?(bundle.valid_from, bundle.valid_to, recorded_at) and
          bundle.classification != :contradictory and bundle.activity.raw_outcome_refs == []
      end)
  end

  defp safe_proposition?(proposition) do
    not Regex.match?(@raw_predicate, proposition.predicate_iri) and
      case proposition.object do
        %RDF.Literal{} = literal ->
          lexical = RDF.Literal.lexical(literal)
          byte_size(lexical) <= 2_048 and not Regex.match?(@secret, lexical)

        %RDF.IRI{value: value} ->
          byte_size(value) <= 512 and not Regex.match?(@secret, value)

        _other ->
          false
      end
  end

  defp scope(decision, %{scope_kind: :repository} = attributes) do
    if attributes[:scope_iri] == decision.scope_iri,
      do: {:ok, :repository, attributes.scope_iri, [], %{}},
      else: :error
  end

  defp scope(_decision, %{scope_kind: :cohort} = attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:scope_iri]),
         {:ok, :derived} <- GraphRegistry.identify(attributes[:cohort_graph_iri]),
         revision when is_integer(revision) and revision > 0 <-
           attributes[:cohort_graph_revision],
         {:ok, evidence} <- resources(attributes[:cohort_evidence_iris], 20, false) do
      {:ok, :cohort, attributes.scope_iri, evidence, %{attributes.cohort_graph_iri => revision}}
    end
  end

  defp scope(_decision, _attributes), do: :error

  defp validity(decision, claims, attributes) do
    valid_from = attributes[:valid_from]
    valid_to = attributes[:valid_to]
    sources = [decision | Enum.map(claims, & &1.prior) ++ decision.evidence_bundles]

    latest_from =
      sources
      |> Enum.map(& &1.valid_from)
      |> Enum.reduce(fn value, current ->
        if DateTime.compare(value, current) == :gt, do: value, else: current
      end)

    earliest_to =
      sources
      |> Enum.map(& &1.valid_to)
      |> Enum.reduce(fn value, current ->
        if DateTime.compare(value, current) == :lt, do: value, else: current
      end)

    if is_struct(valid_from, DateTime) and is_struct(valid_to, DateTime) and
         DateTime.compare(valid_from, latest_from) in [:eq, :gt] and
         DateTime.compare(valid_to, earliest_to) in [:eq, :lt] and
         DateTime.compare(valid_from, valid_to) == :lt,
       do: {:ok, valid_from, valid_to},
       else: :error
  end

  defp identity(decision, claims, attributes, proposition) do
    statement =
      {RDF.iri(proposition.subject_iri), RDF.iri(proposition.predicate_iri), proposition.object}
      |> RDF.Triple.new()
      |> List.wrap()
      |> RDF.Graph.new()
      |> RDF.NTriples.write_string!(sort: true)

    material =
      {
        statement,
        Enum.map(claims, & &1.iri) |> Enum.sort(),
        decision.iri,
        attributes[:repository_iri],
        attributes[:scope_kind],
        attributes[:scope_iri],
        attributes[:classification],
        attributes[:actor_iri],
        attributes[:policy_iri],
        attributes[:policy_version],
        attributes[:confidence],
        attributes[:limitations] |> Enum.sort(),
        Map.get(attributes, :related_resource_iris, []) |> Enum.sort(),
        Map.get(attributes, :supporting_assertion_iris, []) |> Enum.sort(),
        Map.get(attributes, :cohort_evidence_iris, []) |> Enum.sort(),
        attributes[:cohort_graph_iri],
        attributes[:cohort_graph_revision],
        attributes[:valid_from],
        attributes[:valid_to],
        Map.get(attributes, :supersedes_iris, []) |> Enum.sort()
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:knowledge_assertion, material)
  end

  defp source_snapshots(decision) do
    decision.evidence_bundles
    |> Enum.flat_map(fn bundle ->
      activity = bundle.activity

      [
        activity.source_snapshot_iri,
        activity.proposed_snapshot_iri,
        activity.post_change_snapshot_iri
      ]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp source_actors(decision) do
    ([decision.actor_iri] ++
       Enum.flat_map(decision.evidence_bundles, fn bundle ->
         [bundle.activity.evaluator_iri, bundle.activity.execution_actor_iri]
       end))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp adoption_source_revisions(decision) do
    control_graphs =
      decision.evidence_bundles
      |> Enum.map(& &1.activity.control_graph_iri)
      |> MapSet.new()

    Map.reject(decision.assessment.source_graph_revisions, fn {graph, _revision} ->
      MapSet.member?(control_graphs, graph)
    end)
  end

  defp source_revision_statements(assertion) do
    Enum.flat_map(assertion.source_graph_revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          Enum.join([assertion.iri, graph, Integer.to_string(revision)], "\n")
        )

      [
        {assertion.iri, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp resources(values, maximum, allow_empty?)
       when is_list(values) and length(values) <= maximum do
    values = values |> Enum.uniq() |> Enum.sort()

    if (allow_empty? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, values},
       else: :error
  end

  defp resources(_values, _maximum, _allow_empty?), do: :error

  defp safe_texts(values, maximum) when is_list(values) and length(values) <= maximum do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, fn value ->
         is_binary(value) and byte_size(value) in 1..500 and not Regex.match?(@secret, value)
       end),
       do: {:ok, values},
       else: :error
  end

  defp safe_texts(_values, _maximum), do: :error

  defp valid_at?(%DateTime{} = from, %DateTime{} = to, %DateTime{} = at),
    do: DateTime.compare(from, at) in [:lt, :eq] and DateTime.compare(at, to) == :lt

  defp valid_at?(_from, _to, _at), do: false

  defp iri_statements(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp literal_statements(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.XSD.String.new(&1)})

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

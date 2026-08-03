defmodule JidoCode.Knowledge.Evidence.Bundle do
  @moduledoc "Atomic evidence bundle and generated proposed-claim command boundary."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Evidence.Claim
  alias JidoCode.Knowledge.Evidence.Graph, as: EvidenceGraph
  alias JidoCode.Knowledge.Evidence.VerificationActivity
  alias JidoCode.Knowledge.Evidence.VerificationMethod
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :activity,
    :claims,
    :supports,
    :contradicts,
    :strength,
    :classification,
    :coverage,
    :limitations,
    :valid_from,
    :valid_to,
    :supersedes
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @strengths ~w[weak moderate strong conclusive]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @prov "http://www.w3.org/ns/prov#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(VerificationActivity.t(), String.t(), map()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(%VerificationActivity{} = activity, evidence_graph_iri, attributes)
      when is_map(attributes) do
    with {:ok, :evidence} <- GraphRegistry.identify(evidence_graph_iri),
         {:ok, supports} <- resources(attributes[:supports], 100, true),
         {:ok, contradicts} <- resources(attributes[:contradicts], 100, true),
         true <- supports != [] or contradicts != [],
         true <- MapSet.disjoint?(MapSet.new(supports), MapSet.new(contradicts)),
         true <- scoped_targets?(activity.method, supports, contradicts),
         true <- no_hidden_failure?(activity, supports),
         strength when strength in @strengths <- attributes[:strength],
         true <- strength_allowed?(strength, activity, contradicts),
         {:ok, claims} <- claims(activity, evidence_graph_iri, attributes[:generated_claims]),
         {:ok, limitations} <- texts(attributes[:limitations], 30, 512),
         {:ok, valid_from, valid_to} <- interval(attributes[:valid_from], attributes[:valid_to]),
         {:ok, supersedes} <- resources(Map.get(attributes, :supersedes, []), 30, true),
         classification = classification(supports, contradicts),
         coverage = coverage(activity.checks),
         {:ok, iri} <- identity(activity, claims, supports, contradicts, attributes, coverage) do
      {:ok,
       %__MODULE__{
         iri: iri,
         activity: activity,
         claims: claims,
         supports: supports,
         contradicts: contradicts,
         strength: strength,
         classification: classification,
         coverage: coverage,
         limitations: Enum.sort(Enum.uniq(activity.method.interpretation_limits ++ limitations)),
         valid_from: valid_from,
         valid_to: valid_to,
         supersedes: supersedes
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:evidence_bundle)
    end
  rescue
    _error -> invalid(:evidence_bundle)
  end

  def new(_activity, _graph, _attributes), do: invalid(:evidence_bundle)

  @spec record_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(bundle, attributes, options \\ [])

  def record_command(%__MODULE__{} = bundle, attributes, options)
      when is_map(attributes) and is_list(options) do
    activity = bundle.activity
    evidence_graph = attributes[:evidence_graph_iri]

    with {:ok, :evidence} <- GraphRegistry.identify(evidence_graph),
         true <- evidence_graph == hd(bundle.claims).graph_scope_iri,
         expected when is_map(expected) <- attributes[:expected_graph_revisions],
         evidence_revision when is_integer(evidence_revision) and evidence_revision >= 0 <-
           expected[evidence_graph],
         true <- exact_revisions?(activity, expected, evidence_graph),
         recorded_at when is_struct(recorded_at, DateTime) <- attributes[:recorded_at],
         {:ok, target} <-
           EvidenceGraph.target(
             evidence_graph,
             evidence_revision,
             attributes[:repository_scope_iri],
             bundle.iri,
             recorded_at,
             statements(bundle, recorded_at)
           ),
         guards = guards(bundle, evidence_graph),
         {:ok, command} <-
           CommandEnvelope.new(envelope(bundle, attributes, target, guards), options) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_verification_evidence)
    end
  rescue
    _error -> invalid(:record_verification_evidence)
  end

  def record_command(_bundle, _attributes, _options),
    do: invalid(:record_verification_evidence)

  @spec statements(t(), DateTime.t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = bundle, %DateTime{} = recorded_at) do
    [
      {bundle.iri, @rdf_type, RDF.iri(@jf <> "EvidenceBundle")},
      {bundle.iri, @jf <> "verificationActivity", RDF.iri(bundle.activity.iri)},
      {bundle.iri, @jf <> "evidenceStrength",
       RDF.iri(@concept <> Macro.camelize(to_string(bundle.strength)))},
      {bundle.iri, @jf <> "evidenceClassification",
       RDF.iri(@concept <> Macro.camelize(to_string(bundle.classification)))},
      {bundle.iri, @jf <> "coverageTotal", RDF.XSD.NonNegativeInteger.new(bundle.coverage.total)},
      {bundle.iri, @jf <> "coveragePassed",
       RDF.XSD.NonNegativeInteger.new(bundle.coverage.passed)},
      {bundle.iri, @jf <> "coverageFailed",
       RDF.XSD.NonNegativeInteger.new(bundle.coverage.failed)},
      {bundle.iri, @jf <> "coverageSkipped",
       RDF.XSD.NonNegativeInteger.new(bundle.coverage.skipped)},
      {bundle.iri, @jf <> "coverageUnknown",
       RDF.XSD.NonNegativeInteger.new(bundle.coverage.unknown)},
      {bundle.iri, @jf <> "completenessState",
       RDF.iri(@concept <> Macro.camelize(to_string(bundle.activity.completeness)))},
      {bundle.iri, @jf <> "validFrom", RDF.XSD.DateTime.new(bundle.valid_from)},
      {bundle.iri, @jf <> "validTo", RDF.XSD.DateTime.new(bundle.valid_to)},
      {bundle.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(recorded_at)},
      {bundle.iri, @prov <> "wasGeneratedBy", RDF.iri(bundle.activity.iri)},
      {bundle.activity.iri, @prov <> "generated", RDF.iri(bundle.iri)}
    ] ++
      VerificationMethod.statements(bundle.activity.method) ++
      VerificationActivity.statements(bundle.activity) ++
      Enum.flat_map(bundle.claims, &Claim.statements/1) ++
      Enum.map(bundle.claims, fn claim ->
        {bundle.iri, @jf <> "generatedClaim", RDF.iri(claim.iri)}
      end) ++
      Enum.map(bundle.supports, &{bundle.iri, @jf <> "supports", RDF.iri(&1)}) ++
      Enum.map(bundle.contradicts, &{bundle.iri, @jf <> "contradicts", RDF.iri(&1)}) ++
      Enum.map(bundle.limitations, fn limitation ->
        {bundle.iri, @jf <> "limitation", RDF.XSD.String.new(limitation)}
      end) ++
      Enum.map(bundle.supersedes, &{bundle.iri, @jf <> "supersedes", RDF.iri(&1)}) ++
      revision_statements(bundle)
  end

  defp claims(activity, evidence_graph, values) when is_list(values) and values != [] do
    decoded = Enum.map(values, &Claim.new(activity.iri, evidence_graph, &1))

    if length(values) <= 100 and Enum.all?(decoded, &match?({:ok, _}, &1)) do
      claims = decoded |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.iri)

      if claims |> Enum.map(& &1.iri) |> Enum.uniq() |> length() == length(claims),
        do: {:ok, claims},
        else: :error
    else
      :error
    end
  end

  defp claims(_activity, _evidence_graph, _values), do: :error

  defp scoped_targets?(method, supports, contradicts),
    do: Enum.all?(supports ++ contradicts, &(&1 in method.expected_claim_iris))

  defp no_hidden_failure?(activity, supports) do
    supports == [] or
      Enum.all?(activity.checks, fn check -> not check.mandatory? or check.status == :passed end)
  end

  defp strength_allowed?(:conclusive, activity, contradicts),
    do:
      activity.completeness == :complete and contradicts == [] and
        no_hidden_failure?(activity, [:support])

  defp strength_allowed?(_strength, _activity, _contradicts), do: true

  defp coverage(checks) do
    counts = Enum.frequencies_by(checks, & &1.status)

    %{
      total: length(checks),
      passed: Map.get(counts, :passed, 0),
      failed: Map.get(counts, :failed, 0),
      skipped: Map.get(counts, :skipped, 0),
      unknown: Map.get(counts, :unknown, 0)
    }
  end

  defp classification([_ | _], [_ | _]), do: :mixed
  defp classification([], [_ | _]), do: :contradictory
  defp classification([_ | _], []), do: :supporting

  defp identity(activity, claims, supports, contradicts, attributes, coverage) do
    material =
      {
        activity.iri,
        Enum.map(claims, & &1.iri),
        supports,
        contradicts,
        attributes[:strength],
        coverage,
        attributes[:valid_from],
        attributes[:valid_to],
        Map.get(attributes, :supersedes, [])
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:evidence_bundle, material)
  end

  defp revision_statements(bundle) do
    Enum.flat_map(bundle.activity.source_graph_revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          bundle.iri <> "\n" <> graph <> "\n" <> Integer.to_string(revision)
        )

      [
        {bundle.iri, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp exact_revisions?(activity, expected, evidence_graph) do
    expected == Map.put(activity.source_graph_revisions, evidence_graph, expected[evidence_graph])
  end

  defp guards(bundle, evidence_graph) do
    activity = bundle.activity

    [
      {:subject_absent, evidence_graph, bundle.iri},
      {:subject_present, activity.run_graph_iri, activity.attempt_iri},
      {:subject_present, activity.control_graph_iri, activity.task_iri},
      {:subject_present, activity.control_graph_iri, activity.goal_iri},
      {:triple_present, activity.source_graph_iri, activity.source_graph_iri,
       @jf <> "sourceSnapshot", RDF.iri(activity.source_snapshot_iri)}
    ] ++
      Enum.flat_map(activity.artifacts, fn artifact ->
        [
          {:subject_present, activity.run_graph_iri, artifact.iri},
          {:triple_present, activity.run_graph_iri, artifact.iri, @jf <> "contentDigest",
           RDF.XSD.String.new(artifact.digest)},
          {:triple_present, activity.run_graph_iri, artifact.iri, @jf <> "sourceSnapshot",
           RDF.iri(artifact.source_snapshot_iri)}
        ]
      end)
  end

  defp envelope(bundle, attributes, target, guards) do
    command = command_iri(bundle)

    %{
      command_type: "RecordVerificationEvidence",
      command_version: "1.7.0",
      command_iri: command,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: command,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: attributes[:expected_graph_revisions],
      reason: attributes[:reason],
      issued_at: nil,
      payload: %{
        changes: [target],
        guards: guards,
        evidence_bundle_iri: bundle.iri,
        verification_activity_iri: bundle.activity.iri,
        generated_claim_iris: Enum.map(bundle.claims, & &1.iri)
      }
    }
    |> Map.delete(:issued_at)
  end

  defp command_iri(bundle) do
    {:ok, iri} =
      ResourceIdentity.deterministic(:command_request, bundle.iri <> "\nrecord-evidence")

    iri
  end

  defp interval(%DateTime{} = valid_from, %DateTime{} = valid_to) do
    if DateTime.compare(valid_from, valid_to) == :lt,
      do: {:ok, valid_from, valid_to},
      else: :error
  end

  defp interval(_valid_from, _valid_to), do: :error

  defp resources(values, maximum, allow_empty?)
       when is_list(values) and length(values) <= maximum do
    values = Enum.uniq(values)

    if (allow_empty? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp resources(_values, _maximum, _allow_empty?), do: :error

  defp texts(values, maximum, bytes) when is_list(values) and length(values) <= maximum do
    if Enum.all?(values, fn value ->
         is_binary(value) and byte_size(value) in 1..bytes and
           not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
       end),
       do: {:ok, values |> Enum.uniq() |> Enum.sort()},
       else: :error
  end

  defp texts(_values, _maximum, _bytes), do: :error
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

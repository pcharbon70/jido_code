defmodule JidoCode.Knowledge.Memory.MemoryUseAssessment do
  @moduledoc "Independent delayed assessment of one exact memory packet's influence."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ExperienceGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :case_iri,
    :retrieval_packet_iri,
    :retrieval_packet_digest,
    :attempt_iri,
    :attempt_outcome_iri,
    :attempt_actor_iri,
    :evaluator_iri,
    :policy_iri,
    :policy_version,
    :source_graph_revisions,
    :withheld_control,
    :independent_evidence_iris,
    :outcome,
    :signals,
    :limitations,
    :recorded_at,
    :self_report_evidence?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @outcomes ~w[useful neutral misleading stale unauthorized causally_indeterminate]a
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @prov "http://www.w3.org/ns/prov#"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec outcomes() :: [atom()]
  def outcomes, do: @outcomes

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[
      case_iri retrieval_packet_iri attempt_iri attempt_outcome_iri attempt_actor_iri evaluator_iri
      policy_iri
    ]a

    with true <- Enum.all?(resources, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
         true <- attributes.evaluator_iri != attributes.attempt_actor_iri,
         true <- digest?(attributes[:retrieval_packet_digest]),
         true <- safe_revision?(attributes[:policy_version]),
         {:ok, revisions} <- revisions(attributes[:source_graph_revisions]),
         {:ok, control} <- control(attributes[:withheld_control]),
         {:ok, evidence} <- iris(attributes[:independent_evidence_iris], 50, false),
         true <- attributes[:basis] == :independent_evidence,
         true <- attributes[:outcome] in @outcomes,
         {:ok, signals} <- signals(attributes[:signals]),
         {:ok, limitations} <- texts(attributes[:limitations], 30),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         digest <-
           digest_term({
             @revision,
             Map.take(
               attributes,
               resources ++ [:retrieval_packet_digest, :policy_version, :outcome]
             ),
             revisions,
             control,
             evidence,
             signals,
             limitations,
             DateTime.to_iso8601(recorded_at)
           }),
         {:ok, iri} <- ResourceIdentity.deterministic(:memory_use_assessment, digest) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         case_iri: attributes.case_iri,
         retrieval_packet_iri: attributes.retrieval_packet_iri,
         retrieval_packet_digest: attributes.retrieval_packet_digest,
         attempt_iri: attributes.attempt_iri,
         attempt_outcome_iri: attributes.attempt_outcome_iri,
         attempt_actor_iri: attributes.attempt_actor_iri,
         evaluator_iri: attributes.evaluator_iri,
         policy_iri: attributes.policy_iri,
         policy_version: attributes.policy_version,
         source_graph_revisions: revisions,
         withheld_control: control,
         independent_evidence_iris: evidence,
         outcome: attributes.outcome,
         signals: signals,
         limitations: limitations,
         recorded_at: DateTime.truncate(recorded_at, :microsecond),
         self_report_evidence?: false
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:memory_use_assessment)
    end
  rescue
    _error -> invalid(:memory_use_assessment)
  end

  def new(_attributes), do: invalid(:memory_use_assessment)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = assessment) do
    [
      {assessment.iri, @rdf_type, RDF.iri(@jf <> "MemoryUseAssessment")},
      {assessment.iri, @jf <> "about", RDF.iri(assessment.case_iri)},
      {assessment.iri, @jf <> "retrievalPacket", RDF.iri(assessment.retrieval_packet_iri)},
      {assessment.iri, @jf <> "retrievalPacketDigest",
       RDF.XSD.String.new(assessment.retrieval_packet_digest)},
      {assessment.iri, @jf <> "evaluatedAttempt", RDF.iri(assessment.attempt_iri)},
      {assessment.iri, @jf <> "attemptOutcome", RDF.iri(assessment.attempt_outcome_iri)},
      {assessment.iri, @prov <> "wasAssociatedWith", RDF.iri(assessment.evaluator_iri)},
      {assessment.iri, @jf <> "governedBy", RDF.iri(assessment.policy_iri)},
      {assessment.iri, @jf <> "policyVersion", RDF.XSD.String.new(assessment.policy_version)},
      {assessment.iri, @jf <> "memoryUseOutcome", concept(assessment.outcome)},
      {assessment.iri, @jf <> "withheldControlAttempt",
       RDF.iri(assessment.withheld_control.attempt_iri)},
      {assessment.iri, @jf <> "withheldControlPacketDigest",
       RDF.XSD.String.new(assessment.withheld_control.packet_digest)},
      {assessment.iri, @jf <> "withheldControlOutcome",
       RDF.iri(assessment.withheld_control.outcome_iri)},
      {assessment.iri, @jf <> "suspiciousTriggerConcentration",
       RDF.XSD.Double.new(assessment.signals.suspicious_trigger_concentration)},
      {assessment.iri, @jf <> "poisoningSuccess",
       RDF.XSD.Boolean.new(assessment.signals.poisoning_success?)},
      {assessment.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(assessment.recorded_at)}
    ] ++
      refs(assessment.iri, @jf <> "evidenceSource", assessment.independent_evidence_iris) ++
      Enum.map(assessment.limitations, fn limitation ->
        {assessment.iri, @jf <> "limitation", RDF.XSD.String.new(limitation)}
      end) ++
      revision_statements(assessment.iri, assessment.source_graph_revisions)
  end

  @spec record_command(t(), String.t(), non_neg_integer(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(assessment, graph_iri, graph_revision, attributes, options \\ [])

  def record_command(
        %__MODULE__{} = assessment,
        graph_iri,
        graph_revision,
        attributes,
        options
      )
      when is_integer(graph_revision) and graph_revision >= 0 and is_map(attributes) and
             is_list(options) do
    command_iri = command_iri(assessment)

    with true <- attributes[:expected_graph_revisions] == %{graph_iri => graph_revision},
         {:ok, target} <-
           ExperienceGraph.target(
             graph_iri,
             graph_revision,
             attributes[:repository_scope_iri],
             command_iri,
             assessment.recorded_at,
             statements(assessment)
           ) do
      CommandEnvelope.new(
        %{
          command_type: "RecordMemoryUseAssessment",
          command_version: "2.1.0",
          command_iri: command_iri,
          principal_iri: attributes[:principal_iri],
          actor_iri: assessment.evaluator_iri,
          delegated_agent_iri: nil,
          delegation_iri: nil,
          scope_iri: attributes[:repository_scope_iri],
          idempotency_key: command_iri,
          correlation_iri: attributes[:correlation_iri],
          causation_iri: assessment.attempt_outcome_iri,
          ontology_version: "1.2.0",
          shape_version: "1.2.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: attributes[:expected_graph_revisions],
          reason: attributes[:reason],
          payload: %{
            changes: [target],
            guards: [
              {:subject_present, graph_iri, assessment.case_iri},
              {:subject_absent, graph_iri, assessment.iri}
            ],
            assessment_iri: assessment.iri,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_memory_use_assessment)
    end
  end

  def record_command(_assessment, _graph, _revision, _attributes, _options),
    do: invalid(:record_memory_use_assessment)

  defp control(%{attempt_iri: attempt, packet_digest: digest, outcome_iri: outcome} = control)
       when map_size(control) == 3 do
    if ResourceIdentity.validate(attempt) == :ok and ResourceIdentity.validate(outcome) == :ok and
         digest?(digest),
       do: {:ok, control},
       else: :error
  end

  defp control(_control), do: :error

  defp signals(
         %{
           suspicious_trigger_concentration: concentration,
           poisoning_success?: poisoning?
         } = signals
       )
       when map_size(signals) == 2 and is_number(concentration) and concentration >= 0 and
              concentration <= 1 and is_boolean(poisoning?),
       do: {:ok, signals}

  defp signals(_signals), do: :error

  defp revisions(values) when is_map(values) and map_size(values) in 1..16 do
    if Enum.all?(values, fn {graph, revision} ->
         match?({:ok, _family}, GraphRegistry.identify(graph)) and is_integer(revision) and
           revision >= 0
       end),
       do: {:ok, values |> Enum.sort() |> Map.new()},
       else: :error
  end

  defp revisions(_values), do: :error

  defp iris(values, maximum, empty?) when is_list(values) and length(values) <= maximum do
    if (empty? or values != []) and Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, Enum.sort(Enum.uniq(values))},
      else: :error
  end

  defp iris(_values, _maximum, _empty?), do: :error

  defp texts(values, maximum) when is_list(values) and length(values) <= maximum do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..512)),
      do: {:ok, Enum.sort(Enum.uniq(values))},
      else: :error
  end

  defp texts(_values, _maximum), do: :error

  defp safe_revision?(value),
    do: is_binary(value) and Regex.match?(~r/^[a-z0-9][a-z0-9._-]{0,63}$/, value)

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp digest_term(value),
    do:
      value
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

  defp concept(value), do: RDF.iri(@concept <> Macro.camelize(to_string(value)))
  defp refs(subject, predicate, values), do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp revision_statements(subject, revisions) do
    Enum.flat_map(revisions, fn {graph, revision} ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          Enum.join([subject, graph, Integer.to_string(revision)], "\n")
        )

      [
        {subject, @jf <> "sourceGraphRevision", RDF.iri(reference)},
        {reference, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
        {reference, @jf <> "sourceGraph", RDF.iri(graph)},
        {reference, @jf <> "sourceRevisionNumber", RDF.XSD.NonNegativeInteger.new(revision)}
      ]
    end)
  end

  defp command_iri(assessment) do
    {:ok, iri} = ResourceIdentity.deterministic(:command_request, assessment.iri <> "\nrecord")
    iri
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

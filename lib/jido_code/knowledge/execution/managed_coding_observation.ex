defmodule JidoCode.Knowledge.Execution.ManagedCodingObservation do
  @moduledoc """
  Immutable, bounded managed coding event recorded on the shared attempt sequence.

  The resource contains semantic progress and exact correlation only. It never
  serializes strategy state, prompts, transcripts, tool output, credentials, or
  runtime handles.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :kind,
    :command_type,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :profile_iri,
    :strategy_revision,
    :phase,
    :runtime_sequence,
    :reconstruction_watermark,
    :occurred_at
  ]
  defstruct @enforce_keys ++
              [
                :budget_snapshot,
                :terminal_classification,
                :candidate_iri,
                :clarification_session_iri,
                :handoff_state
              ]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @digest ~r/^[a-f0-9]{64}$/
  @definitions %{
    runtime_observation:
      {"CodingRuntimeObservation", "RecordCodingRuntimeObservation", :coding_runtime_observation},
    budget_exhaustion:
      {"CodingBudgetSnapshot", "RecordCodingBudgetExhaustion", :coding_budget_snapshot},
    clarification: {"CodingClarification", "RecordCodingClarification", :coding_clarification},
    candidate_completion:
      {"CandidateCompletionProposal", "ProposeCandidateCompletion",
       :candidate_completion_proposal},
    candidate_handoff: {"CandidateHandoff", "RecordCandidateHandoff", :candidate_handoff}
  }
  @phases ~w[admitted preparing awaiting_model awaiting_tool awaiting_actor assembling_candidate candidate_ready cancelling completed cancelled failed]a
  @terminal ~w[success failure cancelled rejected timed_out budget_exhausted superseded incompatible_revision indeterminate]a
  @handoff ~w[not_started assembling ready handed_off rejected failed]a

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    kind = attributes[:kind]

    with {_class, command_type, _event_type} <- Map.get(@definitions, kind),
         :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- digest?(attributes[:strategy_revision]),
         phase when phase in @phases <- attributes[:phase],
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:runtime_sequence],
         true <- digest?(attributes[:reconstruction_watermark]),
         %DateTime{} = occurred_at <- attributes[:occurred_at],
         :ok <- kind_contract(kind, attributes),
         {:ok, iri} <- identity(attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         kind: kind,
         command_type: command_type,
         attempt_iri: attributes.attempt_iri,
         lease_iri: attributes.lease_iri,
         fencing_token: fence,
         profile_iri: attributes.profile_iri,
         strategy_revision: attributes.strategy_revision,
         phase: phase,
         runtime_sequence: sequence,
         reconstruction_watermark: attributes.reconstruction_watermark,
         occurred_at: DateTime.truncate(occurred_at, :microsecond),
         budget_snapshot: attributes[:budget_snapshot],
         terminal_classification: attributes[:terminal_classification],
         candidate_iri: attributes[:candidate_iri],
         clarification_session_iri: attributes[:clarification_session_iri],
         handoff_state: attributes[:handoff_state]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:managed_coding_observation)
    end
  rescue
    _error -> invalid(:managed_coding_observation)
  end

  def new(_attributes), do: invalid(:managed_coding_observation)

  @spec record_command(t(), EventSegment.t(), map(), keyword()) ::
          {:ok, %{segment: EventSegment.t(), command: struct()}} | {:error, Error.t()}
  def record_command(
        %__MODULE__{} = observation,
        %EventSegment{} = segment,
        attributes,
        options \\ []
      ) do
    {_class, _command_type, event_type} = Map.fetch!(@definitions, observation.kind)

    if observation.attempt_iri == segment.attempt_iri and
         observation.runtime_sequence == segment.sequence_end + 1 do
      EventSegment.append_command(
        segment,
        segment.head_iri,
        %{
          command_type: observation.command_type,
          event_type: event_type,
          role: :observation,
          resource_iris: [observation.iri],
          resource_statements: statements(observation),
          opens_effect_iris: [],
          closes_effect_iris: [],
          occurred_at: observation.occurred_at
        },
        attributes,
        options
      )
    else
      {:error, Error.new(:conflict, :managed_coding_observation_sequence)}
    end
  end

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = observation) do
    {class, _command, _event_type} = Map.fetch!(@definitions, observation.kind)

    [
      {observation.iri, @rdf_type, RDF.iri(@jf <> class)},
      {observation.iri, @jf <> "attempts", RDF.iri(observation.attempt_iri)},
      {observation.iri, @jf <> "validFor", RDF.iri(observation.lease_iri)},
      {observation.iri, @jf <> "fencingToken",
       RDF.XSD.NonNegativeInteger.new(observation.fencing_token)},
      {observation.iri, @jf <> "managedCodingProfile", RDF.iri(observation.profile_iri)},
      {observation.iri, @jf <> "strategyRevisionDigest",
       RDF.XSD.String.new(observation.strategy_revision)},
      {observation.iri, @jf <> "runtimePhase",
       RDF.iri(@concept <> Macro.camelize(to_string(observation.phase)))},
      {observation.iri, @jf <> "runtimeSequence",
       RDF.XSD.NonNegativeInteger.new(observation.runtime_sequence)},
      {observation.iri, @jf <> "reconstructionWatermark",
       RDF.XSD.String.new(observation.reconstruction_watermark)},
      {observation.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(observation.occurred_at)}
    ] ++
      optional_literal(
        observation.iri,
        "budgetSnapshot",
        encode_budget(observation.budget_snapshot)
      ) ++
      optional_concept(
        observation.iri,
        "terminalClassification",
        observation.terminal_classification
      ) ++
      optional_iri(observation.iri, "candidate", observation.candidate_iri) ++
      optional_iri(
        observation.iri,
        "clarificationSession",
        observation.clarification_session_iri
      ) ++ optional_concept(observation.iri, "handoffState", observation.handoff_state)
  end

  defp resources(attributes) do
    Enum.reduce_while(~w[attempt_iri lease_iri profile_iri]a, :ok, fn field, :ok ->
      case ResourceIdentity.validate(attributes[field]) do
        :ok -> {:cont, :ok}
        _error -> {:halt, :error}
      end
    end)
  end

  defp kind_contract(:runtime_observation, attributes) do
    empty_optional?(attributes)
  end

  defp kind_contract(:budget_exhaustion, attributes) do
    budget = attributes[:budget_snapshot]

    if is_map(budget) and map_size(budget) in 1..32 and bounded?(budget, 8_192) and
         attributes[:terminal_classification] == :budget_exhausted and
         is_nil(attributes[:candidate_iri]) and is_nil(attributes[:clarification_session_iri]) and
         is_nil(attributes[:handoff_state]),
       do: :ok,
       else: :error
  end

  defp kind_contract(:clarification, attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:clarification_session_iri]),
         true <- attributes[:phase] == :awaiting_actor,
         true <-
           is_nil(attributes[:budget_snapshot]) and is_nil(attributes[:candidate_iri]) and
             is_nil(attributes[:terminal_classification]) and
             is_nil(attributes[:handoff_state]) do
      :ok
    else
      _invalid -> :error
    end
  end

  defp kind_contract(:candidate_completion, attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:candidate_iri]),
         true <- attributes[:phase] == :candidate_ready,
         classification when classification in @terminal <- attributes[:terminal_classification],
         true <-
           is_nil(attributes[:budget_snapshot]) and
             is_nil(attributes[:clarification_session_iri]) and
             is_nil(attributes[:handoff_state]) do
      :ok
    else
      _invalid -> :error
    end
  end

  defp kind_contract(:candidate_handoff, attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:candidate_iri]),
         state when state in @handoff <- attributes[:handoff_state],
         true <-
           is_nil(attributes[:budget_snapshot]) and
             is_nil(attributes[:clarification_session_iri]) and
             is_nil(attributes[:terminal_classification]) do
      :ok
    else
      _invalid -> :error
    end
  end

  defp empty_optional?(attributes) do
    if Enum.all?(
         ~w[budget_snapshot terminal_classification candidate_iri clarification_session_iri handoff_state]a,
         &is_nil(attributes[&1])
       ),
       do: :ok,
       else: :error
  end

  defp identity(attributes) do
    ResourceIdentity.deterministic(
      :execution_event,
      Enum.join(
        [
          "managed-coding",
          attributes.attempt_iri,
          attributes.kind,
          attributes.runtime_sequence,
          attributes.reconstruction_watermark
        ],
        "\n"
      )
    )
  end

  defp encode_budget(nil), do: nil
  defp encode_budget(value), do: Jason.encode!(value)
  defp optional_literal(_subject, _local, nil), do: []

  defp optional_literal(subject, local, value),
    do: [{subject, @jf <> local, RDF.XSD.String.new(value)}]

  defp optional_iri(_subject, _local, nil), do: []
  defp optional_iri(subject, local, value), do: [{subject, @jf <> local, RDF.iri(value)}]
  defp optional_concept(_subject, _local, nil), do: []

  defp optional_concept(subject, local, value),
    do: [{subject, @jf <> local, RDF.iri(@concept <> Macro.camelize(to_string(value)))}]

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp bounded?(value, limit),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

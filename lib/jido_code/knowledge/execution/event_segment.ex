defmodule JidoCode.Knowledge.Execution.EventSegment do
  @moduledoc """
  Immutable predecessor-chained execution events and bounded segment closure.

  An event command consumes one exact head and creates one successor. The
  active head is therefore the unique head without a `hasSuccessor` edge;
  callers cannot choose a sequence number or use wall-clock ordering. Segment
  closure independently verifies the event set, typed sets, resources,
  content captures, sequence range, and carried effects before committing its
  roots.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :attempt_iri,
    :graph_iri,
    :index,
    :sequence_start,
    :sequence_end,
    :head_iri,
    :head_event_iri,
    :events,
    :resource_iris,
    :content_capture_iris,
    :open_effect_iris,
    :carried_effect_iris,
    :lifecycle_state
  ]
  defstruct @enforce_keys ++
              [
                :predecessor_iri,
                :predecessor_root_digest,
                :event_set_digest,
                :content_root_digest,
                :root_digest,
                :completeness
              ]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_entity "http://www.w3.org/ns/prov#Entity"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @capture_manifest @jf <> "CaptureManifest"
  @concept "https://jido.run/ontology/concept/"
  @event_types ~w[
    attempt_started segment_continued model_start model_outcome tool_start tool_outcome
    message transition proposal sandbox artifact cancellation retry terminal provider_observation
    lifecycle_observation
  ]a
  @roles ~w[observation start outcome transition artifact message terminal]a
  @protocol "2.0.0"

  @spec protocol_version() :: String.t()
  def protocol_version, do: @protocol

  @spec event_types() :: [atom()]
  def event_types, do: @event_types

  @spec open(String.t(), map()) :: {:ok, t(), [tuple()]} | {:error, Error.t()}
  def open(attempt_iri, attributes) when is_map(attributes) do
    index = attributes[:index]
    sequence = Map.get(attributes, :sequence_start, 0)
    predecessor = attributes[:predecessor_iri]
    predecessor_root = attributes[:predecessor_root_digest]
    carried = attributes[:carried_effect_iris] || []
    initial_type = Map.get(attributes, :initial_event_type, :attempt_started)

    with :ok <- ResourceIdentity.validate(attempt_iri),
         true <- is_integer(index) and index in 0..999_999,
         true <- is_integer(sequence) and sequence >= 0,
         :ok <- validate_predecessor(index, predecessor, predecessor_root),
         :ok <- resources(carried),
         true <- length(carried) <= capacity().segment_event_limit,
         true <- initial_type in [:attempt_started, :segment_continued],
         {:ok, graph_iri} <- ExecutionGraph.segment_graph(attempt_iri, index),
         {:ok, iri} <- identity(:event_segment, [attempt_iri, index]),
         {:ok, event} <-
           event(attempt_iri, iri, graph_iri, sequence, nil, %{
             event_type: initial_type,
             role: :observation,
             resource_iris: carried,
             content_capture_iris: [],
             opens_effect_iris: [],
             closes_effect_iris: []
           }),
         {:ok, head_iri} <- head_identity(attempt_iri, index, sequence, event.iri) do
      segment = %__MODULE__{
        iri: iri,
        attempt_iri: attempt_iri,
        graph_iri: graph_iri,
        index: index,
        sequence_start: sequence,
        sequence_end: sequence,
        head_iri: head_iri,
        head_event_iri: event.iri,
        events: [event],
        resource_iris: Enum.sort(Enum.uniq(carried)),
        content_capture_iris: [],
        open_effect_iris: Enum.sort(Enum.uniq(carried)),
        carried_effect_iris: Enum.sort(Enum.uniq(carried)),
        lifecycle_state: :open,
        predecessor_iri: predecessor,
        predecessor_root_digest: predecessor_root,
        event_set_digest: nil,
        content_root_digest: nil,
        root_digest: nil,
        completeness: nil
      }

      {:ok, segment, opening_statements(segment, event)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:event_segment_open)
    end
  rescue
    _error -> invalid(:event_segment_open)
  end

  def open(_attempt_iri, _attributes), do: invalid(:event_segment_open)

  @spec create_target(t(), [tuple()], map()) :: {:ok, map()} | {:error, Error.t()}
  def create_target(%__MODULE__{lifecycle_state: :open} = segment, statements, attributes)
      when is_list(statements) and is_map(attributes) do
    ExecutionGraph.create_segment_target(
      segment.graph_iri,
      attributes.repository_scope_iri,
      attributes.command_iri,
      attributes.recorded_at,
      statements,
      attributes[:parent_graph_iri]
    )
  end

  def create_target(_segment, _statements, _attributes),
    do: invalid(:event_segment_graph_create)

  @doc """
  Adds the first segment to the same `RecordExecutionAttempt` batch as the
  caller-built run/control targets. The run target must already contain the
  named capture manifest, preventing a segmented attempt from being created
  without its accounting contract.
  """
  @spec start_attempt_command(t(), [tuple()], [map()], String.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def start_attempt_command(
        segment,
        opening,
        attempt_targets,
        capture_manifest_iri,
        command_attributes,
        options \\ []
      )

  def start_attempt_command(
        %__MODULE__{index: 0, sequence_start: 0, lifecycle_state: :open} = segment,
        opening,
        attempt_targets,
        capture_manifest_iri,
        command_attributes,
        options
      )
      when is_list(opening) and is_list(attempt_targets) and is_map(command_attributes) and
             is_list(options) do
    with :ok <- ResourceIdentity.validate(capture_manifest_iri),
         true <- capture_manifest_target?(attempt_targets, capture_manifest_iri),
         {:ok, segment_target} <- create_target(segment, opening, command_attributes),
         guards =
           (command_attributes[:authority_guards] || []) ++
             [
               {:subject_absent, segment.graph_iri, segment.iri},
               {:subject_absent, segment.graph_iri, segment.head_iri}
             ],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordExecutionAttempt",
               command_attributes,
               attempt_targets ++ [segment_target],
               guards
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_segmented_execution_attempt)
    end
  rescue
    _error -> invalid(:record_segmented_execution_attempt)
  end

  def start_attempt_command(_segment, _opening, _targets, _manifest, _attributes, _options),
    do: invalid(:record_segmented_execution_attempt)

  @spec append(t(), String.t(), map()) ::
          {:ok, t(), [tuple()]} | {:error, Error.t()}
  def append(%__MODULE__{lifecycle_state: :open} = segment, expected_head_iri, attributes)
      when is_binary(expected_head_iri) and is_map(attributes) do
    next_sequence = segment.sequence_end + 1

    with true <- expected_head_iri == segment.head_iri,
         true <- length(segment.events) < capacity().segment_event_limit,
         true <- attributes[:event_type] in @event_types,
         true <- attributes[:role] in @roles,
         {:ok, event} <-
           event(
             segment.attempt_iri,
             segment.iri,
             segment.graph_iri,
             next_sequence,
             segment.head_event_iri,
             attributes
           ),
         :ok <- validate_effect_transition(segment, event),
         {:ok, head_iri} <-
           head_identity(segment.attempt_iri, segment.index, next_sequence, event.iri) do
      open_effects =
        segment.open_effect_iris
        |> MapSet.new()
        |> MapSet.union(MapSet.new(event.opens_effect_iris))
        |> MapSet.difference(MapSet.new(event.closes_effect_iris))
        |> MapSet.to_list()
        |> Enum.sort()

      next = %{
        segment
        | sequence_end: next_sequence,
          head_iri: head_iri,
          head_event_iri: event.iri,
          events: segment.events ++ [event],
          resource_iris: Enum.sort(Enum.uniq(segment.resource_iris ++ event.resource_iris)),
          content_capture_iris:
            Enum.sort(Enum.uniq(segment.content_capture_iris ++ event.content_capture_iris)),
          open_effect_iris: open_effects
      }

      {:ok, next, successor_statements(segment, next, event)}
    else
      {:error, %Error{} = error} -> {:error, error}
      false when expected_head_iri != segment.head_iri -> conflict(:event_head_consumed)
      _invalid -> invalid(:execution_event)
    end
  rescue
    _error -> invalid(:execution_event)
  end

  def append(%__MODULE__{}, _expected_head_iri, _attributes),
    do: conflict(:event_segment_closed)

  def append(_segment, _head, _attributes), do: invalid(:execution_event)

  @spec append_command(t(), String.t(), map(), map(), keyword()) ::
          {:ok, %{segment: t(), command: CommandEnvelope.t()}} | {:error, Error.t()}
  def append_command(
        segment,
        expected_head_iri,
        event_attributes,
        command_attributes,
        options \\ []
      )

  def append_command(
        %__MODULE__{} = segment,
        expected_head_iri,
        event_attributes,
        command_attributes,
        options
      )
      when is_map(event_attributes) and is_map(command_attributes) and is_list(options) do
    with {:ok, next, statements} <- append(segment, expected_head_iri, event_attributes),
         {:ok, target} <-
           ExecutionGraph.append_target(
             segment.graph_iri,
             command_attributes.expected_segment_revision,
             command_attributes.repository_scope_iri,
             command_attributes.command_iri,
             command_attributes.recorded_at,
             statements
           ),
         guards =
           (command_attributes[:authority_guards] || []) ++
             [
               {:subject_present, segment.graph_iri, expected_head_iri},
               {:predicate_absent, segment.graph_iri, expected_head_iri, @jf <> "hasSuccessor"}
             ],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope("RecordExecutionEvent", command_attributes, [target], guards),
             options
           ) do
      {:ok, %{segment: next, command: command}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_execution_event)
    end
  rescue
    _error -> invalid(:record_execution_event)
  end

  def append_command(_segment, _head, _event, _command, _options),
    do: invalid(:record_execution_event)

  @spec close(t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def close(%__MODULE__{lifecycle_state: :open} = segment, attributes)
      when is_map(attributes) do
    with :ok <- exact_set(segment.events, attributes[:listed_event_iris], & &1.iri, :event_set),
         :ok <- exact_typed_sets(segment.events, attributes[:typed_event_iris]),
         :ok <-
           exact_set(
             segment.resource_iris,
             attributes[:listed_resource_iris],
             & &1,
             :segment_resources
           ),
         :ok <-
           exact_set(
             segment.content_capture_iris,
             attributes[:listed_content_capture_iris],
             & &1,
             :segment_content
           ),
         :ok <- contiguous?(segment),
         :ok <- effect_accounting(segment, attributes),
         completeness when completeness in [:complete, :incomplete] <- attributes[:completeness] do
      event_digest = digest_events(segment.events)
      content_digest = digest_set(segment.content_capture_iris)
      carried = Enum.sort(attributes[:carried_effect_iris] || [])

      root =
        digest_term({
          @protocol,
          segment.attempt_iri,
          segment.index,
          segment.sequence_start,
          segment.sequence_end,
          segment.predecessor_root_digest,
          event_digest,
          content_digest,
          carried,
          completeness
        })

      {:ok,
       %{
         segment
         | lifecycle_state: :closed,
           event_set_digest: event_digest,
           content_root_digest: content_digest,
           root_digest: root,
           carried_effect_iris: carried,
           completeness: completeness
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:event_segment_close)
    end
  rescue
    _error -> invalid(:event_segment_close)
  end

  def close(%__MODULE__{}, _attributes), do: conflict(:event_segment_closed)
  def close(_segment, _attributes), do: invalid(:event_segment_close)

  @spec close_command(t(), map(), map(), keyword()) ::
          {:ok,
           %{
             segment: t(),
             next_segment: t() | nil,
             command: CommandEnvelope.t()
           }}
          | {:error, Error.t()}
  def close_command(segment, closure_attributes, command_attributes, options \\ [])

  def close_command(
        %__MODULE__{} = segment,
        closure_attributes,
        command_attributes,
        options
      )
      when is_map(closure_attributes) and is_map(command_attributes) and is_list(options) do
    with {:ok, closed} <- close(segment, closure_attributes),
         {:ok, closed_target} <-
           ExecutionGraph.close_segment_target(
             command_attributes.segment_metadata,
             command_attributes.repository_scope_iri,
             command_attributes.command_iri,
             command_attributes.recorded_at,
             closed.completeness,
             closure_statements(closed)
           ),
         {:ok, root_target} <-
           ExecutionGraph.append_target(
             command_attributes.run_graph_iri,
             command_attributes.expected_run_revision,
             command_attributes.repository_scope_iri,
             command_attributes.command_iri,
             command_attributes.recorded_at,
             root_statements(closed)
           ),
         {:ok, next, next_targets} <- maybe_open_next(closed, command_attributes),
         guards =
           (command_attributes[:authority_guards] || []) ++
             [
               {:subject_present, segment.graph_iri, segment.head_iri},
               {:predicate_absent, segment.graph_iri, segment.head_iri, @jf <> "hasSuccessor"}
             ],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "CloseEventSegment",
               command_attributes,
               [closed_target, root_target] ++ next_targets,
               guards
             ),
             options
           ) do
      {:ok, %{segment: closed, next_segment: next, command: command}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:close_event_segment)
    end
  rescue
    _error -> invalid(:close_event_segment)
  end

  def close_command(_segment, _closure, _command, _options),
    do: invalid(:close_event_segment)

  @spec next_segment(t()) :: {:ok, t(), [tuple()]} | {:error, Error.t()}
  def next_segment(%__MODULE__{lifecycle_state: :closed} = segment) do
    if segment.index + 1 < capacity().segment_count_limit do
      open(segment.attempt_iri, %{
        index: segment.index + 1,
        sequence_start: segment.sequence_end + 1,
        predecessor_iri: segment.iri,
        predecessor_root_digest: segment.root_digest,
        carried_effect_iris: segment.carried_effect_iris,
        initial_event_type: :segment_continued
      })
    else
      conflict(:continuation_attempt_required)
    end
  end

  def next_segment(%__MODULE__{}), do: conflict(:event_segment_open)
  def next_segment(_segment), do: invalid(:event_segment_continuation)

  @spec continuation_attempt(t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def continuation_attempt(%__MODULE__{lifecycle_state: :closed} = segment, attributes)
      when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:authority_iri]),
         true <- attributes[:reason] in [:segment_limit, :attempt_root_limit],
         {:ok, attempt_iri} <-
           identity(:execution_attempt, [
             segment.attempt_iri,
             segment.root_digest,
             attributes.reason
           ]) do
      {:ok,
       %{
         attempt_iri: attempt_iri,
         continuation_of_iri: segment.attempt_iri,
         predecessor_segment_root: segment.root_digest,
         authority_iri: attributes.authority_iri,
         reason: attributes.reason,
         carried_effect_iris: segment.carried_effect_iris
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:continuation_attempt)
    end
  end

  def continuation_attempt(_segment, _attributes), do: invalid(:continuation_attempt)

  defp maybe_open_next(closed, %{open_next?: true} = attributes) do
    with {:ok, next, statements} <- next_segment(closed),
         {:ok, target} <-
           create_target(next, statements, %{
             repository_scope_iri: attributes.repository_scope_iri,
             command_iri: attributes.command_iri,
             recorded_at: attributes.recorded_at,
             parent_graph_iri: closed.graph_iri
           }) do
      {:ok, next, [target]}
    end
  end

  defp maybe_open_next(_closed, _attributes), do: {:ok, nil, []}

  defp capture_manifest_target?(targets, capture_manifest_iri) do
    Enum.any?(targets, fn
      %{family: :run_attempt, operation: :create, additions: additions} when is_list(additions) ->
        Enum.any?(additions, fn statement ->
          case RDF.Triple.new(statement) do
            {%RDF.IRI{value: ^capture_manifest_iri}, %RDF.IRI{value: @rdf_type},
             %RDF.IRI{value: @capture_manifest}} ->
              true

            _other ->
              false
          end
        end)

      _other ->
        false
    end)
  rescue
    _error -> false
  end

  @spec opening_statements(t(), map()) :: [tuple()]
  def opening_statements(segment, event) do
    [
      {segment.iri, @rdf_type, RDF.iri(@jf <> "SegmentManifest")},
      {segment.iri, @jf <> "segmentOf", RDF.iri(segment.attempt_iri)},
      {segment.iri, @jf <> "memoryProtocolVersion", RDF.XSD.String.new(@protocol)},
      {segment.iri, @jf <> "segmentIndex", RDF.XSD.NonNegativeInteger.new(segment.index)},
      {segment.iri, @jf <> "sequenceStart",
       RDF.XSD.NonNegativeInteger.new(segment.sequence_start)}
    ] ++
      optional_iri(segment.iri, @jf <> "predecessorSegment", segment.predecessor_iri) ++
      optional_literal(
        segment.iri,
        @jf <> "predecessorRootDigest",
        segment.predecessor_root_digest
      ) ++ event_statements(event) ++ head_statements(segment)
  end

  @spec closure_statements(t()) :: [tuple()]
  def closure_statements(%__MODULE__{lifecycle_state: :closed} = segment) do
    [
      {segment.iri, @jf <> "sequenceEnd", RDF.XSD.NonNegativeInteger.new(segment.sequence_end)},
      {segment.iri, @jf <> "eventCount", RDF.XSD.NonNegativeInteger.new(length(segment.events))},
      {segment.iri, @jf <> "eventSetDigest", RDF.XSD.String.new(segment.event_set_digest)},
      {segment.iri, @jf <> "contentRootDigest", RDF.XSD.String.new(segment.content_root_digest)},
      {segment.iri, @jf <> "segmentRootDigest", RDF.XSD.String.new(segment.root_digest)},
      {segment.iri, @jf <> "completenessState",
       RDF.iri(@concept <> Macro.camelize(to_string(segment.completeness)))}
    ] ++
      Enum.map(segment.carried_effect_iris, fn iri ->
        {segment.iri, @jf <> "carriedOpenEffect", RDF.iri(iri)}
      end)
  end

  def closure_statements(_segment), do: []

  @spec root_statements(t()) :: [tuple()]
  def root_statements(%__MODULE__{lifecycle_state: :closed} = segment) do
    [
      {segment.attempt_iri, @jf <> "hasEventSegment", RDF.iri(segment.iri)},
      {segment.attempt_iri, @jf <> "segmentRootDigest", RDF.XSD.String.new(segment.root_digest)}
    ]
  end

  def root_statements(_segment), do: []

  @spec successor_guard(t()) :: tuple()
  def successor_guard(%__MODULE__{} = segment),
    do: {:predicate_absent, segment.graph_iri, segment.head_iri, @jf <> "hasSuccessor"}

  defp event(attempt_iri, segment_iri, graph_iri, sequence, predecessor, attributes) do
    with event_type when event_type in @event_types <- attributes[:event_type],
         role when role in @roles <- attributes[:role],
         :ok <- resources(attributes[:resource_iris] || []),
         :ok <- resources(attributes[:content_capture_iris] || []),
         :ok <-
           capture_statements(
             attributes[:capture_statements] || [],
             attributes[:content_capture_iris] || []
           ),
         :ok <- resources(attributes[:opens_effect_iris] || []),
         :ok <- resources(attributes[:closes_effect_iris] || []),
         true <-
           MapSet.disjoint?(
             MapSet.new(attributes[:opens_effect_iris] || []),
             MapSet.new(attributes[:closes_effect_iris] || [])
           ),
         {:ok, iri} <- identity(:execution_event, [attempt_iri, sequence, event_type]) do
      {:ok,
       %{
         iri: iri,
         attempt_iri: attempt_iri,
         segment_iri: segment_iri,
         graph_iri: graph_iri,
         sequence: sequence,
         predecessor_iri: predecessor,
         event_type: event_type,
         role: role,
         resource_iris: Enum.sort(Enum.uniq(attributes[:resource_iris] || [])),
         content_capture_iris: Enum.sort(Enum.uniq(attributes[:content_capture_iris] || [])),
         capture_statements: attributes[:capture_statements] || [],
         opens_effect_iris: Enum.sort(Enum.uniq(attributes[:opens_effect_iris] || [])),
         closes_effect_iris: Enum.sort(Enum.uniq(attributes[:closes_effect_iris] || [])),
         occurred_at: attributes[:occurred_at],
         source_order: attributes[:source_order],
         source_iri: attributes[:source_iri]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_event)
    end
  end

  defp event_statements(event) do
    [
      {event.iri, @rdf_type, RDF.iri(@prov_entity)},
      {event.iri, @jf <> "segmentOf", RDF.iri(event.segment_iri)},
      {event.iri, @jf <> "eventSequence", RDF.XSD.NonNegativeInteger.new(event.sequence)},
      {event.iri, @jf <> "eventKind", RDF.XSD.String.new(to_string(event.event_type))},
      {event.iri, @jf <> "eventRole", RDF.XSD.String.new(to_string(event.role))}
    ] ++
      optional_iri(event.iri, @jf <> "eventPredecessor", event.predecessor_iri) ++
      optional_time(event.iri, @prov <> "generatedAtTime", event.occurred_at) ++
      optional_iri(event.iri, @jf <> "sourceEvent", event.source_iri) ++
      optional_integer(event.iri, @jf <> "sourceOrder", event.source_order) ++
      refs(event.iri, @jf <> "accountsResource", event.resource_iris) ++
      refs(event.iri, @jf <> "hasCapture", event.content_capture_iris) ++
      refs(event.iri, @jf <> "opensEffect", event.opens_effect_iris) ++
      refs(event.iri, @jf <> "closesEffect", event.closes_effect_iris) ++
      event.capture_statements
  end

  defp head_statements(segment) do
    [
      {segment.head_iri, @rdf_type, RDF.iri(@prov_entity)},
      {segment.head_iri, @jf <> "about", RDF.iri(segment.attempt_iri)},
      {segment.head_iri, @jf <> "activeSegment", RDF.iri(segment.iri)},
      {segment.head_iri, @jf <> "headEvent", RDF.iri(segment.head_event_iri)},
      {segment.head_iri, @jf <> "headSequence",
       RDF.XSD.NonNegativeInteger.new(segment.sequence_end)}
    ]
  end

  defp successor_statements(previous, next, event) do
    [
      {previous.head_iri, @jf <> "hasSuccessor", RDF.iri(next.head_iri)},
      {next.head_iri, @jf <> "consumesHead", RDF.iri(previous.head_iri)}
    ] ++ event_statements(event) ++ head_statements(next)
  end

  defp validate_effect_transition(segment, event) do
    open = MapSet.new(segment.open_effect_iris)
    starts = MapSet.new(event.opens_effect_iris)
    outcomes = MapSet.new(event.closes_effect_iris)

    cond do
      not MapSet.disjoint?(open, starts) -> conflict(:duplicate_effect_start)
      not MapSet.subset?(outcomes, open) -> conflict(:effect_outcome_without_start)
      event.role == :start and MapSet.size(starts) == 0 -> invalid(:effect_start)
      event.role == :outcome and MapSet.size(outcomes) == 0 -> invalid(:effect_outcome)
      true -> :ok
    end
  end

  defp exact_typed_sets(events, typed) when is_map(typed) do
    actual =
      events
      |> Enum.group_by(& &1.event_type, & &1.iri)
      |> Map.new(fn {type, iris} -> {type, Enum.sort(iris)} end)

    normalized =
      Map.new(typed, fn {type, iris} ->
        {type, if(is_list(iris), do: Enum.sort(Enum.uniq(iris)), else: :invalid)}
      end)

    if actual == normalized, do: :ok, else: conflict(:segment_typed_event_set)
  end

  defp exact_typed_sets(_events, _typed), do: invalid(:segment_typed_event_set)

  defp exact_set(actual, listed, mapper, operation) when is_list(listed) do
    expected = actual |> Enum.map(mapper) |> Enum.sort()
    provided = listed |> Enum.uniq() |> Enum.sort()

    if length(listed) == length(provided) and expected == provided,
      do: :ok,
      else: conflict(operation)
  end

  defp exact_set(_actual, _listed, _mapper, operation), do: invalid(operation)

  defp contiguous?(segment) do
    sequences = Enum.map(segment.events, & &1.sequence)
    expected = Enum.to_list(segment.sequence_start..segment.sequence_end)

    if sequences == expected and length(sequences) == length(Enum.uniq(sequences)),
      do: :ok,
      else: conflict(:segment_sequence_gap)
  end

  defp effect_accounting(segment, attributes) do
    carried = attributes[:carried_effect_iris] || []
    ambiguous = attributes[:ambiguous_effect_iris] || []

    with :ok <- resources(carried),
         :ok <- resources(ambiguous),
         true <- MapSet.disjoint?(MapSet.new(carried), MapSet.new(ambiguous)),
         true <-
           MapSet.equal?(
             MapSet.new(segment.open_effect_iris),
             MapSet.union(MapSet.new(carried), MapSet.new(ambiguous))
           ) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> conflict(:segment_open_effects)
    end
  end

  defp validate_predecessor(0, nil, nil), do: :ok

  defp validate_predecessor(index, predecessor, root) when index > 0 do
    with :ok <- ResourceIdentity.validate(predecessor),
         true <- digest?(root) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:event_segment_predecessor)
    end
  end

  defp validate_predecessor(_index, _predecessor, _root),
    do: invalid(:event_segment_predecessor)

  defp envelope(type, attributes, changes, guards) do
    %{
      command_type: type,
      command_version: @protocol,
      command_iri: attributes[:command_iri],
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: attributes[:delegated_agent_iri],
      delegation_iri: attributes[:delegation_iri],
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: attributes[:idempotency_key] || attributes[:command_iri],
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.1.0",
      shape_version: "1.1.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: attributes[:expected_graph_revisions],
      reason: attributes[:reason],
      payload: %{changes: changes, guards: guards}
    }
  end

  defp identity(kind, fields) do
    fields
    |> Enum.map_join("\n", &to_string/1)
    |> then(&ResourceIdentity.deterministic(kind, &1))
  end

  defp head_identity(attempt, index, sequence, event),
    do: identity(:execution_event_head, [attempt, index, sequence, event])

  defp digest_events(events) do
    events
    |> Enum.map(fn event ->
      {event.sequence, event.iri, event.predecessor_iri, event.event_type, event.role,
       event.resource_iris, event.content_capture_iris, event.opens_effect_iris,
       event.closes_effect_iris}
    end)
    |> digest_term()
  end

  defp digest_set(values), do: values |> Enum.sort() |> digest_term()

  defp digest_term(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp resources(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)) and
         length(values) == length(Enum.uniq(values)),
       do: :ok,
       else: invalid(:event_resources)
  end

  defp resources(_values), do: invalid(:event_resources)

  defp capture_statements(statements, capture_iris)
       when is_list(statements) and length(statements) <= 500 do
    allowed = MapSet.new(capture_iris)

    if Enum.all?(statements, fn statement ->
         case RDF.Triple.new(statement) do
           {%RDF.IRI{value: subject}, _, _} = triple ->
             MapSet.member?(allowed, subject) and RDF.Triple.valid?(triple) and
               not RDF.Triple.has_bnode?(triple)

           _invalid ->
             false
         end
       end),
       do: :ok,
       else: invalid(:capture_statements)
  rescue
    _error -> invalid(:capture_statements)
  end

  defp capture_statements(_statements, _capture_iris), do: invalid(:capture_statements)

  defp refs(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, value), do: [{subject, predicate, RDF.iri(value)}]

  defp optional_literal(_subject, _predicate, nil), do: []

  defp optional_literal(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.String.new(value)}]

  defp optional_time(_subject, _predicate, nil), do: []

  defp optional_time(subject, predicate, %DateTime{} = value),
    do: [{subject, predicate, RDF.XSD.DateTime.new(value)}]

  defp optional_time(_subject, _predicate, _value), do: []

  defp optional_integer(_subject, _predicate, nil), do: []

  defp optional_integer(subject, predicate, value) when is_integer(value) and value >= 0,
    do: [{subject, predicate, RDF.XSD.NonNegativeInteger.new(value)}]

  defp optional_integer(_subject, _predicate, _value), do: []

  defp capacity, do: Guardrails.capacity_profile()
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
end

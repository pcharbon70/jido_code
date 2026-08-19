defmodule JidoCode.Knowledge.Execution.SegmentedRun do
  @moduledoc """
  Verifiable segmented run finalization, projection and graph-native recovery.

  Finalization consumes only recomputable closed segment roots. Recovery
  derives the open segment, active head, effects and replay identities from RDF
  graph state; it never turns a closed graph back into writable history.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Memory.CaptureManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :attempt_iri,
    :protocol,
    :segment_roots,
    :terminal_sequence,
    :capture_manifest_iri,
    :capture_completeness_root,
    :run_root_digest,
    :completeness,
    :incomplete_reasons,
    :cancelled_effect_iris,
    :ambiguous_effect_iris,
    :lifecycle_state
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_entity "http://www.w3.org/ns/prov#Entity"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @protocol "2.0.0"
  @incomplete_reasons ~w[
    provider_unavailable capture_failed cancellation_ambiguity bounded_limit
  ]a
  @max_recovery_quads 10_000

  @spec incomplete_reasons() :: [atom()]
  def incomplete_reasons, do: @incomplete_reasons

  @spec finalize(String.t(), [EventSegment.t()], CaptureManifest.t(), map()) ::
          {:ok, t()} | {:error, Error.t()}
  def finalize(attempt_iri, segments, %CaptureManifest{} = manifest, attributes)
      when is_list(segments) and is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attempt_iri),
         true <- manifest.attempt_iri == attempt_iri,
         true <- is_binary(manifest.completeness_root_digest),
         :ok <- segment_chain(attempt_iri, segments),
         :ok <- listed_roots(segments, attributes[:listed_segment_roots]),
         :ok <- event_accounting(segments, attributes),
         :ok <- terminal(segments, attributes[:terminal_sequence]),
         :ok <- effects(segments, attributes),
         :ok <- completeness(segments, attributes),
         {:ok, iri} <- ResourceIdentity.deterministic(:segment_closure, attempt_iri) do
      roots = Enum.map(segments, & &1.root_digest)
      cancelled = Enum.sort(attributes[:cancelled_effect_iris] || [])
      ambiguous = Enum.sort(attributes[:ambiguous_effect_iris] || [])
      reasons = Enum.sort(attributes[:incomplete_reasons] || [])

      run_root =
        digest_term({
          @protocol,
          attempt_iri,
          roots,
          attributes.terminal_sequence,
          manifest.completeness_root_digest,
          cancelled,
          ambiguous,
          reasons,
          attributes.completeness
        })

      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attempt_iri,
         protocol: @protocol,
         segment_roots: roots,
         terminal_sequence: attributes.terminal_sequence,
         capture_manifest_iri: manifest.iri,
         capture_completeness_root: manifest.completeness_root_digest,
         run_root_digest: run_root,
         completeness: attributes.completeness,
         incomplete_reasons: reasons,
         cancelled_effect_iris: cancelled,
         ambiguous_effect_iris: ambiguous,
         lifecycle_state: :closed
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:segmented_run_finalization)
    end
  rescue
    _error -> invalid(:segmented_run_finalization)
  end

  def finalize(_attempt, _segments, _manifest, _attributes),
    do: invalid(:segmented_run_finalization)

  @spec finalize_command(t(), map(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def finalize_command(run, run_metadata, attributes, options \\ [])

  def finalize_command(%__MODULE__{} = run, run_metadata, attributes, options)
      when is_map(run_metadata) and is_map(attributes) and is_list(options) do
    with true <- run_metadata[:graph_iri] == attributes[:run_graph_iri],
         {:ok, target} <-
           ExecutionGraph.close_target(
             run_metadata,
             attributes.repository_scope_iri,
             attributes.command_iri,
             attributes.recorded_at,
             run.completeness,
             statements(run, attributes.recorded_at)
           ),
         guards =
           (attributes[:authority_guards] || []) ++
             [{:subject_absent, attributes.run_graph_iri, run.iri}],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(attributes, target, guards),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:finalize_segmented_execution_run)
    end
  rescue
    _error -> invalid(:finalize_segmented_execution_run)
  end

  def finalize_command(_run, _metadata, _attributes, _options),
    do: invalid(:finalize_segmented_execution_run)

  @spec statements(t(), DateTime.t()) :: [tuple()]
  def statements(%__MODULE__{} = run, %DateTime{} = recorded_at) do
    [
      {run.iri, @rdf_type, RDF.iri(@prov_entity)},
      {run.iri, @jf <> "about", RDF.iri(run.attempt_iri)},
      {run.attempt_iri, @jf <> "memoryProtocolVersion", RDF.XSD.String.new(run.protocol)},
      {run.attempt_iri, @jf <> "terminalSequence",
       RDF.XSD.NonNegativeInteger.new(run.terminal_sequence)},
      {run.attempt_iri, @jf <> "captureCompletenessRoot",
       RDF.XSD.String.new(run.capture_completeness_root)},
      {run.attempt_iri, @jf <> "captureManifest", RDF.iri(run.capture_manifest_iri)},
      {run.capture_manifest_iri, @jf <> "completenessRootDigest",
       RDF.XSD.String.new(run.capture_completeness_root)},
      {run.capture_manifest_iri, @jf <> "captureCompleteness", RDF.iri(@concept <> "Complete")},
      {run.attempt_iri, @jf <> "runRootDigest", RDF.XSD.String.new(run.run_root_digest)},
      {run.attempt_iri, @jf <> "completenessState",
       RDF.iri(@concept <> Macro.camelize(to_string(run.completeness)))},
      {run.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(recorded_at)}
    ] ++
      Enum.map(run.segment_roots, fn root ->
        {run.attempt_iri, @jf <> "orderedSegmentRoot", RDF.XSD.String.new(root)}
      end) ++
      Enum.map(run.incomplete_reasons, fn reason ->
        {run.attempt_iri, @jf <> "incompleteReason", RDF.XSD.String.new(to_string(reason))}
      end) ++
      refs(run.attempt_iri, @jf <> "cancelledEffect", run.cancelled_effect_iris) ++
      refs(run.attempt_iri, @jf <> "ambiguousEffect", run.ambiguous_effect_iris)
  end

  def statements(_run, _recorded_at), do: []

  @doc """
  Decodes safe continuation state from persisted quads only.

  Closed segments may retain a terminal head resource, but it is never exposed
  as active because lifecycle metadata is authoritative.
  """
  @spec recover(RDF.Dataset.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def recover(%RDF.Dataset{} = dataset, attempt_iri) do
    quads = RDF.Dataset.quads(dataset)

    with true <- length(quads) <= @max_recovery_quads,
         :ok <- ResourceIdentity.validate(attempt_iri),
         {:ok, segments} <- recover_segments(quads, attempt_iri),
         {:ok, active} <- active_segment(segments),
         {:ok, head} <- active_head(quads, attempt_iri, active),
         {:ok, effects} <- recovered_effects(quads, active),
         resources = recovered_resources(quads, segments) do
      {:ok,
       %{
         protocol: @protocol,
         attempt_iri: attempt_iri,
         segments: segments,
         active_segment: active,
         active_head: head,
         next_sequence: if(head, do: head.sequence + 1, else: nil),
         open_effect_iris: effects,
         recorded_resource_iris: resources,
         idempotency_identities: Enum.sort(Enum.uniq(resources ++ head_identity(head))),
         continuation_authority: if(head, do: :exact_active_head, else: :none),
         resumable?: not is_nil(active) and not is_nil(head),
         lifecycle_state: if(active, do: :open, else: :closed)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> corrupt(:segmented_run_recovery)
    end
  rescue
    _error -> corrupt(:segmented_run_recovery)
  end

  def recover(_dataset, _attempt), do: invalid(:segmented_run_recovery)

  @spec project(t() | map()) :: {:ok, map()} | {:error, Error.t()}
  def project(%__MODULE__{} = run) do
    {:ok,
     %{
       protocol: @protocol,
       protocol_family: :segmented,
       completeness_claim: :total_expected_event_accounting,
       completeness: run.completeness,
       reconstruction: :stored_representations_only,
       segment_roots: run.segment_roots,
       terminal_sequence: run.terminal_sequence,
       run_root_digest: run.run_root_digest,
       incomplete_reasons: run.incomplete_reasons,
       legacy_rewrite?: false
     }}
  end

  def project(%{protocol: "1.x"} = legacy) do
    with lifecycle when lifecycle in [:closed, :open] <- legacy[:lifecycle_state],
         completeness when completeness in [:complete, :incomplete, :building] <-
           legacy[:completeness] do
      {:ok,
       %{
         protocol: "1.x",
         protocol_family: :legacy,
         completeness_claim: :bounded_observable_subset,
         completeness: completeness,
         reconstruction: :stored_representations_only,
         segment_roots: [],
         terminal_sequence: legacy[:terminal_sequence],
         run_root_digest: nil,
         incomplete_reasons: legacy[:limitations] || [],
         lifecycle_state: lifecycle,
         legacy_rewrite?: false
       }}
    else
      _invalid -> invalid(:legacy_run_projection)
    end
  end

  def project(_input), do: invalid(:run_projection_protocol)

  defp segment_chain(attempt_iri, segments) when segments != [] do
    valid_structs? =
      Enum.all?(segments, fn
        %EventSegment{attempt_iri: ^attempt_iri, lifecycle_state: :closed} = segment ->
          EventSegment.valid_root?(segment)

        _invalid ->
          false
      end)

    ordered = Enum.sort_by(segments, & &1.index)

    chain? =
      Enum.with_index(ordered)
      |> Enum.all?(fn
        {segment, 0} ->
          segment.index == 0 and segment.sequence_start == 0 and
            is_nil(segment.predecessor_iri) and is_nil(segment.predecessor_root_digest)

        {segment, index} ->
          prior = Enum.at(ordered, index - 1)

          segment.index == index and segment.sequence_start == prior.sequence_end + 1 and
            segment.predecessor_iri == prior.iri and
            segment.predecessor_root_digest == prior.root_digest
      end)

    if valid_structs? and ordered == segments and chain?,
      do: :ok,
      else: conflict(:segment_root_chain)
  end

  defp segment_chain(_attempt, _segments), do: invalid(:segment_root_chain)

  defp listed_roots(segments, listed) when is_list(listed) do
    actual = Enum.map(segments, & &1.root_digest)
    if actual == listed, do: :ok, else: conflict(:segment_root_set)
  end

  defp listed_roots(_segments, _listed), do: invalid(:segment_root_set)

  defp event_accounting(segments, attributes) do
    actual = segments |> Enum.flat_map(& &1.events) |> Enum.map(& &1.iri)
    listed = attributes[:accounted_event_iris]
    outside = attributes[:unsegmented_event_iris]

    if is_list(listed) and listed == actual and outside == [] and
         length(listed) == length(Enum.uniq(listed)),
       do: :ok,
       else: conflict(:unsegmented_execution_event)
  end

  defp terminal(segments, terminal_sequence) do
    last_segment = List.last(segments)
    last_event = List.last(last_segment.events)

    if last_segment.sequence_end == terminal_sequence and last_event.sequence == terminal_sequence and
         last_event.event_type == :terminal,
       do: :ok,
       else: conflict(:segmented_terminal_sequence)
  end

  defp effects(segments, attributes) do
    last = List.last(segments)
    cancelled = attributes[:cancelled_effect_iris] || []
    ambiguous = attributes[:ambiguous_effect_iris] || []
    events = Enum.flat_map(segments, & &1.events)
    opened = events |> Enum.flat_map(& &1.opens_effect_iris) |> MapSet.new()
    closed = events |> Enum.flat_map(& &1.closes_effect_iris) |> MapSet.new()
    cancelled_set = MapSet.new(cancelled)

    if valid_resources?(cancelled) and valid_resources?(ambiguous) and
         MapSet.disjoint?(cancelled_set, MapSet.new(ambiguous)) and
         MapSet.subset?(cancelled_set, MapSet.intersection(opened, closed)) and
         MapSet.equal?(MapSet.new(last.open_effect_iris), MapSet.new(ambiguous)) and
         MapSet.equal?(MapSet.new(last.ambiguous_effect_iris), MapSet.new(ambiguous)),
       do: :ok,
       else: conflict(:segmented_open_effects)
  end

  defp completeness(segments, attributes) do
    state = attributes[:completeness]
    reasons = attributes[:incomplete_reasons]

    ambiguous = attributes[:ambiguous_effect_iris] || []

    cond do
      state == :complete and reasons == [] and ambiguous == [] and
          Enum.all?(segments, &(&1.completeness == :complete)) ->
        :ok

      state == :incomplete and is_list(reasons) and reasons != [] and
        length(reasons) == length(Enum.uniq(reasons)) and
          Enum.all?(reasons, &(&1 in @incomplete_reasons)) ->
        :ok

      true ->
        conflict(:segmented_completeness)
    end
  end

  defp recover_segments(quads, attempt_iri) do
    segments =
      quads
      |> Enum.flat_map(fn
        {%RDF.IRI{value: segment}, %RDF.IRI{value: @jf <> "segmentOf"},
         %RDF.IRI{value: ^attempt_iri}, %RDF.IRI{value: graph}} ->
          [%{iri: segment, graph_iri: graph}]

        _other ->
          []
      end)
      |> Enum.uniq()
      |> Enum.map(&recover_segment(quads, &1))

    if segments != [] and Enum.all?(segments, &is_map/1) do
      ordered = Enum.sort_by(segments, & &1.index)

      if Enum.map(ordered, & &1.index) == Enum.to_list(0..(length(ordered) - 1)),
        do: {:ok, ordered},
        else: corrupt(:segmented_recovery_chain)
    else
      corrupt(:segmented_recovery_segments)
    end
  end

  defp recover_segment(quads, segment) do
    graph = segment.graph_iri

    with [index] <- integers(quads, segment.iri, @jf <> "segmentIndex", graph),
         [start] <- integers(quads, segment.iri, @jf <> "sequenceStart", graph),
         [lifecycle] <- iris(quads, graph, @jf <> "lifecycleState", graph),
         lifecycle_state when lifecycle_state in [:open, :closed] <- lifecycle(lifecycle) do
      %{
        iri: segment.iri,
        graph_iri: graph,
        index: index,
        sequence_start: start,
        sequence_end: one_integer(quads, segment.iri, @jf <> "sequenceEnd", graph),
        root_digest: one_literal(quads, segment.iri, @jf <> "segmentRootDigest", graph),
        lifecycle_state: lifecycle_state
      }
    else
      _invalid -> :corrupt
    end
  end

  defp active_segment(segments) do
    case Enum.filter(segments, &(&1.lifecycle_state == :open)) do
      [active] -> {:ok, active}
      [] -> {:ok, nil}
      _many -> corrupt(:multiple_open_event_segments)
    end
  end

  defp active_head(_quads, _attempt, nil), do: {:ok, nil}

  defp active_head(quads, attempt, active) do
    successors =
      quads
      |> Enum.flat_map(fn
        {%RDF.IRI{value: head}, %RDF.IRI{value: @jf <> "hasSuccessor"}, _, %RDF.IRI{value: graph}}
        when graph == active.graph_iri ->
          [head]

        _other ->
          []
      end)
      |> MapSet.new()

    heads =
      quads
      |> Enum.flat_map(fn
        {%RDF.IRI{value: head}, %RDF.IRI{value: @jf <> "about"}, %RDF.IRI{value: ^attempt},
         %RDF.IRI{value: graph}}
        when graph == active.graph_iri ->
          [head]

        _other ->
          []
      end)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(successors, &1))

    case heads do
      [head] ->
        with [segment_iri] <- iris(quads, head, @jf <> "activeSegment", active.graph_iri),
             true <- segment_iri == active.iri,
             [event_iri] <- iris(quads, head, @jf <> "headEvent", active.graph_iri),
             [sequence] <- integers(quads, head, @jf <> "headSequence", active.graph_iri) do
          {:ok, %{iri: head, event_iri: event_iri, sequence: sequence}}
        else
          _invalid -> corrupt(:active_event_head)
        end

      _invalid ->
        corrupt(:active_event_head)
    end
  end

  defp recovered_effects(_quads, nil), do: {:ok, []}

  defp recovered_effects(quads, active) do
    opened =
      objects_in_graph(quads, @jf <> "opensEffect", active.graph_iri) ++
        objects_in_graph(quads, @jf <> "carriedOpenEffect", active.graph_iri)

    closed = objects_in_graph(quads, @jf <> "closesEffect", active.graph_iri)
    {:ok, opened |> MapSet.new() |> MapSet.difference(MapSet.new(closed)) |> Enum.sort()}
  end

  defp recovered_resources(quads, segments) do
    graphs = MapSet.new(Enum.map(segments, & &1.graph_iri))

    quads
    |> Enum.flat_map(fn
      {_, %RDF.IRI{value: @jf <> "accountsResource"}, %RDF.IRI{value: resource},
       %RDF.IRI{value: graph}} ->
        if MapSet.member?(graphs, graph), do: [resource], else: []

      _other ->
        []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp integers(quads, subject, predicate, graph) do
    quads
    |> values(subject, predicate, graph)
    |> Enum.flat_map(fn literal ->
      case RDF.Literal.value(literal) do
        value when is_integer(value) -> [value]
        _invalid -> []
      end
    end)
    |> Enum.uniq()
  end

  defp iris(quads, subject, predicate, graph) do
    quads
    |> values(subject, predicate, graph)
    |> Enum.flat_map(fn
      %RDF.IRI{value: value} -> [value]
      _other -> []
    end)
    |> Enum.uniq()
  end

  defp one_integer(quads, subject, predicate, graph) do
    case integers(quads, subject, predicate, graph) do
      [value] -> value
      [] -> nil
      _many -> :ambiguous
    end
  end

  defp one_literal(quads, subject, predicate, graph) do
    case values(quads, subject, predicate, graph) do
      [%RDF.Literal{} = value] -> RDF.Literal.value(value)
      [] -> nil
      _many -> :ambiguous
    end
  end

  defp values(quads, subject, predicate, graph) do
    Enum.flat_map(quads, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: ^predicate}, object, %RDF.IRI{value: ^graph}} ->
        [object]

      _other ->
        []
    end)
  end

  defp objects_in_graph(quads, predicate, graph) do
    quads
    |> Enum.flat_map(fn
      {_, %RDF.IRI{value: ^predicate}, %RDF.IRI{value: object}, %RDF.IRI{value: ^graph}} ->
        [object]

      _other ->
        []
    end)
    |> Enum.uniq()
  end

  defp lifecycle(@concept <> "Open"), do: :open
  defp lifecycle(@concept <> "Closed"), do: :closed
  defp lifecycle(_value), do: :unknown

  defp head_identity(nil), do: []
  defp head_identity(head), do: [head.iri]

  defp envelope(attributes, target, guards) do
    %{
      command_type: "FinalizeExecutionRun",
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
      ontology_version: "1.2.0",
      shape_version: "1.2.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: attributes[:expected_graph_revisions],
      reason: attributes[:reason],
      payload: %{changes: [target], guards: guards}
    }
  end

  defp refs(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp valid_resources?(values) when is_list(values) do
    length(values) == length(Enum.uniq(values)) and
      Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok))
  end

  defp valid_resources?(_values), do: false

  defp digest_term(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
  defp corrupt(operation), do: {:error, Error.new(:corrupt, operation)}
end

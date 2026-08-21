defmodule JidoCode.Knowledge.Memory.Phase02EventSegmentTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-19 14:00:00Z]

  test "opens sequence zero and only advances from the exact active head" do
    {:ok, segment, statements} = open_segment()
    first_head = segment.head_iri

    assert segment.index == 0
    assert segment.sequence_start == 0
    assert segment.sequence_end == 0
    assert length(segment.events) == 1
    assert Enum.at(segment.events, 0).event_type == :attempt_started
    assert statements != []

    effect = resource(:action_proposal, "model-effect")

    assert {:ok, next, successor_statements} =
             EventSegment.append(segment, first_head, %{
               event_type: :model_start,
               role: :start,
               resource_iris: [effect],
               opens_effect_iris: [effect],
               occurred_at: @now
             })

    assert next.sequence_end == 1
    assert next.open_effect_iris == [effect]
    assert next.head_iri != first_head

    assert Enum.any?(successor_statements, fn statement ->
             {subject, predicate, _object} = RDF.Triple.new(statement)

             to_string(subject) == first_head and
               String.ends_with?(to_string(predicate), "hasSuccessor")
           end)

    assert {:error, %Error{kind: :conflict, operation: :event_head_consumed}} =
             EventSegment.append(next, first_head, %{
               event_type: :message,
               role: :message
             })
  end

  test "closes only exact typed, resource, content, sequence, and effect sets" do
    {:ok, segment, _} = open_segment()
    effect = resource(:tool_invocation, "effect")
    capture = resource(:content_capture, "capture")

    {:ok, segment, _} =
      EventSegment.append(segment, segment.head_iri, %{
        event_type: :tool_start,
        role: :start,
        resource_iris: [effect],
        content_capture_iris: [capture],
        opens_effect_iris: [effect]
      })

    incomplete = closure(segment, carried_effect_iris: [effect], completeness: :incomplete)

    assert {:ok, closed} = EventSegment.close(segment, incomplete)
    assert closed.lifecycle_state == :closed
    assert closed.sequence_start == 0
    assert closed.sequence_end == 1
    assert digest?(closed.event_set_digest)
    assert digest?(closed.content_root_digest)
    assert digest?(closed.root_digest)
    assert closed.carried_effect_iris == [effect]

    assert {:error, %Error{kind: :conflict, operation: :segment_typed_event_set}} =
             EventSegment.close(segment, %{incomplete | typed_event_iris: %{}})

    assert {:error, %Error{kind: :conflict, operation: :segment_resources}} =
             EventSegment.close(segment, %{incomplete | listed_resource_iris: []})

    assert {:error, %Error{kind: :conflict, operation: :segment_content}} =
             EventSegment.close(segment, %{incomplete | listed_content_capture_iris: []})

    assert {:error, %Error{kind: :conflict, operation: :segment_open_effects}} =
             EventSegment.close(segment, %{incomplete | carried_effect_iris: []})
  end

  test "carries open effects explicitly and requires a governed continuation at the attempt limit" do
    {:ok, segment, _} = open_segment()
    effect = resource(:tool_invocation, "carried-effect")

    {:ok, segment, _} =
      EventSegment.append(segment, segment.head_iri, %{
        event_type: :tool_start,
        role: :start,
        opens_effect_iris: [effect],
        resource_iris: [effect]
      })

    {:ok, closed} =
      EventSegment.close(
        segment,
        closure(segment, carried_effect_iris: [effect], completeness: :incomplete)
      )

    assert {:ok, next, statements} = EventSegment.next_segment(closed)
    assert next.index == 1
    assert next.sequence_start == closed.sequence_end + 1
    assert next.predecessor_iri == closed.iri
    assert next.predecessor_root_digest == closed.root_digest
    assert next.open_effect_iris == [effect]
    assert statements != []

    at_limit = %{closed | index: Guardrails.capacity_profile().segment_count_limit - 1}

    assert {:error, %Error{kind: :conflict, operation: :continuation_attempt_required}} =
             EventSegment.next_segment(at_limit)

    authority = resource(:continuation_authority, "limit-authority")

    assert {:ok, continuation} =
             EventSegment.continuation_attempt(at_limit, %{
               authority_iri: authority,
               reason: :segment_limit
             })

    assert continuation.continuation_of_iri == closed.attempt_iri
    assert continuation.predecessor_segment_root == closed.root_digest
    assert continuation.authority_iri == authority
  end

  test "keeps the MG2 segment writer active alongside later guarded writers" do
    assert GraphRegistry.revision() == "2.2.0"

    assert {:ok, %{enabled: true, capability: :execution_writer}} =
             GraphRegistry.fetch(:run_event_segment)

    assert Guardrails.feature_enabled?(:run_event_segment_writer)
    assert Guardrails.feature_enabled?(:experience_writer)

    assert CommandRegistry.segmented_execution_version() == "2.0.0"

    assert {:ok, close} = CommandRegistry.resolve("CloseEventSegment", "2.0.0")
    assert close.allow_closure?
    assert :exact_event_head in close.preconditions

    assert {:ok, append} = CommandRegistry.resolve("RecordExecutionEvent", "2.0.0")
    assert append.graph_families == [:run_attempt, :run_event_segment]
  end

  test "builds append commands with a conflict-safe predecessor guard" do
    {:ok, segment, opening} = open_segment()
    command = resource(:command_request, "append-event")
    scope = resource(:execution_context, "repository-scope")
    actor = resource(:authorization_grant, "actor")
    correlation = resource(:command_request, "correlation")
    causation = resource(:command_request, "causation")

    assert {:ok, target} =
             EventSegment.create_target(segment, opening, %{
               repository_scope_iri: scope,
               command_iri: command,
               recorded_at: @now
             })

    assert target.family == :run_event_segment
    assert target.operation == :create
    assert target.metadata.ontology_version == "https://jido.run/ontology/release/1.2.0"

    attributes = %{
      command_iri: command,
      principal_iri: actor,
      actor_iri: actor,
      repository_scope_iri: scope,
      correlation_iri: correlation,
      causation_iri: causation,
      expected_segment_revision: 1,
      expected_dataset_revision: 1,
      expected_graph_revisions: %{segment.graph_iri => 1},
      recorded_at: @now,
      reason: "record next immutable event"
    }

    assert {:ok, %{command: envelope, segment: successor}} =
             EventSegment.append_command(
               segment,
               segment.head_iri,
               %{event_type: :message, role: :message},
               attributes,
               clock: fn -> @now end
             )

    assert envelope.command_type == "RecordExecutionEvent"
    assert envelope.command_version == "2.0.0"
    assert successor.sequence_end == 1

    graph_iri = segment.graph_iri
    head_iri = segment.head_iri

    assert {:predicate_absent, ^graph_iri, ^head_iri, predicate} =
             List.last(envelope.payload.guards)

    assert String.ends_with?(predicate, "hasSuccessor")
  end

  defp open_segment do
    EventSegment.open(resource(:execution_attempt, "attempt"), %{index: 0})
  end

  defp closure(segment, overrides) do
    base = %{
      listed_event_iris: Enum.map(segment.events, & &1.iri),
      typed_event_iris:
        segment.events
        |> Enum.group_by(& &1.event_type, & &1.iri)
        |> Map.new(),
      listed_resource_iris: segment.resource_iris,
      listed_content_capture_iris: segment.content_capture_iris,
      carried_effect_iris: [],
      ambiguous_effect_iris: [],
      completeness: :complete
    }

    Enum.into(overrides, base)
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
end

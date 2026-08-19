defmodule JidoCode.Knowledge.Memory.Phase02SegmentedRunTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Execution.SegmentedRun
  alias JidoCode.Knowledge.Memory.CaptureManifest
  alias JidoCode.Knowledge.Memory.ContentCapture
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @now ~U[2026-08-19 17:00:00Z]

  test "finalizes an exact multi-segment root chain through the terminal sequence" do
    fixture = complete_fixture()

    assert {:ok, run} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               fixture.segments,
               fixture.manifest,
               finalization_attributes(fixture)
             )

    assert run.protocol == "2.0.0"
    assert run.segment_roots == Enum.map(fixture.segments, & &1.root_digest)
    assert run.terminal_sequence == fixture.terminal_sequence
    assert run.capture_completeness_root == fixture.manifest.completeness_root_digest
    assert digest?(run.run_root_digest)
    assert run.completeness == :complete
    assert run.lifecycle_state == :closed

    assert {:ok, projection} = SegmentedRun.project(run)
    assert projection.protocol_family == :segmented
    assert projection.completeness_claim == :total_expected_event_accounting
    refute projection.legacy_rewrite?
  end

  test "rejects mutated roots, range gaps, unsegmented events, and missing terminal events" do
    fixture = complete_fixture("rejections")
    [first, second] = fixture.segments
    attributes = finalization_attributes(fixture)

    assert {:error, %Error{kind: :conflict, operation: :segment_root_chain}} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               [first, %{second | root_digest: digest("mutated-root")}],
               fixture.manifest,
               %{attributes | listed_segment_roots: [first.root_digest, digest("mutated-root")]}
             )

    assert {:error, %Error{kind: :conflict, operation: :segment_root_chain}} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               [first, %{second | sequence_start: second.sequence_start + 1}],
               fixture.manifest,
               attributes
             )

    assert {:error, %Error{kind: :conflict, operation: :unsegmented_execution_event}} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               fixture.segments,
               fixture.manifest,
               %{attributes | unsegmented_event_iris: [resource(:execution_event, "late")]}
             )

    without_terminal =
      %{second | events: List.delete_at(second.events, -1), sequence_end: second.sequence_end - 1}

    assert {:error, %Error{kind: :conflict}} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               [first, without_terminal],
               fixture.manifest,
               attributes
             )
  end

  test "preserves explicit incomplete finalization for ambiguity and bounded failures" do
    fixture = incomplete_fixture()
    effect = fixture.effect_iri

    assert {:ok, run} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               fixture.segments,
               fixture.manifest,
               finalization_attributes(fixture, %{
                 completeness: :incomplete,
                 ambiguous_effect_iris: [effect],
                 incomplete_reasons: [:cancellation_ambiguity, :provider_unavailable]
               })
             )

    assert run.completeness == :incomplete
    assert run.ambiguous_effect_iris == [effect]
    assert :cancellation_ambiguity in run.incomplete_reasons

    assert {:error, %Error{kind: :conflict, operation: :segmented_open_effects}} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               fixture.segments,
               fixture.manifest,
               finalization_attributes(fixture, %{
                 completeness: :incomplete,
                 ambiguous_effect_iris: [],
                 incomplete_reasons: [:provider_unavailable]
               })
             )

    assert {:error, %Error{kind: :conflict, operation: :segmented_completeness}} =
             SegmentedRun.finalize(
               fixture.attempt_iri,
               fixture.segments,
               fixture.manifest,
               finalization_attributes(fixture, %{
                 completeness: :incomplete,
                 ambiguous_effect_iris: [effect],
                 incomplete_reasons: []
               })
             )
  end

  test "recovers the active head, open effects, and replay identities from RDF after restart" do
    attempt = resource(:execution_attempt, "restart-open")
    {:ok, segment, opening} = EventSegment.open(attempt, %{index: 0})
    graph_target = segment_target!(segment, opening)

    assert {:ok, before_event} =
             graph_target.additions
             |> dataset(segment.graph_iri)
             |> SegmentedRun.recover(attempt)

    assert before_event.resumable?
    assert before_event.active_head.iri == segment.head_iri
    assert before_event.next_sequence == 1
    assert before_event.open_effect_iris == []

    effect = resource(:tool_invocation, "restart-effect")

    {:ok, after_start, successor} =
      EventSegment.append(segment, segment.head_iri, %{
        event_type: :tool_start,
        role: :start,
        resource_iris: [effect],
        opens_effect_iris: [effect]
      })

    open_dataset = dataset(graph_target.additions ++ successor, segment.graph_iri)
    assert {:ok, recovered} = SegmentedRun.recover(open_dataset, attempt)
    assert recovered.active_head.iri == after_start.head_iri
    assert recovered.active_head.event_iri == after_start.head_event_iri
    assert recovered.next_sequence == 2
    assert recovered.open_effect_iris == [effect]
    assert recovered.recorded_resource_iris == [effect]
    assert effect in recovered.idempotency_identities
    assert recovered.continuation_authority == :exact_active_head
  end

  test "treats atomic segment closure as non-resumable and rejects late restore events" do
    attempt = resource(:execution_attempt, "restart-closed")
    {:ok, segment, opening} = EventSegment.open(attempt, %{index: 0})
    graph_target = segment_target!(segment, opening)

    {:ok, segment, terminal_statements} =
      EventSegment.append(segment, segment.head_iri, %{
        event_type: :terminal,
        role: :terminal,
        resource_iris: [resource(:execution_event, "terminal")]
      })

    {:ok, closed} = EventSegment.close(segment, closure(segment))

    assert {:ok, close_target} =
             ExecutionGraph.close_segment_target(
               graph_target.metadata,
               resource(:execution_context, "scope"),
               resource(:command_request, "close-segment"),
               @now,
               :complete,
               EventSegment.closure_statements(closed)
             )

    persisted =
      graph_target.additions
      |> Enum.reject(&metadata_state?(&1, ["Open", "Building"]))
      |> Kernel.++(terminal_statements)
      |> Kernel.++(close_target.additions)
      |> dataset(segment.graph_iri)

    assert {:ok, recovered} = SegmentedRun.recover(persisted, attempt)
    refute recovered.resumable?
    assert recovered.lifecycle_state == :closed
    assert recovered.active_segment == nil
    assert recovered.active_head == nil
    assert recovered.continuation_authority == :none

    assert {:error, %Error{kind: :conflict, operation: :event_segment_closed}} =
             EventSegment.append(closed, closed.head_iri, %{
               event_type: :message,
               role: :message
             })
  end

  test "keeps legacy projection explicit and unchanged" do
    legacy = %{
      protocol: "1.x",
      lifecycle_state: :closed,
      completeness: :incomplete,
      terminal_sequence: 9,
      limitations: ["provider events unavailable"]
    }

    assert {:ok, projection} = SegmentedRun.project(legacy)
    assert projection.protocol_family == :legacy
    assert projection.completeness_claim == :bounded_observable_subset
    assert projection.segment_roots == []
    assert projection.run_root_digest == nil
    assert projection.reconstruction == :stored_representations_only
    refute projection.legacy_rewrite?

    assert {:error, %Error{operation: :run_projection_protocol}} =
             SegmentedRun.project(%{protocol: "unknown"})
  end

  test "builds a guarded FinalizeExecutionRun 2.0 close command" do
    fixture = complete_fixture("finalize-command")

    {:ok, run} =
      SegmentedRun.finalize(
        fixture.attempt_iri,
        fixture.segments,
        fixture.manifest,
        finalization_attributes(fixture)
      )

    scope = resource(:execution_context, "scope")
    command = resource(:command_request, "finalize-run")
    run_graph = run_graph!(fixture.attempt_iri)

    {:ok, open_target} =
      ExecutionGraph.create_target(
        run_graph,
        scope,
        resource(:command_request, "open-run"),
        @now,
        [{fixture.attempt_iri, rdf_type(), RDF.iri(factory("ExecutionAttempt"))}]
      )

    actor = resource(:authorization_grant, "actor")

    attributes = %{
      command_iri: command,
      principal_iri: actor,
      actor_iri: actor,
      repository_scope_iri: scope,
      correlation_iri: resource(:command_request, "correlation"),
      causation_iri: resource(:command_request, "causation"),
      run_graph_iri: run_graph,
      expected_dataset_revision: 5,
      expected_graph_revisions: %{run_graph => 5},
      recorded_at: @now,
      reason: "finalize exact segmented roots"
    }

    assert {:ok, command_envelope} =
             SegmentedRun.finalize_command(run, open_target.metadata, attributes,
               clock: fn -> @now end
             )

    assert command_envelope.command_type == "FinalizeExecutionRun"
    assert command_envelope.command_version == "2.0.0"
    assert List.first(command_envelope.payload.changes).operation == :close
  end

  defp complete_fixture(seed \\ "complete") do
    attempt = resource(:execution_attempt, seed)
    terminal_resource = resource(:execution_event, "#{seed}-terminal-resource")
    manifest = manifest!(attempt, terminal_resource)
    {:ok, first, _} = EventSegment.open(attempt, %{index: 0})

    {:ok, first, _} =
      EventSegment.append(first, first.head_iri, %{
        event_type: :message,
        role: :message,
        resource_iris: [resource(:interaction_message, "#{seed}-message")]
      })

    {:ok, first} = EventSegment.close(first, closure(first))
    {:ok, second, _} = EventSegment.next_segment(first)
    body = List.first(manifest.expected_bodies)
    capture = capture!(manifest, body)

    {:ok, terminal} =
      ContentCapture.attach_to_event([capture], %{
        event_type: :terminal,
        role: :terminal,
        body_role: body.role,
        source_iri: terminal_resource,
        resource_iris: [terminal_resource]
      })

    {:ok, second, _} = EventSegment.append(second, second.head_iri, terminal)
    {:ok, second} = EventSegment.close(second, closure(second))
    {:ok, manifest} = CaptureManifest.close(manifest, [capture])

    %{
      attempt_iri: attempt,
      segments: [first, second],
      manifest: manifest,
      terminal_sequence: second.sequence_end
    }
  end

  defp incomplete_fixture do
    attempt = resource(:execution_attempt, "incomplete")
    terminal_resource = resource(:execution_event, "incomplete-terminal")
    effect = resource(:tool_invocation, "ambiguous-effect")
    manifest = manifest!(attempt, terminal_resource)
    body = List.first(manifest.expected_bodies)
    capture = capture!(manifest, body)
    {:ok, segment, _} = EventSegment.open(attempt, %{index: 0})

    {:ok, segment, _} =
      EventSegment.append(segment, segment.head_iri, %{
        event_type: :tool_start,
        role: :start,
        resource_iris: [effect],
        opens_effect_iris: [effect]
      })

    {:ok, terminal} =
      ContentCapture.attach_to_event([capture], %{
        event_type: :terminal,
        role: :terminal,
        body_role: body.role,
        source_iri: terminal_resource,
        resource_iris: [terminal_resource]
      })

    {:ok, segment, _} = EventSegment.append(segment, segment.head_iri, terminal)

    {:ok, segment} =
      EventSegment.close(
        segment,
        closure(segment, %{
          completeness: :incomplete,
          ambiguous_effect_iris: [effect]
        })
      )

    {:ok, manifest} = CaptureManifest.close(manifest, [capture])

    %{
      attempt_iri: attempt,
      segments: [segment],
      manifest: manifest,
      terminal_sequence: segment.sequence_end,
      effect_iri: effect
    }
  end

  defp manifest!(attempt, terminal_resource) do
    {:ok, manifest} =
      CaptureManifest.new(attempt, %{
        profile: :semantic_history,
        purpose: :managed_continuity,
        policy_revision: DataPolicy.revision(),
        expected_event_classes: [:terminal],
        expected_body_classes: [:model_outcome],
        expected_bodies: [
          %{
            event_iri: terminal_resource,
            event_class: :terminal,
            body_class: :model_outcome,
            role: :output,
            content_identity: digest("#{attempt}-terminal-output")
          }
        ],
        limits: %{
          expected_body_limit: 1,
          segment_event_limit: Guardrails.capacity_profile().segment_event_limit,
          segment_count_limit: Guardrails.capacity_profile().segment_count_limit
        }
      })

    manifest
  end

  defp capture!(manifest, body) do
    {:ok, capture} =
      ContentCapture.new(manifest, body.iri, %{
        event_iri: body.event_iri,
        event_role: body.role,
        content_identity: body.content_identity,
        classification: :model_result,
        purpose: manifest.purpose,
        policy_revision: manifest.policy_revision,
        capture_outcome: :captured,
        representation: :normalized,
        representation_digest: digest(body.content_identity),
        storage_location: :run_event_segment_graph,
        availability: :available,
        retention: :active,
        hold: :not_held,
        limitations: ["normalized provider result"],
        allowed_uses: [:managed_continuity],
        retention_class: :semantic_shell,
        reconstruction: :partial,
        external_provider_availability: :not_external
      })

    capture
  end

  defp finalization_attributes(fixture, overrides \\ %{}) do
    base = %{
      listed_segment_roots: Enum.map(fixture.segments, & &1.root_digest),
      accounted_event_iris: fixture.segments |> Enum.flat_map(& &1.events) |> Enum.map(& &1.iri),
      unsegmented_event_iris: [],
      terminal_sequence: fixture.terminal_sequence,
      cancelled_effect_iris: [],
      ambiguous_effect_iris: [],
      completeness: :complete,
      incomplete_reasons: []
    }

    Map.merge(base, overrides)
  end

  defp closure(segment, overrides \\ %{}) do
    base = %{
      listed_event_iris: Enum.map(segment.events, & &1.iri),
      typed_event_iris: Enum.group_by(segment.events, & &1.event_type, & &1.iri),
      listed_resource_iris: segment.resource_iris,
      listed_content_capture_iris: segment.content_capture_iris,
      carried_effect_iris: [],
      ambiguous_effect_iris: [],
      completeness: :complete
    }

    Map.merge(base, overrides)
  end

  defp segment_target!(segment, opening) do
    {:ok, target} =
      EventSegment.create_target(segment, opening, %{
        repository_scope_iri: resource(:execution_context, "scope"),
        command_iri: resource(:command_request, "open-#{segment.attempt_iri}"),
        recorded_at: @now
      })

    target
  end

  defp dataset(statements, graph) do
    statements
    |> Enum.map(fn statement ->
      case statement do
        {_, _, _, _} -> RDF.Quad.new(statement)
        {subject, predicate, object} -> RDF.Quad.new({subject, predicate, object, graph})
      end
    end)
    |> RDF.Dataset.new()
  end

  defp metadata_state?(statement, labels) do
    case RDF.Quad.new(statement) do
      {_, predicate, object, _} ->
        String.ends_with?(to_string(predicate), ["lifecycleState", "completenessState"]) and
          Enum.any?(labels, &String.ends_with?(to_string(object), &1))

      _other ->
        false
    end
  end

  defp run_graph!(attempt) do
    {:ok, graph} = ExecutionGraph.run_graph(attempt)
    graph
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp rdf_type, do: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  defp factory(term), do: "https://jido.run/ontology/factory##{term}"
end

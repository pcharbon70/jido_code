defmodule JidoCode.Knowledge.Memory.Phase02IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Execution.ImmutableEvent
  alias JidoCode.Knowledge.Execution.SegmentedRun
  alias JidoCode.Knowledge.Memory.CaptureManifest
  alias JidoCode.Knowledge.Memory.ContentCapture
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Security.DataPolicy
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  setup context do
    fixture =
      context
      |> Phase04Fixture.start!()
      |> Phase04Fixture.bootstrap!()
      |> Phase04Fixture.enroll!()

    %{fixture: fixture}
  end

  test "commits and recovers a complete attempt spanning every runtime family and two segments",
       %{
         fixture: fixture
       } do
    state = start_episode!(fixture, "complete-integration")

    assert {:ok, after_attempt_start} = recover!(state)
    assert after_attempt_start.next_sequence == 1
    assert after_attempt_start.open_effect_iris == []

    state = restart_writer(state)
    assert {:ok, before_event_commit} = recover!(state)
    assert before_event_commit.active_head.iri == state.segment.head_iri

    {state, model_start} =
      commit_event!(state, :model_start, %{
        subject_iri: resource(:model_access_profile, "integration-model")
      })

    state = restart_writer(state)
    assert {:ok, after_start_commit} = recover!(state)
    assert after_start_commit.open_effect_iris == [model_start.iri]

    {state, _model_outcome} =
      commit_event!(state, :model_outcome, %{start_iri: model_start.iri})

    {state, _message} = commit_capture_message!(state)

    {state, _transition} =
      commit_event!(state, :transition, %{
        subject_iri: resource(:control_transition, "integration-transition")
      })

    {state, _proposal} =
      commit_event!(state, :proposal, %{
        subject_iri: resource(:action_proposal, "integration-proposal")
      })

    {state, _artifact} =
      commit_event!(state, :artifact, %{
        subject_iri: resource(:generated_artifact, "integration-artifact")
      })

    state = restart_writer(state)
    assert {:ok, still_open_before_closure} = recover!(state)
    assert still_open_before_closure.active_segment.index == 0

    state = close_segment!(state, true, :complete)
    state = restart_writer(state)
    assert {:ok, after_atomic_closure} = recover!(state)
    assert after_atomic_closure.active_segment.index == 1
    assert after_atomic_closure.next_sequence == state.segment.sequence_end + 1

    {state, tool_start} =
      commit_event!(state, :tool_start, %{
        subject_iri: resource(:tool_definition_revision, "integration-tool"),
        capability_iri: resource(:capability_declaration, "integration-capability"),
        approval_iri: resource(:approval_request, "integration-approval"),
        effect_journal_iri: resource(:action_proposal, "integration-effect-journal"),
        dispatch_state: :not_dispatched
      })

    {state, _tool_outcome} =
      commit_event!(state, :tool_outcome, %{start_iri: tool_start.iri})

    {state, _sandbox} =
      commit_event!(state, :sandbox, %{
        subject_iri: resource(:sandbox_activity, "integration-sandbox")
      })

    {state, _provider} =
      commit_event!(state, :provider_observation, %{
        provider_source_iri: resource(:provider_object, "integration-provider-stream"),
        provider_source_order: 0,
        attribution_iri: resource(:observation_activity, "integration-provider-attribution")
      })

    {state, _cancellation} =
      commit_event!(state, :cancellation, %{
        subject_iri: resource(:cancellation_request, "integration-cancellation")
      })

    {state, _retry} =
      commit_event!(state, :retry, %{
        subject_iri: resource(:retry_decision, "integration-retry")
      })

    {state, _terminal} =
      commit_event!(state, :terminal, %{
        subject_iri: resource(:execution_event, "integration-terminal")
      })

    state = close_segment!(state, false, :complete)
    state = restart_writer(state)
    assert {:ok, before_finalization} = recover!(state)
    refute before_finalization.resumable?
    assert before_finalization.lifecycle_state == :closed

    state = finalize_run!(state, :complete, [], [], [])
    dataset = Phase04Fixture.export_dataset!(state.fixture)

    assert state.finalization_receipt.outcome == :committed
    assert count_predicate(dataset, "eventSequence") == 15
    assert count_predicate(dataset, "segmentRootDigest") >= 4
    assert count_predicate(dataset, "captureOutcome") == 1
    assert count_predicate(dataset, "completenessRootDigest") == 1
    assert count_predicate(dataset, "runRootDigest") == 1

    assert {:ok, after_finalization} = SegmentedRun.recover(dataset, state.attempt_iri)
    refute after_finalization.resumable?
    assert Enum.map(after_finalization.segments, & &1.lifecycle_state) == [:closed, :closed]
  end

  test "conflicts concurrent head use, replays idempotently, and finalizes ambiguity explicitly",
       %{
         fixture: fixture
       } do
    state = start_episode!(fixture, "incomplete-integration")
    authority = authority(state)

    {:ok, winner} =
      ImmutableEvent.new(
        authority,
        typed_attributes(state, authority, :tool_start, %{
          subject_iri: resource(:tool_definition_revision, "winner-tool"),
          capability_iri: resource(:capability_declaration, "winner-capability"),
          approval_iri: resource(:approval_request, "winner-approval"),
          effect_journal_iri: resource(:action_proposal, "winner-journal"),
          dispatch_state: :not_dispatched
        })
      )

    {:ok, loser} =
      ImmutableEvent.new(
        authority,
        typed_attributes(state, authority, :tool_start, %{
          subject_iri: resource(:tool_definition_revision, "loser-tool"),
          capability_iri: resource(:capability_declaration, "loser-capability"),
          approval_iri: resource(:approval_request, "loser-approval"),
          effect_journal_iri: resource(:action_proposal, "loser-journal"),
          dispatch_state: :not_dispatched,
          semantic_digest: digest("loser")
        })
      )

    winner_command = event_command!(state, winner)
    loser_command = event_command!(state, loser)

    assert {:ok, winner_receipt} = Writer.execute(state.fixture.writer, winner_command.command)
    assert winner_receipt.outcome == :committed

    assert {:ok, loser_receipt} = Writer.execute(state.fixture.writer, loser_command.command)
    assert loser_receipt.outcome == :conflicted

    assert {:ok, replay} = Writer.execute(state.fixture.writer, winner_command.command)
    assert replay.outcome == :already_committed
    assert replay.dataset_revision == winner_receipt.dataset_revision

    state = %{state | segment: winner_command.segment, counter: state.counter + 1}
    {state, _message} = commit_capture_message!(state)

    {state, _terminal} =
      commit_event!(state, :terminal, %{
        subject_iri: resource(:execution_event, "ambiguous-terminal")
      })

    state = close_segment!(state, false, :incomplete, [winner.iri])

    assert {:error, %Error{kind: :conflict, operation: :unsegmented_execution_event}} =
             SegmentedRun.finalize(
               state.attempt_iri,
               state.segments,
               closed_manifest!(state),
               finalization_attributes(state, :incomplete, [winner.iri], [
                 :cancellation_ambiguity
               ])
               |> Map.put(:unsegmented_event_iris, [loser.iri])
             )

    state =
      finalize_run!(
        state,
        :incomplete,
        [],
        [winner.iri],
        [:cancellation_ambiguity, :provider_unavailable]
      )

    assert state.finalization.completeness == :incomplete
    assert state.finalization.ambiguous_effect_iris == [winner.iri]
    assert state.finalization_receipt.outcome == :committed

    assert {:error, %JidoCode.Knowledge.Error{operation: :command_type}} =
             CommandRegistry.resolve("RecordToolInvocation", "2.0.0")

    assert {:ok, legacy} =
             SegmentedRun.project(%{
               protocol: "1.x",
               lifecycle_state: :closed,
               completeness: :complete,
               terminal_sequence: 3,
               limitations: []
             })

    assert legacy.completeness_claim == :bounded_observable_subset
  end

  defp start_episode!(fixture, seed) do
    attempt = resource(:execution_attempt, seed)
    message_source = resource(:interaction_message, "#{seed}-message-source")
    manifest = manifest!(attempt, message_source)
    {:ok, segment, opening} = Knowledge.open_event_segment(attempt, %{index: 0})
    run_graph = run_graph!(attempt)
    command = resource(:command_request, "#{seed}-attempt-start")

    {:ok, run_target} =
      ExecutionGraph.create_segmented_run_target(
        run_graph,
        fixture.repository_scope,
        command,
        fixture.issued_at,
        [
          {attempt, @rdf_type, RDF.iri(@jf <> "ExecutionAttempt")},
          {attempt, @jf <> "memoryProtocolVersion", RDF.XSD.String.new("2.0.0")}
        ]
      )

    attributes =
      command_attributes(fixture, command, %{run_graph => 0, segment.graph_iri => 0})

    assert {:ok, envelope} =
             Knowledge.start_segmented_execution_attempt(
               segment,
               opening,
               [run_target],
               manifest,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, envelope)
    assert receipt.outcome == :committed

    body = List.first(manifest.expected_bodies)
    capture = capture!(manifest, body)

    %{
      fixture: fixture,
      seed: seed,
      attempt_iri: attempt,
      run_graph_iri: run_graph,
      manifest: manifest,
      capture: capture,
      message_source_iri: message_source,
      segment: segment,
      segments: [],
      counter: 1,
      lease_iri: resource(:execution_lease, "#{seed}-lease"),
      fencing_token: 11,
      start_receipt: receipt
    }
  end

  defp commit_capture_message!(state) do
    authority = authority(state)

    {:ok, event} =
      ImmutableEvent.new(
        authority,
        typed_attributes(state, authority, :message, %{
          subject_iri: state.message_source_iri
        })
      )

    event_attributes =
      event
      |> ImmutableEvent.event_attributes()
      |> Map.put(:body_role, List.first(state.manifest.expected_bodies).role)
      |> Map.put(:source_iri, state.message_source_iri)

    {:ok, event_attributes} =
      ContentCapture.attach_to_event([state.capture], event_attributes)

    result = event_command!(state, event, event_attributes)
    assert {:ok, receipt} = Writer.execute(state.fixture.writer, result.command)
    assert receipt.outcome == :committed

    {%{state | segment: result.segment, counter: state.counter + 1}, event}
  end

  defp commit_event!(state, type, extras) do
    authority = authority(state)
    {:ok, event} = ImmutableEvent.new(authority, typed_attributes(state, authority, type, extras))
    result = event_command!(state, event)
    assert {:ok, receipt} = Writer.execute(state.fixture.writer, result.command)
    assert receipt.outcome == :committed
    {%{state | segment: result.segment, counter: state.counter + 1}, event}
  end

  defp event_command!(state, event, event_attributes \\ nil) do
    attributes =
      command_attributes(
        state.fixture,
        resource(
          :command_request,
          "#{state.seed}-event-#{state.counter}-#{event.event_type}-#{event.iri}"
        ),
        %{state.segment.graph_iri => graph_revision!(state, state.segment.graph_iri)}
      )
      |> Map.put(:expected_segment_revision, graph_revision!(state, state.segment.graph_iri))

    event_attributes = event_attributes || ImmutableEvent.event_attributes(event)

    assert {:ok, result} =
             EventSegment.append_command(
               state.segment,
               event.predecessor_head_iri,
               event_attributes,
               attributes,
               clock: fn -> state.fixture.issued_at end
             )

    result
  end

  defp close_segment!(state, open_next?, completeness, ambiguous \\ []) do
    graph_revision = graph_revision!(state, state.segment.graph_iri)
    run_revision = graph_revision!(state, state.run_graph_iri)
    command = resource(:command_request, "#{state.seed}-close-#{state.segment.index}")

    expected = %{
      state.segment.graph_iri => graph_revision,
      state.run_graph_iri => run_revision
    }

    expected =
      if open_next? do
        {:ok, next_graph} =
          ExecutionGraph.segment_graph(state.attempt_iri, state.segment.index + 1)

        Map.put(expected, next_graph, 0)
      else
        expected
      end

    attributes =
      command_attributes(state.fixture, command, expected)
      |> Map.merge(%{
        segment_metadata: graph_metadata!(state, state.segment.graph_iri),
        run_graph_iri: state.run_graph_iri,
        expected_run_revision: run_revision,
        open_next?: open_next?
      })

    closure = closure(state.segment, completeness, ambiguous)

    assert {:ok, result} =
             EventSegment.close_command(state.segment, closure, attributes,
               clock: fn -> state.fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(state.fixture.writer, result.command)
    assert receipt.outcome == :committed

    %{
      state
      | segment: result.next_segment,
        segments: state.segments ++ [result.segment],
        counter: state.counter + 1
    }
  end

  defp finalize_run!(state, completeness, cancelled, ambiguous, reasons) do
    manifest = closed_manifest!(state)
    attributes = finalization_attributes(state, completeness, ambiguous, reasons)
    attributes = Map.put(attributes, :cancelled_effect_iris, cancelled)

    assert {:ok, finalization} =
             Knowledge.finalize_segmented_run(
               state.attempt_iri,
               state.segments,
               manifest,
               attributes
             )

    command = resource(:command_request, "#{state.seed}-finalize")
    run_revision = graph_revision!(state, state.run_graph_iri)

    command_attributes =
      command_attributes(state.fixture, command, %{state.run_graph_iri => run_revision})
      |> Map.put(:run_graph_iri, state.run_graph_iri)

    assert {:ok, envelope} =
             Knowledge.finalize_segmented_run_command(
               finalization,
               graph_metadata!(state, state.run_graph_iri),
               command_attributes,
               clock: fn -> state.fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(state.fixture.writer, envelope)

    Map.merge(state, %{
      manifest: manifest,
      finalization: finalization,
      finalization_receipt: receipt
    })
  end

  defp finalization_attributes(state, completeness, ambiguous, reasons) do
    %{
      listed_segment_roots: Enum.map(state.segments, & &1.root_digest),
      accounted_event_iris: state.segments |> Enum.flat_map(& &1.events) |> Enum.map(& &1.iri),
      unsegmented_event_iris: [],
      terminal_sequence: state.segments |> List.last() |> Map.fetch!(:sequence_end),
      cancelled_effect_iris: [],
      ambiguous_effect_iris: ambiguous,
      completeness: completeness,
      incomplete_reasons: reasons
    }
  end

  defp closed_manifest!(state) do
    case state.manifest.completeness_root_digest do
      nil ->
        {:ok, manifest} = CaptureManifest.close(state.manifest, [state.capture])
        manifest

      _root ->
        state.manifest
    end
  end

  defp typed_attributes(state, authority, type, extras) do
    Map.merge(
      %{
        event_type: type,
        attempt_iri: state.attempt_iri,
        lease_iri: state.lease_iri,
        fencing_token: state.fencing_token,
        context_iri: authority.context_iri,
        context_revision: authority.context_revision,
        predecessor_head_iri: state.segment.head_iri,
        semantic_digest: digest("#{state.seed}-#{state.counter}-#{type}"),
        resource_revision: "2.0.0",
        occurred_at: state.fixture.issued_at
      },
      extras
    )
  end

  defp authority(state) do
    %{
      attempt_iri: state.attempt_iri,
      lease_iri: state.lease_iri,
      fencing_token: state.fencing_token,
      context_iri: resource(:context_manifest, "#{state.seed}-context-#{state.counter}"),
      context_revision: state.counter
    }
  end

  defp command_attributes(fixture, command, revisions) do
    %{
      command_iri: command,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      repository_scope_iri: fixture.repository_scope,
      correlation_iri: resource(:command_request, "correlation-#{command}"),
      causation_iri: fixture.enrollment_envelope.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: revisions,
      recorded_at: fixture.issued_at,
      reason: "phase 2 total semantic accounting integration"
    }
  end

  defp closure(segment, completeness, ambiguous) do
    %{
      listed_event_iris: Enum.map(segment.events, & &1.iri),
      typed_event_iris: Enum.group_by(segment.events, & &1.event_type, & &1.iri),
      listed_resource_iris: segment.resource_iris,
      listed_content_capture_iris: segment.content_capture_iris,
      carried_effect_iris: [],
      ambiguous_effect_iris: ambiguous,
      completeness: completeness
    }
  end

  defp manifest!(attempt, message_source) do
    {:ok, manifest} =
      Knowledge.capture_manifest(attempt, %{
        profile: :semantic_history,
        purpose: :managed_continuity,
        policy_revision: DataPolicy.revision(),
        expected_event_classes: [:message],
        expected_body_classes: [:interaction_message],
        expected_bodies: [
          %{
            event_iri: message_source,
            event_class: :message,
            body_class: :interaction_message,
            role: :message,
            content_identity: digest("#{attempt}-message")
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
      Knowledge.content_capture(manifest, body.iri, %{
        event_iri: body.event_iri,
        event_role: body.role,
        content_identity: body.content_identity,
        classification: :interaction_content,
        purpose: manifest.purpose,
        policy_revision: manifest.policy_revision,
        capture_outcome: :captured,
        representation: :normalized,
        representation_digest: digest(body.content_identity),
        storage_location: :run_event_segment_graph,
        availability: :available,
        retention: :active,
        hold: :not_held,
        limitations: ["normalized message representation"],
        allowed_uses: [:managed_continuity],
        retention_class: :semantic_shell,
        reconstruction: :partial,
        external_provider_availability: :not_external
      })

    capture
  end

  defp restart_writer(state) do
    Phase04Fixture.kill_writer!(state.fixture)
    %{state | fixture: Phase04Fixture.restart_writer!(state.fixture)}
  end

  defp recover!(state) do
    state.fixture
    |> Phase04Fixture.export_dataset!()
    |> SegmentedRun.recover(state.attempt_iri)
  end

  defp graph_revision!(state, graph),
    do: Phase04Fixture.current_graph_revision!(state.fixture, graph)

  defp graph_metadata!(state, graph) do
    {:ok, metadata} = StoreServer.request(state.fixture.store_server, {:graph_metadata, graph})
    metadata
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

  defp count_predicate(dataset, suffix) do
    Enum.count(RDF.Dataset.quads(dataset), fn {_, predicate, _, _} ->
      String.ends_with?(to_string(predicate), suffix)
    end)
  end
end

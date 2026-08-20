defmodule JidoCode.TestSupport.Phase03RetrievalFixture do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Execution.ImmutableEvent
  alias JidoCode.Knowledge.Memory.ContentCapture
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Security.DataPolicy
  alias JidoCode.TestSupport.Phase05Fixture

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  def complete!(context) do
    fixture = Phase05Fixture.complete!(context)
    attempt = resource(:execution_attempt, "phase-03-retrieval-attempt")
    message_source = resource(:interaction_message, "phase-03-retrieval-message")
    manifest = manifest!(attempt, message_source)
    {:ok, segment, opening} = Knowledge.open_event_segment(attempt, %{index: 0})
    {:ok, run_graph} = ExecutionGraph.run_graph(attempt)
    start_command = resource(:command_request, "phase-03-retrieval-start")

    {:ok, run_target} =
      ExecutionGraph.create_segmented_run_target(
        run_graph,
        fixture.repository_scope,
        start_command,
        fixture.issued_at,
        [
          {attempt, @rdf_type, RDF.iri(@jf <> "ExecutionAttempt")},
          {attempt, @jf <> "memoryProtocolVersion", RDF.XSD.String.new("2.0.0")}
        ]
      )

    assert {:ok, envelope} =
             Knowledge.start_segmented_execution_attempt(
               segment,
               opening,
               [run_target],
               manifest,
               command_attributes(fixture, start_command, %{
                 run_graph => 0,
                 segment.graph_iri => 0
               }),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, envelope)
    body = List.first(manifest.expected_bodies)
    capture = capture!(manifest, body)
    lease = resource(:execution_lease, "phase-03-retrieval-lease")
    context_iri = resource(:context_manifest, "phase-03-retrieval-context")
    signature = digest("phase-03-exact-failure-signature")

    authority = %{
      attempt_iri: attempt,
      lease_iri: lease,
      fencing_token: 3,
      context_iri: context_iri,
      context_revision: 1
    }

    assert {:ok, event} =
             ImmutableEvent.new(authority, %{
               event_type: :message,
               attempt_iri: attempt,
               lease_iri: lease,
               fencing_token: 3,
               context_iri: context_iri,
               context_revision: 1,
               predecessor_head_iri: segment.head_iri,
               semantic_digest: signature,
               resource_revision: "2.0.0",
               occurred_at: fixture.issued_at,
               subject_iri: message_source
             })

    event_attributes =
      event
      |> ImmutableEvent.event_attributes()
      |> Map.put(:body_role, body.role)
      |> Map.put(:source_iri, message_source)

    assert {:ok, event_attributes} = ContentCapture.attach_to_event([capture], event_attributes)
    event_command = resource(:command_request, "phase-03-retrieval-message-event")

    attributes =
      fixture
      |> command_attributes(event_command, %{segment.graph_iri => 1})
      |> Map.put(:expected_segment_revision, 1)

    assert {:ok, result} =
             EventSegment.append_command(
               segment,
               segment.head_iri,
               event_attributes,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, result.command)

    Map.merge(fixture, %{
      memory_attempt: attempt,
      memory_run_graph: run_graph,
      memory_segment_graph: segment.graph_iri,
      memory_segment: result.segment,
      memory_manifest: manifest,
      memory_capture: capture,
      memory_event: event,
      failure_signature: signature
    })
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
      reason: "phase 3 governed retrieval integration"
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

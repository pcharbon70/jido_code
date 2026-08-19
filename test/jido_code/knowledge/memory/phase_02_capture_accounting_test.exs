defmodule JidoCode.Knowledge.Memory.Phase02CaptureAccountingTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Memory.CaptureManifest
  alias JidoCode.Knowledge.Memory.ContentCapture
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @now ~U[2026-08-19 15:00:00Z]

  test "creates an opaque episode manifest with pinned profile, policy, limits, and roots" do
    manifest = manifest!()

    assert manifest.profile == :semantic_history
    assert manifest.purpose == :managed_continuity
    assert manifest.policy_revision == DataPolicy.revision()
    assert length(manifest.expected_bodies) == 4
    assert digest?(manifest.expected_root_digest)
    assert Enum.all?(manifest.expected_bodies, &String.contains?(&1.iri, "/content-body/"))

    refute Enum.any?(CaptureManifest.statements(manifest), fn statement ->
             RDF.Triple.new(statement)
             |> Tuple.to_list()
             |> Enum.any?(&(to_string(&1) =~ "raw prompt"))
           end)

    assert {:error, %Error{operation: :capture_manifest}} =
             CaptureManifest.new(
               manifest.attempt_iri,
               manifest_attributes(%{profile: :diagnostic_capture})
             )

    assert {:error, %Error{operation: :capture_limits}} =
             CaptureManifest.new(
               manifest.attempt_iri,
               manifest_attributes(%{
                 limits: %{
                   expected_body_limit: 4,
                   segment_event_limit: 81,
                   segment_count_limit: 80
                 }
               })
             )
  end

  test "records independent state dimensions and never treats a commitment as replayable" do
    manifest = manifest!()

    [artifact, instruction, message, tool] =
      Enum.sort_by(manifest.expected_bodies, & &1.body_class)

    exact =
      capture!(manifest, artifact, %{
        classification: :artifact_content,
        capture_outcome: :captured,
        representation: :exact,
        storage_location: :run_event_segment_graph,
        availability: :available,
        reconstruction: :exact
      })

    omitted =
      capture!(manifest, instruction, %{
        classification: :prompt_representation,
        capture_outcome: :omitted_by_policy,
        representation: :absent,
        representation_digest: nil,
        storage_location: :omitted,
        availability: :unavailable,
        reconstruction: :impossible
      })

    normalized =
      capture!(manifest, message, %{
        classification: :interaction_content,
        capture_outcome: :captured,
        representation: :normalized,
        storage_location: :run_event_segment_graph,
        availability: :available,
        reconstruction: :partial
      })

    commitment =
      capture!(manifest, tool, %{
        classification: :tool_output,
        capture_outcome: :captured,
        representation: :commitment_only,
        storage_location: :run_event_segment_graph,
        availability: :available,
        reconstruction: :partial
      })

    assert ContentCapture.replayable?(exact)
    refute ContentCapture.replayable?(omitted)
    refute ContentCapture.replayable?(normalized)
    refute ContentCapture.replayable?(commitment)
    assert commitment.availability == :available
    assert commitment.retention == :active
    assert commitment.hold == :not_held
    assert commitment.external_provider_availability == :not_external
    assert length(ContentCapture.statements(omitted)) > 0
  end

  test "rejects forbidden, raw tool, inconsistent redaction, and fabricated availability states" do
    manifest = manifest!()
    body = Enum.find(manifest.expected_bodies, &(&1.body_class == :tool_stdout_stderr))

    assert {:error, %Error{kind: :unauthorized, operation: :capture_secret_value}} =
             ContentCapture.new(
               manifest,
               body.iri,
               capture_attributes(body, %{
                 classification: :secret_value,
                 representation: :commitment_only
               })
             )

    assert {:error, %Error{kind: :unauthorized, operation: :capture_representation}} =
             ContentCapture.new(
               manifest,
               body.iri,
               capture_attributes(body, %{
                 classification: :tool_output,
                 representation: :exact,
                 reconstruction: :exact
               })
             )

    assert {:error, %Error{operation: :capture_outcome_representation}} =
             ContentCapture.new(
               manifest,
               body.iri,
               capture_attributes(body, %{
                 classification: :tool_output,
                 representation: :deterministically_redacted,
                 redaction_receipt_iri: nil
               })
             )

    assert {:error, %Error{operation: :capture_provider_availability}} =
             ContentCapture.new(
               manifest,
               body.iri,
               capture_attributes(body, %{
                 classification: :tool_output,
                 storage_location: :external_provider,
                 external_provider_availability: :not_external
               })
             )
  end

  test "makes missing, duplicate, and unlisted capture entries a manifest closure conflict" do
    manifest = manifest!()
    captures = all_captures(manifest)

    assert {:ok, closed} = CaptureManifest.close(manifest, captures)
    assert digest?(closed.completeness_root_digest)
    assert CaptureManifest.closure_statements(closed) != []

    assert {:error, %Error{kind: :conflict, operation: :capture_manifest_incomplete}} =
             CaptureManifest.close(manifest, Enum.drop(captures, 1))

    assert {:error, %Error{kind: :conflict, operation: :capture_manifest_incomplete}} =
             CaptureManifest.close(manifest, captures ++ [List.first(captures)])

    foreign_manifest = manifest!("foreign-attempt")
    foreign_capture = foreign_manifest |> all_captures() |> List.first()

    assert {:error, %Error{kind: :conflict, operation: :capture_manifest_incomplete}} =
             CaptureManifest.close(manifest, [foreign_capture | Enum.drop(captures, 1)])
  end

  test "creates manifest, run graph, first segment, and sequence-zero head in one command" do
    manifest = manifest!()
    {:ok, segment, opening} = EventSegment.open(manifest.attempt_iri, %{index: 0})
    scope = resource(:execution_context, "scope")
    command = resource(:command_request, "start-segmented-attempt")

    assert {:ok, run_target} =
             ExecutionGraph.create_target(
               run_graph!(manifest.attempt_iri),
               scope,
               command,
               @now,
               [
                 {manifest.attempt_iri, rdf_type(), RDF.iri(factory("ExecutionAttempt"))}
               ]
             )

    assert {:ok, [run_target]} = CaptureManifest.attach_to_run_targets(manifest, [run_target])

    attributes = %{
      command_iri: command,
      principal_iri: resource(:authorization_grant, "actor"),
      actor_iri: resource(:authorization_grant, "actor"),
      repository_scope_iri: scope,
      correlation_iri: resource(:command_request, "correlation"),
      causation_iri: resource(:command_request, "causation"),
      expected_dataset_revision: 0,
      expected_graph_revisions: %{
        run_target.graph_iri => 0,
        segment.graph_iri => 0
      },
      recorded_at: @now,
      reason: "start total semantic accounting"
    }

    assert {:ok, command_envelope} =
             EventSegment.start_attempt_command(
               segment,
               opening,
               [run_target],
               manifest.iri,
               attributes,
               clock: fn -> @now end
             )

    assert command_envelope.command_type == "RecordExecutionAttempt"
    assert command_envelope.command_version == "2.0.0"

    assert Enum.map(command_envelope.payload.changes, & &1.family) == [
             :run_attempt,
             :run_event_segment
           ]
  end

  test "binds content shells to one event role and appends their statements with the event" do
    manifest = manifest!()
    body = Enum.find(manifest.expected_bodies, &(&1.body_class == :interaction_message))

    capture =
      capture!(manifest, body, %{
        classification: :interaction_content,
        capture_outcome: :captured,
        representation: :normalized,
        storage_location: :run_event_segment_graph,
        availability: :available,
        reconstruction: :partial
      })

    event_attributes = %{
      event_type: :message,
      role: :message,
      body_role: body.role,
      source_iri: body.event_iri,
      resource_iris: [body.event_iri]
    }

    assert {:ok, with_capture} = ContentCapture.attach_to_event([capture], event_attributes)
    {:ok, segment, _} = EventSegment.open(manifest.attempt_iri, %{index: 0})
    assert {:ok, next, statements} = EventSegment.append(segment, segment.head_iri, with_capture)
    assert next.content_capture_iris == [capture.iri]

    assert Enum.any?(statements, fn statement ->
             {subject, _, _} = RDF.Triple.new(statement)
             to_string(subject) == capture.iri
           end)

    assert {:error, %Error{operation: :capture_event_ownership}} =
             ContentCapture.attach_to_event([capture], %{event_attributes | body_role: :output})
  end

  defp manifest!(seed \\ "attempt") do
    attempt = resource(:execution_attempt, seed)
    {:ok, manifest} = CaptureManifest.new(attempt, manifest_attributes())
    manifest
  end

  defp manifest_attributes(overrides \\ %{}) do
    specs = [
      body_spec(:instruction_content, :instruction, :model_start, "instruction"),
      body_spec(:interaction_message, :message, :message, "message"),
      body_spec(:tool_stdout_stderr, :output, :tool_outcome, "tool-output"),
      body_spec(:embedded_artifact, :artifact, :artifact, "artifact")
    ]

    base = %{
      profile: :semantic_history,
      purpose: :managed_continuity,
      policy_revision: DataPolicy.revision(),
      expected_event_classes: Enum.map(specs, & &1.event_class),
      expected_body_classes: Enum.map(specs, & &1.body_class),
      expected_bodies: specs,
      limits: %{
        expected_body_limit: length(specs),
        segment_event_limit: Guardrails.capacity_profile().segment_event_limit,
        segment_count_limit: Guardrails.capacity_profile().segment_count_limit
      }
    }

    Map.merge(base, overrides)
  end

  defp body_spec(body_class, role, event_class, seed) do
    %{
      event_iri: resource(:execution_event, seed),
      event_class: event_class,
      body_class: body_class,
      role: role,
      content_identity: digest(seed)
    }
  end

  defp all_captures(manifest) do
    Enum.map(manifest.expected_bodies, fn body ->
      case body.body_class do
        :instruction_content ->
          capture!(manifest, body, %{
            classification: :prompt_representation,
            capture_outcome: :omitted_by_policy,
            representation: :absent,
            representation_digest: nil,
            storage_location: :omitted,
            availability: :unavailable,
            reconstruction: :impossible
          })

        :interaction_message ->
          capture!(manifest, body, %{
            classification: :interaction_content,
            capture_outcome: :captured,
            representation: :normalized,
            storage_location: :run_event_segment_graph,
            availability: :available,
            reconstruction: :partial
          })

        :tool_stdout_stderr ->
          capture!(manifest, body, %{
            classification: :tool_output,
            capture_outcome: :captured,
            representation: :commitment_only,
            storage_location: :run_event_segment_graph,
            availability: :available,
            reconstruction: :partial
          })

        :embedded_artifact ->
          capture!(manifest, body, %{
            classification: :artifact_content,
            capture_outcome: :captured,
            representation: :exact,
            storage_location: :run_event_segment_graph,
            availability: :available,
            reconstruction: :exact
          })
      end
    end)
  end

  defp capture!(manifest, body, overrides) do
    {:ok, capture} = ContentCapture.new(manifest, body.iri, capture_attributes(body, overrides))
    capture
  end

  defp capture_attributes(body, overrides) do
    base = %{
      event_iri: body.event_iri,
      event_role: body.role,
      content_identity: body.content_identity,
      classification: :internal,
      purpose: :managed_continuity,
      policy_revision: DataPolicy.revision(),
      capture_outcome: :captured,
      representation: :commitment_only,
      representation_digest: digest(body.content_identity),
      storage_location: :run_event_segment_graph,
      availability: :available,
      retention: :active,
      hold: :not_held,
      redaction_receipt_iri: nil,
      limitations: ["semantic representation only"],
      allowed_uses: [:managed_continuity],
      retention_class: :semantic_shell,
      reconstruction: :partial,
      external_provider_availability: :not_external
    }

    Map.merge(base, overrides)
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

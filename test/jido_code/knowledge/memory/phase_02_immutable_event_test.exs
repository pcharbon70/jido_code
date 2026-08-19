defmodule JidoCode.Knowledge.Memory.Phase02ImmutableEventTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.ImmutableEvent
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-19 16:00:00Z]

  test "records tool start and outcome as distinct fenced resources on one sequence" do
    {:ok, segment, _} = open_segment()
    authority = authority(segment)

    assert {:ok, start} =
             ImmutableEvent.new(
               authority,
               event_attributes(authority, segment, :tool_start, %{
                 subject_iri: resource(:tool_definition_revision, "tool-v2"),
                 capability_iri: resource(:capability_declaration, "tool-capability"),
                 approval_iri: resource(:approval_request, "tool-approval"),
                 effect_journal_iri: resource(:action_proposal, "effect-journal"),
                 dispatch_state: :not_dispatched
               })
             )

    assert start.command_type == "RecordToolInvocationStart"
    assert start.role == :start
    assert Enum.any?(ImmutableEvent.statements(start), &predicate?(&1, "effectJournal"))

    assert {:ok, segment, _} =
             EventSegment.append(
               segment,
               segment.head_iri,
               ImmutableEvent.event_attributes(start)
             )

    assert segment.open_effect_iris == [start.iri]

    next_authority = %{authority | context_revision: 1}

    assert {:ok, outcome} =
             ImmutableEvent.new(
               next_authority,
               event_attributes(next_authority, segment, :tool_outcome, %{
                 start_iri: start.iri
               })
             )

    assert outcome.iri != start.iri
    assert outcome.command_type == "RecordToolOutcome"
    assert Enum.any?(ImmutableEvent.statements(outcome), &object?(&1, start.iri))

    assert {:ok, closed_effects, _} =
             EventSegment.append(
               segment,
               segment.head_iri,
               ImmutableEvent.event_attributes(outcome)
             )

    assert closed_effects.open_effect_iris == []

    assert Enum.map(closed_effects.events, & &1.event_type) == [
             :attempt_started,
             :tool_start,
             :tool_outcome
           ]
  end

  test "rejects stale fences, missing approval/journal, and post-dispatch tool starts" do
    {:ok, segment, _} = open_segment()
    authority = authority(segment)

    base =
      event_attributes(authority, segment, :tool_start, %{
        subject_iri: resource(:tool_definition_revision, "tool"),
        capability_iri: resource(:capability_declaration, "capability"),
        approval_iri: resource(:approval_request, "approval"),
        effect_journal_iri: resource(:action_proposal, "journal"),
        dispatch_state: :not_dispatched
      })

    assert {:error, %Error{operation: :immutable_execution_event}} =
             ImmutableEvent.new(authority, %{base | fencing_token: authority.fencing_token + 1})

    assert {:error, %Error{operation: :tool_start_authority}} =
             ImmutableEvent.new(authority, %{base | approval_iri: nil})

    assert {:error, %Error{operation: :tool_start_authority}} =
             ImmutableEvent.new(authority, %{base | effect_journal_iri: nil})

    assert {:error, %Error{operation: :tool_start_authority}} =
             ImmutableEvent.new(authority, %{base | dispatch_state: :dispatched})
  end

  test "uses event-specific 2.0 command names while legacy tool resolution remains historical" do
    assert {:ok, %{version: "1.6.0"}} =
             CommandRegistry.resolve("RecordToolInvocation", "1.6.0")

    assert {:ok, %{version: "1.8.0"}} =
             CommandRegistry.resolve("RecordToolInvocation", "1.8.0")

    assert {:error, %Error{operation: :command_type}} =
             CommandRegistry.resolve("RecordToolInvocation", "2.0.0")

    assert {:ok, tool_start} =
             CommandRegistry.resolve("RecordToolInvocationStart", "2.0.0")

    assert tool_start.graph_families == [:run_event_segment]
    assert :before_dispatch in tool_start.preconditions

    for type <- ImmutableEvent.types() do
      {:ok, segment, _} = open_segment("registry-#{type}")
      authority = authority(segment)
      attributes = attributes_for_type(authority, segment, type)
      assert {:ok, event} = ImmutableEvent.new(authority, attributes)
      assert {:ok, definition} = CommandRegistry.resolve(event.command_type, "2.0.0")
      assert :run_event_segment in definition.graph_families
    end
  end

  test "puts transitions, proposals, sandbox, artifacts, messages, cancellation, retry, and terminal on one head chain" do
    types = [
      :transition,
      :proposal,
      :sandbox,
      :artifact,
      :message,
      :cancellation,
      :retry,
      :terminal
    ]

    {:ok, initial, _} = open_segment("all-event-families")

    final =
      Enum.reduce(types, initial, fn type, segment ->
        authority = authority(segment)

        assert {:ok, event} =
                 ImmutableEvent.new(authority, attributes_for_type(authority, segment, type))

        assert {:ok, next, _} =
                 EventSegment.append(
                   segment,
                   segment.head_iri,
                   ImmutableEvent.event_attributes(event)
                 )

        next
      end)

    assert Enum.map(final.events, & &1.event_type) == [:attempt_started | types]
    assert Enum.map(final.events, & &1.sequence) == Enum.to_list(0..length(types))
    assert length(final.resource_iris) == length(types)
  end

  test "keeps provider source ordering and requires explicit attribution" do
    {:ok, segment, _} = open_segment("provider-order")
    authority = authority(segment)
    source = resource(:provider_object, "provider-stream")
    attribution = resource(:observation_activity, "provider-attribution")

    first_attrs =
      event_attributes(authority, segment, :provider_observation, %{
        provider_source_iri: source,
        provider_source_order: 10,
        attribution_iri: attribution
      })

    assert {:ok, first} = ImmutableEvent.new(authority, first_attrs)

    assert {:ok, segment, _} =
             EventSegment.append(
               segment,
               segment.head_iri,
               ImmutableEvent.event_attributes(first)
             )

    next_authority = authority(segment)

    assert {:ok, gap} =
             ImmutableEvent.new(
               next_authority,
               event_attributes(next_authority, segment, :provider_observation, %{
                 provider_source_iri: source,
                 provider_source_order: 12,
                 attribution_iri: attribution
               })
             )

    command_attributes = command_attributes(segment)

    assert {:error, %Error{kind: :conflict, operation: :immutable_event_predecessor}} =
             ImmutableEvent.record_command(
               gap,
               segment,
               command_attributes,
               clock: fn -> @now end
             )

    assert {:error, %Error{operation: :provider_observation_event}} =
             ImmutableEvent.new(
               next_authority,
               event_attributes(next_authority, segment, :provider_observation, %{
                 provider_source_iri: source,
                 provider_source_order: 11,
                 attribution_iri: nil
               })
             )

    assert {:ok, second} =
             ImmutableEvent.new(
               next_authority,
               event_attributes(next_authority, segment, :provider_observation, %{
                 provider_source_iri: source,
                 provider_source_order: 11,
                 attribution_iri: attribution
               })
             )

    assert {:ok, %{command: command}} =
             ImmutableEvent.record_command(
               second,
               segment,
               command_attributes,
               clock: fn -> @now end
             )

    assert command.command_type == "RecordProviderObservation"
  end

  test "links later activities without moving them out of their accepted families" do
    {:ok, segment, _} = open_segment("accepted-related-family")
    authority = authority(segment)
    evidence_graph = graph!(:evidence, %{repository: resource(:execution_context, "repository")})
    verification = resource(:verification_activity, "verification")

    related = %{
      role: :verification,
      resource_iri: verification,
      graph_iri: evidence_graph
    }

    assert {:ok, event} =
             ImmutableEvent.new(
               authority,
               attributes_for_type(authority, segment, :lifecycle_observation)
               |> Map.put(:related, related)
             )

    assert event.related_graph_iri == evidence_graph
    assert Enum.any?(ImmutableEvent.statements(event), &object?(&1, verification))
    assert {:ok, :evidence} = GraphRegistry.identify(evidence_graph)

    memory_graph = graph!(:memory, %{repository: resource(:execution_context, "repository")})

    assert {:error, %Error{operation: :immutable_event_related_family}} =
             ImmutableEvent.new(
               authority,
               attributes_for_type(authority, segment, :lifecycle_observation)
               |> Map.put(:related, %{related | graph_iri: memory_graph})
             )
  end

  defp attributes_for_type(authority, segment, type) when type in [:model_start, :tool_start] do
    extras =
      case type do
        :model_start ->
          %{subject_iri: resource(:model_access_profile, "model")}

        :tool_start ->
          %{
            subject_iri: resource(:tool_definition_revision, "tool"),
            capability_iri: resource(:capability_declaration, "capability"),
            approval_iri: resource(:approval_request, "approval"),
            effect_journal_iri: resource(:action_proposal, "journal"),
            dispatch_state: :not_dispatched
          }
      end

    event_attributes(authority, segment, type, extras)
  end

  defp attributes_for_type(authority, segment, type)
       when type in [:model_outcome, :tool_outcome] do
    event_attributes(authority, segment, type, %{
      start_iri:
        resource(
          if(type == :model_outcome, do: :model_invocation, else: :tool_invocation),
          "start"
        )
    })
  end

  defp attributes_for_type(authority, segment, :provider_observation) do
    event_attributes(authority, segment, :provider_observation, %{
      provider_source_iri: resource(:provider_object, "provider"),
      provider_source_order: 0,
      attribution_iri: resource(:observation_activity, "attribution")
    })
  end

  defp attributes_for_type(authority, segment, type) do
    event_attributes(authority, segment, type, %{
      subject_iri: resource(:execution_event, "#{type}-subject")
    })
  end

  defp event_attributes(authority, segment, type, extras) do
    Map.merge(
      %{
        event_type: type,
        attempt_iri: authority.attempt_iri,
        lease_iri: authority.lease_iri,
        fencing_token: authority.fencing_token,
        context_iri: authority.context_iri,
        context_revision: authority.context_revision,
        predecessor_head_iri: segment.head_iri,
        semantic_digest: digest("#{type}-#{segment.sequence_end}"),
        resource_revision: "2.0.0",
        occurred_at: @now
      },
      extras
    )
  end

  defp authority(segment) do
    %{
      attempt_iri: segment.attempt_iri,
      lease_iri: resource(:execution_lease, "lease"),
      fencing_token: 7,
      context_iri: resource(:context_manifest, "context-#{segment.sequence_end}"),
      context_revision: segment.sequence_end
    }
  end

  defp command_attributes(segment) do
    command = resource(:command_request, "command-#{segment.sequence_end}")
    actor = resource(:authorization_grant, "actor")

    %{
      command_iri: command,
      principal_iri: actor,
      actor_iri: actor,
      repository_scope_iri: resource(:execution_context, "scope"),
      correlation_iri: resource(:command_request, "correlation"),
      causation_iri: resource(:command_request, "causation"),
      expected_segment_revision: segment.sequence_end + 1,
      expected_dataset_revision: segment.sequence_end + 1,
      expected_graph_revisions: %{segment.graph_iri => segment.sequence_end + 1},
      recorded_at: @now,
      authority_guards: [
        {:subject_present, segment.graph_iri, segment.attempt_iri}
      ],
      reason: "record immutable typed execution event"
    }
  end

  defp open_segment(seed \\ "immutable-event") do
    EventSegment.open(resource(:execution_attempt, seed), %{index: 0})
  end

  defp graph!(family, scopes) do
    {:ok, graph} = GraphRegistry.graph_iri(family, scopes)
    graph
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp predicate?(statement, suffix) do
    {_, predicate, _} = RDF.Triple.new(statement)
    String.ends_with?(to_string(predicate), suffix)
  end

  defp object?(statement, expected) do
    {_, _, object} = RDF.Triple.new(statement)
    to_string(object) == expected
  end
end

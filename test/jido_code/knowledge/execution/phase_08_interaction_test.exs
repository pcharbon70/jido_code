defmodule JidoCode.Knowledge.Execution.Phase08InteractionTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture

  setup context do
    {:ok, fixture: Phase07SchedulingFixture.leased!(context)}
  end

  test "persists bounded interaction chronology without directly mutating work", %{
    fixture: fixture
  } do
    opened_at = DateTime.add(fixture.issued_at, 200, :second)

    session_attributes = %{
      scope_iri: fixture.schedulable_task.iri,
      enrollment_iri: fixture.enrollment.iri,
      participants: [fixture.actor],
      audiences: [fixture.actor],
      authority_iri: fixture.actor,
      purpose: "Clarify execution constraints",
      opened_at: opened_at,
      idempotency_key: "phase-08-interaction"
    }

    assert {:ok, session} = Knowledge.interaction_session(session_attributes)

    open_attributes =
      fixture
      |> attributes(900, fixture.lease.iri, "open interaction session", opened_at)

    assert {:ok, opened} =
             Knowledge.open_interaction_session(session, open_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, opened.command)
    assert {:ok, session_resolution} = Transition.resolve(opened.transitions)
    assert session_resolution.current_state == :active

    first =
      message!(fixture, opened.session, 0, %{
        content: "Please keep network access disabled.",
        classification: :internal,
        intent: :clarification,
        recorded_at: DateTime.add(opened_at, 1, :second),
        provenance_iri: opened.command.command_iri
      })

    first_attributes =
      fixture
      |> attributes(901, opened.command.command_iri, "record clarification", first.recorded_at)

    assert {:ok, first_record} =
             Knowledge.record_interaction_message(first, session_resolution, first_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, first_record.command)

    second =
      message!(fixture, opened.session, 1, %{
        content: "this value must not be persisted",
        classification: :redacted,
        intent: :steering_request,
        recorded_at: DateTime.add(opened_at, 2, :second),
        provenance_iri: first.iri,
        reply_to_iri: first.iri,
        resulting_command_iri: first_record.command.command_iri
      })

    second_attributes =
      fixture
      |> attributes(902, first.iri, "record redacted steering request", second.recorded_at)

    assert {:ok, second_record} =
             Knowledge.record_interaction_message(second, session_resolution, second_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, second_record.command)

    assert {:ok, timeline_result} =
             query(fixture, :interaction_timeline, opened.session.iri)

    assert {:ok, projection} =
             Knowledge.project_interaction(timeline_result, %{
               graph_iri: fixture.control_graph,
               session_iri: opened.session.iri
             })

    assert projection.data.count == 2
    assert Enum.map(projection.data.messages, & &1.sequence) == [0, 1]
    assert Enum.at(projection.data.messages, 1).redacted?
    assert Enum.at(projection.data.messages, 1).content == "[REDACTED]"
    assert Enum.at(projection.data.messages, 1).reply_to_iri == first.iri

    assert {:ok, goal_result} =
             QueryRunner.execute(
               :transition_endpoint,
               QueryCatalog.execution_version(),
               %{graph: fixture.control_graph, resource: fixture.goal.iri},
               fixture.authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: second.recorded_at
             )

    assert Enum.any?(goal_result.data, fn row ->
             decoded(row, "state") ==
               "https://jido.run/ontology/concept/GoalApproved"
           end)
  end

  test "closes sessions through a transition and rejects stale message appends", %{
    fixture: fixture
  } do
    recorded_at = DateTime.add(fixture.issued_at, 220, :second)

    {:ok, session} =
      Knowledge.interaction_session(%{
        scope_iri: fixture.schedulable_task.iri,
        enrollment_iri: fixture.enrollment.iri,
        participants: [fixture.actor],
        audiences: [fixture.actor],
        authority_iri: fixture.actor,
        purpose: "Cancellation coordination",
        opened_at: recorded_at,
        idempotency_key: "phase-08-close-interaction"
      })

    open_attributes = attributes(fixture, 910, fixture.lease.iri, "open session", recorded_at)

    {:ok, opened} =
      Knowledge.open_interaction_session(session, open_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, opened.command)
    {:ok, resolution} = Transition.resolve(opened.transitions)

    close_attributes =
      attributes(
        fixture,
        911,
        opened.session.iri,
        "close session",
        DateTime.add(recorded_at, 1, :second)
      )
      |> Map.put(:action, :close)

    assert {:ok, closing} =
             Knowledge.transition_interaction_session(
               opened.session,
               resolution,
               close_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, closing.command)
    assert {:ok, closed} = Transition.resolve(opened.transitions ++ [closing.transition])
    assert closed.current_state == :closed

    stale_message =
      message!(fixture, opened.session, 0, %{
        content: "late cancellation request",
        classification: :internal,
        intent: :cancellation_request,
        recorded_at: DateTime.add(recorded_at, 2, :second),
        provenance_iri: closing.command.command_iri
      })

    stale_attributes =
      attributes(
        fixture,
        912,
        closing.command.command_iri,
        "reject stale message",
        stale_message.recorded_at
      )

    assert {:ok, stale_command} =
             Knowledge.record_interaction_message(stale_message, resolution, stale_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :conflicted, retry: :refresh}} =
             Writer.execute(fixture.writer, stale_command.command)
  end

  test "rejects secret-bearing message content", %{fixture: fixture} do
    assert {:error, %{operation: :interaction_message_content}} =
             Knowledge.interaction_message(%{
               session_iri: fixture.schedulable_task.iri,
               sender_iri: fixture.actor,
               audiences: [fixture.actor],
               sequence: 0,
               content: "-----BEGIN PRIVATE KEY-----",
               classification: :confidential,
               intent: :clarification,
               recorded_at: fixture.issued_at,
               provenance_iri: fixture.lease.iri
             })
  end

  defp message!(fixture, session, sequence, values) do
    {:ok, message} =
      Knowledge.interaction_message(
        Map.merge(
          %{
            session_iri: session.iri,
            sender_iri: fixture.actor,
            audiences: [fixture.actor],
            sequence: sequence,
            reply_to_iri: nil,
            resulting_command_iri: nil
          },
          values
        )
      )

    message
  end

  defp attributes(fixture, sequence, cause, reason, recorded_at) do
    fixture
    |> Phase07Fixture.base_attributes(sequence, cause, reason)
    |> Map.merge(%{
      graph_iri: fixture.control_graph,
      expected_graph_revision:
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.control_graph),
      recorded_at: recorded_at
    })
  end

  defp query(fixture, name, resource) do
    QueryRunner.execute(
      name,
      QueryCatalog.execution_version(),
      %{graph: fixture.control_graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp decoded(row, key) do
    case row[key] do
      %{value: value} -> value
      value -> value
    end
  end
end

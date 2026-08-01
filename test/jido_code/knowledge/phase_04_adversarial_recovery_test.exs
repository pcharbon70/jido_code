defmodule JidoCode.Knowledge.Phase04AdversarialRecoveryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandStatus
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  setup context do
    fixture =
      context
      |> Phase04Fixture.start!()
      |> Phase04Fixture.bootstrap!()
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()

    %{fixture: fixture}
  end

  test "serializes equivalent, divergent, and stale command races deterministically", %{
    fixture: fixture
  } do
    equivalent = proposal_envelope!(fixture, 50, "race-equivalent")

    results =
      [equivalent, equivalent]
      |> Task.async_stream(
        &Writer.execute(fixture.writer, &1),
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {:ok, receipt}} -> receipt end)

    assert Enum.sort(Enum.map(results, & &1.outcome)) == [:already_committed, :committed]
    assert Enum.uniq(Enum.map(results, & &1.dataset_revision)) == [5]
    assert StoreServer.summary(fixture.store_server).dataset_revision == 5

    divergent =
      proposal_envelope!(fixture, 51, "race-equivalent",
        command_iri: equivalent.command_iri,
        expected_dataset_revision: 4,
        expected_graph_revision: 1
      )

    assert {:ok, conflict} = Writer.execute(fixture.writer, divergent)
    assert conflict.outcome == :conflicted
    assert StoreServer.summary(fixture.store_server).dataset_revision == 5

    first = proposal_envelope!(fixture, 52, "stale-race-one")
    second = proposal_envelope!(fixture, 53, "stale-race-two")

    stale_results =
      [first, second]
      |> Task.async_stream(
        &Writer.execute(fixture.writer, &1),
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {:ok, receipt}} -> receipt end)

    assert Enum.count(stale_results, &(&1.outcome == :committed)) == 1
    assert Enum.count(stale_results, &(&1.outcome == :conflicted)) == 1
    assert StoreServer.summary(fixture.store_server).dataset_revision == 6
    assert Phase04Fixture.current_graph_revision!(fixture, fixture.control_graph) == 3
  end

  test "recovers authoritative absence and presence across writer and client death", %{
    fixture: fixture
  } do
    absent = proposal_envelope!(fixture, 60, "writer-killed-before-commit")
    writer_pid = GenServer.whereis(fixture.writer)
    :ok = :sys.suspend(writer_pid)
    parent = self()

    {caller, caller_monitor} =
      spawn_monitor(fn ->
        send(parent, {:command_queued, self()})
        send(parent, {:command_result, Writer.execute(fixture.writer, absent)})
      end)

    assert_receive {:command_queued, ^caller}
    assert eventually(fn -> message_queue_length(writer_pid) > 0 end)
    Phase04Fixture.kill_writer!(fixture)
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}
    assert_receive {:command_result, {:ok, unavailable}}
    assert unavailable.outcome == :unavailable

    fixture = Phase04Fixture.restart_writer!(fixture)

    assert {:ok, %CommandStatus{outcome: :unknown}} =
             Writer.command_status(fixture.writer, absent)

    assert StoreServer.summary(fixture.store_server).dataset_revision == 4

    committed = proposal_envelope!(fixture, 61, "writer-killed-after-commit")
    assert {:ok, receipt} = Writer.execute(fixture.writer, committed)
    assert receipt.outcome == :committed

    Phase04Fixture.kill_writer!(fixture)
    fixture = Phase04Fixture.restart_writer!(fixture)

    assert {:ok, %CommandStatus{outcome: :committed} = recovered} =
             Writer.command_status(fixture.writer, committed)

    assert recovered.dataset_revision == receipt.dataset_revision
    assert {:ok, replay} = Writer.execute(fixture.writer, committed)
    assert replay.outcome == :already_committed
    assert StoreServer.summary(fixture.store_server).dataset_revision == 5

    timed_out = proposal_envelope!(fixture, 62, "response-lost-after-dispatch")
    writer_pid = GenServer.whereis(fixture.writer)
    :ok = :sys.suspend(writer_pid)

    assert {:ok, unknown} =
             Writer.execute(fixture.writer, timed_out,
               operation_timeout: 5_000,
               caller_timeout: 20
             )

    assert unknown.outcome == :unknown_after_timeout
    :ok = :sys.resume(writer_pid)

    assert eventually(fn ->
             match?(
               {:ok, %CommandStatus{outcome: :committed}},
               Writer.command_status(fixture.writer, timed_out)
             )
           end)

    assert {:ok, timed_out_replay} = Writer.execute(fixture.writer, timed_out)
    assert timed_out_replay.outcome == :already_committed
    assert StoreServer.summary(fixture.store_server).dataset_revision == 6
  end

  test "converges under dropped, duplicated, delayed, and reordered wake-up hints", %{
    fixture: fixture
  } do
    assert :ok = ChangeFeed.subscribe(fixture.repository_scope)

    first = proposal_envelope!(fixture, 70, "notification-one")
    assert {:ok, first_receipt} = Writer.execute(fixture.writer, first)
    assert_receive {:jido_code_change, %ChangeEvent{} = first_event}
    assert first_event.dataset_revision == first_receipt.dataset_revision

    second = proposal_envelope!(fixture, 71, "notification-two")
    assert {:ok, second_receipt} = Writer.execute(fixture.writer, second)
    assert_receive {:jido_code_change, %ChangeEvent{} = second_event}
    assert second_event.dataset_revision == second_receipt.dataset_revision

    reordered = [second_event, first_event, second_event]

    final_revision =
      Enum.reduce(reordered, 4, fn event, known_revision ->
        case ChangeFeed.requery(event, known_revision) do
          {:refresh, _hint} -> StoreServer.summary(fixture.store_server).dataset_revision
          :ignore -> known_revision
        end
      end)

    assert final_revision == 6
    assert ChangeFeed.requery(first_event, final_revision) == :ignore

    dropped_first_revision =
      case ChangeFeed.requery(second_event, 4) do
        {:refresh, _hint} -> StoreServer.summary(fixture.store_server).dataset_revision
        :ignore -> 4
      end

    assert dropped_first_revision == 6
    assert StoreServer.summary(fixture.store_server).dataset_revision > 4
  end

  test "conceals guessed outcomes and excludes fixture secrets from public surfaces", %{
    fixture: fixture
  } do
    secret = "phase04-secret=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    envelope = proposal_envelope!(fixture, 80, secret, reason: secret)
    assert :ok = ChangeFeed.subscribe(fixture.repository_scope)

    log =
      capture_log(fn ->
        assert {:ok, receipt} = Writer.execute(fixture.writer, envelope)
        assert receipt.outcome == :committed
        refute inspect(receipt) =~ secret
      end)

    assert_receive {:jido_code_change, %ChangeEvent{} = event}
    refute inspect(event) =~ secret
    refute log =~ secret
    refute inspect(CommandEnvelope.safe_map(envelope)) =~ secret

    dataset = Phase04Fixture.export_dataset!(fixture)
    canonical = RDF.NQuads.write_string!(dataset, sort: true)
    refute canonical =~ secret

    guessed_actor = Phase04Fixture.resource!("phase-04-guessed-actor")

    guessed =
      %{
        envelope
        | command_iri: Phase04Fixture.local!(:command, 81),
          principal_iri: guessed_actor,
          actor_iri: guessed_actor,
          idempotency_key: "guessed-key"
      }

    assert {:ok, %CommandStatus{outcome: :inaccessible} = concealed} =
             Writer.command_status(fixture.writer, guessed)

    assert concealed.command_iri == nil

    assert {:error, %Error{kind: :unauthorized}} =
             StoreServer.request(
               fixture.store_server,
               {:command_outcome,
                %{
                  audit_graph: fixture.graphs.audit,
                  command_iri: envelope.command_iri,
                  receipt_iri: envelope.command_iri <> "/receipt"
                }}
             )
  end

  defp proposal_envelope!(fixture, timestamp, idempotency_key, options \\ []) do
    goal = Phase04Fixture.local!(:goal, timestamp)

    changes = [
      %{
        family: :repository_control,
        graph_iri: fixture.control_graph,
        operation: :append,
        metadata: %{lifecycle_state: :open},
        additions: [
          {goal, @rdf_type, RDF.iri(@jf <> "Goal")},
          {goal, @jf <> "about", RDF.iri(fixture.repository)}
        ],
        supersessions: [],
        invalidations: [],
        removals: []
      }
    ]

    Phase04Fixture.envelope!(
      fixture,
      "ProposeGoal",
      Keyword.get(options, :command_iri, Phase04Fixture.local!(:command, timestamp)),
      fixture.repository_scope,
      idempotency_key,
      %{
        fixture.control_graph =>
          Keyword.get(
            options,
            :expected_graph_revision,
            Phase04Fixture.current_graph_revision!(fixture, fixture.control_graph)
          )
      },
      changes,
      expected_dataset_revision:
        Keyword.get(
          options,
          :expected_dataset_revision,
          StoreServer.summary(fixture.store_server).dataset_revision
        ),
      reason: Keyword.get(options, :reason, "phase 04 adversarial fixture")
    )
  end

  defp eventually(callback, attempts \\ 500)
  defp eventually(callback, 0), do: callback.()

  defp eventually(callback, attempts) do
    if callback.() do
      true
    else
      Process.sleep(10)
      eventually(callback, attempts - 1)
    end
  end

  defp message_queue_length(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, length} -> length
      nil -> 0
    end
  end
end

defmodule JidoCode.Knowledge.ChangeFeedTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.CommandStatus
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @issued ~U[2026-07-31 18:00:00Z]

  test "derives bounded opaque topics and emits only revision wake-up metadata" do
    repository = resource!("change-feed-repository")
    scope = scope!("change-feed-repository")

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    {:ok, audit_graph} =
      GraphRegistry.graph_iri(:security_audit, %{period: "2026-07"})

    envelope = envelope!(repository, scope, control_graph)

    receipt =
      CommandReceipt.success(:committed, %{
        command_iri: envelope.command_iri,
        receipt_iri: envelope.command_iri <> "/receipt",
        change_set_iri: deterministic!(:change_set, "change-feed-fixture"),
        dataset_revision: 8,
        graph_revisions: %{
          control_graph => %{prior: 2, new: 3},
          audit_graph => %{prior: 4, new: 5}
        },
        affected_graphs: [control_graph, audit_graph],
        assertion_count: 2,
        supersession_count: 0,
        actor_iri: envelope.actor_iri,
        committed_at: @issued
      })

    assert {:ok, topic} = ChangeFeed.topic(scope)
    assert byte_size(topic) == 85
    refute String.contains?(topic, scope)

    assert {:ok, event} = ChangeEvent.new(envelope, receipt)
    assert event.dataset_revision == 8
    assert event.command_class == "ProposeGoal"
    assert event.scope_iri == scope

    assert event.affected_graphs == [
             %{family: :repository_control, revision: 3},
             %{family: :security_audit, revision: 5}
           ]

    safe = ChangeEvent.safe_map(event)
    refute Map.has_key?(safe, :command_iri)
    refute Map.has_key?(safe, :actor_iri)
    refute inspect(safe) =~ "change-feed-secret"

    assert {:refresh, %{after_dataset_revision: 6, hinted_dataset_revision: 8}} =
             ChangeFeed.requery(event, 6)

    assert :ignore = ChangeFeed.requery(event, 8)
    assert :ignore = ChangeFeed.requery(event, 9)
  end

  test "drops non-committed notifications and rejects invalid scope topics" do
    assert :dropped =
             ChangeFeed.publish(
               :invalid_envelope,
               CommandReceipt.failure(:invalid),
               JidoCode.PubSub
             )

    assert {:error, %{operation: :change_scope}} = ChangeFeed.topic("not an iri")

    assert CommandStatus.outcomes() == [
             :unknown,
             :staged,
             :committed,
             :rejected,
             :superseded,
             :inaccessible
           ]
  end

  defp envelope!(repository, scope, control_graph) do
    actor = resource!("change-feed-actor")
    goal = local!(:goal, 1)

    {:ok, envelope} =
      CommandEnvelope.new(
        %{
          command_type: "ProposeGoal",
          command_version: "1.0.0",
          command_iri: local!(:command, 3),
          principal_iri: actor,
          actor_iri: actor,
          delegated_agent_iri: nil,
          delegation_iri: nil,
          scope_iri: scope,
          idempotency_key: "change-feed-secret",
          correlation_iri: local!(:activity, 4),
          causation_iri: local!(:command, 5),
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision: 7,
          expected_graph_revisions: %{control_graph => 2},
          reason: "sensitive fixture reason",
          payload: %{
            changes: [
              %{
                family: :repository_control,
                graph_iri: control_graph,
                operation: :append,
                metadata: %{lifecycle_state: :open},
                additions: [
                  {goal, RDF.type(), RDF.iri("https://jido.run/ontology/factory#Goal")},
                  {goal, "https://jido.run/ontology/factory#about", RDF.iri(repository)}
                ],
                supersessions: [],
                invalidations: [],
                removals: []
              }
            ]
          }
        },
        clock: fn -> @issued end
      )

    envelope
  end

  defp resource!(value) do
    {:ok, iri} = ResourceIdentity.repository(value)
    iri
  end

  defp scope!(value) do
    {:ok, iri} = ResourceIdentity.scope(:repository, value)
    iri
  end

  defp local!(kind, timestamp) do
    entropy = :binary.copy(<<rem(timestamp, 255)>>, 10)
    {:ok, iri} = ResourceIdentity.local(kind, timestamp, entropy)
    iri
  end

  defp deterministic!(kind, material) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, material)
    iri
  end
end

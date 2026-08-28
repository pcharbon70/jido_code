defmodule JidoCode.Knowledge.RepositoryWiki.SchedulerAutomaticUpdateTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.RepositoryWiki.AutomaticUpdate
  alias JidoCode.Factory.RepositoryWiki.Scheduler
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 16:00:00Z]
  @scheduler JidoCode.TestRepositoryWikiScheduler

  setup do
    start_supervised!(
      {Scheduler,
       name: @scheduler,
       maximum_pending: 3,
       maximum_active: 2,
       maximum_per_tenant: 1,
       revalidator: fn trigger, current ->
         action = Map.get(current, trigger.source_fence, :full_rebuild)
         {:ok, %{action: action, fence: trigger.source_fence}}
       end}
    )

    repository = resource(:repository_reconciliation, "scheduled-repository")
    tenant = resource(:authorization_grant, "scheduled-tenant")
    controller = resource(:authorization_grant, "scheduled-controller")
    profile_digest = digest("scheduled-profile")

    %{
      repository: repository,
      tenant: tenant,
      controller: controller,
      profile_digest: profile_digest
    }
  end

  test "admits only controller-authenticated closed trigger classes", context do
    assert {:ok, trigger} = trigger(context, :repository_change, "source-1", :normal, 0)
    assert trigger.repository_iri == context.repository
    assert trigger.causal_iris == [resource(:observation_activity, "cause-source-1")]

    payload = trigger_payload(context, "source-1", :normal, 0)

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_update_trigger(:repository_change, payload, %{
               controller_authenticated?: false,
               controller_iri: context.controller
             })

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_update_trigger(:repository_selected, payload, %{
               controller_authenticated?: true,
               controller_iri: context.controller
             })
  end

  test "debounces and coalesces latest source while retaining every cause", context do
    assert {:ok, first} = trigger(context, :repository_change, "source-1", :normal, 0)
    assert {:ok, second} = trigger(context, :accepted_document, "source-2", :high, 1)

    assert {:ok, :queued} = Scheduler.enqueue(@scheduler, first)
    assert {:ok, :coalesced} = Scheduler.enqueue(@scheduler, second)
    assert {:ok, :duplicate} = Scheduler.enqueue(@scheduler, second)

    assert {:ok, admitted} = Scheduler.next(@scheduler, %{})
    assert admitted.source_fence == "source-2"
    assert admitted.priority == :high
    assert admitted.coalesced_trigger_count == 1
    assert length(admitted.causal_iris) == 2
    assert admitted.admitted_classification.action == :full_rebuild

    assert :ok = Scheduler.complete(@scheduler, context.tenant, context.repository, :activated)
    assert %{pending_count: 0, active_count: 0, terminal_count: 1} = Scheduler.status(@scheduler)
  end

  test "enforces bounded queue, per-tenant capacity, and admission-time skip evidence", context do
    other_repository = resource(:repository_reconciliation, "scheduled-other-repository")
    other_tenant = resource(:authorization_grant, "scheduled-other-tenant")

    assert {:ok, first} = trigger(context, :repository_change, "source-critical", :critical, 0)

    assert {:ok, same_tenant} =
             context
             |> Map.put(:repository, other_repository)
             |> trigger(:repository_change, "source-normal", :normal, 1)

    assert {:ok, other_tenant_trigger} =
             context
             |> Map.merge(%{
               repository: resource(:repository_reconciliation, "third"),
               tenant: other_tenant
             })
             |> trigger(:scheduled_refresh, "source-noop", :low, 2)

    assert {:ok, :queued} = Scheduler.enqueue(@scheduler, same_tenant)
    assert {:ok, :queued} = Scheduler.enqueue(@scheduler, other_tenant_trigger)
    assert {:ok, :queued} = Scheduler.enqueue(@scheduler, first)

    overflow_context = %{
      context
      | repository: resource(:repository_reconciliation, "overflow-repository"),
        tenant: resource(:authorization_grant, "overflow-tenant")
    }

    assert {:ok, overflow} =
             trigger(overflow_context, :repository_change, "source-overflow", :normal, 3)

    assert {:error, :backpressure} = Scheduler.enqueue(@scheduler, overflow)

    assert {:ok, critical} = Scheduler.next(@scheduler, %{})
    assert critical.iri == first.iri

    assert {:skipped, evidence} = Scheduler.next(@scheduler, %{"source-noop" => :no_change})
    assert evidence.state == :skipped
    assert evidence.detail.action == :no_change

    assert :empty = Scheduler.next(@scheduler, %{})
    assert :ok = Scheduler.complete(@scheduler, context.tenant, context.repository, :done)
    assert {:ok, next_same_tenant} = Scheduler.next(@scheduler, %{})
    assert next_same_tenant.repository_iri == other_repository
  end

  test "automatic deterministic updates pass exact gates and record zero usage", context do
    assert {:ok, trigger} = trigger(context, :repository_change, "source-automatic", :high, 0)
    test_pid = self()
    automatic_context = automatic_context(context, trigger)

    ports = %{
      reclassify: fn received, _current ->
        send(test_pid, {:stage, :reclassify, received.iri})
        {:ok, %{action: :full_rebuild, reason: :source_changed}}
      end,
      compile: fn received, _classification, current ->
        send(test_pid, {:stage, :compile, received.iri})

        {:ok,
         %{
           edition_iri: resource(:wiki_edition, "automatic-edition"),
           source_fence: received.source_fence,
           profile_digest: current.profile_digest,
           lease_fence: current.lease_fence,
           enrollment_revision: current.enrollment_revision
         }}
      end,
      lint: fn _compilation, _current ->
        send(test_pid, {:stage, :lint})
        {:ok, %{status: :passed, blocking_count: 0}}
      end,
      render: fn _compilation, _current ->
        send(test_pid, {:stage, :render})
        {:ok, %{status: :passed, blocking_count: 0}}
      end,
      account: fn _compilation, _current ->
        send(test_pid, {:stage, :account})

        {:ok,
         %{
           tokens: %{input: 0, output: 0, cached: 0, reasoning: 0},
           costs: %{reserved: 0, measured: 0, charged: 0, refunded: 0, unknown: 0}
         }}
      end,
      activate: fn _compilation, _lint, _render, _usage, _current ->
        send(test_pid, {:stage, :activate})
        {:ok, %{outcome: :activated}}
      end,
      mark_stale: fn received, reason, _current ->
        send(test_pid, {:stale, received.iri, reason})
        :ok
      end
    }

    assert {:ok, outcome} = AutomaticUpdate.run(trigger, automatic_context, ports)
    assert outcome.state == :activated
    assert outcome.usage.tokens.input == 0

    assert_receive {:stage, :reclassify, _}
    assert_receive {:stage, :compile, _}
    assert_receive {:stage, :lint}
    assert_receive {:stage, :render}
    assert_receive {:stage, :account}
    assert_receive {:stage, :activate}
    refute_receive {:stale, _, _}

    assert {:error, %{reason: :stale_or_unauthorized}} =
             AutomaticUpdate.run(
               trigger,
               %{automatic_context | current_lease_fence: "lost"},
               ports
             )

    assert_receive {:stale, _, :stale_or_unauthorized}
  end

  test "retries only bounded transient outcomes and reconstructs from graph state", context do
    {:ok, profile} = Knowledge.repository_wiki_maintainer_profile(@now, nil)
    assert {:retry, 250} = AutomaticUpdate.retry_decision(:timeout, profile, 0)
    assert {:retry, 500} = AutomaticUpdate.retry_decision(:unavailable, profile, 1)
    assert :stop = AutomaticUpdate.retry_decision(:unauthorized, profile, 0)
    assert :stop = AutomaticUpdate.retry_decision(:timeout, profile, 3)

    assert %{action: :resume, reason: :incomplete_edition} =
             AutomaticUpdate.recover(
               %{
                 enrollment_revision: 4,
                 source_fence: "source-1",
                 terminal?: false,
                 edition_state: :building,
                 attempt_iri: resource(:wiki_compilation_attempt, "recover-attempt")
               },
               %{enrollment_revision: 4, source_fence: "source-1"}
             )

    assert %{action: :supersede, reason: :stale_source} =
             AutomaticUpdate.recover(
               %{enrollment_revision: 4, source_fence: "old", terminal?: false},
               %{enrollment_revision: 4, source_fence: "new"}
             )

    assert context.repository != context.tenant
  end

  defp automatic_context(context, trigger) do
    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      source_fence: trigger.source_fence,
      current_source_fence: trigger.source_fence,
      profile_digest: context.profile_digest,
      policy_revision: 7,
      lease_current?: true,
      lease_fence: "lease-fence-9",
      current_lease_fence: "lease-fence-9",
      enrollment_revision: 4,
      current_enrollment_revision: 4,
      generation_mode: :deterministic_only,
      reservation_posture: :zero_token
    }
  end

  defp trigger(context, type, source_fence, priority, second) do
    Knowledge.repository_wiki_update_trigger(
      type,
      trigger_payload(context, source_fence, priority, second),
      %{controller_authenticated?: true, controller_iri: context.controller}
    )
  end

  defp trigger_payload(context, source_fence, priority, second) do
    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      source_fence: source_fence,
      policy_revision: 7,
      profile_digest: context.profile_digest,
      classification_digest: digest("classification-#{source_fence}"),
      classification: %{action: :full_rebuild},
      priority: priority,
      idempotency_key: "trigger-#{source_fence}",
      causal_iris: [resource(:observation_activity, "cause-#{source_fence}")],
      recorded_at: DateTime.add(@now, second, :second)
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

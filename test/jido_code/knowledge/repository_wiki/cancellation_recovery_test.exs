defmodule JidoCode.Knowledge.RepositoryWiki.CancellationRecoveryTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.RepositoryWiki.RecoveryCoordinator
  alias JidoCode.Factory.RepositoryWiki.Scheduler
  alias JidoCode.Factory.RepositoryWiki.Shutdown
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 19:00:00Z]
  @expiry ~U[2026-09-28 19:00:00Z]

  setup do
    repository = resource(:repository_reconciliation, "cancel-repository")
    tenant = resource(:authorization_grant, "cancel-tenant")
    actor = resource(:authorization_grant, "cancel-actor")
    edition = resource(:wiki_edition, "cancel-edition")
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})
    {:ok, catalog_graph} = GraphRegistry.graph_iri(:factory_catalog, %{})

    {:ok, profile} =
      Knowledge.wiki_generation_profile(:automatic_deterministic, %{
        approved_at: @now,
        expires_at: @expiry,
        preview_mode: :allowed
      })

    {:ok, enrollment} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: repository,
        tenant_iri: tenant,
        revision: 3,
        state: :automatic,
        generation_profile: profile,
        generation_mode: :deterministic_only,
        preview_mode: :allowed,
        read_visibility: :retained,
        cancellation_generation: 2,
        current_edition_iri: edition,
        recorded_at: @now
      })

    resolution = %{
      repository_iri: repository,
      tenant_iri: tenant,
      current_state: :automatic,
      current_revision: enrollment.revision,
      current_enrollment_iri: enrollment.iri,
      current_transition_iri: resource(:control_transition, "cancel-current-transition"),
      cancellation_generation: enrollment.cancellation_generation,
      current_edition_iri: edition
    }

    command_attributes = %{
      control_graph_iri: control_graph,
      catalog_graph_iri: catalog_graph,
      expected_control_revision: 7,
      expected_catalog_revision: 5,
      expected_dataset_revision: 20,
      generation_profile: nil,
      preview_mode: :disabled,
      read_visibility: :retained,
      recorded_at: @now,
      principal_iri: actor,
      actor_iri: actor,
      scope_iri: repository,
      correlation_iri: resource(:authorization_grant, "cancel-correlation"),
      causation_iri: resource(:authorization_grant, "cancel-causation"),
      reason: "disable repository wiki"
    }

    {:ok, disable_command} =
      Knowledge.transition_repository_wiki_enrollment(
        repository,
        tenant,
        resolution,
        :off,
        command_attributes,
        clock: fn -> @now end
      )

    base = %{
      repository_iri: repository,
      tenant_iri: tenant,
      enrollment_revision: enrollment.revision,
      cancellation_generation: enrollment.cancellation_generation
    }

    attributes = %{
      repository_iri: repository,
      tenant_iri: tenant,
      disable_command: disable_command,
      prior_enrollment_revision: 3,
      enrollment_revision: 4,
      prior_cancellation_generation: 2,
      cancellation_generation: 3,
      retained_read_policy: :allow,
      current_edition_iri: edition,
      queued_triggers: [item(base, :wiki_compilation_attempt, "queued", %{})],
      active_effects: [item(base, :wiki_compilation_attempt, "active", %{})],
      leases: [item(base, :wiki_maintainer, "lease", %{state: :active})],
      reservations: [
        item(base, :wiki_reservation, "unconsumed", %{state: :reserved, invoked?: false}),
        item(base, :wiki_reservation, "invoked", %{state: :reserved, invoked?: true}),
        item(base, :wiki_reservation, "consumed", %{state: :consumed, invoked?: true})
      ],
      attempts: [
        item(base, :wiki_compilation_attempt, "deterministic", %{
          generation_mode: :deterministic_only,
          terminal_state: nil,
          effect_started?: true
        }),
        item(base, :wiki_compilation_attempt, "synthesis", %{
          generation_mode: :synthesis_allowed,
          terminal_state: nil,
          effect_started?: true
        })
      ],
      artifacts: [item(base, :wiki_edition, "readable", %{readable?: true})],
      recorded_at: @now
    }

    {:ok, plan} = Knowledge.plan_repository_wiki_cancellation(attributes)

    %{
      repository: repository,
      tenant: tenant,
      actor: actor,
      edition: edition,
      profile: profile,
      enrollment: enrollment,
      base: base,
      attributes: attributes,
      plan: plan
    }
  end

  test "builds closed cancellation and accounting actions while retaining reads independently",
       context do
    plan = context.plan

    assert Knowledge.valid_repository_wiki_cancellation_plan?(plan)

    assert plan.retained_read == %{
             readable?: true,
             edition_iri: context.edition,
             generation_enabled?: false,
             product_navigation?: false
           }

    assert Enum.map(plan.actions.reconcile_accounting.reservations, & &1.action) == [
             :release_unconsumed,
             :retain_unknown_liability,
             :retain_consumed_liability
           ]

    assert Enum.map(plan.actions.reconcile_accounting.attempts, & &1.action) == [
             :record_cancelled_zero_usage,
             :record_usage_pending
           ]

    assert {:ok, hidden} =
             context.attributes
             |> Map.put(:retained_read_policy, :deny)
             |> Knowledge.plan_repository_wiki_cancellation()

    refute hidden.retained_read.readable?
    refute hidden.retained_read.product_navigation?

    assert {:error, %{kind: :invalid_input}} =
             context.attributes
             |> Map.put(:unreviewed_callback, "caller-selected")
             |> Knowledge.plan_repository_wiki_cancellation()
  end

  test "commits disable before every signal and does not signal after a failed commit", context do
    test_pid = self()
    ports = shutdown_ports(test_pid, :ok)

    assert {:ok, result} = Shutdown.execute(context.plan, ports)
    assert result.state == :disabled
    assert result.cancellation_generation == 3

    assert_receive {:stage, :commit_disable}
    assert_receive {:stage, :stop_admission}
    assert_receive {:stage, :terminal_pending_triggers}
    assert_receive {:stage, :cancel_active_effects}
    assert_receive {:stage, :revoke_leases}
    assert_receive {:stage, :reconcile_accounting}
    assert_receive {:stage, :retain_artifacts}
    assert_receive {:stage, :stop_owner}

    assert {:error, %{outcome: :stale_graph, effect_started?: false}} =
             Shutdown.execute(context.plan, shutdown_ports(test_pid, {:error, :stale_graph}))

    assert_receive {:stage, :commit_disable}
    refute_receive {:stage, :stop_admission}
  end

  test "disable and re-enrollment reject every old-generation result", context do
    old_result = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      enrollment_revision: 3,
      cancellation_generation: 2,
      lease_generation: 4,
      source_fence: "source-3"
    }

    off =
      Map.merge(old_result, %{state: :off, enrollment_revision: 4, cancellation_generation: 3})

    refute Shutdown.result_current?(old_result, off)

    re_enrolled = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      state: :automatic,
      enrollment_revision: 5,
      cancellation_generation: 3,
      lease_generation: 5,
      source_fence: "source-5"
    }

    refute Shutdown.result_current?(old_result, re_enrolled)
    assert Shutdown.result_current?(Map.delete(re_enrolled, :state), re_enrolled)
  end

  test "scheduler cancellation fences queued admission, active work, and late completion",
       context do
    scheduler = Module.concat(__MODULE__, CancellationScheduler)

    start_supervised!(
      {Scheduler,
       name: scheduler,
       revalidator: fn trigger, _current ->
         {:ok, %{action: :full_rebuild, source_fence: trigger.source_fence}}
       end}
    )

    trigger =
      item(context.base, :wiki_compilation_attempt, "scheduler-cancel-trigger", %{
        idempotency_key: "scheduler-cancel-trigger",
        profile_digest: context.profile.profile_digest,
        policy_revision: 7,
        source_fence: "source-3",
        priority: :high,
        causal_iris: [context.actor],
        recorded_at: @now
      })

    assert {:ok, :queued} = Scheduler.enqueue(scheduler, trigger)
    assert {:ok, admitted} = Scheduler.next(scheduler, %{})
    assert admitted.iri == trigger.iri

    assert {:ok, %{active_cancelled?: true, pending_cancelled: 0}} =
             Scheduler.disable_repository(scheduler, context.tenant, context.repository, 4, 3)

    assert {:error, :not_active} =
             Scheduler.complete(scheduler, context.tenant, context.repository, :late_success)

    assert {:error, :disabled} = Scheduler.enqueue(scheduler, trigger)

    assert {:error, :stale_generation} =
             Scheduler.enable_repository(scheduler, context.tenant, context.repository, 4, 3)

    assert :ok =
             Scheduler.enable_repository(scheduler, context.tenant, context.repository, 5, 3)

    assert {:ok, :queued} = Scheduler.enqueue(scheduler, trigger)
    assert %{disabled_count: 0, terminal_count: 1} = Scheduler.status(scheduler)
  end

  test "derives recovery necessity and exact-fence actions only from graph facts", context do
    facts = recovery_facts(context)

    assert {:ok, plan} =
             Knowledge.plan_repository_wiki_maintainer_recovery(
               enrollment_map(context),
               facts,
               @now
             )

    assert plan.status == :recovering
    assert plan.update_necessary?

    assert Enum.map(plan.actions, & &1.action) == [
             :acquire_owner,
             :resume_edition,
             :reconcile_reservation,
             :reconcile_usage,
             :resume_metadata,
             :qualify_activation,
             :enqueue_update
           ]

    stale =
      item(context.base, :wiki_edition, "stale-incomplete", %{
        original_fence: "stale-original",
        source_fence: "stale-source",
        original_fence_valid?: true
      })

    assert {:ok, with_stale} =
             Knowledge.plan_repository_wiki_maintainer_recovery(
               enrollment_map(context),
               %{facts | incomplete_editions: [stale | facts.incomplete_editions]},
               @now
             )

    assert Enum.any?(with_stale.superseded, &(&1.iri == stale.iri))
  end

  test "startup recovery runs repositories in a bounded fleet and fails closed when degraded",
       context do
    test_pid = self()
    second_repository = resource(:repository_reconciliation, "cancel-repository-two")
    second = %{enrollment_map(context) | repository_iri: second_repository}
    first = enrollment_map(context)

    fact_loader = fn enrollment ->
      facts = recovery_facts(context)

      {:ok,
       facts
       |> scope_facts(enrollment.repository_iri, enrollment.tenant_iri)
       |> Map.put(:current_source_fence, "source-4")}
    end

    name = Module.concat(__MODULE__, RecoveryFleet)

    start_supervised!(
      {RecoveryCoordinator,
       name: name,
       enrollment_loader: fn -> {:ok, [first, second]} end,
       fact_loader: fact_loader,
       ports: recovery_ports(test_pid),
       clock: fn -> @now end,
       maximum_concurrency: 2}
    )

    status = RecoveryCoordinator.status(name)
    assert status.status == :ready
    assert status.repository_count == 2
    assert Enum.all?(status.results, &(&1.status == :recovered))
    assert_receive {:recovery, :acquire_owner, _repository}
    assert_receive {:recovery, :acquire_owner, _repository}

    degraded_name = Module.concat(__MODULE__, RecoveryDegraded)
    degraded_facts = put_in(recovery_facts(context), [:dependencies, :accounting], :unavailable)

    start_supervised!(
      Supervisor.child_spec(
        {RecoveryCoordinator,
         name: degraded_name,
         enrollment_loader: fn -> {:ok, [first]} end,
         fact_loader: fn _enrollment -> {:ok, degraded_facts} end,
         ports: recovery_ports(test_pid),
         clock: fn -> @now end},
        id: degraded_name
      )
    )

    degraded = RecoveryCoordinator.status(degraded_name)
    assert degraded.status == :degraded
    assert hd(degraded.results).degraded_dependencies == [:accounting]
    refute_receive {:degraded_recovery_effect, _action}
  end

  test "publishes the reviewed graph-derived recovery status query" do
    assert :repository_wiki_recovery_status in QueryCatalog.names("2.11.0")
    refute :repository_wiki_recovery_status in QueryCatalog.names("2.10.0")
    assert :ok = QueryCatalog.verify()
  end

  defp shutdown_ports(test_pid, commit_result) do
    action_ports =
      Map.new(
        ~w[
          stop_admission terminal_pending_triggers cancel_active_effects revoke_leases
          reconcile_accounting retain_artifacts stop_owner
        ]a,
        fn stage ->
          {stage,
           fn _action, _plan ->
             send(test_pid, {:stage, stage})
             :ok
           end}
        end
      )

    Map.put(action_ports, :commit_disable, fn _command ->
      send(test_pid, {:stage, :commit_disable})

      case commit_result do
        :ok -> {:ok, %{outcome: :committed}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp recovery_ports(test_pid) do
    Map.new(
      ~w[
        acquire_owner resume_edition reconcile_reservation reconcile_usage resume_metadata
        qualify_activation enqueue_update
      ]a,
      fn action ->
        {action,
         fn _request, plan ->
           send(test_pid, {:recovery, action, plan.repository_iri})
           :ok
         end}
      end
    )
  end

  defp recovery_facts(context) do
    exact = fn kind, seed ->
      item(context.base, kind, seed, %{
        original_fence: "original-fence-3",
        source_fence: "source-4",
        original_fence_valid?: true
      })
    end

    %{
      dependencies: %{
        store: :ready,
        harness: :ready,
        artifact: :ready,
        profile: :ready,
        accounting: :ready
      },
      worker_ready?: true,
      profile_digest: context.profile.profile_digest,
      current_source_fence: "source-4",
      current_edition: %{source_fence: "source-3", stale?: true},
      lease: nil,
      incomplete_editions: [exact.(:wiki_edition, "recover-edition")],
      reservations: [exact.(:wiki_reservation, "recover-reservation")],
      usage_pending_attempts: [exact.(:wiki_usage_record, "recover-usage")],
      metadata_refreshes: [exact.(:wiki_compilation_attempt, "recover-metadata")],
      activation_candidates: [exact.(:wiki_edition, "recover-activation")],
      terminal_attempts: [
        exact.(:wiki_compilation_attempt, "recover-failed") |> Map.put(:state, :failed)
      ],
      triggers: [exact.(:wiki_compilation_attempt, "recover-trigger")]
    }
  end

  defp scope_facts(facts, repository_iri, tenant_iri) do
    keys = [
      :incomplete_editions,
      :reservations,
      :usage_pending_attempts,
      :metadata_refreshes,
      :activation_candidates,
      :terminal_attempts,
      :triggers
    ]

    Enum.reduce(keys, facts, fn key, scoped ->
      Map.update!(scoped, key, fn values ->
        Enum.map(
          values,
          &Map.merge(&1, %{repository_iri: repository_iri, tenant_iri: tenant_iri})
        )
      end)
    end)
  end

  defp enrollment_map(context) do
    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      state: :automatic,
      revision: context.enrollment.revision,
      cancellation_generation: context.enrollment.cancellation_generation
    }
  end

  defp item(base, kind, seed, extra) do
    base
    |> Map.put(:iri, resource(kind, seed))
    |> Map.merge(extra)
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

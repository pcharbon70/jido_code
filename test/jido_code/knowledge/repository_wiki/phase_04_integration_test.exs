defmodule JidoCode.Knowledge.RepositoryWiki.Phase04IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.RepositoryWiki.AccountingReconciler
  alias JidoCode.Factory.RepositoryWiki.AutomaticUpdate
  alias JidoCode.Factory.RepositoryWiki.Coordinator
  alias JidoCode.Factory.RepositoryWiki.Scheduler
  alias JidoCode.Factory.RepositoryWiki.SynthesisBoundary
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.RepositoryWiki.PriceProfile
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 21:00:00Z]
  @later ~U[2026-08-28 22:00:00Z]
  @expiry ~U[2026-09-28 21:00:00Z]

  setup do
    %{
      repository: resource(:repository_reconciliation, "rw4-repository"),
      other_repository: resource(:repository_reconciliation, "rw4-other-repository"),
      tenant: resource(:authorization_grant, "rw4-tenant"),
      actor: resource(:authorization_grant, "rw4-actor"),
      controller: resource(:authorization_grant, "rw4-controller")
    }
  end

  test "parallel sessions converge on one owner and bounded coalesced work per repository",
       context do
    registry = Module.concat(__MODULE__, MaintainerRegistry)
    supervisor = Module.concat(__MODULE__, MaintainerSupervisor)
    coordinator = Module.concat(__MODULE__, MaintainerCoordinator)
    scheduler = Module.concat(__MODULE__, FleetScheduler)
    test_pid = self()

    start_supervised!({Registry, keys: :unique, name: registry})
    start_supervised!({DynamicSupervisor, name: supervisor, strategy: :one_for_one})

    start_supervised!(
      {Coordinator,
       name: coordinator,
       registry: registry,
       supervisor: supervisor,
       lease_gateway: fn lease ->
         send(test_pid, {:lease, lease.repository_iri})
         {:ok, %{outcome: :committed}}
       end}
    )

    start_supervised!(
      {Scheduler,
       name: scheduler,
       maximum_pending: 8,
       maximum_active: 2,
       maximum_per_tenant: 2,
       revalidator: fn trigger, _current ->
         {:ok, %{action: :full_rebuild, source_fence: trigger.source_fence}}
       end}
    )

    {:ok, maintainer_profile} = Knowledge.repository_wiki_maintainer_profile(@now, @expiry)
    generation_profile_iri = resource(:wiki_generation_profile, "rw4-generation")
    enrollment = enrollment(context, context.repository, generation_profile_iri)

    owner_context =
      owner_context(context, context.repository, generation_profile_iri, maintainer_profile)

    starts =
      1..16
      |> Task.async_stream(
        fn _session ->
          Coordinator.ensure_owner(coordinator, enrollment, maintainer_profile, owner_context)
        end,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(starts, &match?({:ok, _owner}, &1)) == 1
    assert Enum.count(starts, &match?({:already_started, _pid}, &1)) == 15
    assert_receive {:lease, repository}
    assert repository == context.repository

    other_profile_iri = resource(:wiki_generation_profile, "rw4-other-generation")

    assert {:ok, _other_owner} =
             Coordinator.ensure_owner(
               coordinator,
               enrollment(context, context.other_repository, other_profile_iri),
               maintainer_profile,
               owner_context(
                 context,
                 context.other_repository,
                 other_profile_iri,
                 maintainer_profile
               )
             )

    first = trigger(context, context.repository, "source-1", :normal, 0)
    successor = trigger(context, context.repository, "source-2", :critical, 1)
    unrelated = trigger(context, context.other_repository, "other-source-1", :high, 2)

    assert {:ok, :queued} = Scheduler.enqueue(scheduler, first)
    assert {:ok, :coalesced} = Scheduler.enqueue(scheduler, successor)
    assert {:ok, :queued} = Scheduler.enqueue(scheduler, unrelated)

    assert {:ok, admitted} = Scheduler.next(scheduler, %{})
    assert admitted.repository_iri == context.repository
    assert admitted.source_fence == "source-2"
    assert length(admitted.causal_iris) == 2

    assert {:ok, %{active_cancelled?: true}} =
             Scheduler.disable_repository(scheduler, context.tenant, context.repository, 9, 4)

    assert {:error, :not_active} =
             Scheduler.complete(scheduler, context.tenant, context.repository, :late_success)

    assert {:ok, other} = Scheduler.next(scheduler, %{})
    assert other.repository_iri == context.other_repository

    assert :ok =
             Scheduler.complete(scheduler, context.tenant, context.other_repository, :activated)
  end

  test "automatic deterministic maintenance records attributable zero model usage", context do
    profile_digest = digest("rw4-automatic-profile")
    trigger = trigger(context, context.repository, "automatic-source", :high, 0)
    trigger = %{trigger | profile_digest: profile_digest}

    current = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      source_fence: trigger.source_fence,
      current_source_fence: trigger.source_fence,
      profile_digest: profile_digest,
      policy_revision: trigger.policy_revision,
      lease_current?: true,
      lease_fence: "lease-9",
      current_lease_fence: "lease-9",
      enrollment_revision: 9,
      current_enrollment_revision: 9,
      generation_mode: :deterministic_only,
      reservation_posture: :zero_token
    }

    ports = automatic_ports(profile_digest, :zero)
    assert {:ok, outcome} = AutomaticUpdate.run(trigger, current, ports)
    assert outcome.state == :activated
    assert outcome.usage.tokens == %{input: 0, output: 0, cached: 0, reasoning: 0}
    assert outcome.usage.costs.charged == 0
    assert outcome.usage.local_work.input_bytes == 4_096

    assert {:error, %{reason: :nonzero_deterministic_usage}} =
             AutomaticUpdate.run(trigger, current, automatic_ports(profile_digest, :nonzero))
  end

  test "budget reservation, checked prices, terminal usage, and unknown liability reconcile",
       context do
    fixture = accounting_fixture(context)
    request = reservation_request(fixture, "rw4-first", fixture.attempt, fixture.invocation)
    reservation_context = reservation_context(fixture, [])

    assert {:ok, first} = Knowledge.reserve_repository_wiki_budget(request, reservation_context)
    assert first.liability.cost_microunits == 68

    second =
      reservation_request(
        fixture,
        "rw4-second",
        resource(:wiki_compilation_attempt, "rw4-second-attempt"),
        resource(:model_invocation, "rw4-second-invocation")
      )

    assert {:error, :insufficient_budget} =
             Knowledge.reserve_repository_wiki_budget(
               second,
               %{reservation_context | reservations: [first]}
             )

    assert {:error, %{operation: :wiki_cost_overflow}} =
             PriceProfile.cost(
               fixture.price,
               %{
                 input: 9_223_372_036_854_775_807,
                 output: 0,
                 cached: 0,
                 reasoning: 0
               },
               @now
             )

    assert {:ok, zero} =
             Knowledge.repository_wiki_deterministic_usage(%{
               repository_iri: context.repository,
               tenant_iri: context.tenant,
               actor_iri: context.actor,
               attempt_iri: fixture.attempt,
               edition_iri: fixture.edition,
               profile_iri: fixture.synthesis.iri,
               reservation_iri: nil,
               invocation_iri: nil,
               state: :cancelled,
               trigger: "automatic",
               source_revision: "source-accounting",
               currency: "CAD",
               local_work: %{elapsed_ms: 13, input_bytes: 2_048},
               recorded_at: @later
             })

    assert Enum.all?(zero.tokens, fn {_class, count} -> count == 0 end)
    assert Enum.all?(zero.costs, fn {_class, amount} -> amount == 0 end)

    attempt = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      attempt_iri: fixture.attempt,
      usage_iri: resource(:wiki_usage_record, "rw4-unknown-usage"),
      reservation_iri: first.iri,
      invocation_iri: first.invocation_iri,
      provider_request_iri: resource(:provider_object, "rw4-provider-request"),
      model: fixture.price.model,
      price_revision: fixture.price.revision,
      accounting_fence: "accounting-4",
      invoked_at: @now,
      terminal_usage_iri: nil,
      reserved_cost: first.liability.cost_microunits
    }

    assert {:ok, unknown} =
             AccountingReconciler.reconcile(
               attempt,
               %{
                 repository_iri: context.repository,
                 tenant_iri: context.tenant,
                 accounting_fence: "accounting-4",
                 price_revision: fixture.price.revision,
                 retrieval_supported?: false,
                 retrieval_attempt: 0,
                 maximum_retrieval_attempts: 2
               },
               %{record_terminal: fn usage, _current -> {:ok, usage.state} end}
             )

    assert unknown.outcome == :usage_unknown
    assert unknown.usage.costs.unknown == first.liability.cost_microunits
    assert unknown.usage.costs.refunded == 0
  end

  test "production synthesis is structurally absent and fake effects remain fully fenced",
       context do
    fixture = synthesis_fixture(context)
    test_pid = self()
    ports = synthesis_ports(fixture, test_pid)

    assert SynthesisBoundary.production_adapter_catalog() == []

    assert {:error, %{outcome: :unavailable, effect_started?: false}} =
             SynthesisBoundary.invoke(
               fixture.request,
               boundary_context(fixture, :production),
               ports
             )

    refute_receive {:synthesis_effect, _stage}

    for {change, outcome} <- [
          {{:synthesis_opt_in?, false}, :missing_opt_in},
          {{:profile_enabled?, false}, :disabled_profile},
          {{:price_enabled?, false}, :disabled_profile},
          {{:reservation_current?, false}, :reservation_unavailable}
        ] do
      {key, value} = change

      assert {:error, %{outcome: ^outcome, effect_started?: false}} =
               SynthesisBoundary.invoke(
                 fixture.request,
                 Map.put(boundary_context(fixture, :test), key, value),
                 ports
               )
    end

    failing = Map.put(ports, :adapter, fn _request, _current -> {:error, :provider_failure} end)

    assert {:error, %{outcome: :provider_failure, effect_started?: true}} =
             SynthesisBoundary.invoke(fixture.request, boundary_context(fixture, :test), failing)

    assert_receive {:synthesis_effect, :commit}

    malformed =
      Map.put(ports, :normalize, fn _observation, _request, _current ->
        {:error, :malformed_output}
      end)

    assert {:error, %{outcome: :malformed_output, effect_started?: true}} =
             SynthesisBoundary.invoke(
               fixture.request,
               boundary_context(fixture, :test),
               malformed
             )

    usage_drift =
      Map.put(ports, :normalize, fn _observation, request, _current ->
        {:ok,
         %{
           output: %{sections: []},
           usage: valid_usage(fixture, request) |> Map.put(:model, "drifted-model")
         }}
      end)

    assert {:error, %{outcome: :usage_drift, effect_started?: true}} =
             SynthesisBoundary.invoke(
               fixture.request,
               boundary_context(fixture, :test),
               usage_drift
             )

    attempt = %{
      attempt_iri: fixture.request.attempt_iri,
      reservation_iri: fixture.request.reservation_iri,
      invocation_iri: fixture.request.invocation_iri,
      provider_request_iri: fixture.provider_request,
      model: fixture.request.model,
      price_revision: 4
    }

    usage =
      valid_usage(fixture, fixture.request)
      |> Map.merge(%{
        usage_iri: resource(:wiki_usage_record, "rw4-late-usage"),
        attempt_iri: attempt.attempt_iri,
        price_revision: 4,
        accounting_fence: "late-accounting-4"
      })

    assert {:ok, %{late?: true}} =
             AccountingReconciler.late_usage(usage, attempt, %{
               accounting_fence: "late-accounting-4",
               usage_records: []
             })

    assert {:error, :mismatched_late_usage} =
             AccountingReconciler.late_usage(
               %{usage | reservation_iri: resource(:wiki_reservation, "wrong-reservation")},
               attempt,
               %{accounting_fence: "late-accounting-4", usage_records: []}
             )
  end

  test "disable and degraded recovery reject old generations without disturbing retained evidence",
       context do
    old_result = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      enrollment_revision: 8,
      cancellation_generation: 3,
      lease_generation: 2,
      source_fence: "old-source"
    }

    disabled = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      state: :off,
      enrollment_revision: 9,
      cancellation_generation: 4,
      lease_generation: 2,
      source_fence: "old-source"
    }

    refute Knowledge.repository_wiki_result_current?(old_result, disabled)

    re_enrolled = %{
      disabled
      | state: :automatic,
        enrollment_revision: 10,
        lease_generation: 3,
        source_fence: "new-source"
    }

    refute Knowledge.repository_wiki_result_current?(old_result, re_enrolled)
    assert Knowledge.repository_wiki_result_current?(Map.delete(re_enrolled, :state), re_enrolled)

    recovery_facts = %{
      dependencies: %{
        store: :ready,
        harness: :ready,
        artifact: :ready,
        profile: :ready,
        accounting: :unavailable
      },
      worker_ready?: true,
      profile_digest: digest("rw4-recovery-profile"),
      current_source_fence: "new-source",
      current_edition: %{source_fence: "old-source", stale?: true},
      lease: nil,
      incomplete_editions: [],
      reservations: [],
      usage_pending_attempts: [],
      metadata_refreshes: [],
      activation_candidates: [],
      terminal_attempts: [],
      triggers: []
    }

    assert {:ok, recovery} =
             Knowledge.plan_repository_wiki_maintainer_recovery(
               %{
                 repository_iri: context.repository,
                 tenant_iri: context.tenant,
                 state: :automatic,
                 revision: 10,
                 cancellation_generation: 4
               },
               recovery_facts,
               @now
             )

    assert recovery.status == :degraded
    assert recovery.degraded_dependencies == [:accounting]
    assert recovery.actions == []
  end

  defp enrollment(context, repository_iri, generation_profile_iri) do
    %{
      state: :automatic,
      maintenance_mode: :automatic,
      generation_mode: :deterministic_only,
      repository_iri: repository_iri,
      tenant_iri: context.tenant,
      generation_profile_iri: generation_profile_iri,
      revision: 8,
      cancellation_generation: 3
    }
  end

  defp owner_context(context, repository_iri, generation_profile_iri, profile) do
    %{
      repository_iri: repository_iri,
      tenant_iri: context.tenant,
      generation_profile_iri: generation_profile_iri,
      maintainer_profile_digest: profile.digest,
      enrollment_revision: 8,
      cancellation_generation: 3,
      policy_revision: 5,
      current_policy_revision: 5,
      worker_ready?: true,
      evaluated_at: @now,
      holder_iri: resource(:wiki_maintainer, "holder-#{repository_iri}")
    }
  end

  defp trigger(context, repository_iri, source_fence, priority, second) do
    {:ok, trigger} =
      Knowledge.repository_wiki_update_trigger(
        :repository_change,
        %{
          repository_iri: repository_iri,
          tenant_iri: context.tenant,
          source_fence: source_fence,
          policy_revision: 5,
          profile_digest: digest("rw4-trigger-profile"),
          classification_digest: digest("classification-#{source_fence}"),
          classification: %{action: :full_rebuild},
          priority: priority,
          idempotency_key: "rw4-trigger-#{repository_iri}-#{source_fence}",
          causal_iris: [
            resource(:observation_activity, "cause-#{repository_iri}-#{source_fence}")
          ],
          recorded_at: DateTime.add(@now, second, :second)
        },
        %{controller_authenticated?: true, controller_iri: context.controller}
      )

    trigger
  end

  defp automatic_ports(profile_digest, usage_mode) do
    %{
      reclassify: fn _trigger, _current -> {:ok, %{action: :full_rebuild}} end,
      compile: fn trigger, _classification, current ->
        {:ok,
         %{
           edition_iri: resource(:wiki_edition, "rw4-auto-edition"),
           source_fence: trigger.source_fence,
           profile_digest: profile_digest,
           lease_fence: current.lease_fence,
           enrollment_revision: current.enrollment_revision
         }}
      end,
      lint: fn _compilation, _current -> {:ok, %{status: :passed, blocking_count: 0}} end,
      render: fn _compilation, _current -> {:ok, %{status: :passed, blocking_count: 0}} end,
      account: fn _compilation, _current ->
        count = if usage_mode == :zero, do: 0, else: 1

        {:ok,
         %{
           tokens: %{input: count, output: 0, cached: 0, reasoning: 0},
           costs: %{reserved: 0, measured: 0, charged: count, refunded: 0, unknown: 0},
           local_work: %{elapsed_ms: 27, input_bytes: 4_096}
         }}
      end,
      activate: fn _compilation, _lint, _render, _usage, _current ->
        {:ok, %{outcome: :activated}}
      end,
      mark_stale: fn _trigger, _reason, _current -> :ok end
    }
  end

  defp accounting_fixture(context) do
    attempt = resource(:wiki_compilation_attempt, "rw4-accounting-attempt")
    invocation = resource(:model_invocation, "rw4-accounting-invocation")
    edition = resource(:wiki_edition, "rw4-accounting-edition")

    {:ok, synthesis} =
      Knowledge.repository_wiki_disabled_synthesis_profile(:manual_synthesis_disabled, %{
        provider: "future-provider",
        model: "future-model-v1",
        region: "ca-central",
        accounting_basis: "provider-token-observation-v1",
        prompt_digest: digest("rw4-prompt"),
        tool_policy: :reviewed_read_only,
        retention_policy: :digest_only,
        maximum_input_tokens: 2_000,
        maximum_output_tokens: 1_000,
        maximum_cached_tokens: 500,
        maximum_reasoning_tokens: 250,
        approved_at: @now,
        expires_at: @expiry
      })

    {:ok, price} =
      Knowledge.repository_wiki_price_profile(%{
        revision: 4,
        provider: synthesis.provider,
        model: synthesis.model,
        region: synthesis.region,
        currency: "CAD",
        unit_tokens: 1_000,
        rates: %{input: 10, output: 40, cached: 5, reasoning: 20},
        rounding: :ceil,
        source_provenance: resource(:provider_object, "rw4-price-source"),
        supersedes: nil,
        effective_at: @now,
        expires_at: @expiry,
        state: :disabled
      })

    {:ok, budget} =
      Knowledge.repository_wiki_budget(%{
        revision: 4,
        repository_iri: context.repository,
        tenant_iri: context.tenant,
        actor_iri: context.actor,
        profile_iri: synthesis.iri,
        period_key: "repository/2026-08",
        starts_at: @now,
        expires_at: @expiry,
        currency: "CAD",
        limits: %{
          provider_calls: 1,
          input_tokens: 2_000,
          output_tokens: 1_000,
          cached_tokens: 500,
          reasoning_tokens: 250,
          total_tokens: 3_750,
          cost_microunits: 68
        }
      })

    Map.merge(context, %{
      attempt: attempt,
      invocation: invocation,
      edition: edition,
      synthesis: synthesis,
      price: price,
      budget: budget,
      session: resource(:interaction_session, "rw4-accounting-session")
    })
  end

  defp reservation_request(fixture, idempotency_key, attempt, invocation) do
    %{
      idempotency_key: idempotency_key,
      actor_iri: fixture.actor,
      tenant_iri: fixture.tenant,
      repository_iri: fixture.repository,
      session_iri: fixture.session,
      source_revision: "source-accounting",
      edition_iri: fixture.edition,
      attempt_iri: attempt,
      profile_iri: fixture.synthesis.iri,
      provider: fixture.price.provider,
      model: fixture.price.model,
      price_revision: fixture.price.revision,
      prompt_digest: fixture.synthesis.prompt_digest,
      invocation_iri: invocation,
      budget_revision: fixture.budget.revision,
      enrollment_revision: 9,
      current_fence: "source-accounting",
      currency: "CAD",
      maximum_usage: %{input: 2_000, output: 1_000, cached: 500, reasoning: 250},
      recorded_at: @now,
      expires_at: @later
    }
  end

  defp reservation_context(fixture, reservations) do
    %{
      budget: fixture.budget,
      price_profile: fixture.price,
      expected_fence: "source-accounting",
      enrollment_revision: 9,
      committed: %{},
      reservations: reservations,
      evaluated_at: @now
    }
  end

  defp synthesis_fixture(context) do
    attempt = resource(:wiki_compilation_attempt, "rw4-synthesis-attempt")
    reservation = resource(:wiki_reservation, "rw4-synthesis-reservation")
    invocation = resource(:model_invocation, "rw4-synthesis-invocation")
    profile = resource(:wiki_generation_profile, "rw4-synthesis-profile")
    price = resource(:wiki_budget, "rw4-synthesis-price")
    provider_request = resource(:provider_object, "rw4-synthesis-provider-request")

    request_context = %{
      controller_authenticated?: true,
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      profile_iri: profile,
      price_iri: price,
      provider: "fake-provider",
      model: "fake-model-v1"
    }

    {:ok, request} =
      Knowledge.repository_wiki_synthesis_request(
        %{
          repository_iri: context.repository,
          tenant_iri: context.tenant,
          actor_iri: context.actor,
          session_iri: resource(:interaction_session, "rw4-synthesis-session"),
          attempt_iri: attempt,
          edition_iri: resource(:wiki_edition, "rw4-synthesis-edition"),
          reservation_iri: reservation,
          invocation_iri: invocation,
          profile_iri: profile,
          price_iri: price,
          provider: request_context.provider,
          model: request_context.model,
          source_fence: "rw4-synthesis-source",
          source_facts: [
            %{
              resource_iri: resource(:source_artifact, "rw4-synthesis-source"),
              digest: digest("rw4-source-fact"),
              kind: :source
            }
          ],
          retrieval_context: [resource(:knowledge_assertion, "rw4-retrieval")],
          prompt_digest: digest("rw4-fixed-prompt"),
          output_schema: :wiki_synthesis_fragment_v1,
          token_limits: %{input: 500, output: 250, cached: 100, reasoning: 50},
          redaction_policy: :secrets_and_private_content,
          recorded_at: @now
        },
        request_context
      )

    %{
      request: request,
      profile: profile,
      price: price,
      reservation: reservation,
      provider_request: provider_request
    }
  end

  defp boundary_context(fixture, deployment) do
    %{
      deployment: deployment,
      adapter_catalog: if(deployment == :test, do: [:fake], else: []),
      wiki_enrolled?: true,
      synthesis_opt_in?: true,
      profile_enabled?: true,
      price_enabled?: true,
      worker_ready?: true,
      reservation_state: :reserved,
      reservation_current?: true,
      reservation_iri: fixture.reservation,
      profile_iri: fixture.profile,
      price_iri: fixture.price,
      source_fence: fixture.request.source_fence,
      provider: fixture.request.provider,
      model: fixture.request.model,
      provider_request_iri: fixture.provider_request
    }
  end

  defp synthesis_ports(fixture, test_pid) do
    %{
      commit_invocation: fn _request, _current ->
        send(test_pid, {:synthesis_effect, :commit})
        {:ok, %{outcome: :committed}}
      end,
      adapter: fn _request, _current ->
        send(test_pid, {:synthesis_effect, :adapter})
        {:ok, %{provider_request_iri: fixture.provider_request}}
      end,
      normalize: fn _observation, request, _current ->
        {:ok, %{output: %{sections: []}, usage: valid_usage(fixture, request)}}
      end,
      lint: fn _output, _request, _current -> {:ok, %{status: :passed, blocking_count: 0}} end,
      review: fn _output, _lint, _request, _current ->
        {:ok, %{decision: :pending_human_review}}
      end
    }
  end

  defp valid_usage(fixture, request) do
    %{
      provider_request_iri: fixture.provider_request,
      provider: request.provider,
      model: request.model,
      reservation_iri: request.reservation_iri,
      invocation_iri: request.invocation_iri,
      input: 100,
      output: 50,
      cached: 10,
      reasoning: 5
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

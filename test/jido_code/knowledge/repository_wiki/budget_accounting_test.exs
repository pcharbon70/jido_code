defmodule JidoCode.Knowledge.RepositoryWiki.BudgetAccountingTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.GenerationCatalog
  alias JidoCode.Knowledge.RepositoryWiki.PriceProfile
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 13:00:00Z]
  @later ~U[2026-08-28 14:00:00Z]
  @expiry ~U[2026-09-01 00:00:00Z]

  setup do
    repository = resource(:repository_reconciliation, "budget-repository")
    tenant = resource(:authorization_grant, "budget-tenant")
    actor = resource(:authorization_grant, "budget-actor")
    session = resource(:interaction_session, "budget-session")
    edition = resource(:wiki_edition, "budget-edition")
    attempt = resource(:wiki_compilation_attempt, "budget-attempt")
    invocation = resource(:model_invocation, "budget-invocation")
    provenance = resource(:provider_object, "price-provenance")
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})
    {:ok, run_graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: attempt})

    {:ok, synthesis} =
      GenerationCatalog.disabled_synthesis_profile(:manual_synthesis_disabled, %{
        provider: "future-provider",
        model: "future-model-v1",
        region: "ca-central",
        accounting_basis: "provider-token-observation-v1",
        prompt_digest: digest("prompt"),
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
        revision: 3,
        provider: synthesis.provider,
        model: synthesis.model,
        region: synthesis.region,
        currency: "CAD",
        unit_tokens: 1_000,
        rates: %{input: 10, output: 40, cached: 5, reasoning: 20},
        rounding: :ceil,
        source_provenance: provenance,
        supersedes: nil,
        effective_at: @now,
        expires_at: @expiry,
        state: :disabled
      })

    {:ok, budget} =
      Knowledge.repository_wiki_budget(%{
        revision: 7,
        repository_iri: repository,
        tenant_iri: tenant,
        actor_iri: actor,
        profile_iri: synthesis.iri,
        period_key: "repository/2026-08",
        starts_at: @now,
        expires_at: @expiry,
        currency: "CAD",
        limits: %{
          provider_calls: 2,
          input_tokens: 3_000,
          output_tokens: 2_000,
          cached_tokens: 1_000,
          reasoning_tokens: 500,
          total_tokens: 6_500,
          cost_microunits: 120
        }
      })

    %{
      repository: repository,
      tenant: tenant,
      actor: actor,
      session: session,
      edition: edition,
      attempt: attempt,
      invocation: invocation,
      control_graph: control_graph,
      run_graph: run_graph,
      synthesis: synthesis,
      price: price,
      budget: budget
    }
  end

  test "publishes only deterministic selectable profiles and keeps V1 synthesis closed" do
    assert GenerationCatalog.provider_adapters() == []
    assert GenerationCatalog.price_profiles() == []

    assert {:ok, deterministic} =
             Knowledge.repository_wiki_generation_catalog_profile(:automatic_deterministic, %{
               approved_at: @now,
               expires_at: @expiry,
               preview_mode: :allowed
             })

    assert deterministic.generation_mode == :deterministic_only
    assert deterministic.model_calls == 0
    assert deterministic.token_limits == %{input: 0, output: 0, cached: 0, reasoning: 0}
    assert deterministic.component_digests.compiler == deterministic.components.compiler.digest
    assert deterministic.eligible?

    assert {:error, %{kind: :unavailable, operation: :wiki_synthesis_profile}} =
             Knowledge.resolve_repository_wiki_generation_profile(
               :manual_synthesis_disabled,
               %{},
               @now
             )

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.resolve_repository_wiki_generation_profile(
               :repository_selected_module,
               %{endpoint: "https://attacker.invalid"},
               @now
             )
  end

  test "defines immutable disabled price profiles with checked integer rounding", context do
    refute PriceProfile.selectable?(context.price, @later)

    assert {:ok, 53} =
             PriceProfile.cost(
               context.price,
               %{input: 1_001, output: 999, cached: 1, reasoning: 1},
               @later
             )

    assert {:error, %{operation: :wiki_cost_overflow}} =
             PriceProfile.cost(
               context.price,
               %{
                 input: 9_223_372_036_854_775_807,
                 output: 0,
                 cached: 0,
                 reasoning: 0
               },
               @later
             )

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_price_profile(%{
               revision: 1,
               provider: "provider",
               model: "model",
               region: "region",
               currency: "CAD",
               unit_tokens: 1_000,
               rates: %{input: 1, output: 1, cached: 1, reasoning: 1},
               rounding: :ceil,
               source_provenance: resource(:provider_object, "price"),
               effective_at: @now,
               expires_at: @expiry,
               state: :enabled
             })
  end

  test "reserves aggregate liability exactly once and prevents concurrent overspend", context do
    request = request(context, "reserve-1", context.attempt, context.invocation)
    reservation_context = reservation_context(context, [])

    assert {:ok, first} = Knowledge.reserve_repository_wiki_budget(request, reservation_context)
    assert first.liability.cost_microunits == 68
    assert first.liability.total_tokens == 3_750
    assert first.state == :reserved

    assert {:duplicate, ^first} =
             Knowledge.reserve_repository_wiki_budget(request, %{
               reservation_context
               | reservations: [first]
             })

    second_attempt = resource(:wiki_compilation_attempt, "budget-attempt-2")
    second_invocation = resource(:model_invocation, "budget-invocation-2")
    second_request = request(context, "reserve-2", second_attempt, second_invocation)

    assert {:error, :insufficient_budget} =
             Knowledge.reserve_repository_wiki_budget(
               second_request,
               %{reservation_context | reservations: [first]}
             )

    assert {:error, :stale_or_mismatched} =
             Knowledge.reserve_repository_wiki_budget(
               %{request | repository_iri: resource(:repository_reconciliation, "other")},
               reservation_context
             )

    assert {:ok, released} =
             Knowledge.transition_repository_wiki_reservation(first, :released, @later)

    assert released.state == :released

    assert {:ok, ^released} =
             Knowledge.transition_repository_wiki_reservation(released, :released, @later)
  end

  test "records terminal zero-token and measured usage without double charging", context do
    base = usage_attributes(context)

    assert {:ok, zero} = Knowledge.repository_wiki_deterministic_usage(base)
    assert zero.generation_mode == :deterministic_only
    assert zero.tokens == %{input: 0, output: 0, cached: 0, reasoning: 0}
    assert zero.costs == %{reserved: 0, measured: 0, charged: 0, refunded: 0, unknown: 0}

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_deterministic_usage(%{base | state: :not_terminal})

    request = request(context, "measured", context.attempt, context.invocation)

    assert {:ok, reservation} =
             Knowledge.reserve_repository_wiki_budget(request, reservation_context(context, []))

    raw = %{
      input: 1_000,
      output: 500,
      cached: 100,
      reasoning: 50,
      provider_request_iri: resource(:provider_object, "provider-request"),
      provider: context.price.provider,
      model: context.price.model,
      region: context.price.region,
      raw_evidence_digest: digest("raw-usage")
    }

    measured_attributes =
      base
      |> Map.merge(%{
        state: :success,
        reservation_iri: reservation.iri,
        invocation_iri: reservation.invocation_iri,
        reserved_cost: reservation.liability.cost_microunits
      })

    assert {:ok, measured} =
             Knowledge.repository_wiki_measured_usage(raw, context.price, measured_attributes)

    assert measured.costs.charged == 32
    assert measured.costs.refunded == 36

    usage =
      Map.merge(measured, %{
        accounting_fence: "accounting-9",
        price_revision: reservation.price_revision
      })

    assert {:ok, reconciliation} =
             Knowledge.reconcile_repository_wiki_usage(reservation, usage, %{
               accounting_fence: "accounting-9",
               usage_records: []
             })

    assert reconciliation.reservation.state == :consumed

    assert {:duplicate, ^usage} =
             Knowledge.reconcile_repository_wiki_usage(reservation, usage, %{
               accounting_fence: "accounting-9",
               usage_records: [usage]
             })

    assert {:error, :mismatched_usage} =
             Knowledge.reconcile_repository_wiki_usage(reservation, usage, %{
               accounting_fence: "accounting-10",
               usage_records: []
             })
  end

  test "builds revision-fenced reservation and terminal usage semantic commands", context do
    request = request(context, "semantic-reservation", context.attempt, context.invocation)

    assert {:ok, reservation} =
             Knowledge.reserve_repository_wiki_budget(request, reservation_context(context, []))

    attributes = command_attributes(context)

    assert {:ok, reserve_command} =
             Knowledge.reserve_repository_wiki_budget_command(
               reservation,
               context.budget,
               attributes,
               clock: fn -> @now end
             )

    assert reserve_command.command_type == "ReserveWikiModelBudget"
    assert reserve_command.command_version == "2.11.0"
    assert reserve_command.expected_graph_revisions == %{context.control_graph => 4}

    assert {:ok, usage} = Knowledge.repository_wiki_deterministic_usage(usage_attributes(context))

    assert {:ok, usage_command} =
             Knowledge.record_repository_wiki_usage(
               usage,
               attributes,
               clock: fn -> @now end
             )

    assert usage_command.command_type == "RecordWikiModelUsage"

    assert usage_command.expected_graph_revisions == %{
             context.control_graph => 4,
             context.run_graph => 2
           }
  end

  defp reservation_context(context, reservations) do
    %{
      budget: context.budget,
      price_profile: context.price,
      expected_fence: "source-fence-1",
      enrollment_revision: 4,
      committed: %{},
      reservations: reservations,
      evaluated_at: @now
    }
  end

  defp request(context, idempotency_key, attempt, invocation) do
    %{
      idempotency_key: idempotency_key,
      actor_iri: context.actor,
      tenant_iri: context.tenant,
      repository_iri: context.repository,
      session_iri: context.session,
      source_revision: "source-fence-1",
      edition_iri: context.edition,
      attempt_iri: attempt,
      profile_iri: context.synthesis.iri,
      provider: context.price.provider,
      model: context.price.model,
      price_revision: context.price.revision,
      prompt_digest: digest("prompt"),
      invocation_iri: invocation,
      budget_revision: context.budget.revision,
      enrollment_revision: 4,
      current_fence: "source-fence-1",
      currency: "CAD",
      maximum_usage: %{input: 2_000, output: 1_000, cached: 500, reasoning: 250},
      recorded_at: @now,
      expires_at: @later
    }
  end

  defp usage_attributes(context) do
    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      actor_iri: context.actor,
      attempt_iri: context.attempt,
      edition_iri: context.edition,
      profile_iri: context.synthesis.iri,
      reservation_iri: nil,
      invocation_iri: nil,
      state: :success,
      trigger: "manual",
      source_revision: "source-fence-1",
      currency: "CAD",
      local_work: %{elapsed_ms: 21, input_bytes: 1_024},
      recorded_at: @later
    }
  end

  defp command_attributes(context) do
    %{
      control_graph_iri: context.control_graph,
      run_graph_iri: context.run_graph,
      expected_control_revision: 4,
      expected_run_revision: 2,
      expected_dataset_revision: 9,
      enrollment_revision: 4,
      principal_iri: resource(:authorization_grant, "accounting-principal"),
      actor_iri: context.actor,
      scope_iri: context.repository,
      correlation_iri: resource(:authorization_grant, "accounting-correlation"),
      causation_iri: resource(:authorization_grant, "accounting-causation"),
      reason: "record exact wiki accounting"
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end

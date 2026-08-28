defmodule JidoCode.Knowledge.RepositoryWiki.OperationsCostTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.RepositoryWiki.BackupRestore
  alias JidoCode.Factory.RepositoryWiki.FleetOperations
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.OperationsTelemetry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.RepositoryWikiOperationsProjection

  @start ~U[2026-08-01 00:00:00Z]
  @now ~U[2026-08-28 16:00:00Z]
  @period_end ~U[2026-09-01 00:00:00Z]

  setup do
    %{
      repository: resource(:repository_reconciliation, "rw5-operations-repository"),
      other_repository: resource(:repository_reconciliation, "rw5-operations-other"),
      tenant: resource(:authorization_grant, "rw5-operations-tenant"),
      other_tenant: resource(:authorization_grant, "rw5-operations-other-tenant"),
      actor: resource(:authorization_grant, "rw5-operations-actor"),
      edition: resource(:wiki_edition, "rw5-operations-edition")
    }
  end

  test "reports deterministic local work as exactly zero model tokens and cost", fixture do
    attributes = projection_attributes(fixture, [usage(fixture, :deterministic_only, "CAD")], [])

    assert {:ok, projection} = RepositoryWikiOperationsProjection.build(attributes)
    assert projection.state == :ready
    assert projection.totals.attempts == 1
    assert projection.totals.deterministic_attempts == 1
    assert projection.totals.local_elapsed_ms == 25
    assert projection.totals.local_input_bytes == 4_096
    assert projection.totals.input_tokens == 0
    assert projection.totals.output_tokens == 0
    assert projection.totals.cached_tokens == 0
    assert projection.totals.reasoning_tokens == 0
    assert projection.totals.measured_cost_microunits == 0

    assert projection.currency_totals == [
             %{
               id: Contract.digest({:currency, "CAD"}),
               currency: "CAD",
               measured: 0,
               unknown: 0,
               reserved: 0
             }
           ]

    assert projection.profile.synthesis_available? == false
    assert projection.profile.unavailable_reason == :hosted_synthesis_disabled_in_v1
    assert Enum.any?(projection.breakdowns, &(&1.dimension == :trigger and &1.value == "manual"))
  end

  test "distinguishes reservations, pending and unknown usage, and currencies", fixture do
    cad =
      usage(fixture, :synthesis_allowed, "CAD",
        state: :usage_unknown,
        tokens: %{input: 10, output: 4, cached: 2, reasoning: 1},
        costs: %{reserved: 30, charged: 20, unknown: 10}
      )

    usd =
      usage(fixture, :synthesis_allowed, "USD",
        state: :usage_pending,
        tokens: %{input: 3, output: 1, cached: 0, reasoning: 0},
        costs: %{reserved: 8, charged: 0, unknown: 8},
        attempt_iri: resource(:execution_attempt, "rw5-operations-usd-attempt"),
        iri: resource(:wiki_usage_record, "rw5-operations-usd-usage")
      )

    reservations = [
      reservation(fixture, "CAD", :reserved, 40),
      reservation(fixture, "USD", :usage_pending, 12, "second")
    ]

    assert {:ok, projection} =
             RepositoryWikiOperationsProjection.build(
               projection_attributes(fixture, [cad, usd], reservations)
             )

    assert projection.state == :usage_unknown
    assert projection.totals.input_tokens == 13
    assert projection.totals.reserved_liability_microunits == 52
    assert projection.totals.measured_cost_microunits == 20
    assert projection.totals.unknown_liability_microunits == 18
    assert Enum.sort(projection.warnings) == [:multicurrency, :usage_pending, :usage_unknown]
    assert Enum.map(projection.currency_totals, & &1.currency) == ["CAD", "USD"]
    assert length(projection.reservations) == 2
    refute Enum.any?(projection.reservations, &Map.has_key?(&1, :repository_iri))
  end

  test "rejects cross-scope accounting and nonzero deterministic usage", fixture do
    cross_scope = %{
      usage(fixture, :deterministic_only, "CAD")
      | repository_iri: fixture.other_repository
    }

    assert {:error, %{kind: :unauthorized}} =
             RepositoryWikiOperationsProjection.build(
               projection_attributes(fixture, [cross_scope], [])
             )

    nonzero =
      usage(fixture, :deterministic_only, "CAD",
        tokens: %{input: 1, output: 0, cached: 0, reasoning: 0}
      )

    assert {:error, %{kind: :unauthorized}} =
             RepositoryWikiOperationsProjection.build(
               projection_attributes(fixture, [nonzero], [])
             )
  end

  test "projects fleet health and exact alert rules without process state", fixture do
    healthy = repository_snapshot(fixture, fixture.repository, fixture.tenant)

    degraded =
      repository_snapshot(fixture, fixture.other_repository, fixture.other_tenant)
      |> put_in([:current, :state], :stale)
      |> put_in([:compilation, :failed], 3)
      |> put_in([:compilation, :abandoned], 1)
      |> put_in([:queue, :pending], 25)
      |> put_in([:accounting, :live_reservations], 2)
      |> put_in([:accounting, :oldest_reservation_age_seconds], 7_200)
      |> put_in([:accounting, :usage_unknown], 1)
      |> put_in([:restore, :state], :drifted)

    assert {:ok, fleet} = FleetOperations.project([degraded, healthy], fleet_policy())
    assert fleet.repository_count == 2
    assert fleet.enrollment_counts == %{automatic: 2}
    assert fleet.stale_count == 1
    assert fleet.queue_pending == 25
    assert fleet.reservations_live == 2
    assert fleet.usage_unknown == 1
    assert Contract.digest?(fleet.digest)

    types = Enum.map(fleet.alerts, & &1.type)
    assert :stale_current_edition in types
    assert :repeated_deterministic_failure in types
    assert :abandoned_edition in types
    assert :queue_pressure in types
    assert :stuck_reservation in types
    assert :usage_unknown in types
    assert :restore_drift in types
  end

  test "emits only closed low-cardinality fleet telemetry", _fixture do
    handler = "rw5-fleet-telemetry-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        OperationsTelemetry.event(),
        fn event, measurements, metadata, _config ->
          send(parent, {:fleet_telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    measurements = %{
      repositories: 2,
      current: 1,
      stale: 1,
      queue_pending: 3,
      queue_active: 1,
      reservations_live: 1,
      usage_pending: 0,
      usage_unknown: 1,
      retained_bytes: 4_096,
      alerts: 2,
      duration_ms: 10
    }

    metadata = %{
      outcome: :degraded,
      operation: :projection,
      mode: :mixed,
      generation_profile: :deterministic_only,
      severity: :warning
    }

    assert :ok = OperationsTelemetry.emit(measurements, metadata)

    assert_receive {:fleet_telemetry, [:jido_code, :repository_wiki, :fleet], ^measurements,
                    ^metadata}

    assert_raise ArgumentError, fn ->
      OperationsTelemetry.emit(measurements, Map.put(metadata, :repository, "private-repo"))
    end

    assert_raise ArgumentError, fn ->
      OperationsTelemetry.emit(Map.put(measurements, :source_body, 1), metadata)
    end
  end

  test "backs up and restores multiple wiki graphs before rebuilding and restarting", fixture do
    repositories = [
      restore_repository(fixture.repository, fixture.tenant, "one"),
      restore_repository(fixture.other_repository, fixture.other_tenant, "two")
    ]

    parent = self()
    ports = restore_ports(parent)

    assert {:ok, evidence} =
             BackupRestore.execute(
               repositories,
               %{digest: digest("backup-snapshot"), dataset_revision: 91},
               ports,
               concurrency: 2
             )

    assert evidence.repository_count == 2
    assert evidence.restored_dataset_revision == 91
    assert Enum.all?(evidence.repositories, & &1.verified?)
    assert Enum.all?(evidence.repositories, & &1.projections_rebuilt?)
    assert Enum.all?(evidence.repositories, &(&1.maintainer == :running))
    assert Contract.digest?(evidence.digest)

    for _repository <- repositories do
      assert_receive {:rebuild, iri}
      assert iri in Enum.map(repositories, & &1.repository_iri)
      assert_receive {:restart, ^iri}
      assert_receive {:verify, ^iri}
    end
  end

  test "restore rejects cross-repository rebuilt projections", fixture do
    repository = restore_repository(fixture.repository, fixture.tenant, "drift")
    ports = restore_ports(self())

    drifting = %{
      ports
      | rebuild: fn _repository, _restored ->
          {:ok,
           %{
             repository_iri: fixture.other_repository,
             tenant_iri: fixture.tenant,
             disposable_projections?: true
           }}
        end
    }

    assert {:error, %{outcome: :cross_scope}} =
             BackupRestore.execute(
               [repository],
               %{digest: digest("backup-snapshot"), dataset_revision: 91},
               drifting
             )
  end

  defp projection_attributes(fixture, usage, reservations) do
    %{
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      evaluated_at: @now,
      period_start: @start,
      period_end: @now,
      usage_records: usage,
      reservations: reservations,
      budget: %{
        state: :available,
        limit: 10_000,
        remaining: 9_000,
        currency: "CAD",
        window_start: @start,
        window_end: @period_end
      },
      profile: %{
        deterministic_available?: true,
        synthesis_available?: false,
        unavailable_reason: :hosted_synthesis_disabled_in_v1
      }
    }
  end

  defp usage(fixture, mode, currency, overrides \\ []) do
    %{
      iri: resource(:wiki_usage_record, "rw5-operations-usage"),
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      attempt_iri: resource(:execution_attempt, "rw5-operations-attempt"),
      edition_iri: fixture.edition,
      actor_iri: fixture.actor,
      generation_mode: mode,
      trigger: "manual",
      profile_key:
        if(mode == :deterministic_only, do: "manual_deterministic", else: "test_synthesis"),
      source_revision: digest("rw5-operations-source"),
      state: :success,
      tokens: %{input: 0, output: 0, cached: 0, reasoning: 0},
      costs: %{reserved: 0, charged: 0, unknown: 0},
      currency: currency,
      local_work: %{elapsed_ms: 25, input_bytes: 4_096},
      recorded_at: ~U[2026-08-20 10:00:00Z]
    }
    |> Map.merge(Map.new(overrides))
  end

  defp reservation(fixture, currency, state, cost, suffix \\ "first") do
    %{
      iri: resource(:wiki_reservation, "rw5-reservation-#{suffix}"),
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      state: state,
      cost_microunits: cost,
      currency: currency,
      expires_at: @period_end
    }
  end

  defp repository_snapshot(fixture, repository, tenant) do
    %{
      repository_iri: repository,
      tenant_iri: tenant,
      enrollment: :automatic,
      current: %{state: :current, recorded_at: ~U[2026-08-28 15:55:00Z]},
      maintainer: :running,
      lease: %{expires_at: ~U[2026-08-28 16:05:00Z], fence: "lease-5"},
      queue: %{pending: 0, active: 1},
      compilation: %{success: 3, failed: 0, abandoned: 0},
      coverage: %{pages: 20, dependencies: 42, guides: 5, gaps: 0},
      accounting: %{
        live_reservations: 0,
        usage_pending: 0,
        usage_unknown: 0,
        oldest_reservation_age_seconds: 0
      },
      storage: %{edition_count: 3, retained_bytes: 12_000},
      restore: %{state: :verified, recorded_at: ~U[2026-08-28 15:00:00Z]},
      cross_scope_violation?: false,
      fixture: fixture.repository
    }
  end

  defp fleet_policy do
    %{
      evaluated_at: @now,
      stale_after_seconds: 3_600,
      repeated_failure_threshold: 3,
      abandoned_after_seconds: 3_600,
      lease_grace_seconds: 60,
      queue_pressure_threshold: 20,
      reservation_stuck_seconds: 3_600
    }
  end

  defp restore_repository(repository, tenant, suffix) do
    %{
      repository_iri: repository,
      tenant_iri: tenant,
      current_edition_iri: resource(:wiki_edition, "rw5-restore-edition-#{suffix}"),
      source_fence: "source-#{suffix}",
      accounting_digest: digest("accounting-#{suffix}"),
      enrollment_revision: 5,
      cancellation_generation: 2
    }
  end

  defp restore_ports(parent) do
    %{
      backup: fn snapshot -> {:ok, %{digest: snapshot.digest}} end,
      restore: fn backup, snapshot ->
        {:ok, %{digest: backup.digest, dataset_revision: snapshot.dataset_revision}}
      end,
      rebuild: fn repository, _restored ->
        send(parent, {:rebuild, repository.repository_iri})

        {:ok,
         %{
           repository_iri: repository.repository_iri,
           tenant_iri: repository.tenant_iri,
           disposable_projections?: true
         }}
      end,
      restart: fn repository, rebuilt ->
        send(parent, {:restart, repository.repository_iri})

        {:ok,
         %{
           repository_iri: rebuilt.repository_iri,
           tenant_iri: rebuilt.tenant_iri,
           state: :running
         }}
      end,
      verify: fn repository, _restored, _rebuilt, _restarted ->
        send(parent, {:verify, repository.repository_iri})

        {:ok,
         %{
           repository_iri: repository.repository_iri,
           tenant_iri: repository.tenant_iri,
           graph_digest: digest({:graph, repository.repository_iri}),
           current_edition_iri: repository.current_edition_iri,
           source_fence: repository.source_fence,
           accounting_digest: repository.accounting_digest,
           enrollment_revision: repository.enrollment_revision,
           cancellation_generation: repository.cancellation_generation,
           current_count: 1
         }}
      end
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: Contract.digest(value)
end

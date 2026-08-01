defmodule JidoCode.Knowledge.Repositories.Phase06EnrollmentTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.Enrollment
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.Repositories.Projection
  alias JidoCode.Knowledge.Repositories.Subscription
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    {:ok, fixture: fixture, authority: authority}
  end

  test "conceptual identity rejects locations and locator identity survives transfer" do
    assert {:error, %{kind: :invalid_input}} =
             ResourceIdentity.conceptual_repository("https://github.com/agentjido/jido_code")

    assert {:error, %{kind: :invalid_input}} =
             ResourceIdentity.conceptual_repository("/tmp/jido_code")

    assert {:error, %{kind: :invalid_input}} = ResourceIdentity.conceptual_repository(%{})

    observed_at = ~U[2026-08-01 12:00:00Z]

    assert {:ok, original} =
             locator(%{
               external_id: "R_kgDOPhase6",
               owner: "agentjido",
               state: :active,
               observed_at: observed_at
             })

    assert {:ok, transferred} =
             locator(%{
               external_id: "R_kgDOPhase6",
               owner: "jido",
               state: :transferred,
               observed_at: DateTime.add(observed_at, 60)
             })

    assert original.iri == transferred.iri
    assert original.canonical == transferred.canonical
    refute original.observed_address == transferred.observed_address
    assert original.canonical == "github.com/id/R_kgDOPhase6"
  end

  test "repository catalog version extends without changing the Phase 5 contract" do
    assert QueryCatalog.version() == "1.0.0"
    assert QueryCatalog.repository_version() == "1.1.0"
    assert length(QueryCatalog.names("1.0.0")) == 17
    assert length(QueryCatalog.names("1.1.0")) == 27
    assert :ok = QueryCatalog.verify()

    for name <- [
          :repository_description,
          :locator_resolution,
          :active_enrollment,
          :enrollment_history,
          :factory_repository_cohort
        ] do
      assert {:ok, definition} = QueryCatalog.fetch(name, "1.1.0")
      assert definition.graph_families == [:factory_catalog]
    end

    assert {:error, %{kind: :invalid_input}} =
             QueryCatalog.fetch(:repository_description, "1.0.0")

    assert "ChangeEnrollment" in CommandRegistry.names("1.1.0")
    assert "ReconcileRepositoryIdentity" in CommandRegistry.names("1.1.0")
  end

  test "enrolls, reconciles, changes locators, suspends admission, and projects history", %{
    fixture: fixture,
    authority: authority
  } do
    repository = conceptual_repository!("phase-06-managed-repository")
    repository_scope = Phase04Fixture.scope!(:repository, "phase-06-managed-repository")
    policy_boundary = Phase04Fixture.resource!("phase-06-policy-boundary")
    policy = Phase04Fixture.resource!("phase-06-policy")
    command_iri = Phase04Fixture.local!(:command, 601)

    {:ok, primary_locator} =
      locator(%{
        external_id: "R_phase_06_primary",
        owner: "agentjido",
        state: :active,
        observed_at: fixture.issued_at
      })

    assert {:ok, enrollment} =
             Enrollment.new(%{
               factory_iri: fixture.factory_iri,
               repository_iri: repository,
               repository_scope_iri: repository_scope,
               policy_boundary_iri: policy_boundary,
               policy_iris: [policy],
               locator: primary_locator,
               actor_iri: fixture.actor,
               cause_iri: command_iri,
               reason: "accept repository into Phase 6 fixture",
               valid_from: fixture.issued_at,
               valid_to: DateTime.add(fixture.issued_at, 86_400 * 365)
             })

    assert {:ok, initial} = EnrollmentTransition.resolve(enrollment.transitions)
    assert initial.current_state == :active
    assert initial.admission == :allowed

    assert {:ok, enroll_command} =
             Enrollment.enroll_command(
               enrollment,
               command_attributes(fixture, command_iri, "phase-06-enroll"),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, enroll_receipt} = Writer.execute(fixture.writer, enroll_command)
    assert enroll_receipt.outcome == :committed

    duplicate_iri = Phase04Fixture.local!(:command, 602)

    assert {:ok, duplicate} =
             Enrollment.enroll_command(
               enrollment,
               command_attributes(fixture, duplicate_iri, "phase-06-overlap"),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, duplicate_receipt} = Writer.execute(fixture.writer, duplicate)
    assert duplicate_receipt.outcome == :conflicted

    evidence_command_iri = Phase04Fixture.local!(:command, 603)

    assert {:ok, reconcile} =
             Enrollment.reconcile_locator_command(
               repository,
               primary_locator,
               command_attributes(fixture, evidence_command_iri, "phase-06-reconcile")
               |> Map.merge(%{
                 evidence_source_iri: Phase04Fixture.resource!("provider-identity-evidence"),
                 evidence_digest: String.duplicate("a", 64),
                 actor_iri: fixture.actor,
                 recorded_at: fixture.issued_at
               }),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, _receipt} = Writer.execute(fixture.writer, reconcile)

    {:ok, transferred_locator} =
      locator(%{
        external_id: "R_phase_06_primary",
        owner: "jido",
        state: :transferred,
        observed_at: DateTime.add(fixture.issued_at, 60)
      })

    transfer_iri = Phase04Fixture.local!(:command, 604)

    assert {:ok, transfer} =
             Enrollment.change_command(
               initial,
               change_attributes(
                 fixture,
                 transfer_iri,
                 :active,
                 "phase-06-transfer",
                 %{
                   change_kind: :locator_change,
                   locator: transferred_locator,
                   repository_iri: repository
                 }
               ),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, _receipt} = Writer.execute(fixture.writer, transfer.command)

    {:ok, after_transfer} =
      EnrollmentTransition.resolve(enrollment.transitions ++ [transfer.transition])

    {:ok, mirror_locator} =
      locator(%{
        external_id: "R_phase_06_mirror",
        owner: "jido-mirror",
        state: :active,
        observed_at: DateTime.add(fixture.issued_at, 120),
        relationships: [%{kind: :mirror, locator_iri: primary_locator.iri}]
      })

    mirror_iri = Phase04Fixture.local!(:command, 605)

    assert {:ok, mirror} =
             Enrollment.change_command(
               after_transfer,
               change_attributes(fixture, mirror_iri, :active, "phase-06-mirror", %{
                 change_kind: :locator_change,
                 locator: mirror_locator,
                 repository_iri: repository
               }),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, _receipt} = Writer.execute(fixture.writer, mirror.command)

    {:ok, after_mirror} =
      EnrollmentTransition.resolve(
        enrollment.transitions ++ [transfer.transition, mirror.transition]
      )

    suspend_iri = Phase04Fixture.local!(:command, 606)

    assert {:ok, suspension} =
             Enrollment.change_command(
               after_mirror,
               change_attributes(fixture, suspend_iri, :suspended, "phase-06-suspend"),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, _receipt} = Writer.execute(fixture.writer, suspension.command)

    assert {:ok, suspended} =
             EnrollmentTransition.resolve(
               enrollment.transitions ++
                 [transfer.transition, mirror.transition, suspension.transition]
             )

    assert suspended.current_state == :suspended
    assert suspended.admission == {:blocked, :suspended}

    results =
      repository_results(fixture, authority, repository, enrollment, [
        primary_locator,
        mirror_locator
      ])

    assert {:ok, projection} = Projection.build(repository, results)
    assert projection.repository_iri == repository

    assert Enum.map(projection.locators, & &1.iri) ==
             Enum.sort([primary_locator.iri, mirror_locator.iri])

    assert [projected_enrollment] = projection.enrollments
    assert projected_enrollment.state == "suspended"
    refute projected_enrollment.admission
    assert policy in projected_enrollment.policy_refs
    assert length(projected_enrollment.history) == 5
    assert projection.receipt.complete?
    refute projection.receipt.truncated?
  end

  test "subscription re-queries catalog, policy, and observation scope hints", %{
    fixture: fixture,
    authority: authority
  } do
    repository_scope = Phase04Fixture.scope!(:repository, "phase-06-subscription")
    owner = self()

    refresh = fn _authority, revision ->
      {:ok, %{receipt: %{dataset_revision: revision}, marker: :refreshed}}
    end

    assert {:ok, subscription} =
             Subscription.start_link(
               scope_iris: [fixture.factory_scope, repository_scope],
               authority: authority,
               refresh: refresh,
               owner: owner,
               debounce_ms: 0
             )

    send(subscription, {
      :jido_code_change,
      %JidoCode.Knowledge.ChangeEvent{
        dataset_revision: 11,
        affected_graphs: [%{family: :factory_policy, revision: 2}],
        scope_iri: fixture.factory_scope,
        command_class: "AssertDesiredOutcome",
        receipt_iri: Phase04Fixture.resource!("phase-06-subscription-receipt")
      }
    })

    assert_receive {:repository_projection_refreshed,
                    %{receipt: %{dataset_revision: 11}, marker: :refreshed}}

    assert Subscription.last_revision(subscription) == 11

    send(subscription, {
      :jido_code_change,
      %JidoCode.Knowledge.ChangeEvent{
        dataset_revision: 12,
        affected_graphs: [%{family: :run_attempt, revision: 1}],
        scope_iri: repository_scope,
        command_class: "RecordExecutionAttempt",
        receipt_iri: Phase04Fixture.resource!("phase-06-ignored-receipt")
      }
    })

    refute_receive {:repository_projection_refreshed, _result}, 30
  end

  defp repository_results(fixture, authority, repository, enrollment, locators) do
    catalog = fixture.graphs.catalog

    {:ok, repository_result} =
      query(fixture, authority, :repository_description, %{
        graph: catalog,
        resource: repository
      })

    {:ok, enrollment_result} =
      query(fixture, authority, :active_enrollment, %{graph: catalog, resource: repository})

    {:ok, history_result} =
      query(fixture, authority, :enrollment_history, %{
        graph: catalog,
        resource: enrollment.iri
      })

    locator_results =
      Enum.map(locators, fn locator ->
        {:ok, result} =
          query(fixture, authority, :repository_description, %{
            graph: catalog,
            resource: locator.iri
          })

        result
      end)

    %{
      repository: repository_result,
      enrollments: enrollment_result,
      histories: [history_result],
      locators: locator_results
    }
  end

  defp query(fixture, authority, name, parameters) do
    QueryRunner.execute(
      name,
      "1.1.0",
      parameters,
      authority,
      fixture.factory_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp command_attributes(fixture, command_iri, idempotency_key) do
    %{
      command_iri: command_iri,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      factory_scope_iri: fixture.factory_scope,
      idempotency_key: idempotency_key,
      correlation_iri: Phase04Fixture.local!(:activity, :erlang.phash2(command_iri, 200) + 700),
      causation_iri: fixture.bootstrap_command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      catalog_graph_iri: fixture.graphs.catalog,
      expected_catalog_revision:
        Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog),
      reason: "phase 06 repository enrollment integration"
    }
  end

  defp change_attributes(fixture, command_iri, next_state, key, extra \\ %{}) do
    command_attributes(fixture, command_iri, key)
    |> Map.merge(%{
      next_state: next_state,
      actor_iri: fixture.actor,
      recorded_at: fixture.issued_at
    })
    |> Map.merge(extra)
  end

  defp locator(overrides) do
    Locator.new(
      Map.merge(
        %{
          provider: "https://github.com",
          external_id: "R_default",
          owner: "agentjido",
          name: "jido_code",
          state: :active,
          observed_at: ~U[2026-08-01 12:00:00Z],
          relationships: []
        },
        overrides
      )
    )
  end

  defp conceptual_repository!(seed) do
    {:ok, iri} = ResourceIdentity.conceptual_repository(seed)
    iri
  end
end

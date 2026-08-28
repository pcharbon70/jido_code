defmodule JidoCode.Knowledge.RepositoryWiki.MaintainerRuntimeTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.RepositoryWiki.MaintainerLease
  alias JidoCode.Factory.RepositoryWiki.Coordinator, as: RepositoryWikiCoordinator
  alias JidoCode.Runtime.RepositoryWikiMaintainerSupervisor
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 15:00:00Z]
  @expiry ~U[2026-08-29 15:00:00Z]
  @registry JidoCode.TestWikiMaintainerRegistry
  @supervisor JidoCode.TestWikiMaintainerSupervisor
  @coordinator JidoCode.TestWikiMaintainerCoordinator

  setup do
    start_supervised!({Registry, keys: :unique, name: @registry})

    start_supervised!(
      {DynamicSupervisor, name: @supervisor, strategy: :one_for_one, max_restarts: 10}
    )

    test_pid = self()

    start_supervised!(
      {RepositoryWikiCoordinator,
       name: @coordinator,
       registry: @registry,
       supervisor: @supervisor,
       lease_gateway: fn lease ->
         send(test_pid, {:lease_committed, lease})
         {:ok, %{status: :committed}}
       end}
    )

    repository = resource(:repository_reconciliation, "maintainer-repository")
    tenant = resource(:authorization_grant, "maintainer-tenant")
    generation_profile = resource(:wiki_generation_profile, "maintainer-generation-profile")
    holder = resource(:wiki_maintainer, "maintainer-holder")
    {:ok, profile} = Knowledge.repository_wiki_maintainer_profile(@now, @expiry)
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    enrollment = %{
      state: :automatic,
      maintenance_mode: :automatic,
      generation_mode: :deterministic_only,
      repository_iri: repository,
      tenant_iri: tenant,
      generation_profile_iri: generation_profile,
      revision: 8,
      cancellation_generation: 2
    }

    context = %{
      repository_iri: repository,
      tenant_iri: tenant,
      generation_profile_iri: generation_profile,
      maintainer_profile_digest: profile.digest,
      enrollment_revision: 8,
      cancellation_generation: 2,
      policy_revision: 4,
      current_policy_revision: 4,
      worker_ready?: true,
      evaluated_at: DateTime.add(@now, 60, :second),
      holder_iri: holder
    }

    %{
      repository: repository,
      tenant: tenant,
      generation_profile: generation_profile,
      holder: holder,
      profile: profile,
      enrollment: enrollment,
      context: context,
      control_graph: control_graph
    }
  end

  test "admits only exact automatic deterministic enrollment", context do
    assert :ok =
             Knowledge.repository_wiki_maintainer_eligibility(
               context.profile,
               context.enrollment,
               context.context
             )

    assert {:error, :manual_process_free} =
             Knowledge.repository_wiki_maintainer_eligibility(
               context.profile,
               %{context.enrollment | state: :manual, maintenance_mode: :manual},
               context.context
             )

    assert {:error, :off} =
             Knowledge.repository_wiki_maintainer_eligibility(
               context.profile,
               %{context.enrollment | state: :off, maintenance_mode: :off},
               context.context
             )

    assert {:error, :stale_enrollment} =
             Knowledge.repository_wiki_maintainer_eligibility(
               context.profile,
               context.enrollment,
               %{context.context | enrollment_revision: 9}
             )

    manual = %{context.enrollment | state: :manual, maintenance_mode: :manual}

    assert {:error, :manual_process_free} =
             RepositoryWikiCoordinator.ensure_owner(
               @coordinator,
               manual,
               context.profile,
               context.context
             )

    assert RepositoryWikiMaintainerSupervisor.active(@supervisor) == []

    assert {:error, :manual_request_not_admitted} =
             RepositoryWikiCoordinator.start_manual_owner(
               @coordinator,
               manual,
               context.profile,
               context.context
             )

    assert {:ok, %{purpose: :manual_request}} =
             RepositoryWikiCoordinator.start_manual_owner(
               @coordinator,
               manual,
               context.profile,
               Map.put(context.context, :manual_request_admitted?, true)
             )

    assert length(RepositoryWikiMaintainerSupervisor.active(@supervisor)) == 1
  end

  test "acquires, renews, fences takeover, and revokes graph leases", context do
    attributes = lease_attributes(context)
    assert {:ok, first} = Knowledge.acquire_repository_wiki_maintainer_lease(attributes)
    assert first.generation == 1
    assert first.state == :active

    assert {:duplicate, ^first} =
             Knowledge.acquire_repository_wiki_maintainer_lease(attributes, first)

    other_holder = resource(:wiki_maintainer, "other-holder")

    assert {:error, :owned} =
             Knowledge.acquire_repository_wiki_maintainer_lease(
               %{attributes | holder_iri: other_holder},
               first
             )

    renewed_at = DateTime.add(attributes.acquired_at, 5, :second)
    renewed_expiry = DateTime.add(renewed_at, 30, :second)

    assert {:ok, renewed} =
             Knowledge.renew_repository_wiki_maintainer_lease(first, %{
               holder_iri: first.holder_iri,
               generation: first.generation,
               fence: first.fence,
               enrollment_revision: first.enrollment_revision,
               profile_digest: first.profile_digest,
               cancellation_generation: first.cancellation_generation,
               heartbeat_at: renewed_at,
               expires_at: renewed_expiry
             })

    assert renewed.expires_at == renewed_expiry

    takeover_at = DateTime.add(first.expires_at, 1, :second)

    assert {:ok, successor} =
             Knowledge.acquire_repository_wiki_maintainer_lease(
               %{
                 attributes
                 | holder_iri: other_holder,
                   acquired_at: takeover_at,
                   expires_at: DateTime.add(takeover_at, 30, :second)
               },
               first
             )

    assert successor.generation == 2
    refute successor.fence == first.fence

    assert {:ok, revoked} = MaintainerLease.revoke(successor, 3, takeover_at)
    refute MaintainerLease.current?(revoked, lease_context(successor), takeover_at)
  end

  test "builds an enabled exact-fence maintainer lease semantic command", context do
    assert {:ok, lease} =
             Knowledge.acquire_repository_wiki_maintainer_lease(lease_attributes(context))

    assert {:ok, command} =
             Knowledge.acquire_repository_wiki_maintainer_lease_command(
               lease,
               %{
                 control_graph_iri: context.control_graph,
                 expected_control_revision: 6,
                 expected_dataset_revision: 12,
                 enrollment_revision: 8,
                 source_fence: "maintainer-source-1",
                 principal_iri: resource(:authorization_grant, "maintainer-principal"),
                 actor_iri: resource(:authorization_grant, "maintainer-actor"),
                 scope_iri: context.repository,
                 correlation_iri: resource(:authorization_grant, "maintainer-correlation"),
                 causation_iri: resource(:authorization_grant, "maintainer-causation"),
                 reason: "acquire current repository wiki maintainer"
               },
               clock: fn -> @now end
             )

    assert command.command_type == "AcquireWikiMaintainerLease"
    assert command.command_version == "2.11.0"
    assert command.expected_graph_revisions == %{context.control_graph => 6}
  end

  test "serializes parallel starts to one runtime owner and keeps other repositories independent",
       context do
    outcomes =
      1..12
      |> Task.async_stream(
        fn _index ->
          RepositoryWikiCoordinator.ensure_owner(
            @coordinator,
            context.enrollment,
            context.profile,
            context.context
          )
        end,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, outcome} -> outcome end)

    assert Enum.count(outcomes, &match?({:ok, _}, &1)) == 1
    assert Enum.count(outcomes, &match?({:already_started, _}, &1)) == 11
    assert_receive {:lease_committed, lease}
    assert lease.repository_iri == context.repository
    assert length(RepositoryWikiMaintainerSupervisor.active(@supervisor)) == 1

    assert {:ok, status} =
             RepositoryWikiCoordinator.status(@coordinator, context.tenant, context.repository)

    assert status.state == :idle
    assert status.queued_trigger_count == 0
    assert status.lease_generation == 1

    other_repository = resource(:repository_reconciliation, "other-maintained-repository")
    other_profile_iri = resource(:wiki_generation_profile, "other-generation-profile")

    other_enrollment = %{
      context.enrollment
      | repository_iri: other_repository,
        generation_profile_iri: other_profile_iri
    }

    other_context = %{
      context.context
      | repository_iri: other_repository,
        generation_profile_iri: other_profile_iri,
        holder_iri: resource(:wiki_maintainer, "other-runtime-holder")
    }

    assert {:ok, _owner} =
             RepositoryWikiCoordinator.ensure_owner(
               @coordinator,
               other_enrollment,
               context.profile,
               other_context
             )

    assert length(RepositoryWikiMaintainerSupervisor.active(@supervisor)) == 2

    assert :ok =
             RepositoryWikiCoordinator.stop_owner(
               @coordinator,
               context.tenant,
               context.repository
             )

    assert {:ok, %{state: :not_running}} =
             RepositoryWikiCoordinator.status(@coordinator, context.tenant, context.repository)
  end

  test "publishes bounded graph-backed maintainer status only in runtime query revision" do
    assert QueryCatalog.repository_wiki_version() == "2.10.0"
    assert QueryCatalog.repository_wiki_runtime_version() == "2.11.0"
    refute :repository_wiki_maintainer_status in QueryCatalog.names("2.10.0")
    assert :repository_wiki_maintainer_status in QueryCatalog.names("2.11.0")

    assert {:ok, definition} =
             QueryCatalog.fetch(:repository_wiki_maintainer_status, "2.11.0")

    assert definition.graph_families == [:repository_control]
    assert definition.limits.row_limit == 200
    assert :ok = QueryCatalog.verify()
  end

  defp lease_attributes(context) do
    acquired_at = context.context.evaluated_at

    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      holder_iri: context.holder,
      profile_digest: context.profile.digest,
      enrollment_revision: context.enrollment.revision,
      cancellation_generation: context.enrollment.cancellation_generation,
      acquired_at: acquired_at,
      expires_at: DateTime.add(acquired_at, 30, :second)
    }
  end

  defp lease_context(lease) do
    %{
      enrollment_revision: lease.enrollment_revision,
      profile_digest: lease.profile_digest,
      cancellation_generation: lease.cancellation_generation
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

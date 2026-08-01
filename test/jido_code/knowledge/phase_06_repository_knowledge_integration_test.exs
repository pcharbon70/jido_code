defmodule JidoCode.Knowledge.Phase06RepositoryKnowledgeIntegrationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias JidoCode.Factory.Observations.Command, as: ObservationCommand
  alias JidoCode.Factory.Observations.Ingress
  alias JidoCode.Factory.SourceAnalysis.Request
  alias JidoCode.Integrations.FakeRepositoryProvider
  alias JidoCode.Integrations.GitRepository
  alias JidoCode.Knowledge.CommandStatus
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Projections.Source
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase06Fixture

  setup context do
    {:ok, fixture: Phase06Fixture.complete!(context)}
  end

  test "enrollment, provider/Git observation, source semantics, reorder, and lifecycle converge",
       %{
         fixture: fixture
       } do
    assert fixture.enrollment_receipt.outcome == :committed
    assert fixture.observation_receipt.outcome == :committed
    assert fixture.publication_receipt.outcome == :committed
    assert GitRepository.compare_revision(fixture.initial_commit, fixture.git_snapshot) == :match

    assert {:ok, enrollments} =
             Phase06Fixture.query(
               fixture,
               :active_enrollment,
               %{
                 graph: fixture.graphs.catalog,
                 resource: fixture.repository
               },
               fixture.factory_scope
             )

    assert Enum.any?(enrollments.data, fn row ->
             get_in(row, ["enrollment", :value]) == fixture.enrollment.iri
           end)

    assert {:ok, latest} =
             Phase06Fixture.query(fixture, :latest_complete_observation, %{
               graph: fixture.observation.graph_iri,
               resource: fixture.enrollment.iri
             })

    assert [%{"batch" => %{value: batch}}] = latest.data
    assert batch == fixture.observation.batch_iri

    assert {:ok, modules} =
             Phase06Fixture.query(fixture, :source_modules, %{
               graph: fixture.publication.graph_iri,
               snapshot: fixture.observation.snapshot_iri
             })

    assert Enum.any?(modules.data, &(get_in(&1, ["name", :value]) == "Integration.Server"))

    assert {:ok, source_projection} =
             Source.build(modules, %{
               graph_iri: fixture.publication.graph_iri,
               snapshot_iri: fixture.observation.snapshot_iri,
               repository_iri: fixture.repository
             })

    assert source_projection.source.coverage == "complete"
    refute source_projection.source.degraded?

    assert {:ok, duplicate_observation} =
             Writer.execute(fixture.writer, fixture.observation.command)

    assert duplicate_observation.outcome == :already_committed

    assert {:ok, duplicate_source} =
             Writer.execute(fixture.writer, fixture.publication.command)

    assert duplicate_source.outcome == :already_committed

    first_graph = fixture.observation.graph_iri

    delayed =
      Phase06Fixture.provider_observation!(
        fixture,
        "delayed-poll",
        fixture.git_snapshot,
        source_time: DateTime.add(fixture.issued_at, -3_600)
      )

    assert delayed.observation_receipt.outcome == :committed
    refute delayed.observation.graph_iri == first_graph

    assert {:ok, first_metadata} =
             QueryRunner.graph_metadata(first_graph, server: fixture.query_runner)

    assert {:ok, delayed_metadata} =
             QueryRunner.graph_metadata(delayed.observation.graph_iri,
               server: fixture.query_runner
             )

    assert first_metadata.lifecycle_state == :closed
    assert delayed_metadata.lifecycle_state == :closed

    {:ok, transferred_locator} =
      Locator.new(%{
        provider: "https://github.com",
        external_id: fixture.knowledge_locator.external_id,
        owner: "jido",
        name: "managed-integration",
        state: :transferred,
        observed_at: DateTime.add(fixture.issued_at, 1),
        relationships: []
      })

    fixture =
      Phase06Fixture.transition!(delayed, :active, 1, %{
        change_kind: :locator_change,
        locator: transferred_locator,
        repository_iri: fixture.repository
      })

    fixture = Phase06Fixture.transition!(fixture, :suspended, 2)
    assert fixture.enrollment_resolution.admission == {:blocked, :suspended}

    assert {:error, %{kind: :conflict, operation: :observation_enrollment_inactive}} =
             Ingress.poll(%{
               enrollment: fixture.enrollment_resolution,
               locator: fixture.external_locator,
               observations: fixture.provider_observations,
               retrieved_at: fixture.issued_at,
               poll_identity: "blocked-while-suspended"
             })

    fixture = Phase06Fixture.transition!(fixture, :active, 3)
    fixture = Phase06Fixture.transition!(fixture, :retiring, 4)
    fixture = Phase06Fixture.transition!(fixture, :retired, 5)
    assert fixture.enrollment_resolution.current_state == :retired
    assert fixture.enrollment_resolution.admission == {:blocked, :retired}

    assert {:ok, history} =
             Phase06Fixture.query(
               fixture,
               :enrollment_history,
               %{
                 graph: fixture.graphs.catalog,
                 resource: fixture.enrollment.iri
               },
               fixture.factory_scope
             )

    assert length(history.data) == 7

    assert history.data |> List.last() |> get_in(["state", :value]) ==
             EnrollmentTransition.state_iri(:retired)
  end

  test "failure boundaries reject substitution and redact external/source material", %{
    fixture: fixture
  } do
    context = Phase06Fixture.observation_context(fixture, fixture.git_snapshot)
    other_enrollment = Phase04Fixture.resource!("phase-06-other-enrollment")

    assert {:error, %{kind: :invalid_input, operation: :observation_command}} =
             ObservationCommand.build(
               fixture.observation_envelope,
               put_in(context, [:enrollment, :enrollment_iri], other_enrollment),
               clock: fn -> fixture.issued_at end
             )

    assert {:error, %{kind: :invalid_input, operation: :observation_command}} =
             ObservationCommand.build(
               fixture.observation_envelope,
               %{context | locator_iri: Phase04Fixture.resource!("phase-06-other-locator")},
               clock: fn -> fixture.issued_at end
             )

    {:ok, failed_provider} =
      FakeRepositoryProvider.new(%{
        {:repository, fixture.external_locator.external_id} =>
          {:error, :unauthorized, :provider_stale_credentials},
        {:issues, fixture.external_locator.external_id, nil} => %{
          observations: fixture.provider_observations,
          next_cursor: "partial-page"
        },
        {:issues, fixture.external_locator.external_id, "partial-page"} =>
          {:error, :unavailable, :provider_rate_limit}
      })

    assert {:error, %{kind: :unauthorized, operation: :provider_stale_credentials}} =
             FakeRepositoryProvider.observe_repository(
               failed_provider,
               fixture.external_locator,
               fixture.credential_reference,
               []
             )

    assert {:ok, %{next_cursor: "partial-page"}} =
             FakeRepositoryProvider.observe_collection(
               failed_provider,
               :issues,
               fixture.external_locator,
               fixture.credential_reference,
               nil,
               []
             )

    assert {:error, %{kind: :unavailable, operation: :provider_rate_limit}} =
             FakeRepositoryProvider.observe_collection(
               failed_provider,
               :issues,
               fixture.external_locator,
               fixture.credential_reference,
               "partial-page",
               []
             )

    partial =
      Phase06Fixture.provider_observation!(fixture, "partial-poll", fixture.git_snapshot,
        completeness: :partial
      )

    assert partial.observation_receipt.outcome == :committed
    assert "pagination_incomplete" in partial.observation_envelope.warnings

    deleted =
      Phase06Fixture.provider_observation!(fixture, "deleted-poll", fixture.git_snapshot,
        availability: false
      )

    assert deleted.observation_receipt.outcome == :committed

    secret = "phase-six-secret-value"
    body = Jason.encode!(%{"repository" => %{"id" => fixture.external_locator.external_id}})

    assert {:error, %{kind: :unauthorized, operation: :webhook_signature}} =
             Ingress.webhook(%{
               enrollment: fixture.enrollment_resolution,
               locator: fixture.external_locator,
               content_type: "application/json",
               body: body,
               signature: "sha256=" <> String.duplicate("0", 64),
               secret: secret,
               delivery_id: "invalid-signature",
               event: "repository",
               delivered_at: fixture.issued_at,
               received_at: fixture.issued_at
             })

    assert {:error, %{kind: :unavailable, operation: :git_command}} =
             GitRepository.materialize(fixture.git_adapter, %{
               remote: fixture.source_repository,
               ref: "refs/heads/missing",
               operation_id: "missing-ref",
               depth: 5
             })

    limited_snapshot = %{
      fixture.git_snapshot
      | submodules?: true,
        lfs?: true,
        limitations: ["shallow_history"]
    }

    limited = Phase06Fixture.analyze!(fixture, fixture.worktree, limited_snapshot)
    assert limited.coverage.status == :partial
    assert "submodules_not_analyzed" in limited.warnings
    assert "lfs_objects_not_analyzed" in limited.warnings
    assert "git_snapshot_limited" in limited.warnings

    assert {:error, %{kind: :invalid_input}} =
             Request.new(%{
               repository_iri: fixture.repository,
               snapshot_iri: fixture.observation.snapshot_iri,
               worktree: fixture.worktree,
               git_snapshot: fixture.git_snapshot,
               profile: :elixir,
               include_paths: ["../private"],
               exclude_paths: [],
               limits: %{},
               ontology_version: "1.0.0",
               output_graph_iri: fixture.publication.graph_iri,
               input_tree_digest: fixture.git_snapshot.tree_sha
             })

    log =
      capture_log(fn ->
        assert {:ok, _metadata} =
                 QueryRunner.graph_metadata(fixture.publication.graph_iri,
                   server: fixture.query_runner
                 )
      end)

    dataset = Phase04Fixture.export_dataset!(fixture)
    canonical = RDF.NQuads.write_string!(dataset, sort: true)

    for forbidden <- [
          secret,
          fixture.worktree.path,
          fixture.source_repository,
          "defmodule Integration.Server",
          "GIT_AUTHOR_DATE"
        ] do
      refute canonical =~ forbidden
      refute log =~ forbidden
      refute inspect(fixture.observation_envelope) =~ forbidden
    end
  end

  test "source graphs reproduce through cache loss, force push, crash, and restore", %{
    fixture: fixture
  } do
    initial_graph = fixture.publication.graph_iri
    initial_snapshot = fixture.observation.snapshot_iri
    initial_analysis = Phase06Fixture.canonical_dataset(fixture.analysis_result)

    assert :ok = GitRepository.cleanup(fixture.git_adapter, fixture.worktree)
    refute File.exists?(fixture.worktree.path)

    {recreated_worktree, recreated_snapshot} =
      Phase06Fixture.rematerialize!(fixture, "recreated", fixture.initial_commit)

    recreated_analysis = Phase06Fixture.analyze!(fixture, recreated_worktree, recreated_snapshot)
    assert Phase06Fixture.canonical_dataset(recreated_analysis) == initial_analysis

    force = Phase06Fixture.force_push!(fixture)
    refute force.transient_commit == force.replacement_commit
    refute force.replacement_commit == fixture.initial_commit

    assert {:contradiction, _evidence} =
             GitRepository.compare_revision(fixture.initial_commit, force.snapshot)

    fixture = Phase06Fixture.provider_observation!(fixture, "force-push", force.snapshot)
    forced_result = Phase06Fixture.analyze!(fixture, force.worktree, force.snapshot)
    pending = Phase06Fixture.publication_command!(fixture, forced_result, force.snapshot)
    refute pending.graph_iri == initial_graph

    writer_pid = GenServer.whereis(fixture.writer)
    :ok = :sys.suspend(writer_pid)
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        send(parent, {:source_publication_queued, self()})

        send(
          parent,
          {:source_publication_result, Writer.execute(fixture.writer, pending.command)}
        )
      end)

    assert_receive {:source_publication_queued, ^caller}
    assert eventually(fn -> message_queue_length(writer_pid) > 0 end)
    Phase04Fixture.kill_writer!(fixture)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}
    assert_receive {:source_publication_result, {:ok, unavailable}}
    assert unavailable.outcome == :unavailable

    fixture = Phase04Fixture.restart_writer!(fixture)

    assert {:ok, %CommandStatus{outcome: absent_status}} =
             Writer.command_status(fixture.writer, pending.command)

    assert absent_status in [:unknown, :inaccessible]

    assert {:ok, nil} =
             QueryRunner.graph_metadata(pending.graph_iri, server: fixture.query_runner)

    assert {:ok, committed} = Writer.execute(fixture.writer, pending.command)
    assert committed.outcome == :committed, inspect(committed)

    Phase04Fixture.kill_writer!(fixture)
    fixture = Phase04Fixture.restart_writer!(fixture)

    assert {:ok, %CommandStatus{outcome: :committed}} =
             Writer.command_status(fixture.writer, pending.command)

    assert {:ok, replay} = Writer.execute(fixture.writer, pending.command)
    assert replay.outcome == :already_committed

    assert {:ok, old_modules} =
             Phase06Fixture.query(fixture, :source_modules, %{
               graph: initial_graph,
               snapshot: initial_snapshot
             })

    assert {:ok, new_modules} =
             Phase06Fixture.query(fixture, :source_modules, %{
               graph: pending.graph_iri,
               snapshot: fixture.observation.snapshot_iri
             })

    assert old_modules.data != []
    assert new_modules.data != []
    refute old_modules.graph_revisions == new_modules.graph_revisions

    assert :ok = GitRepository.cleanup(fixture.git_adapter, force.worktree)
    refute File.exists?(force.worktree.path)

    assert {:ok, still_queryable} =
             Phase06Fixture.query(fixture, :source_modules, %{
               graph: pending.graph_iri,
               snapshot: fixture.observation.snapshot_iri
             })

    assert still_queryable.data == new_modules.data

    before_dataset = Phase04Fixture.export_dataset!(fixture)
    retained_graphs = [fixture.graphs.catalog, fixture.observation.graph_iri, pending.graph_iri]

    before_digests =
      Map.new(retained_graphs, &{&1, Phase06Fixture.graph_digest(before_dataset, &1)})

    assert {:ok, backup} = Maintenance.backup(fixture.maintenance, [])

    later =
      Phase06Fixture.provider_observation!(
        fixture,
        "post-backup-delivery",
        force.snapshot,
        source_time: fixture.issued_at
      )

    assert later.observation_receipt.outcome == :committed

    assert {:ok, restore} =
             Maintenance.restore(fixture.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert restore.integrity_status == :ok

    assert {:ok, nil} =
             QueryRunner.graph_metadata(later.observation.graph_iri, server: fixture.query_runner)

    after_dataset = Phase04Fixture.export_dataset!(fixture)

    after_digests =
      Map.new(retained_graphs, &{&1, Phase06Fixture.graph_digest(after_dataset, &1)})

    assert after_digests == before_digests

    assert {:ok, restored_modules} =
             Phase06Fixture.query(fixture, :source_modules, %{
               graph: pending.graph_iri,
               snapshot: fixture.observation.snapshot_iri
             })

    assert restored_modules.data == new_modules.data
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

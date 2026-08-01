defmodule JidoCode.Knowledge.Phase06ObservationBatchTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Observations.Command, as: ObservationCommand
  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.ObservationEnvelope
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.Enrollment
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"
  @issued ~U[2026-07-31 19:00:00Z]

  setup context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()
    fixture = enroll_repository!(fixture)

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    {:ok, fixture: fixture, authority: authority}
  end

  test "records immutable sourced claims and reuses exact snapshot identity", %{
    fixture: fixture,
    authority: authority
  } do
    snapshot = git_snapshot!(String.duplicate("a", 40), String.duplicate("b", 40))
    first_envelope = observation_envelope!(fixture, "first-delivery", "private")

    visibility_assertions = [
      claim(fixture.repository, "visibility", "public"),
      claim(fixture.repository, "visibility", "internal")
    ]

    assert {:ok, first} =
             ObservationCommand.build(
               first_envelope,
               command_context(fixture, snapshot, visibility_assertions),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, first_receipt} = Writer.execute(fixture.writer, first.command)
    assert first_receipt.outcome == :committed
    assert length(first.claim_iris) == 6
    assert is_binary(first.snapshot_iri)

    assert {:ok, replay_receipt} = Writer.execute(fixture.writer, first.command)
    assert replay_receipt.outcome == :already_committed
    assert replay_receipt.receipt_iri == first_receipt.receipt_iri

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(first.graph_iri, server: fixture.query_runner)

    assert metadata.lifecycle_state == :closed
    assert metadata.completeness_state == :complete

    assert {:ok, latest} =
             query(fixture, authority, :latest_complete_observation, %{
               graph: first.graph_iri,
               resource: fixture.enrollment.iri
             })

    assert [%{"batch" => %{value: batch}}] = latest.data
    assert batch == first.batch_iri

    assert {:ok, history} =
             query(fixture, authority, :observation_claim_history, %{
               graph: first.graph_iri,
               resource: fixture.repository
             })

    assert length(history.data) == 6

    visibility_claim =
      history.data
      |> Enum.find(fn row ->
        get_in(row, ["predicate", :value]) == @jf <> "visibility" and
          get_in(row, ["object", :value]) == "private"
      end)
      |> get_in(["claim", :value])

    assert {:ok, contradictions} =
             query(fixture, authority, :observation_contradictions, %{
               graph: first.graph_iri,
               resource: visibility_claim
             })

    assert contradictions.data != []

    assert {:ok, snapshot_projection} =
             query(fixture, authority, :repository_snapshot_description, %{
               graph: first.graph_iri,
               resource: first.snapshot_iri
             })

    assert Enum.any?(snapshot_projection.data, fn triple ->
             triple.predicate.value == @jf <> "treeIdentity"
           end)

    second_envelope = observation_envelope!(fixture, "second-delivery", "private")

    correction =
      fixture.repository
      |> claim("visibility", "private-corrected")
      |> Map.put(:supersedes, [visibility_claim])

    second_context =
      command_context(fixture, snapshot, [correction])
      |> Map.put(:previous_batch_iri, first.batch_iri)
      |> Map.put(:prior_claims, [
        %{
          claim_iri: visibility_claim,
          subject: fixture.repository,
          predicate: @jf <> "visibility",
          object: RDF.XSD.String.new("private")
        }
      ])

    assert {:ok, second} =
             ObservationCommand.build(second_envelope, second_context,
               clock: fn -> fixture.issued_at end
             )

    assert second.snapshot_iri == first.snapshot_iri
    assert second.graph_iri != first.graph_iri
    assert {:ok, second_receipt} = Writer.execute(fixture.writer, second.command)
    assert second_receipt.outcome == :committed

    assert {:ok, second_history} =
             query(fixture, authority, :observation_claim_history, %{
               graph: second.graph_iri,
               resource: fixture.repository
             })

    corrected_claim =
      second_history.data
      |> Enum.find(&(get_in(&1, ["object", :value]) == "private-corrected"))
      |> get_in(["claim", :value])

    assert {:ok, cross_batch_contradiction} =
             query(fixture, authority, :observation_contradictions, %{
               graph: second.graph_iri,
               resource: corrected_claim
             })

    assert Enum.any?(cross_batch_contradiction.data, fn row ->
             get_in(row, ["contradiction", :value]) == visibility_claim
           end)

    assert {:ok, supersession} =
             query(fixture, authority, :supersession, %{
               graph: second.graph_iri,
               resource: visibility_claim
             })

    assert supersession.data != []

    assert {:ok, different_snapshot} =
             ResourceIdentity.repository_snapshot(
               fixture.repository,
               :sha1,
               String.duplicate("c", 40)
             )

    refute different_snapshot == first.snapshot_iri
  end

  test "divergent delivery content conflicts and stale active enrollment cannot admit a batch", %{
    fixture: fixture
  } do
    snapshot = git_snapshot!(String.duplicate("d", 40), String.duplicate("e", 40))
    envelope = observation_envelope!(fixture, "stable-delivery", "private")

    assert {:ok, initial} =
             ObservationCommand.build(envelope, command_context(fixture, snapshot, []),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, committed} = Writer.execute(fixture.writer, initial.command)
    assert committed.outcome == :committed

    divergent = observation_envelope!(fixture, "stable-delivery", "public")

    assert {:ok, changed} =
             ObservationCommand.build(divergent, command_context(fixture, snapshot, []),
               clock: fn -> fixture.issued_at end
             )

    assert changed.batch_iri == initial.batch_iri

    assert {:ok, divergent_receipt} = Writer.execute(fixture.writer, changed.command)
    assert divergent_receipt.outcome == :conflicted

    {:ok, active} = EnrollmentTransition.resolve(fixture.enrollment.transitions)
    suspension_iri = Phase04Fixture.local!(:command, 906)

    assert {:ok, suspension} =
             Enrollment.change_command(
               active,
               %{
                 command_iri: suspension_iri,
                 principal_iri: fixture.actor,
                 actor_iri: fixture.actor,
                 factory_scope_iri: fixture.factory_scope,
                 idempotency_key: "phase-06-observation-suspend",
                 correlation_iri: Phase04Fixture.local!(:activity, 906),
                 causation_iri: fixture.enrollment_command.command_iri,
                 expected_dataset_revision:
                   StoreServer.summary(fixture.store_server).dataset_revision,
                 catalog_graph_iri: fixture.graphs.catalog,
                 expected_catalog_revision:
                   Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog),
                 reason: "suspend observation admission",
                 next_state: :suspended,
                 recorded_at: fixture.issued_at
               },
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, suspension_receipt} = Writer.execute(fixture.writer, suspension.command)
    assert suspension_receipt.outcome == :committed

    stale_envelope = observation_envelope!(fixture, "after-suspension", "private")
    stale_context = command_context(fixture, snapshot, [])

    assert {:ok, stale_command} =
             ObservationCommand.build(stale_envelope, stale_context,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, blocked} = Writer.execute(fixture.writer, stale_command.command)
    assert blocked.outcome == :conflicted
  end

  defp enroll_repository!(fixture) do
    {:ok, repository} = ResourceIdentity.conceptual_repository("phase-06-observed-repository")
    repository_scope = Phase04Fixture.scope!(:repository, "phase-06-observed-repository")
    command_iri = Phase04Fixture.local!(:command, 900)

    {:ok, locator} =
      Locator.new(%{
        provider: "https://github.com",
        external_id: "phase-06-observed-id",
        owner: "agentjido",
        name: "observed",
        state: :active,
        observed_at: fixture.issued_at,
        relationships: []
      })

    {:ok, enrollment} =
      Enrollment.new(%{
        factory_iri: fixture.factory_iri,
        repository_iri: repository,
        repository_scope_iri: repository_scope,
        policy_boundary_iri: Phase04Fixture.resource!("phase-06-observation-boundary"),
        policy_iris: [Phase04Fixture.resource!("phase-06-observation-policy")],
        locator: locator,
        actor_iri: fixture.actor,
        cause_iri: command_iri,
        reason: "enroll observed repository",
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 86_400 * 365)
      })

    {:ok, command} =
      Enrollment.enroll_command(
        enrollment,
        %{
          command_iri: command_iri,
          principal_iri: fixture.actor,
          factory_scope_iri: fixture.factory_scope,
          idempotency_key: "phase-06-observation-enrollment",
          correlation_iri: Phase04Fixture.local!(:activity, 900),
          causation_iri: fixture.bootstrap_command_iri,
          expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
          catalog_graph_iri: fixture.graphs.catalog,
          expected_catalog_revision:
            Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog),
          reason: "phase 06 observation enrollment"
        },
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed
    {:ok, resolution} = EnrollmentTransition.resolve(enrollment.transitions)

    Map.merge(fixture, %{
      repository: repository,
      repository_scope: repository_scope,
      locator: locator,
      enrollment: enrollment,
      enrollment_resolution: resolution,
      enrollment_command: command
    })
  end

  defp observation_envelope!(fixture, delivery, visibility) do
    digest = :crypto.hash(:sha256, delivery <> visibility) |> Base.encode16(case: :lower)

    {:ok, observation} =
      ProviderObservation.new(%{
        kind: :repository,
        external_id: fixture.locator.external_id,
        source_time: DateTime.add(fixture.issued_at, -60),
        retrieved_at: fixture.issued_at,
        etag: "etag-#{delivery}",
        source_revision: "provider-v1",
        response_digest: digest,
        data: %{
          default_branch: "main",
          visibility: visibility,
          archived: false,
          fork: false
        },
        completeness: %{
          status: :complete,
          covered: ["repository", "default_branch", "visibility"],
          missing: []
        },
        limitations: ["provider_observation"],
        warnings: []
      })

    {:ok, envelope} =
      ObservationEnvelope.new(%{
        source: :webhook,
        delivery_identity: ObservationEnvelope.delivery_identity([delivery]),
        enrollment_iri: fixture.enrollment.iri,
        locator_iri: fixture.locator.iri,
        received_at: fixture.issued_at,
        source_time: observation.source_time,
        observations: [observation],
        completeness: observation.completeness,
        warnings: []
      })

    envelope
  end

  defp command_context(fixture, snapshot, additional_assertions) do
    active = fixture.enrollment_resolution

    %{
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      enrollment: %{
        enrollment_iri: fixture.enrollment.iri,
        current_transition: active.current_transition,
        current_state: active.current_state,
        admission: active.admission,
        catalog_graph_iri: fixture.graphs.catalog,
        catalog_revision: Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog)
      },
      actor_iri: fixture.actor,
      principal_iri: fixture.actor,
      adapter_iri: Phase04Fixture.resource!("phase-06-provider-adapter"),
      adapter_version: "req-github/1.0.0",
      git_snapshot: snapshot,
      additional_assertions: additional_assertions,
      correlation_iri: Phase04Fixture.local!(:activity, 901),
      causation_iri: fixture.enrollment_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      reason: "record phase 06 observation batch"
    }
  end

  defp claim(subject, predicate, value) do
    %{
      mode: :claim,
      subject: subject,
      predicate: @jf <> predicate,
      object: RDF.XSD.String.new(value),
      epistemic_state: :observed,
      source_observed_at: DateTime.add(@issued, -60),
      disputable?: true
    }
  end

  defp git_snapshot!(commit, tree) do
    {:ok, snapshot} =
      GitSnapshot.new(%{
        commit_sha: commit,
        tree_sha: tree,
        parents: [],
        ref: "refs/heads/main",
        object_format: :sha1,
        submodules?: false,
        lfs?: false,
        clean?: true,
        observed_at: ~U[2026-07-31 19:00:00Z],
        limitations: []
      })

    snapshot
  end

  defp query(fixture, authority, name, parameters) do
    QueryRunner.execute(
      name,
      "1.1.0",
      parameters,
      authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end
end

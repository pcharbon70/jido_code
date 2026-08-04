defmodule JidoCode.TestSupport.Phase09EvidenceFixture do
  @moduledoc false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture

  @jf "https://jido.run/ontology/factory#"
  @environment %{runtime: "beam", operating_system: "linux", profile: "test"}

  def prepared!(context) do
    fixture = Phase08ExecutionFixture.completed!(context)
    {:ok, evidence_graph} = Knowledge.evidence_graph_identity(fixture.repository)

    {:ok, method} =
      Knowledge.verification_method(%{
        name: "repository protection test suite",
        kind: :test_execution,
        version: "1.0.0",
        input_classes: [:source_snapshot, :artifact, :attempt, :goal],
        expected_claim_iris: [fixture.goal.iri],
        requires_complete?: true,
        evaluator_capability_iri: fixture.capability,
        environment: @environment,
        bounds: %{max_duration_ms: 60_000, max_artifacts: 10, max_checks: 100},
        interpretation_limits: ["tests do not prove external application"],
        independent_evaluator?: false
      })

    source_revisions = %{
      fixture.attempt.run_graph_iri => graph_revision!(fixture, fixture.attempt.run_graph_iri),
      fixture.control_graph => graph_revision!(fixture, fixture.control_graph),
      fixture.publication.graph_iri => graph_revision!(fixture, fixture.publication.graph_iri)
    }

    {:ok, activity} =
      Knowledge.verification_activity(method, %{
        attempt_iri: fixture.attempt.iri,
        task_iri: fixture.attempt.task_iri,
        goal_iri: fixture.attempt.goal_iri,
        run_graph_iri: fixture.attempt.run_graph_iri,
        control_graph_iri: fixture.control_graph,
        source_graph_iri: fixture.publication.graph_iri,
        source_snapshot_iri: fixture.attempt.snapshot_iri,
        proposed_snapshot_iri: nil,
        post_change_snapshot_iri: nil,
        artifacts: [fixture.artifact],
        source_graph_revisions: source_revisions,
        evaluator_iri: fixture.actor,
        execution_actor_iri: fixture.attempt.actor_iri,
        environment: @environment,
        checks: [
          %{id: "mix-test", status: :passed, mandatory?: true, outcome_refs: []},
          %{id: "patch-shape", status: :passed, mandatory?: true, outcome_refs: []}
        ],
        completeness: :complete,
        started_at: DateTime.add(fixture.issued_at, 200, :second),
        ended_at: DateTime.add(fixture.issued_at, 205, :second),
        raw_outcome_refs: []
      })

    recorded_at = DateTime.add(fixture.issued_at, 206, :second)

    {:ok, bundle} =
      Knowledge.evidence_bundle(activity, evidence_graph, %{
        supports: [fixture.goal.iri],
        contradicts: [],
        strength: :strong,
        generated_claims: [
          %{
            subject_iri: fixture.repository,
            predicate_iri: @jf <> "defaultBranchProtected",
            object: %{type: :boolean, value: true},
            valid_from: recorded_at,
            valid_to: DateTime.add(recorded_at, 86_400),
            recorded_at: recorded_at
          }
        ],
        limitations: ["provider state requires separate post-change observation"],
        valid_from: recorded_at,
        valid_to: DateTime.add(recorded_at, 86_400),
        supersedes: []
      })

    expected_revisions = Map.put(source_revisions, evidence_graph, 0)

    command_attributes = %{
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      repository_scope_iri: fixture.repository_scope,
      evidence_graph_iri: evidence_graph,
      correlation_iri: Phase04Fixture.local!(:activity, 950),
      causation_iri: fixture.finalization.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: expected_revisions,
      reason: "record exact verification evidence",
      recorded_at: recorded_at
    }

    Map.merge(fixture, %{
      evidence_graph: evidence_graph,
      verification_method: method,
      verification_activity: activity,
      evidence_bundle: bundle,
      evidence_command_attributes: command_attributes
    })
  end

  def recorded!(context) do
    fixture = prepared!(context)

    {:ok, command} =
      Knowledge.record_verification_evidence(
        fixture.evidence_bundle,
        fixture.evidence_command_attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)

    Map.merge(fixture, %{evidence_command: command, evidence_receipt: receipt})
  end

  def requirements(fixture, overrides \\ %{}) do
    Map.merge(
      %{
        policy_iri: fixture.policy.iri,
        policy_version: fixture.policy.version,
        policy_graph_revision: graph_revision!(fixture, fixture.graphs.policy),
        plan_iri: fixture.plan.iri,
        plan_graph_revision: graph_revision!(fixture, fixture.control_graph),
        required_method_kinds: [:test_execution],
        required_environments: [@environment],
        minimum_coverage: 1.0,
        independent_reviewers: 0,
        maximum_age_seconds: 86_400,
        require_security?: false,
        require_post_change?: false,
        waiver_allowed?: false,
        policy_conflicted?: false,
        required_target_iris: [fixture.goal.iri],
        source_graph_revisions: fixture.verification_activity.source_graph_revisions
      },
      overrides
    )
  end

  def graph_revision!(fixture, graph),
    do: Phase08AttemptFixture.graph_revision!(fixture, graph)
end

defmodule JidoCode.TestSupport.Phase07ReconciliationFixture do
  @moduledoc false

  alias JidoCode.Knowledge.Control.Reconciliation
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase07GovernanceFixture

  def reconciled!(context) do
    context
    |> Phase07GovernanceFixture.governance!()
    |> build_package!()
    |> record_reconciliation!()
    |> transition_reconciliation!(:running, 762)
    |> transition_reconciliation!(:completed, 763)
  end

  def build_package!(fixture) do
    graph_revisions = %{
      fixture.graphs.catalog => graph_revision!(fixture, fixture.graphs.catalog),
      fixture.graphs.policy => graph_revision!(fixture, fixture.graphs.policy),
      fixture.observation.graph_iri => graph_revision!(fixture, fixture.observation.graph_iri),
      fixture.publication.graph_iri => graph_revision!(fixture, fixture.publication.graph_iri),
      fixture.cohort_graph => graph_revision!(fixture, fixture.cohort_graph),
      fixture.control_graph => graph_revision!(fixture, fixture.control_graph)
    }

    attributes = %{
      scope_iri: fixture.repository_scope,
      repository_iri: fixture.repository,
      enrollment: %{
        iri: fixture.enrollment.iri,
        state: fixture.enrollment_resolution.current_state,
        admission: fixture.enrollment_resolution.admission,
        current_transition: fixture.enrollment_resolution.current_transition
      },
      observation: %{
        batch_iri: fixture.observation.batch_iri,
        snapshot_iri: fixture.observation.snapshot_iri,
        complete?: true,
        contradictory?: false
      },
      absence_checks?: true,
      graph_revisions: graph_revisions,
      current_graph_revisions: graph_revisions,
      authorized_graphs: Map.keys(graph_revisions),
      required_subjects: %{
        fixture.graphs.catalog => [fixture.enrollment.iri],
        fixture.graphs.policy => [fixture.policy.iri, fixture.desired_outcome.iri],
        fixture.observation.graph_iri => [fixture.observation.batch_iri],
        fixture.cohort_graph => [fixture.cohort_membership.iri],
        fixture.control_graph => [fixture.goal.iri, fixture.obligation.iri]
      },
      desired_outcome_iris: [fixture.desired_outcome.iri],
      policy_iris: [fixture.policy.iri],
      knowledge_iris: [fixture.observation.snapshot_iri],
      goal_iris: [fixture.goal.iri],
      obligation_iris: [fixture.obligation.iri],
      knowledge_state: :known,
      query_version: "1.4.0",
      rule_version: "1.0.0",
      ontology_versions: ["1.0.0"],
      actor_iri: fixture.actor,
      budget: %{max_changes: 20, max_rows: 200, timeout_ms: 5_000},
      requested_at: DateTime.add(fixture.issued_at, 60, :second),
      deadline: DateTime.add(fixture.issued_at, 360, :second)
    }

    {:ok, package} = ReconciliationPackage.new(attributes)

    Map.merge(fixture, %{
      reconciliation_package: package,
      reconciliation_package_attributes: attributes
    })
  end

  def record_reconciliation!(fixture) do
    evaluation = %{
      desired_outcome_iri: fixture.desired_outcome.iri,
      dimension_iri: fixture.obligation.dimension_iri,
      observed_state: :unsatisfied,
      complete?: true,
      evidence_iris: [fixture.observation.batch_iri],
      policy_iris: [fixture.policy.iri],
      applicability_iri: fixture.cohort_membership.iri,
      existing_goal_iri: fixture.goal.iri,
      existing_obligation_iri: fixture.obligation.iri,
      obsolete_goal_iri: nil,
      risk: 2,
      ambiguous?: false,
      human_approval_required?: false,
      policy_conflict?: false,
      superseded_proposal_iris: []
    }

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(761, fixture.obligation.iri, "record reconciliation")
      |> Map.merge(%{
        control_graph_iri: fixture.control_graph,
        catalog_graph_iri: fixture.graphs.catalog,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        cause_iri: fixture.obligation.iri,
        recorded_at: DateTime.add(fixture.issued_at, 61, :second)
      })

    {:ok, reconciliation} =
      Reconciliation.new(fixture.reconciliation_package, [evaluation], attributes)

    {:ok, recording} =
      Reconciliation.record_command(reconciliation, attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, recording.command)

    Map.merge(fixture, %{
      reconciliation: reconciliation,
      reconciliation_evaluation: evaluation,
      reconciliation_recording: recording,
      reconciliation_receipt: receipt,
      reconciliation_transitions: [reconciliation.transition]
    })
  end

  def transition_reconciliation!(fixture, next_state, sequence) do
    {:ok, resolution} = Transition.resolve(fixture.reconciliation_transitions)

    attributes =
      fixture
      |> Phase07Fixture.base_attributes(
        sequence,
        resolution.current_transition,
        "transition reconciliation #{next_state}"
      )
      |> Map.merge(%{
        scope_iri: fixture.repository_scope,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: graph_revision!(fixture, fixture.control_graph),
        next_state: next_state,
        recorded_at: DateTime.add(fixture.issued_at, sequence - 700, :second)
      })

    {:ok, transition} =
      Reconciliation.transition_command(resolution, attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, transition.command)
    transitions = fixture.reconciliation_transitions ++ [transition.transition]
    {:ok, resolution} = Transition.resolve(transitions)

    Map.merge(fixture, %{
      reconciliation_transitions: transitions,
      reconciliation_resolution: resolution,
      reconciliation_transition_receipt: receipt
    })
  end

  def graph_revision!(fixture, graph), do: Phase07Fixture.graph_revision!(fixture, graph)

  def dataset_revision(fixture),
    do: StoreServer.summary(fixture.store_server).dataset_revision
end

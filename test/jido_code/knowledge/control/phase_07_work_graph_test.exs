defmodule JidoCode.Knowledge.Control.Phase07WorkGraphTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Control.DesiredOutcome
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Control.WorkGraph
  alias JidoCode.Knowledge.Control.WorkProjection
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture

  setup context do
    {:ok, fixture: Phase07Fixture.work!(context)}
  end

  test "persists desired intent, goal/task structure, exact plan context, and adoption", %{
    fixture: fixture
  } do
    assert fixture.desired_outcome_receipt.outcome == :committed
    assert fixture.goal_receipt.outcome == :committed
    assert fixture.plan_receipt.outcome == :committed
    assert fixture.plan_adoption_receipt.outcome == :committed
    assert fixture.desired_resolution.current_state == :active
    assert fixture.goal_resolution.current_state == :approved
    assert fixture.adopted_plan.transition.next_state == :approved
    assert Enum.all?(fixture.plan_adoption.transitions, &(&1.next_state == :approved))

    assert fixture.plan.source_snapshot_iri == fixture.observation.snapshot_iri
    assert length(fixture.plan.tasks) == 3
    assert length(fixture.plan.graph_references) == 3

    assert Map.new(fixture.plan.graph_references, &{&1.graph_iri, &1.revision}) ==
             fixture.plan_attributes.input_graph_revisions

    assert QueryCatalog.control_loop_version() == "1.2.0"
    assert :ok = QueryCatalog.verify()

    assert {:ok, dag} =
             query(fixture, :task_dag, %{
               graph: fixture.control_graph,
               resource: fixture.plan.iri
             })

    assert {:ok, dag_projection} =
             WorkProjection.build(dag, %{
               graph_iri: fixture.control_graph,
               resource_iri: fixture.plan.iri,
               task_limit: 10
             })

    assert dag_projection.data.task_count == 3
    refute dag_projection.receipt.truncated?

    assert {:ok, context} =
             query(fixture, :plan_context, %{
               graph: fixture.control_graph,
               resource: fixture.plan.iri
             })

    assert {:ok, context_projection} =
             WorkProjection.build(context, %{
               graph_iri: fixture.control_graph,
               resource_iri: fixture.plan.iri
             })

    assert context_projection.data.snapshot_iri == fixture.observation.snapshot_iri
    assert length(context_projection.data.input_graph_revisions) == 3

    assert {:ok, history} =
             query(fixture, :work_transition_history, %{
               graph: fixture.control_graph,
               resource: fixture.goal.iri
             })

    assert {:ok, history_projection} =
             WorkProjection.build(history, %{
               graph_iri: fixture.control_graph,
               resource_iri: fixture.goal.iri
             })

    assert Enum.map(history_projection.data, & &1.revision) == [0, 1]
  end

  test "retains conflicting intent only with an explicit resolution", %{fixture: fixture} do
    base =
      fixture
      |> Phase07Fixture.base_attributes(
        710,
        fixture.desired_outcome.iri,
        "assert conflicting unprotected branch intent"
      )
      |> Map.merge(%{
        scope_iri: fixture.repository_scope,
        proposition: %{
          subject: fixture.repository,
          predicate: "https://jido.run/ontology/factory#defaultBranchProtected",
          object: false
        },
        priority: :normal,
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 31_536_000),
        policy_refs: fixture.desired_outcome.policy_refs,
        evidence_refs: fixture.desired_outcome.evidence_refs,
        constraints: [],
        conflicts_with: [fixture.desired_outcome.iri],
        cause_iri: fixture.desired_outcome.iri,
        recorded_at: DateTime.add(fixture.issued_at, 10, :second)
      })

    assert {:error, %{operation: :desired_outcome_conflict_resolution}} =
             DesiredOutcome.new(base)

    {:ok, conflicting} = DesiredOutcome.new(Map.put(base, :supersede_conflicts?, true))

    command_attributes =
      base
      |> Map.put(:supersede_conflicts?, true)
      |> Map.merge(%{
        enrollment: Phase07Fixture.enrollment_context(fixture),
        policy_graph_iri: fixture.graphs.policy,
        control_graph_iri: fixture.control_graph,
        expected_policy_revision: Phase07Fixture.graph_revision!(fixture, fixture.graphs.policy),
        expected_control_revision: Phase07Fixture.graph_revision!(fixture, fixture.control_graph)
      })

    assert {:ok, assertion} =
             DesiredOutcome.assert_command(conflicting, command_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, assertion.command)
    assert receipt.outcome == :committed

    dataset = Phase04Fixture.export_dataset!(fixture)
    quads = RDF.Dataset.quads(dataset)

    assert Enum.any?(quads, fn
             {%RDF.IRI{value: subject}, %RDF.IRI{value: predicate}, %RDF.IRI{value: object},
              _graph} ->
               subject == conflicting.iri and
                 predicate == "https://jido.run/ontology/factory#supersedes" and
                 object == fixture.desired_outcome.iri

             _other ->
               false
           end)
  end

  test "rejects cyclic, capability-incomplete, stale, and assumption-invalid plans", %{
    fixture: fixture
  } do
    cyclic =
      fixture.plan_attributes
      |> Map.merge(Phase07Fixture.base_attributes(fixture, 720, fixture.goal.iri, "cyclic plan"))
      |> Map.put(
        :expected_control_revision,
        Phase07Fixture.graph_revision!(fixture, fixture.control_graph)
      )
      |> Map.put(:tasks, [
        %{key: "one", kind: :verification, depends_on: ["two"]},
        %{key: "two", kind: :change, depends_on: ["one"]},
        %{key: "approve", kind: :approval}
      ])

    assert {:error, %{operation: :plan_dependency_cycle}} = WorkGraph.propose_plan(cyclic)

    missing_capability =
      fixture.plan_attributes
      |> Map.merge(
        Phase07Fixture.base_attributes(fixture, 721, fixture.goal.iri, "missing capability")
      )
      |> Map.put(
        :expected_control_revision,
        Phase07Fixture.graph_revision!(fixture, fixture.control_graph)
      )
      |> Map.put(:available_capability_iris, [])

    assert {:error, %{operation: :plan_capability_coverage}} =
             WorkGraph.propose_plan(missing_capability)

    adoption =
      fixture
      |> Phase07Fixture.base_attributes(722, fixture.plan.iri, "stale adoption")
      |> Map.merge(%{
        source_graph_iri: fixture.plan.source_graph_iri,
        source_graph_revision: fixture.plan.source_graph_revision + 1,
        policy_graph_revision: fixture.plan.policy_graph_revision,
        assumptions_valid?: true,
        control_graph_iri: fixture.control_graph,
        expected_control_revision: Phase07Fixture.graph_revision!(fixture, fixture.control_graph),
        recorded_at: fixture.issued_at
      })

    assert {:error, %{operation: :adopt_plan_source_revision}} =
             WorkGraph.adopt_plan(fixture.plan, adoption)

    assert {:error, %{operation: :adopt_plan_replanning_required}} =
             WorkGraph.adopt_plan(
               fixture.plan,
               %{
                 adoption
                 | source_graph_revision: fixture.plan.source_graph_revision,
                   assumptions_valid?: false
               }
             )

    assert {:ok, resolution} = Transition.resolve(fixture.goal_transitions)
    assert resolution.current_state == :approved
  end

  test "work projections enforce explicit task and history bounds", %{fixture: fixture} do
    assert {:ok, dag} =
             query(fixture, :task_dag, %{
               graph: fixture.control_graph,
               resource: fixture.plan.iri
             })

    assert {:error, %{operation: :work_projection_task_bound}} =
             WorkProjection.build(dag, %{
               graph_iri: fixture.control_graph,
               task_limit: 2
             })

    assert {:error, %{operation: :work_projection_bounds}} =
             WorkProjection.build(dag, %{
               graph_iri: fixture.control_graph,
               task_limit: 101
             })

    assert {:ok, lens} =
             query(fixture, :work_lens, %{
               graph: fixture.control_graph,
               state: :approved
             })

    assert lens.data != []
  end

  defp query(fixture, name, parameters) do
    QueryRunner.execute(
      name,
      QueryCatalog.control_loop_version(),
      parameters,
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end
end

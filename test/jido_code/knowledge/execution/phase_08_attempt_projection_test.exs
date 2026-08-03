defmodule JidoCode.Knowledge.Execution.Phase08AttemptProjectionTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.TestSupport.Phase08AttemptFixture

  @projection_queries ~w[
    attempt_status attempt_timeline tool_invocations attempt_artifacts
    cancellation_retry_lineage run_completeness
  ]a

  setup context do
    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    {:ok, fixture: fixture}
  end

  test "discovers graph-visible active attempts and task lineage", %{fixture: fixture} do
    assert {:ok, active} = query(fixture, :active_attempts, fixture.control_graph, nil)
    assert [row] = active.data
    assert decoded(row, "attempt") == fixture.attempt.iri
    assert decoded(row, "lease") == fixture.lease.iri
    assert decoded(row, "task") == fixture.attempt.task_iri
    assert decoded(row, "fence") == fixture.attempt.fencing_token

    assert {:ok, by_task} =
             query(fixture, :attempt_by_task, fixture.control_graph, fixture.attempt.task_iri)

    assert Enum.any?(by_task.data, &(decoded(&1, "attempt") == fixture.attempt.iri))
  end

  test "builds a bounded operational projection without prompts or raw tool output", %{
    fixture: fixture
  } do
    results =
      Map.new(@projection_queries, fn name ->
        {:ok, result} =
          query(fixture, name, fixture.attempt.run_graph_iri, fixture.attempt.iri)

        {name, result}
      end)

    assert {:ok, projection} =
             Knowledge.project_execution_attempt(results, %{
               graph_iri: fixture.attempt.run_graph_iri,
               attempt_iri: fixture.attempt.iri
             })

    assert projection.current_state == :running
    refute projection.terminal?
    assert projection.operational_completion == :in_progress
    assert projection.verification_state == :not_evaluated
    assert projection.evidence_state == :not_recorded
    assert projection.decision_state == :not_decided
    assert projection.fencing_token == fixture.attempt.fencing_token
    assert projection.runtime_version == fixture.attempt.runtime_version
    assert projection.source_snapshot_iri == fixture.attempt.snapshot_iri
    assert projection.constraints["network"] == "deny"
    assert projection.tool_invocations == []
    assert projection.artifacts == []

    incoherent =
      Map.update!(results, :attempt_timeline, fn result ->
        %{result | dataset_revision: result.dataset_revision + 1}
      end)

    assert {:error, %{operation: :attempt_projection}} =
             Knowledge.project_execution_attempt(incoherent, %{
               graph_iri: fixture.attempt.run_graph_iri,
               attempt_iri: fixture.attempt.iri
             })

    rendered = inspect(projection)
    refute rendered =~ fixture.execution_context.instruction
    refute rendered =~ "stdout"
    refute rendered =~ "stderr"
  end

  test "catalog exposes all bounded execution recovery lenses", %{fixture: _fixture} do
    names = QueryCatalog.names(QueryCatalog.execution_version())

    for name <- [:active_attempts, :attempt_by_task | @projection_queries] do
      assert name in names
    end

    assert :ok = QueryCatalog.verify()
  end

  defp query(fixture, name, graph, nil) do
    QueryRunner.execute(
      name,
      QueryCatalog.execution_version(),
      %{graph: graph},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp query(fixture, name, graph, resource) do
    QueryRunner.execute(
      name,
      QueryCatalog.execution_version(),
      %{graph: graph, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp decoded(row, key) do
    value = Map.get(row, key) || Map.get(row, String.to_existing_atom(key))

    case value do
      %{
        type: :literal,
        value: lexical,
        datatype: "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
      } ->
        String.to_integer(lexical)

      %{value: decoded} ->
        decoded

      decoded ->
        decoded
    end
  end
end

defmodule JidoCode.Knowledge.Execution.Phase08EffectProvenanceTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture

  setup context do
    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    {:ok, fixture: fixture}
  end

  test "records one fenced invocation and rejects divergent outcome replay", %{fixture: fixture} do
    invocation = invocation!(fixture)
    start_attributes = command_attributes(fixture, 930, invocation.iri, "start governed tool")

    assert {:ok, start} =
             Knowledge.start_tool_invocation(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               start_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, start_receipt} = Writer.execute(fixture.writer, start)
    assert start_receipt.outcome == :committed, inspect(start_receipt)
    assert {:ok, replay} = Writer.execute(fixture.writer, start)
    assert replay.outcome == :already_committed

    outcome_attributes =
      fixture
      |> command_attributes(931, invocation.iri, "record governed tool outcome")
      |> Map.merge(%{
        status: :completed,
        exit_status: 0,
        stdout: "protected main",
        stderr: "",
        external_output_iris: [],
        usage: %{cpu_ms: 5, memory_bytes: 2_048, output_bytes: 14},
        artifact_iris: [],
        redaction: :applied
      })

    assert {:ok, outcome} =
             Knowledge.record_tool_outcome(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               outcome_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, divergent} =
             Knowledge.record_tool_outcome(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               %{outcome_attributes | stdout: "different provider replay"},
               clock: fn -> fixture.issued_at end
             )

    assert outcome.command_iri == divergent.command_iri
    assert {:ok, receipt} = Writer.execute(fixture.writer, outcome)
    assert receipt.outcome == :committed
    assert {:ok, duplicate} = Writer.execute(fixture.writer, outcome)
    assert duplicate.outcome == :already_committed
    assert {:ok, conflict} = Writer.execute(fixture.writer, divergent)
    assert conflict.outcome == :conflicted

    stale = %{outcome_attributes | fencing_token: fixture.attempt.fencing_token + 1}

    assert {:error, %{operation: :record_tool_outcome}} =
             Knowledge.record_tool_outcome(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               stale,
               clock: fn -> fixture.issued_at end
             )
  end

  test "records normalized patches and operational findings without creating evidence", %{
    fixture: fixture
  } do
    invocation = invocation!(fixture)

    assert {:ok, artifact} =
             Knowledge.execution_artifact(%{
               kind: :patch,
               base_snapshot_iri: fixture.attempt.snapshot_iri,
               generator_iri: invocation.iri,
               media_type: "text/x-diff",
               content: "--- a/config.exs\r\n+++ b/config.exs\r\n+protected = true\r\n",
               content_digest: nil,
               byte_count: nil,
               sensitivity: :internal,
               external_uri: nil,
               affected_paths: ["config/config.exs"],
               affected_symbols: [],
               proposed_commit_iri: nil,
               proposed_tree_iri: nil,
               findings: [
                 %{kind: :partial_output, summary: "provider returned one bounded warning"},
                 %{kind: :cleanup_failure, summary: "disposable material required later cleanup"}
               ]
             })

    assert artifact.storage == :embedded
    refute artifact.embedded_content =~ "\r"
    assert :ok = Knowledge.verify_execution_artifact(artifact)

    attributes = command_attributes(fixture, 932, invocation.iri, "record patch artifact")

    assert {:ok, command} =
             Knowledge.record_execution_artifact(
               artifact,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed

    assert {:ok, description} = query(fixture, artifact.iri)

    classes =
      description.data
      |> Enum.filter(&(decoded(&1, "predicate") == rdf_type()))
      |> Enum.map(&decoded(&1, "object"))

    assert "https://jido.run/ontology/factory#Artifact" in classes
    assert "https://jido.run/ontology/factory#Patch" in classes
    refute "https://jido.run/ontology/factory#EvidenceBundle" in classes
  end

  test "fails closed for unavailable or substituted external artifacts while history remains", %{
    fixture: fixture
  } do
    body = String.duplicate("artifact", 5)
    digest = "sha256:" <> (:crypto.hash(:sha256, body) |> Base.encode16(case: :lower))
    invocation = invocation!(fixture)

    assert {:ok, artifact} =
             Knowledge.execution_artifact(%{
               kind: :generated,
               base_snapshot_iri: fixture.attempt.snapshot_iri,
               generator_iri: invocation.iri,
               media_type: "application/octet-stream",
               content: nil,
               content_digest: digest,
               byte_count: byte_size(body),
               sensitivity: :internal,
               external_uri: "https://artifacts.example.test/immutable/sha256/#{digest}",
               affected_paths: [],
               affected_symbols: [],
               proposed_commit_iri: nil,
               proposed_tree_iri: nil,
               findings: []
             })

    assert {:error, %{kind: :unavailable}} = Knowledge.verify_execution_artifact(artifact)

    assert {:error, %{kind: :corrupt}} =
             Knowledge.verify_execution_artifact(artifact,
               fetch: fn _uri -> {:ok, "substituted"} end
             )

    assert :ok =
             Knowledge.verify_execution_artifact(artifact, fetch: fn _uri -> {:ok, body} end)

    attributes = command_attributes(fixture, 933, invocation.iri, "record external artifact")

    assert {:ok, command} =
             Knowledge.record_execution_artifact(
               artifact,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, command)
    assert {:error, %{kind: :unavailable}} = Knowledge.verify_execution_artifact(artifact)
    assert {:ok, description} = query(fixture, artifact.iri)
    assert description.data != []
  end

  defp invocation!(fixture) do
    {:ok, invocation} =
      Knowledge.tool_invocation(fixture.attempt, %{
        tool_iri: Phase04Fixture.resource!("phase-08-tool"),
        capability_iri: fixture.capability,
        tool_version: "1.0.0",
        sequence: 1,
        deadline: DateTime.add(fixture.issued_at, 400, :second),
        expected_effect: Phase04Fixture.resource!("phase-08-repository-settings-write"),
        input_refs: [fixture.attempt.snapshot_iri],
        input_digests: %{"snapshot" => "sha256:" <> String.duplicate("a", 64)}
      })

    invocation
  end

  defp command_attributes(fixture, sequence, cause, reason) do
    fixture
    |> Phase07Fixture.base_attributes(sequence, cause, reason)
    |> Map.merge(%{
      fencing_token: fixture.attempt.fencing_token,
      run_graph_iri: fixture.attempt.run_graph_iri,
      expected_run_revision:
        Phase08AttemptFixture.graph_revision!(fixture, fixture.attempt.run_graph_iri),
      control_graph_iri: fixture.control_graph,
      expected_control_revision:
        Phase08AttemptFixture.graph_revision!(fixture, fixture.control_graph),
      recorded_at: DateTime.add(fixture.issued_at, sequence - 800, :second)
    })
  end

  defp query(fixture, resource) do
    QueryRunner.execute(
      :resource_description,
      QueryCatalog.execution_version(),
      %{graph: fixture.attempt.run_graph_iri, resource: resource},
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp decoded(row, key) do
    value = Map.get(row, key) || Map.get(row, String.to_existing_atom(key))
    if is_map(value), do: value.value, else: value
  end

  defp rdf_type, do: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
end

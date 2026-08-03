defmodule JidoCode.TestSupport.Phase08ExecutionFixture do
  @moduledoc false

  alias JidoCode.Factory.Sandbox
  alias JidoCode.Factory.Sandbox.Request, as: SandboxRequest
  alias JidoCode.Factory.Tool.Request, as: ToolRequest
  alias JidoCode.Factory.ToolRunner
  alias JidoCode.Integrations.MemorySandbox
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeToolAdapter
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture

  @projection_queries ~w[
    attempt_status attempt_timeline tool_invocations attempt_artifacts
    cancellation_retry_lineage run_completeness
  ]a
  @patch "--- a/config/config.exs\n+++ b/config/config.exs\n+config :jido_code, protected_main: true\n"

  def completed!(context) do
    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    request = Phase08AttemptFixture.request!(fixture)
    {sandbox, sandbox_request, sandbox_events} = sandbox_lifecycle!(fixture, request)
    invocation = invocation!(fixture)

    start =
      fixture
      |> command_attributes(930, invocation.iri, "start integration tool invocation")
      |> then(fn attributes ->
        {:ok, command} =
          Knowledge.start_tool_invocation(
            invocation,
            fixture.attempt,
            fixture.attempt_resolution,
            fixture.lease,
            attributes,
            clock: fn -> fixture.issued_at end
          )

        command
      end)

    {:ok, start_receipt} = Writer.execute(fixture.writer, start)
    true = start_receipt.outcome == :committed

    tool_result = execute_tool!(fixture, request, invocation)
    artifact = artifact!(fixture, invocation)

    outcome =
      fixture
      |> command_attributes(931, invocation.iri, "record integration tool outcome")
      |> Map.merge(%{
        status: tool_result.status,
        exit_status: tool_result.exit_status,
        stdout: tool_result.stdout,
        stderr: tool_result.stderr,
        external_output_iris: tool_result.external_output_iris,
        usage: tool_result.usage,
        artifact_iris: [artifact.iri],
        redaction: tool_result.redaction
      })
      |> then(fn attributes ->
        {:ok, command} =
          Knowledge.record_tool_outcome(
            invocation,
            fixture.attempt,
            fixture.attempt_resolution,
            fixture.lease,
            attributes,
            clock: fn -> fixture.issued_at end
          )

        command
      end)

    {:ok, outcome_receipt} = Writer.execute(fixture.writer, outcome)
    true = outcome_receipt.outcome == :committed

    artifact_command =
      fixture
      |> command_attributes(932, invocation.iri, "record integration patch artifact")
      |> then(fn attributes ->
        {:ok, command} =
          Knowledge.record_execution_artifact(
            artifact,
            fixture.attempt,
            fixture.attempt_resolution,
            fixture.lease,
            attributes,
            clock: fn -> fixture.issued_at end
          )

        command
      end)

    {:ok, artifact_receipt} = Writer.execute(fixture.writer, artifact_command)
    true = artifact_receipt.outcome == :committed

    fixture = Phase08AttemptFixture.transition!(fixture, :completed, 933)
    {:ok, outcome_event_iri} = outcome_event_iri(invocation)

    finalization =
      fixture
      |> command_attributes(934, fixture.attempt_resolution.current_transition, "close run graph")
      |> Map.merge(%{
        completeness: :complete,
        lease_mode: :current,
        terminal_sequence: fixture.attempt_resolution.current_revision,
        tool_invocation_iris: [invocation.iri],
        artifact_iris: [artifact.iri],
        required_event_iris: [outcome_event_iri],
        sandbox_activities: provenance_activities(sandbox_events),
        missing_outputs: [],
        limitations: ["runtime completion remains operational provenance"],
        usage: %{cpu_ms: 9, memory_bytes: 8_192, output_bytes: byte_size(@patch)},
        diagnostic: nil,
        cancellation_iri: nil,
        run_metadata: run_metadata!(fixture)
      })
      |> then(fn attributes ->
        {:ok, command} =
          Knowledge.finalize_execution_run(
            fixture.attempt,
            fixture.attempt_resolution,
            fixture.lease,
            attributes,
            clock: fn -> fixture.issued_at end
          )

        command
      end)

    {:ok, finalization_receipt} = Writer.execute(fixture.writer, finalization)
    true = finalization_receipt.outcome == :committed
    projection = projection!(fixture)

    Map.merge(fixture, %{
      execution_request: request,
      sandbox: sandbox,
      sandbox_request: sandbox_request,
      sandbox_events: sandbox_events,
      invocation: invocation,
      invocation_start: start,
      invocation_start_receipt: start_receipt,
      tool_result: tool_result,
      tool_outcome: outcome,
      tool_outcome_iri: outcome_event_iri,
      tool_outcome_receipt: outcome_receipt,
      artifact: artifact,
      artifact_command: artifact_command,
      artifact_receipt: artifact_receipt,
      finalization: finalization,
      finalization_receipt: finalization_receipt,
      projection: projection
    })
  end

  def projection!(fixture) do
    results =
      Map.new(@projection_queries, fn name ->
        {:ok, result} =
          QueryRunner.execute(
            name,
            QueryCatalog.execution_version(),
            %{graph: fixture.attempt.run_graph_iri, resource: fixture.attempt.iri},
            fixture.authority,
            fixture.repository_scope,
            server: fixture.query_runner,
            evaluated_at: fixture.issued_at
          )

        {name, result}
      end)

    {:ok, projection} =
      Knowledge.project_execution_attempt(results, %{
        graph_iri: fixture.attempt.run_graph_iri,
        attempt_iri: fixture.attempt.iri
      })

    projection
  end

  def command_attributes(fixture, sequence, cause, reason) do
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

  def invocation!(fixture, sequence \\ 1) do
    {:ok, invocation} =
      Knowledge.tool_invocation(fixture.attempt, %{
        tool_iri: Phase04Fixture.resource!("phase-08-integration-tool-#{sequence}"),
        capability_iri: fixture.capability,
        tool_version: "1.0.0",
        sequence: sequence,
        deadline: DateTime.add(fixture.issued_at, 500, :second),
        expected_effect:
          Phase04Fixture.resource!("phase-08-integration-repository-settings-write"),
        input_refs: [fixture.attempt.snapshot_iri],
        input_digests: %{"snapshot" => "sha256:" <> String.duplicate("a", 64)}
      })

    invocation
  end

  defp sandbox_lifecycle!(fixture, request) do
    {:ok, sandbox_request} = sandbox_request(request)

    runner = fn _command, _files ->
      %{
        stdout: "sandbox-applied",
        stderr: "",
        exit_status: 0,
        usage: %{cpu_ms: 3, memory_bytes: 2_048},
        writes: %{".jido-code/patch/protected-main.diff" => @patch}
      }
    end

    child =
      Supervisor.child_spec(
        {MemorySandbox,
         runners: %{"apply-protection" => runner},
         clock: fn -> DateTime.add(fixture.issued_at, 125, :second) end},
        id: make_ref(),
        restart: :temporary
      )

    sandbox = ExUnit.Callbacks.start_supervised!(child)
    options = [authority: AllowExecutionAuthority]

    {:ok, provisioned} =
      Sandbox.provision(MemorySandbox, sandbox, sandbox_request, options)

    {:ok, materialized} =
      Sandbox.materialize(
        MemorySandbox,
        sandbox,
        sandbox_request,
        %{snapshot_iri: request.snapshot_iri, files: %{".jido-code/patch/base.diff" => ""}},
        options
      )

    {:ok, executed} =
      Sandbox.execute(
        MemorySandbox,
        sandbox,
        sandbox_request,
        %{name: "apply-protection", args: ["--check"], environment: %{}, network: false},
        options
      )

    {:ok, collected} = Sandbox.collect(MemorySandbox, sandbox, sandbox_request, options)
    {:ok, destroyed} = Sandbox.destroy(MemorySandbox, sandbox, sandbox_request, options)

    {sandbox, sandbox_request, [provisioned, materialized, executed, collected, destroyed]}
  end

  defp sandbox_request(request) do
    SandboxRequest.new(%{
      execution: request,
      base_snapshot_iri: request.snapshot_iri,
      allowed_write_paths: [".jido-code/patch"],
      command_allowlist: ["apply-protection"],
      environment_allowlist: [],
      secret_reference_iris: [],
      limits: %{
        cpu_ms: 1_000,
        memory_bytes: 1_048_576,
        disk_bytes: 1_048_576,
        timeout_ms: 1_000,
        output_bytes: 2_048,
        network: :deny
      }
    })
  end

  defp execute_tool!(fixture, request, invocation) do
    {:ok, tool_request} =
      ToolRequest.new(%{
        execution: request,
        invocation_iri: invocation.iri,
        tool_iri: invocation.tool_iri,
        tool_version: invocation.tool_version,
        sequence: invocation.sequence,
        deadline: invocation.deadline,
        expected_effect: "repository.settings.write",
        allowed_effects: fixture.execution_context.allowed_effects,
        input_refs: invocation.input_refs,
        input_digests: invocation.input_digests,
        arguments: %{operation: "protect-main"},
        output_bytes: 2_048
      })

    {:ok, result} =
      ToolRunner.execute(FakeToolAdapter, nil, tool_request, authority: AllowExecutionAuthority)

    result
  end

  defp artifact!(fixture, invocation) do
    {:ok, artifact} =
      Knowledge.execution_artifact(%{
        kind: :patch,
        base_snapshot_iri: fixture.attempt.snapshot_iri,
        generator_iri: invocation.iri,
        media_type: "text/x-diff",
        content: @patch,
        content_digest: nil,
        byte_count: nil,
        sensitivity: :internal,
        external_uri: nil,
        affected_paths: ["config/config.exs"],
        affected_symbols: [],
        proposed_commit_iri: nil,
        proposed_tree_iri: nil,
        findings: []
      })

    artifact
  end

  defp provenance_activities(events) do
    events
    |> Enum.with_index(1)
    |> Enum.map(fn {event, sequence} ->
      event |> Map.from_struct() |> Map.put(:sequence, sequence)
    end)
  end

  defp outcome_event_iri(invocation),
    do: ResourceIdentity.deterministic(:tool_invocation_event, invocation.iri <> "\noutcome")

  defp run_metadata!(fixture) do
    {:ok, metadata} =
      StoreServer.request(fixture.store_server, {:graph_metadata, fixture.attempt.run_graph_iri})

    metadata
  end
end

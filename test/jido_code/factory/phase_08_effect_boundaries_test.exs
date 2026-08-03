defmodule JidoCode.Factory.Phase08EffectBoundariesTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Sandbox
  alias JidoCode.Factory.Sandbox.Request, as: SandboxRequest
  alias JidoCode.Factory.Tool.Request, as: ToolRequest
  alias JidoCode.Factory.ToolRunner
  alias JidoCode.Integrations.MemorySandbox
  alias JidoCode.TestSupport.AllowExecutionAuthority
  alias JidoCode.TestSupport.FakeToolAdapter
  alias JidoCode.TestSupport.Phase08AttemptFixture

  setup context do
    fixture = Phase08AttemptFixture.started!(context)
    request = Phase08AttemptFixture.request!(fixture)
    {:ok, sandbox_request} = sandbox_request(request)

    runner = fn _command, _files ->
      %{
        stdout: "patched",
        stderr: "",
        exit_status: 0,
        usage: %{cpu_ms: 2, memory_bytes: 1_024},
        writes: %{".jido-code/patch/result.diff" => "+protected = true\n"}
      }
    end

    {:ok, sandbox} =
      start_supervised(
        Supervisor.child_spec(
          {MemorySandbox,
           runners: %{"apply-patch" => runner}, clock: fn -> fixture.issued_at end},
          id: make_ref()
        )
      )

    {:ok, fixture: fixture, request: request, sandbox_request: sandbox_request, sandbox: sandbox}
  end

  test "authorizes every lifecycle operation and destroys disposable work", context do
    options = [authority: AllowExecutionAuthority]

    assert {:error, %{kind: :unavailable}} =
             Sandbox.provision(MemorySandbox, context.sandbox, context.sandbox_request)

    assert {:ok, provisioned} =
             Sandbox.provision(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               options
             )

    assert provisioned.details.status == :ready
    refute Map.has_key?(provisioned.details, :path)
    refute Map.has_key?(provisioned.details, :handle)

    assert {:ok, materialized} =
             Sandbox.materialize(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               %{
                 snapshot_iri: context.request.snapshot_iri,
                 files: %{".jido-code/patch/base.diff" => ""}
               },
               options
             )

    assert materialized.details.file_count == 1

    assert {:ok, executed} =
             Sandbox.execute(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               %{
                 name: "apply-patch",
                 args: ["--check"],
                 environment: %{"MIX_ENV" => "test"},
                 network: false
               },
               options
             )

    assert executed.details.stdout == "patched"

    assert {:ok, collected} =
             Sandbox.collect(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               options
             )

    assert collected.details.file_count == 2

    assert {:ok, %{details: %{status: :destroyed}}} =
             Sandbox.destroy(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               options
             )

    assert {:error, %{kind: :conflict}} =
             Sandbox.inspect(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               options
             )

    assert context.fixture.attempt_start_receipt.outcome == :committed
  end

  test "denies path escape, network, secret values, output flooding, and timeout", context do
    options = [authority: AllowExecutionAuthority]

    assert {:ok, _event} =
             Sandbox.provision(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               options
             )

    assert {:error, %{kind: :unauthorized}} =
             Sandbox.materialize(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               %{snapshot_iri: context.request.snapshot_iri, files: %{"../escape" => "bad"}},
               options
             )

    for command <- [
          %{
            name: "apply-patch",
            args: [],
            environment: %{},
            network: true
          },
          %{
            name: "apply-patch",
            args: [],
            environment: %{},
            network: false,
            secret_values: %{token: "raw"}
          }
        ] do
      assert {:error, %{kind: :unauthorized}} =
               Sandbox.execute(
                 MemorySandbox,
                 context.sandbox,
                 context.sandbox_request,
                 command,
                 options
               )
    end

    flooding = fn _command, _files ->
      %{
        stdout: String.duplicate("x", 1_100),
        stderr: "",
        exit_status: 0,
        writes: %{},
        usage: %{cpu_ms: 1, memory_bytes: 1_024}
      }
    end

    {:ok, flood_sandbox} =
      start_supervised(
        Supervisor.child_spec(
          {MemorySandbox, runners: %{"apply-patch" => flooding}},
          id: make_ref()
        )
      )

    assert {:ok, _event} =
             Sandbox.provision(MemorySandbox, flood_sandbox, context.sandbox_request, options)

    assert {:error, %{kind: :corrupt}} =
             Sandbox.execute(
               MemorySandbox,
               flood_sandbox,
               context.sandbox_request,
               %{name: "apply-patch", args: [], environment: %{}, network: false},
               options
             )

    sleeping = fn _command, _files ->
      Process.sleep(25)

      %{
        stdout: "",
        stderr: "",
        exit_status: 0,
        writes: %{},
        usage: %{cpu_ms: 1, memory_bytes: 1_024}
      }
    end

    {:ok, timeout_sandbox} =
      start_supervised(
        Supervisor.child_spec(
          {MemorySandbox, runners: %{"apply-patch" => sleeping}},
          id: make_ref()
        )
      )

    {:ok, short_request} =
      context.sandbox_request
      |> Map.from_struct()
      |> put_in([:limits, :timeout_ms], 1)
      |> SandboxRequest.new()

    assert {:ok, _event} =
             Sandbox.provision(MemorySandbox, timeout_sandbox, short_request, options)

    assert {:error, %{kind: :timeout}} =
             Sandbox.execute(
               MemorySandbox,
               timeout_sandbox,
               short_request,
               %{name: "apply-patch", args: [], environment: %{}, network: false},
               options
             )
  end

  test "tool requests enforce effects and adapters cannot return semantic commands", context do
    assert {:ok, request} =
             ToolRequest.new(%{
               execution: context.request,
               invocation_iri: resource!("tool-invocation"),
               tool_iri: resource!("tool"),
               tool_version: "1.0.0",
               sequence: 1,
               deadline: DateTime.add(context.fixture.issued_at, 300, :second),
               expected_effect: "repository.settings.write",
               allowed_effects: ["repository.settings.write"],
               input_refs: [context.request.snapshot_iri],
               input_digests: %{"snapshot" => "sha256:" <> String.duplicate("a", 64)},
               arguments: %{operation: "protect-main"},
               output_bytes: 1_024
             })

    assert {:ok, result} =
             ToolRunner.execute(FakeToolAdapter, nil, request, authority: AllowExecutionAuthority)

    assert result.status == :completed

    assert {:error, %{kind: :corrupt}} =
             ToolRunner.execute(FakeToolAdapter, nil, request,
               authority: AllowExecutionAuthority,
               scenario: :semantic_command
             )

    assert {:error, %{kind: :corrupt}} =
             ToolRunner.execute(FakeToolAdapter, nil, request,
               authority: AllowExecutionAuthority,
               scenario: :secret
             )

    assert {:error, %{kind: :invalid_input}} =
             request
             |> Map.from_struct()
             |> Map.put(:expected_effect, "network.write")
             |> ToolRequest.new()
  end

  defp sandbox_request(request) do
    SandboxRequest.new(%{
      execution: request,
      base_snapshot_iri: request.snapshot_iri,
      allowed_write_paths: [".jido-code/patch"],
      command_allowlist: ["apply-patch"],
      environment_allowlist: ["MIX_ENV"],
      secret_reference_iris: [],
      limits: %{
        cpu_ms: 1_000,
        memory_bytes: 1_048_576,
        disk_bytes: 1_048_576,
        timeout_ms: 1_000,
        output_bytes: 1_024,
        network: :deny
      }
    })
  end

  defp resource!(seed),
    do: JidoCode.TestSupport.Phase04Fixture.resource!("phase-08-effect-#{seed}")
end

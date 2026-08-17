defmodule JidoCode.Factory.Harness.PhaseH03ToolGatewayTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Tool.Authorization
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.ExecutionReceipt
  alias JidoCode.Factory.Tool.EffectJournal
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.ToolGateway
  alias JidoCode.Factory.Tool.KnowledgeLedger
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeReferenceToolAdapter
  alias JidoCode.TestSupport.FakeToolLedger
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture

  test "commits start before effect and records exactly one bounded outcome" do
    {proposal, capability, current, options} = gateway_fixture()

    assert {:ok,
            %ExecutionReceipt{
              status: :completed,
              effect_dispatched: true,
              result: %Result{stdout: "safe output"}
            }} = ToolGateway.execute(proposal, capability, current, options)

    assert_received {:tool_ledger_start, %Authorization{}, %Request{} = request}
    assert_received :tool_current_revalidated
    assert_received {:reference_tool_effect, ^request, [mode: :fixture]}
    assert_received {:tool_ledger_outcome, _start, %Result{status: :completed}}
    refute_received {:tool_ledger_outcome, _start, _second_result}

    assert MapSet.new(Map.keys(request.arguments)) == MapSet.new([:expected_digest, :path])
    assert request.input_digests["authorization"] =~ ~r/^sha256:[a-f0-9]{64}$/
    assert request.input_digests["proposal"] =~ ~r/^sha256:[a-f0-9]{64}$/
    assert request.input_digests["arguments.internal"] =~ ~r/^sha256:[a-f0-9]{64}$/
  end

  test "pre-admission rejection is concealed and has no durable start or effect" do
    {proposal, capability, current, options} = gateway_fixture()
    revoked = %{current | lease_state: :revoked}

    assert {:error, %AdapterError{operation: :tool_authorization}} =
             ToolGateway.execute(proposal, capability, revoked, options)

    refute_received {:tool_ledger_start, _authorization, _request}
    refute_received {:reference_tool_effect, _request, _options}
    refute_received {:tool_ledger_outcome, _start, _result}
  end

  test "a failed or non-authorizing start commit prevents every effect" do
    {proposal, capability, current, options} =
      gateway_fixture(
        ledger: %{
          owner: self(),
          start_result: {:error, AdapterError.new(:conflict, :tool_start_commit)}
        }
      )

    assert {:error, %AdapterError{operation: :tool_start_commit}} =
             ToolGateway.execute(proposal, capability, current, options)

    assert_received {:tool_ledger_start, _authorization, _request}
    refute_received {:reference_tool_effect, _request, _options}
    refute_received {:tool_ledger_outcome, _start, _result}
  end

  test "race-time denial after committed start records an authorized no-effect outcome" do
    {proposal, capability, current, options} =
      gateway_fixture(
        current: fn capability, current ->
          %{current | fencing_token: capability.fencing_token + 1}
        end
      )

    assert {:ok,
            %ExecutionReceipt{
              status: :rejected,
              effect_dispatched: false,
              result: %Result{stderr: "tool=authorization_revoked"}
            }} = ToolGateway.execute(proposal, capability, current, options)

    assert_received {:tool_ledger_start, _authorization, _request}
    assert_received {:tool_ledger_outcome, _start, %Result{status: :rejected}}
    refute_received {:reference_tool_effect, _request, _options}
  end

  test "adapter errors and corrupt results become one safe failed outcome" do
    scenarios = [
      {:error, AdapterError.new(:timeout, :fixture_adapter)},
      {:ok, :not_a_result}
    ]

    for adapter_result <- scenarios do
      {proposal, capability, current, options} = gateway_fixture(adapter_result: adapter_result)

      assert {:ok,
              %ExecutionReceipt{
                status: :failed,
                effect_dispatched: true,
                result: %Result{stderr: diagnostic}
              }} = ToolGateway.execute(proposal, capability, current, options)

      assert diagnostic in [
               "tool=timeout;operation=fixture_adapter",
               "tool=invalid_adapter_result"
             ]

      assert_received {:tool_ledger_outcome, _start, %Result{status: :failed}}
      refute_received {:tool_ledger_outcome, _start, _duplicate}
    end
  end

  test "an unavailable outcome commit is explicit after the effect" do
    {proposal, capability, current, options} =
      gateway_fixture(
        ledger: %{
          owner: self(),
          outcome_result: {:error, AdapterError.new(:unavailable, :tool_outcome_commit)}
        }
      )

    assert {:error, %AdapterError{operation: :tool_outcome_commit}} =
             ToolGateway.execute(proposal, capability, current, options)

    assert_received {:reference_tool_effect, _request, _options}
    assert_received {:tool_ledger_outcome, _start, %Result{status: :completed}}
    refute_received {:tool_ledger_outcome, _start, _duplicate}
  end

  test "replaying the same effect identity returns the first result without redispatch" do
    {proposal, capability, current, options} = gateway_fixture()

    assert {:ok, %ExecutionReceipt{effect_dispatched: true}} =
             ToolGateway.execute(proposal, capability, current, options)

    assert_received {:reference_tool_effect, request, _options}

    assert {:ok,
            %ExecutionReceipt{
              effect_dispatched: false,
              result: %Result{stdout: "safe output"}
            }} = ToolGateway.execute(proposal, capability, current, options)

    refute_received {:reference_tool_effect, ^request, _options}
  end

  test "the Knowledge ledger atomically builds proposal/start and bounded outcome commands" do
    fixture =
      %{test: :phase_h03_knowledge_ledger}
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)

    assert {:ok, definition} = Catalog.fetch("read_file")
    expected_effect = Phase04Fixture.resource!("phase-h03-source-read")
    deadline = DateTime.add(fixture.issued_at, 500, :second)

    assert {:ok, invocation} =
             Knowledge.tool_invocation(fixture.attempt, %{
               tool_iri: definition.iri,
               capability_iri: fixture.attempt.capability_iri,
               tool_version: definition.version,
               sequence: 1,
               deadline: deadline,
               expected_effect: expected_effect,
               input_refs: [fixture.attempt.snapshot_iri],
               input_digests: %{
                 "arguments.internal" => "sha256:" <> String.duplicate("a", 64),
                 "authorization" => "sha256:" <> String.duplicate("b", 64),
                 "proposal" => "sha256:" <> String.duplicate("c", 64)
               }
             })

    proposal = proposal!(invocation.iri, fixture.attempt.snapshot_iri)
    capability = capability!(fixture)

    authorization = %Authorization{
      proposal: proposal,
      proposal_digest: proposal.proposal_digest,
      tool_name: proposal.tool_name,
      tool_version: proposal.tool_version,
      definition: definition,
      arguments: proposal.arguments,
      capability: capability,
      decision_digest: String.duplicate("b", 64),
      authorized_at: DateTime.utc_now()
    }

    assert {:ok, request} =
             Request.new(%{
               execution: Phase08AttemptFixture.request!(fixture),
               invocation_iri: invocation.iri,
               tool_iri: definition.iri,
               tool_version: definition.version,
               sequence: 1,
               deadline: deadline,
               expected_effect: "source.read",
               allowed_effects: ["source.read"],
               input_refs: invocation.input_refs,
               input_digests: invocation.input_digests,
               arguments: proposal.arguments,
               output_bytes: definition.max_output_bytes
             })

    owner = self()

    executor = fn command, _options ->
      send(owner, {:knowledge_tool_command, command})
      {:ok, %{outcome: :committed}}
    end

    assert {:ok, ledger} =
             KnowledgeLedger.new(
               attempt: fixture.attempt,
               attempt_resolution: fixture.attempt_resolution,
               lease: fixture.lease,
               expected_effect_iri: expected_effect,
               start_attributes: fn _authorization ->
                 Phase08ExecutionFixture.command_attributes(
                   fixture,
                   930,
                   invocation.iri,
                   "record governed tool start"
                 )
               end,
               outcome_attributes: fn _result ->
                 Phase08ExecutionFixture.command_attributes(
                   fixture,
                   931,
                   invocation.iri,
                   "record governed tool outcome"
                 )
               end,
               executor: executor,
               command_options: [clock: fn -> fixture.issued_at end]
             )

    assert {:ok, start_receipt} = KnowledgeLedger.start(ledger, authorization, request)
    assert_received {:knowledge_tool_command, start_command}
    assert start_command.command_type == "RecordToolInvocation"

    [start_target] = start_command.payload.changes
    types = Enum.filter(start_target.additions, &(elem(&1, 1) == rdf_type()))
    assert Enum.any?(types, &(inspect(elem(&1, 2)) =~ "ActionProposal"))
    assert Enum.any?(types, &(inspect(elem(&1, 2)) =~ "ToolInvocation"))
    refute inspect(start_command) =~ "raw-value"

    assert {:ok, result} = result("safe output")

    assert {:ok, %{outcome: :committed}} =
             KnowledgeLedger.outcome(ledger, start_receipt, result)

    assert_received {:knowledge_tool_command, outcome_command}
    assert outcome_command.command_type == "RecordToolOutcome"
    refute inspect(outcome_command) =~ "raw-value"
  end

  defp gateway_fixture(options \\ []) do
    invocation = resource!(:tool_invocation, "gateway")
    proposal = proposal!(invocation, resource!(:knowledge_assertion, "source"))
    capability = capability!()
    current = current(capability, proposal)
    current_mutator = Keyword.get(options, :current, fn _capability, value -> value end)
    owner = self()

    current_provider = fn ->
      send(owner, :tool_current_revalidated)
      current_mutator.(capability, current)
    end

    ledger = Keyword.get(options, :ledger, %{owner: self()})
    adapter_result = Keyword.get(options, :adapter_result, result("safe output"))
    {:ok, effect_journal} = EffectJournal.start_link()

    gateway_options = [
      execution_request: execution_request!(),
      sequence: 1,
      expected_effect: "source.read",
      allowed_effects: ["source.read"],
      ledger: {FakeToolLedger, ledger},
      effect_sink: {EffectJournal, effect_journal},
      current_provider: current_provider,
      adapter: {FakeReferenceToolAdapter, %{owner: self(), result: adapter_result}},
      adapter_options: [mode: :fixture]
    ]

    {proposal, capability, current, gateway_options}
  end

  defp proposal!(invocation, input_ref) do
    assert {:ok, proposal} =
             Proposal.from_directive(invocation, %{
               tool_name: "read_file",
               tool_version: "1.0.0",
               classification: :internal,
               input_refs: [input_ref],
               arguments: %{
                 path: "lib/jido_code.ex",
                 expected_digest: "sha256:" <> String.duplicate("a", 64)
               }
             })

    proposal
  end

  defp capability!(fixture \\ nil) do
    execution =
      if fixture, do: Phase08AttemptFixture.request!(fixture), else: execution_request!()

    source =
      if fixture,
        do: fixture.attempt.snapshot_iri,
        else: resource!(:knowledge_assertion, "source")

    assert {:ok, capability} =
             Capability.new(%{
               attempt_iri: execution.attempt_iri,
               lease_iri: execution.lease_iri,
               task_iri: execution.task_iri,
               repository_iri: execution.repository_iri,
               actor_iri: execution.actor_iri,
               agent_iri: execution.agent_iri,
               profile_iri: resource!(:harness_profile, "gateway-profile"),
               model: "openai:gpt-4.1-mini",
               tool_catalog_version: "1.0.0",
               snapshot_iri: execution.snapshot_iri,
               source_graph_revisions: %{resource!(:graph_revision_reference, "policy") => 9},
               permitted_tools: ["read_file"],
               path_prefixes: ["lib"],
               ref_iris: [source],
               graph_scope_iris: [resource!(:graph_revision_reference, "policy")],
               network_destinations: [],
               registered_commands: [],
               data_classes: [:internal],
               resource_ceilings: %{output_bytes: 262_144, timeout_ms: 300_000},
               credential_reference_iris: [],
               expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
               fencing_token: execution.fencing_token,
               idempotency_namespace: "sha256:" <> String.duplicate("d", 64),
               policy_revision: 41,
               revocation_generation: 3,
               authority_classes: [:tool_execution]
             })

    capability
  end

  defp execution_request! do
    assert {:ok, request} =
             ExecutionRequest.new(%{
               attempt_iri: resource!(:execution_attempt, "attempt"),
               lease_iri: resource!(:execution_lease, "lease"),
               task_iri: resource!(:knowledge_assertion, "task"),
               goal_iri: resource!(:knowledge_assertion, "goal"),
               plan_iri: resource!(:knowledge_assertion, "plan"),
               repository_iri: resource!(:knowledge_assertion, "repository"),
               snapshot_iri: resource!(:repository_snapshot, "snapshot"),
               actor_iri: resource!(:knowledge_assertion, "actor"),
               agent_iri: resource!(:knowledge_assertion, "agent"),
               capability_iri: resource!(:knowledge_assertion, "capability"),
               fencing_token: 17,
               context_digest: String.duplicate("e", 64),
               runtime_version: "phase-h03-fixture/1",
               constraints: %{}
             })

    request
  end

  defp current(capability, proposal) do
    %{
      now: DateTime.utc_now(),
      invocation_iri: proposal.invocation_iri,
      attempt_iri: capability.attempt_iri,
      lease_iri: capability.lease_iri,
      lease_state: :active,
      policy_revision: capability.policy_revision,
      source_graph_revisions: capability.source_graph_revisions,
      snapshot_iri: capability.snapshot_iri,
      fencing_token: capability.fencing_token,
      revocation_generation: capability.revocation_generation,
      approval_refs: [],
      approved_tools: []
    }
  end

  defp result(stdout) do
    Result.new(
      %{
        status: :completed,
        exit_status: 0,
        stdout: stdout,
        stderr: "",
        external_output_iris: [],
        usage: %{cpu_ms: 1},
        artifact_iris: [],
        redaction: :none
      },
      262_144
    )
  end

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h03-gateway-#{seed}")
    iri
  end

  defp rdf_type, do: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
end

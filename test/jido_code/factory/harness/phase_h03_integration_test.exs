defmodule JidoCode.Factory.Harness.PhaseH03IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.EffectJournal
  alias JidoCode.Factory.Tool.ExecutionReceipt
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.RepositoryPathGuard
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.ToolGateway
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeReferenceToolAdapter
  alias JidoCode.TestSupport.FakeToolLedger

  test "all catalog tools reject open or incomplete shapes with only safe errors" do
    for {name, arguments} <- valid_arguments() do
      assert {:ok, definition} = Catalog.fetch(name)

      hostile_calls = [
        Map.put(arguments, :unknown_effect, "expand authority"),
        Map.delete(arguments, List.first(definition.input_schema.required))
      ]

      for hostile <- hostile_calls do
        assert {:error, %AdapterError{} = error} =
                 Catalog.validate(name, definition.version, hostile, constraints())

        assert error.kind in definition.safe_errors
        refute_received {:hostile_effect, ^name}
      end
    end
  end

  test "hostile paths, shell syntax, and destinations fail before dispatch" do
    digest = "sha256:" <> String.duplicate("a", 64)

    hostile = [
      {"read_file", %{path: "../../etc/passwd", expected_digest: digest}},
      {"read_file", %{path: "/etc/passwd", expected_digest: digest}},
      {"create_file",
       %{
         path: "lib/../config/runtime.exs",
         content: "bad",
         expected_parent_digest: digest
       }},
      {"run_registered_check", %{check: "mix-test; curl https://attacker.invalid"}},
      {"run_governed_command", %{command: "$(cat /etc/passwd)"}},
      {"submit_candidate",
       %{
         candidate_ref: resource!("candidate"),
         approval_ref: resource!("approval"),
         destination: "https://attacker.invalid/hook",
         expected_revision: 9
       }}
    ]

    for {name, arguments} <- hostile do
      assert {:error, %AdapterError{kind: :invalid_input, operation: :tool_input}} =
               Catalog.validate(name, "1.0.0", arguments, constraints())

      refute_received {:hostile_effect, ^name}
    end
  end

  test "repository path resolution rejects symlinks and never exposes host paths in inspection" do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-code-phase-h03-#{System.unique_integer([:positive, :monotonic])}"
      )

    lib = Path.join(root, "lib")
    outside = Path.join(root, "outside")
    File.mkdir_p!(lib)
    File.mkdir_p!(outside)
    File.write!(Path.join(lib, "safe.ex"), "defmodule Safe do\nend\n")
    File.write!(Path.join(outside, "secret.ex"), "secret")
    :ok = File.ln_s(outside, Path.join(lib, "linked"))
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:ok, resolved} =
             RepositoryPathGuard.resolve(root, "lib/safe.ex", ["lib"], :existing_file)

    assert resolved.absolute == Path.join(lib, "safe.ex")

    assert inspect(resolved) ==
             "#JidoCode.Factory.Tool.ResolvedPath<relative: \"lib/safe.ex\", ...>"

    refute inspect(resolved) =~ root

    assert {:ok, created} =
             RepositoryPathGuard.resolve(root, "lib/new.ex", ["lib"], :new_file)

    assert created.relative == "lib/new.ex"

    assert {:error, %AdapterError{operation: :repository_path}} =
             RepositoryPathGuard.resolve(
               root,
               "lib/linked/secret.ex",
               ["lib"],
               :existing_file
             )
  end

  test "revocation, lease expiry, and fence supersession all win the dispatch race" do
    mutations = [
      fn capability, current ->
        %{current | revocation_generation: capability.revocation_generation + 1}
      end,
      fn capability, current ->
        %{current | now: DateTime.add(capability.expires_at, 1, :second)}
      end,
      fn capability, current ->
        %{current | fencing_token: capability.fencing_token + 1}
      end
    ]

    for mutate <- mutations do
      {proposal, capability, current, options} = gateway_fixture(current: mutate)

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
  end

  test "pre-admission hostile authority creates no start, effect, or outcome" do
    {proposal, capability, current, options} = gateway_fixture()
    denied = %{current | lease_state: :revoked}

    assert {:error, %AdapterError{operation: :tool_authorization}} =
             ToolGateway.execute(proposal, capability, denied, options)

    refute_received {:tool_ledger_start, _authorization, _request}
    refute_received {:reference_tool_effect, _request, _options}
    refute_received {:tool_ledger_outcome, _start, _result}
  end

  test "a crash after durable start but before effect retries without a duplicate effect" do
    owner = self()

    blocker = fn ->
      send(owner, :after_start_waiting)

      receive do
        :release_crashed_gateway -> raise "unexpected release"
      end
    end

    {proposal, capability, current, options} = gateway_fixture(current_provider: blocker)

    task = Task.async(fn -> ToolGateway.execute(proposal, capability, current, options) end)
    assert_receive {:tool_ledger_start, _authorization, _request}
    assert_receive :after_start_waiting
    assert Task.shutdown(task, :brutal_kill) == nil

    refute_received {:reference_tool_effect, _request, _adapter_options}
    refute_received {:tool_ledger_outcome, _start, _result}

    retry_options = Keyword.put(options, :current_provider, fn -> current end)

    assert {:ok, %ExecutionReceipt{status: :completed, effect_dispatched: true}} =
             ToolGateway.execute(proposal, capability, current, retry_options)

    assert_received {:reference_tool_effect, _request, _adapter_options}
    refute_received {:reference_tool_effect, _duplicate_request, _duplicate_options}
    assert_received {:tool_ledger_outcome, _start, %Result{status: :completed}}
    refute_received {:tool_ledger_outcome, _start, _duplicate_result}
  end

  defp gateway_fixture(options \\ []) do
    execution = execution_request!()
    invocation = resource!(:tool_invocation, "gateway")

    assert {:ok, proposal} =
             Proposal.from_directive(invocation, %{
               tool_name: "read_file",
               tool_version: "1.0.0",
               classification: :internal,
               input_refs: [execution.snapshot_iri],
               arguments: %{
                 path: "lib/jido_code.ex",
                 expected_digest: "sha256:" <> String.duplicate("a", 64)
               }
             })

    assert {:ok, capability} = capability(execution)
    current = current(capability, proposal)
    owner = self()
    mutate = Keyword.get(options, :current, fn _capability, value -> value end)

    current_provider =
      Keyword.get(options, :current_provider, fn -> mutate.(capability, current) end)

    {:ok, journal} = EffectJournal.start_link()
    assert {:ok, result} = result()

    gateway_options = [
      execution_request: execution,
      sequence: 1,
      expected_effect: "source.read",
      allowed_effects: ["source.read"],
      ledger: {FakeToolLedger, %{owner: owner}},
      effect_sink: {EffectJournal, journal},
      current_provider: current_provider,
      adapter: {FakeReferenceToolAdapter, %{owner: owner, result: {:ok, result}}},
      adapter_options: [mode: :integration]
    ]

    {proposal, capability, current, gateway_options}
  end

  defp capability(execution) do
    Capability.new(%{
      attempt_iri: execution.attempt_iri,
      lease_iri: execution.lease_iri,
      task_iri: execution.task_iri,
      repository_iri: execution.repository_iri,
      actor_iri: execution.actor_iri,
      agent_iri: execution.agent_iri,
      profile_iri: resource!(:harness_profile, "profile"),
      model: "openai:gpt-4.1-mini",
      tool_catalog_version: "1.0.0",
      snapshot_iri: execution.snapshot_iri,
      source_graph_revisions: %{resource!(:graph_revision_reference, "policy") => 4},
      permitted_tools: ["read_file"],
      path_prefixes: ["lib"],
      ref_iris: [execution.snapshot_iri],
      graph_scope_iris: [resource!(:graph_revision_reference, "policy")],
      network_destinations: [],
      registered_commands: [],
      data_classes: [:internal],
      resource_ceilings: %{output_bytes: 262_144, timeout_ms: 300_000},
      credential_reference_iris: [],
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
      fencing_token: execution.fencing_token,
      idempotency_namespace: "sha256:" <> String.duplicate("e", 64),
      policy_revision: 44,
      revocation_generation: 5,
      authority_classes: [:tool_execution]
    })
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

  defp execution_request! do
    assert {:ok, request} =
             ExecutionRequest.new(%{
               attempt_iri: resource!(:execution_attempt, "attempt"),
               lease_iri: resource!(:execution_lease, "lease"),
               task_iri: resource!("task"),
               goal_iri: resource!("goal"),
               plan_iri: resource!("plan"),
               repository_iri: resource!("repository"),
               snapshot_iri: resource!(:repository_snapshot, "snapshot"),
               actor_iri: resource!("actor"),
               agent_iri: resource!("agent"),
               capability_iri: resource!("capability"),
               fencing_token: 101,
               context_digest: String.duplicate("f", 64),
               runtime_version: "phase-h03-integration/1",
               constraints: %{}
             })

    request
  end

  defp result do
    Result.new(
      %{
        status: :completed,
        exit_status: 0,
        stdout: "bounded output",
        stderr: "",
        external_output_iris: [],
        usage: %{cpu_ms: 1},
        artifact_iris: [],
        redaction: :none
      },
      262_144
    )
  end

  defp valid_arguments do
    digest = "sha256:" <> String.duplicate("a", 64)

    %{
      "search_source" => %{query: "ToolGateway", scope_ref: resource!("scope")},
      "inspect_symbol" => %{
        symbol: "JidoCode.Factory.ToolGateway.execute/4",
        source_ref: resource!("source"),
        expected_revision: 8
      },
      "read_file" => %{path: "lib/jido_code.ex", expected_digest: digest},
      "apply_edit" => %{
        path: "lib/jido_code.ex",
        expected_digest: digest,
        old_text: "old",
        new_text: "new",
        expected_matches: 1
      },
      "create_file" => %{
        path: "test/new_test.exs",
        content: "content",
        expected_parent_digest: digest
      },
      "delete_file" => %{path: "test/old_test.exs", expected_digest: digest},
      "run_registered_check" => %{check: "mix-test"},
      "run_governed_command" => %{command: "format-check"},
      "show_candidate_diff" => %{snapshot_ref: resource!("snapshot")},
      "submit_candidate" => %{
        candidate_ref: resource!("candidate"),
        approval_ref: resource!("approval"),
        destination: "github_pull_request",
        expected_revision: 12
      },
      "request_clarification" => %{
        question: "Which branch?",
        reason: "ambiguous_intent"
      }
    }
  end

  defp constraints do
    %{
      allowed_path_prefixes: ["lib", "test"],
      allowed_refs: [
        resource!("scope"),
        resource!("source"),
        resource!("snapshot"),
        resource!("candidate"),
        resource!("approval")
      ],
      allowed_destinations: ["github_pull_request"],
      registered_commands: ["mix-test", "format-check"]
    }
  end

  defp resource!(seed), do: resource!(:knowledge_assertion, seed)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h03-integration-#{seed}")
    iri
  end
end

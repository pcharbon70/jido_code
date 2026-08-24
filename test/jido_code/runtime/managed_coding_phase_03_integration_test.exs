defmodule JidoCode.Runtime.ManagedCodingPhase03IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.CandidateDirectiveExecutor
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.ContextDirectiveExecutor
  alias JidoCode.Factory.ManagedCoding.LoopBudget
  alias JidoCode.Factory.ManagedCoding.ModelDirectiveExecutor
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.ReadRequest
  alias JidoCode.Factory.ManagedCoding.ToolDirectiveExecutor
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.EffectJournal
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Integrations.ManagedCodingAdapterRegistry
  alias JidoCode.Integrations.ManagedCodingCandidateTools
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Runtime.JidoInstance
  alias JidoCode.Runtime.ManagedCoding.Agent, as: ManagedAgent
  alias JidoCode.Runtime.ManagedCoding.AgentState
  alias JidoCode.Runtime.ManagedCoding.Directive.Candidate
  alias JidoCode.Runtime.ManagedCoding.Directive.Context
  alias JidoCode.Runtime.ManagedCoding.Directive.Model
  alias JidoCode.Runtime.ManagedCoding.Directive.Tool
  alias JidoCode.Runtime.ManagedCoding.Dispatcher
  alias JidoCode.Runtime.ManagedCoding.SingleAgentLoop
  alias JidoCode.TestSupport.AgentManagedCodingContextSink
  alias JidoCode.TestSupport.FakeManagedCodingDirective
  alias JidoCode.TestSupport.FakeManagedCodingModelLedger
  alias JidoCode.TestSupport.FakeModelAuthority
  alias JidoCode.TestSupport.FakeSecretProvider
  alias JidoCode.TestSupport.FakeToolLedger
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.SequencedModelInteraction

  @policy_graph "https://jido.run/graph/factory/policy"

  setup context do
    root = Path.join(System.tmp_dir!(), "jido-code-phase-03-#{context.test}")
    File.rm_rf!(root)
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "lib/example.ex"), source(:old))
    git!(root, ["init"])
    git!(root, ["config", "user.email", "fixture@example.test"])
    git!(root, ["config", "user.name", "Fixture"])
    git!(root, ["add", "."])
    git!(root, ["commit", "-m", "fixture"])
    on_exit(fn -> File.rm_rf!(root) end)

    execution = execution_request!()
    capability = capability!(execution)
    requests = managed_requests!(root, execution)
    mutation_current = mutation_current(requests.mutation)

    check_runner = fn command, _timeout ->
      {output, status} =
        System.cmd(command.executable, command.arguments,
          cd: command.cwd,
          env: Map.to_list(command.environment),
          stderr_to_stdout: true
        )

      {:ok, %{exit_code: status, output: output, duration_ms: 1}}
    end

    adapter_state = %{
      read_request: requests.read,
      mutation_request: requests.mutation,
      analysis_revision_number: 7,
      effect_options: [
        current_provider: fn -> mutation_current end,
        check_catalog: check_catalog!(),
        check_runner: check_runner
      ]
    }

    {:ok, registry} = ManagedCodingAdapterRegistry.new(adapter_state)
    {:ok, journal} = EffectJournal.start_link()
    {:ok, context_store} = Elixir.Agent.start_link(fn -> %{} end)

    %{
      root: root,
      execution: execution,
      capability: capability,
      requests: requests,
      mutation_current: mutation_current,
      registry: registry,
      journal: journal,
      context_store: context_store
    }
  end

  test "runs inspect-edit-check-candidate through one real AgentServer and governed seams",
       fixture do
    old_digest = digest(File.read!(Path.join(fixture.root, "lib/example.ex")))

    responses = [
      tool_response(
        "read_file",
        %{"path" => "lib/example.ex", "expected_digest" => old_digest},
        fixture.execution.snapshot_iri
      ),
      tool_response(
        "apply_edit",
        %{
          "path" => "lib/example.ex",
          "expected_digest" => old_digest,
          "old_text" => ":old",
          "new_text" => ":new",
          "expected_matches" => 1
        },
        fixture.execution.snapshot_iri
      ),
      tool_response(
        "run_registered_check",
        %{"check" => "git-diff-check"},
        fixture.execution.snapshot_iri
      ),
      decision_response(%{
        "kind" => "completion_proposal",
        "summary" => "Candidate contains the requested edit",
        "claims" => ["Changed lib/example.ex"]
      })
    ]

    {:ok, response_agent} = Elixir.Agent.start_link(fn -> Enum.map(responses, &{:ok, &1}) end)
    {:ok, gateway} = model_gateway(response_agent)
    {:ok, budget_spec} = Budget.new(budget_attributes())
    {:ok, budget} = LoopBudget.new(budget_spec, checks_limit: 2)
    {:ok, initial} = AgentState.initial(initial_agent_state(fixture.execution))

    id = "managed-phase-03-#{System.unique_integer([:positive])}"

    {:ok, agent_server} =
      JidoInstance.start_agent(ManagedAgent, id: id, initial_state: AgentState.to_map(initial))

    on_exit(fn -> if Process.alive?(agent_server), do: JidoInstance.stop_agent(agent_server) end)

    tool_provider = tool_provider(fixture)
    capture = candidate_capture(fixture)
    model_state = model_state(gateway, fixture.context_store, fixture.execution)

    context_state = %{
      compiler_options: [query: &query/6],
      context_sink: {AgentManagedCodingContextSink, fixture.context_store}
    }

    directive_factory = directive_factory(fixture)

    {:ok, loop} =
      SingleAgentLoop.start_link(
        agent_server: agent_server,
        budget: budget,
        directive_factory: directive_factory,
        observation_provider: &observations/2
      )

    unused = {FakeManagedCodingDirective, %{owner: self()}}

    handlers = %{
      context: {ContextDirectiveExecutor, context_state},
      model: {ModelDirectiveExecutor, model_state},
      tool: {ToolDirectiveExecutor, %{tool_provider: tool_provider}},
      candidate: {CandidateDirectiveExecutor, %{capture: capture}},
      actor: unused,
      observation: unused,
      continuation: unused
    }

    current_provider = fn attempt ->
      %{
        attempt_iri: attempt,
        fencing_token: fixture.execution.fencing_token,
        target: agent_server,
        current?: true
      }
    end

    {:ok, dispatcher} =
      Dispatcher.start_link(
        handlers: handlers,
        current_provider: current_provider,
        delivery: fn target, signal -> SingleAgentLoop.deliver(loop, target, signal) end,
        max_concurrency: 2,
        max_per_attempt: 1,
        max_queue: 16
      )

    :ok = SingleAgentLoop.attach_dispatcher(loop, dispatcher)
    :ok = SingleAgentLoop.begin(loop)

    terminal = await_terminal(loop)
    assert %{status: :completed, agent: %{phase: :candidate_ready} = agent} = terminal
    assert length(agent.candidate_digests) == 1
    assert File.read!(Path.join(fixture.root, "lib/example.ex")) == source(:new)
    assert Elixir.Agent.get(response_agent, & &1) == []

    assert_received {:model_ledger_start, _, _}
    assert_received {:model_ledger_outcome, _, _}
    assert_received {:tool_ledger_start, _, _}
    assert_received {:tool_ledger_outcome, _, _}
  end

  defp directive_factory(fixture) do
    fn effect, payload, agent ->
      attributes = %{
        attempt_iri: agent.attempt_iri,
        fencing_token: agent.fencing_token,
        sequence: agent.sequence + 1,
        invocation_iri: invocation(effect, agent),
        deadline: DateTime.add(DateTime.utc_now(), 30, :second),
        payload: directive_payload(effect, payload, fixture)
      }

      case effect do
        :context -> Context.new(attributes)
        :model -> Model.new(attributes)
        :tool -> Tool.new(attributes)
        :candidate -> Candidate.new(attributes)
      end
    end
  end

  defp invocation(:context, agent),
    do: resource(:context_manifest, "context-#{agent.sequence + 1}")

  defp invocation(_effect, agent), do: agent.current_invocation_iri

  defp directive_payload(:context, _payload, fixture),
    do: %{context: context_attributes(fixture)}

  defp directive_payload(:model, _payload, _fixture),
    do: %{request_revision: raw_digest("managed-request")}

  defp directive_payload(_effect, payload, _fixture), do: payload

  defp context_attributes(fixture) do
    {:ok, tree} =
      WorkspaceDigest.tree(fixture.root, %{
        file_count: 100,
        input_bytes: 64_000,
        disk_bytes: 128_000
      })

    snapshot = fixture.execution.snapshot_iri

    %{
      compiler: %{
        attempt_iri: fixture.execution.attempt_iri,
        manifest_index: 1,
        repository_iri: fixture.execution.repository_iri,
        snapshot_iri: snapshot,
        analysis_profile: "elixir-ast/1.0.0",
        expected_dataset_revision: 44,
        source_graph_revisions: %{@policy_graph => 7},
        authority: :fixture_authority,
        scope_iri: Phase04Fixture.scope!(:factory, "phase-03-loop"),
        sections: [context_section(snapshot, fixture.execution.repository_iri)],
        budget: %{max_items: 20, max_bytes: 65_536, max_tokens: 16_384, max_item_bytes: 4_096}
      },
      pins: %{
        task_iri: fixture.execution.task_iri,
        snapshot_iri: snapshot,
        lease_iri: fixture.execution.lease_iri,
        capability_iri: fixture.execution.capability_iri,
        source_revision: raw_digest("source"),
        workspace_revision: tree.digest,
        policy_revision: raw_digest("policy"),
        prompt_revision: raw_digest("prompt"),
        tool_revision: raw_digest("tools"),
        profile_revision: raw_digest("profile"),
        authority_revision: raw_digest("authority"),
        graph_revisions: %{@policy_graph => 7},
        erasure_generation: 0,
        memory_partition_digest: nil
      },
      memory: :disabled
    }
  end

  defp context_section(snapshot, repository) do
    %{
      kind: :task,
      query_name: :resource_description,
      query_version: "1.7.0",
      parameters: %{resource: resource(:knowledge_assertion, "loop-task-context")},
      item_iri: resource(:knowledge_assertion, "loop-context-item"),
      classification: :internal,
      required?: true,
      graph_revisions: %{@policy_graph => 7},
      repository_iri: repository,
      snapshot_iri: snapshot,
      analysis_profile: "elixir-ast/1.0.0"
    }
  end

  defp query(:resource_description, "1.7.0", parameters, _authority, _scope, _options) do
    {:ok,
     %{
       query_name: :resource_description,
       query_version: "1.7.0",
       dataset_revision: 44,
       graph_revisions: %{@policy_graph => 7},
       completeness: %{complete?: true},
       freshness: :current,
       truncated?: false,
       data: %{resource: parameters.resource}
     }}
  end

  defp model_state(gateway, store, execution) do
    request_provider = fn envelope ->
      context = Elixir.Agent.get(store, &Map.fetch!(&1, :context))

      {:ok,
       %{
         invocation_iri: envelope.invocation_iri,
         profile_iri: gateway.profile.profile_iri,
         context_manifest_iri: context.compiled.manifest.iri,
         provider: "openai",
         model: "gpt-4.1-mini",
         messages: context.compiled.serialized,
         options: [temperature: 0.0],
         deadline: DateTime.add(DateTime.utc_now(), 20, :second)
       }}
    end

    %{
      gateway: gateway,
      request_provider: request_provider,
      ledger: {FakeManagedCodingModelLedger, %{owner: self()}},
      attempt: execution.attempt_iri
    }
  end

  defp tool_provider(fixture) do
    owner = self()

    fn envelope, tool ->
      {:ok, definition} = Catalog.fetch(tool.name, tool.version)
      {:ok, adapter} = ManagedCodingAdapterRegistry.fetch(fixture.registry, definition)

      {:ok, proposal} =
        Proposal.from_directive(envelope.invocation_iri, %{
          tool_name: tool.name,
          tool_version: tool.version,
          classification: tool.classification,
          input_refs: tool.input_refs,
          arguments: tool.arguments
        })

      current = gateway_current(fixture.capability, proposal)

      options = [
        execution_request: fixture.execution,
        sequence: envelope.sequence,
        expected_effect: "managed.loop.#{envelope.sequence}",
        allowed_effects: ["managed.loop.#{envelope.sequence}"],
        ledger: {FakeToolLedger, %{owner: owner}},
        effect_sink: {EffectJournal, fixture.journal},
        current_provider: fn -> current end,
        adapter: adapter
      ]

      {:ok, proposal, fixture.capability, current, options}
    end
  end

  defp candidate_capture(fixture) do
    fn _envelope, _proposal ->
      case ManagedCodingCandidateTools.capture_candidate(
             fixture.requests.mutation,
             %{
               toolchain_revision: raw_digest("toolchain"),
               profile_revision: raw_digest("profile")
             },
             current_provider: fn -> fixture.mutation_current end
           ) do
        {:ok, artifact} -> {:ok, %{candidate_digest: artifact.artifact_digest}}
        error -> error
      end
    end
  end

  defp observations(:model, signal) do
    data = signal.data
    {Map.get(data, :usage, %{}), [observed_only: [:cost_microunits]]}
  end

  defp observations(:tool, _signal), do: {%{}, []}
  defp observations(_effect, _signal), do: {%{}, []}

  defp model_gateway(responses) do
    profile_iri = resource(:model_access_profile, "phase-03-model-profile")
    credential_iri = resource(:knowledge_assertion, "phase-03-model-credential")

    {:ok, reference} =
      CredentialReference.new(%{iri: credential_iri, provider: "openai", key: "fixture-key"})

    {:ok, profile} =
      BufferedProfile.new(
        %{
          profile_iri: profile_iri,
          credential_reference_iri: credential_iri,
          provider: "openai",
          model: "gpt-4.1-mini",
          endpoint: "https://api.openai.com/v1",
          access_mode: :host_api,
          credential_class: :static_reusable,
          billing_mode: :metered_api,
          readiness: [:credential_available, :authenticated, :model_available, :policy_allowed]
        },
        reference
      )

    ModelGateway.new(SequencedModelInteraction, %{owner: self(), responses: responses},
      profile: profile,
      secret_provider: {FakeSecretProvider, %{owner: self(), result: {:ok, "broker-key"}}},
      authority: {FakeModelAuthority, %{owner: self(), results: %{}}}
    )
  end

  defp tool_response(name, arguments, input_ref) do
    decision_response(%{
      "kind" => "tool_proposal",
      "tool" => %{
        "name" => name,
        "version" => "1.0.0",
        "arguments" => arguments,
        "classification" => "internal",
        "input_refs" => [input_ref]
      }
    })
  end

  defp decision_response(body) do
    {:ok, response} =
      Response.new(%{
        type: :final_answer,
        text: Jason.encode!(body),
        thinking: "",
        tool_calls: [],
        finish_reason: :stop,
        usage: %{input_tokens: 10, output_tokens: 5},
        call_metadata: %{response_id: "fixture-#{System.unique_integer([:positive])}"},
        provenance: %{fixture: true}
      })

    response
  end

  defp await_terminal(loop, remaining \\ 300)

  defp await_terminal(loop, 0),
    do: flunk("loop did not terminate: #{inspect(SingleAgentLoop.status(loop))}")

  defp await_terminal(loop, remaining) do
    status = SingleAgentLoop.status(loop)

    if status.status in [:completed, :failed, :stopped],
      do: status,
      else:
        (
          Process.sleep(10)
          await_terminal(loop, remaining - 1)
        )
  end

  defp initial_agent_state(execution),
    do: %{
      attempt_iri: execution.attempt_iri,
      fencing_token: execution.fencing_token,
      profile_digest: raw_digest("profile"),
      context_digest: raw_digest("context"),
      tool_digest: raw_digest("tools"),
      model_digest: raw_digest("model")
    }

  defp budget_attributes do
    Map.new(Budget.dimensions(), fn dimension ->
      enforcement = if dimension in [:tokens, :cost_microunits], do: :next_effect, else: :hard
      {dimension, %{limit: 1_000_000, enforcement: enforcement}}
    end)
  end

  defp managed_requests!(root, execution) do
    {:ok, tree} =
      WorkspaceDigest.tree(root, %{file_count: 100, input_bytes: 64_000, disk_bytes: 128_000})

    workspace = resource(:sandbox_instance, "phase-03-workspace")

    {:ok, read} =
      ReadRequest.new(%{
        repository_iri: execution.repository_iri,
        snapshot_iri: execution.snapshot_iri,
        actor_iri: execution.actor_iri,
        workspace_iri: workspace,
        workspace_root: root,
        workspace_digest: tree.digest,
        analysis_revision: raw_digest("analysis"),
        allowed_paths: ["lib"],
        visible_classifications: [:internal],
        max_results: 20,
        max_bytes: 64_000
      })

    {:ok, mutation} =
      MutationRequest.new(%{
        attempt_iri: execution.attempt_iri,
        lease_iri: execution.lease_iri,
        fencing_token: execution.fencing_token,
        workspace_iri: workspace,
        workspace_root: root,
        workspace_digest: tree.digest,
        snapshot_iri: execution.snapshot_iri,
        capability_iri: execution.capability_iri,
        policy_revision: raw_digest("policy"),
        allowed_paths: ["lib"],
        protected_paths: [".git"],
        limits: %{disk_bytes: 128_000, changed_files: 8, diff_bytes: 64_000, output_bytes: 32_000}
      })

    %{read: read, mutation: mutation}
  end

  defp mutation_current(request),
    do: %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      workspace_iri: request.workspace_iri,
      workspace_digest: request.workspace_digest,
      snapshot_iri: request.snapshot_iri,
      capability_iri: request.capability_iri,
      policy_revision: request.policy_revision,
      lease_current?: true,
      policy_current?: true
    }

  defp check_catalog! do
    {:ok, definition} =
      CheckDefinition.new(%{
        name: "git-diff-check",
        executable: System.find_executable("git"),
        arguments: ["diff", "--check"],
        cwd: ".",
        environment: %{"LANG" => "C.UTF-8"},
        toolchain_digest: raw_digest("git"),
        timeout_ms: 10_000,
        output_bytes: 16_384,
        resources: %{cpu_ms: 5_000, memory_bytes: 64_000_000, process_count: 4},
        retry_policy: :safe_idempotent,
        network: :deny
      })

    {:ok, catalog} = CheckCatalog.new([definition])
    catalog
  end

  defp execution_request! do
    {:ok, request} =
      ExecutionRequest.new(%{
        attempt_iri: resource(:execution_attempt, "phase-03-attempt"),
        lease_iri: resource(:execution_lease, "phase-03-lease"),
        task_iri: resource(:knowledge_assertion, "task"),
        goal_iri: resource(:knowledge_assertion, "goal"),
        plan_iri: resource(:knowledge_assertion, "plan"),
        repository_iri: resource(:knowledge_assertion, "repository"),
        snapshot_iri: resource(:repository_snapshot, "snapshot"),
        actor_iri: resource(:knowledge_assertion, "actor"),
        agent_iri: resource(:knowledge_assertion, "agent"),
        capability_iri: resource(:capability_declaration, "capability"),
        fencing_token: 303,
        context_digest: raw_digest("context"),
        runtime_version: "managed-coding-phase-03/1",
        constraints: %{}
      })

    request
  end

  defp capability!(execution) do
    graph = resource(:graph_revision_reference, "policy")

    {:ok, capability} =
      Capability.new(%{
        attempt_iri: execution.attempt_iri,
        lease_iri: execution.lease_iri,
        task_iri: execution.task_iri,
        repository_iri: execution.repository_iri,
        actor_iri: execution.actor_iri,
        agent_iri: execution.agent_iri,
        profile_iri: resource(:harness_profile, "profile"),
        model: "openai:test",
        tool_catalog_version: "1.0.0",
        snapshot_iri: execution.snapshot_iri,
        source_graph_revisions: %{graph => 7},
        permitted_tools: ManagedCodingAdapterRegistry.enabled_names(),
        path_prefixes: ["lib"],
        ref_iris: [execution.snapshot_iri],
        graph_scope_iris: [graph],
        network_destinations: [],
        registered_commands: ["git-diff-check"],
        data_classes: [:internal],
        resource_ceilings: %{output_bytes: 262_144, timeout_ms: 300_000},
        credential_reference_iris: [],
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
        fencing_token: execution.fencing_token,
        idempotency_namespace: "sha256:" <> raw_digest("effects"),
        policy_revision: 51,
        revocation_generation: 3,
        authority_classes: [:tool_execution]
      })

    capability
  end

  defp gateway_current(capability, proposal),
    do: %{
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

  defp source(value), do: "defmodule Example do\n  def value, do: #{inspect(value)}\nend\n"
  defp digest(value), do: "sha256:" <> WorkspaceDigest.digest(value)
  defp raw_digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-03-#{seed}")
    iri
  end

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end
end

defmodule JidoCode.Factory.ManagedCodingPhase02IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.ReadRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.EffectJournal
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.ToolGateway
  alias JidoCode.Integrations.ManagedCodingAdapterRegistry
  alias JidoCode.Integrations.ManagedCodingCandidateTools
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeToolLedger

  setup context do
    root = Path.join(System.tmp_dir!(), "jido-code-phase-02-#{context.test}")
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
    check_catalog = check_catalog!()

    mutation_current = %{
      attempt_iri: requests.mutation.attempt_iri,
      lease_iri: requests.mutation.lease_iri,
      fencing_token: requests.mutation.fencing_token,
      workspace_iri: requests.mutation.workspace_iri,
      workspace_digest: requests.mutation.workspace_digest,
      snapshot_iri: requests.mutation.snapshot_iri,
      capability_iri: requests.mutation.capability_iri,
      policy_revision: requests.mutation.policy_revision,
      lease_current?: true,
      policy_current?: true
    }

    check_runner = fn command, _timeout ->
      {output, status} =
        System.cmd(command.executable, command.arguments,
          cd: command.cwd,
          env: Map.to_list(command.environment),
          stderr_to_stdout: true
        )

      {:ok, %{exit_code: status, output: output, duration_ms: 1}}
    end

    state = %{
      read_request: requests.read,
      mutation_request: requests.mutation,
      analysis_revision_number: 7,
      effect_options: [
        current_provider: fn -> mutation_current end,
        check_catalog: check_catalog,
        check_runner: check_runner
      ]
    }

    {:ok, registry} = ManagedCodingAdapterRegistry.new(state)
    {:ok, journal} = EffectJournal.start_link()

    %{
      root: root,
      execution: execution,
      capability: capability,
      requests: requests,
      mutation_current: mutation_current,
      registry: registry,
      journal: journal
    }
  end

  test "all ordinary tools perform real work through ToolGateway and candidate capture stays local",
       fixture do
    original_path = Path.join(fixture.root, "lib/example.ex")
    original_digest = digest(File.read!(original_path))

    assert completed =
             execute!(
               fixture,
               "search_source",
               %{query: "Example", scope_ref: resource("scope")},
               1
             )

    assert decode(completed)["data"]["total_matches"] == 1

    inspected =
      execute!(
        fixture,
        "inspect_symbol",
        %{symbol: "Example", source_ref: resource("source"), expected_revision: 7},
        2
      )

    assert decode(inspected)["data"]["matches"] != []

    read =
      execute!(
        fixture,
        "read_file",
        %{path: "lib/example.ex", expected_digest: original_digest},
        3
      )

    assert decode(read)["data"]["digest"] == original_digest

    edited =
      execute!(
        fixture,
        "apply_edit",
        %{
          path: "lib/example.ex",
          expected_digest: original_digest,
          old_text: ":old",
          new_text: ":new",
          expected_matches: 1
        },
        4
      )

    assert decode(edited)["outcome"] == "committed"
    assert File.read!(original_path) == source(:new)

    new_path = Path.join(fixture.root, "lib/new.ex")

    created =
      execute!(
        fixture,
        "create_file",
        %{
          path: "lib/new.ex",
          content: "defmodule New do\nend\n",
          expected_parent_digest:
            JidoCode.Integrations.ManagedCodingMutationTools.parent_digest(new_path)
        },
        5
      )

    assert decode(created)["outcome"] == "committed"

    deleted =
      execute!(
        fixture,
        "delete_file",
        %{path: "lib/new.ex", expected_digest: digest(File.read!(new_path))},
        6
      )

    assert decode(deleted)["details"]["candidate_diff"]["operation"] == "delete"
    refute File.exists?(new_path)

    checked = execute!(fixture, "run_registered_check", %{check: "git-diff-check"}, 7)
    assert decode(checked)["status"] == "success"

    diff =
      execute!(
        fixture,
        "show_candidate_diff",
        %{snapshot_ref: fixture.execution.snapshot_iri, max_bytes: 64_000},
        8
      )

    assert decode(diff)["changed_paths"] == ["lib/example.ex"]

    revisions = %{
      toolchain_revision: raw_digest("toolchain"),
      profile_revision: raw_digest("profile")
    }

    assert {:ok, first_candidate} =
             ManagedCodingCandidateTools.capture_candidate(
               fixture.requests.mutation,
               revisions,
               current_provider: fn -> fixture.mutation_current end
             )

    assert {:ok, second_candidate} =
             ManagedCodingCandidateTools.capture_candidate(
               fixture.requests.mutation,
               revisions,
               current_provider: fn -> fixture.mutation_current end
             )

    assert first_candidate == second_candidate
    assert first_candidate.changed_paths == ["lib/example.ex"]

    assert_received {:tool_ledger_start, _authorization, _request}
    assert_received {:tool_ledger_outcome, _start, _result}
  end

  test "the gateway rejects a stale fence before a concrete adapter effect", fixture do
    path = Path.join(fixture.root, "lib/example.ex")

    arguments = %{
      path: "lib/example.ex",
      expected_digest: digest(File.read!(path)),
      old_text: ":old",
      new_text: ":forbidden",
      expected_matches: 1
    }

    {:ok, definition} = Catalog.fetch("apply_edit")
    {:ok, adapter} = ManagedCodingAdapterRegistry.fetch(fixture.registry, definition)
    proposal = proposal!(fixture.execution, "apply_edit", arguments, 99)
    current = gateway_current(fixture.capability, proposal)
    stale = %{current | fencing_token: current.fencing_token + 1}

    assert {:ok, receipt} =
             ToolGateway.execute(
               proposal,
               fixture.capability,
               current,
               gateway_options(fixture, adapter, stale, 99)
             )

    assert receipt.status == :rejected
    refute receipt.effect_dispatched
    assert File.read!(path) == source(:old)
  end

  defp execute!(fixture, name, arguments, sequence) do
    {:ok, definition} = Catalog.fetch(name)
    {:ok, adapter} = ManagedCodingAdapterRegistry.fetch(fixture.registry, definition)
    proposal = proposal!(fixture.execution, name, arguments, sequence)
    current = gateway_current(fixture.capability, proposal)

    assert {:ok, receipt} =
             ToolGateway.execute(
               proposal,
               fixture.capability,
               current,
               gateway_options(fixture, adapter, current, sequence)
             )

    assert receipt.status == :completed
    assert receipt.effect_dispatched
    receipt.result
  end

  defp gateway_options(fixture, adapter, current, sequence) do
    [
      execution_request: fixture.execution,
      sequence: sequence,
      expected_effect: "managed.tool.#{sequence}",
      allowed_effects: ["managed.tool.#{sequence}"],
      ledger: {FakeToolLedger, %{owner: self()}},
      effect_sink: {EffectJournal, fixture.journal},
      current_provider: fn -> current end,
      adapter: adapter
    ]
  end

  defp proposal!(execution, name, arguments, sequence) do
    {:ok, proposal} =
      Proposal.from_directive(resource(:tool_invocation, "#{name}-#{sequence}"), %{
        tool_name: name,
        tool_version: "1.0.0",
        classification: :internal,
        input_refs: [execution.snapshot_iri],
        arguments: arguments
      })

    proposal
  end

  defp gateway_current(capability, proposal) do
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

  defp managed_requests!(root, execution) do
    {:ok, tree} =
      WorkspaceDigest.tree(root, %{file_count: 100, input_bytes: 64_000, disk_bytes: 128_000})

    workspace_iri = resource(:sandbox_instance, "phase-02-workspace")

    {:ok, read} =
      ReadRequest.new(%{
        repository_iri: execution.repository_iri,
        snapshot_iri: execution.snapshot_iri,
        actor_iri: execution.actor_iri,
        workspace_iri: workspace_iri,
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
        workspace_iri: workspace_iri,
        workspace_root: root,
        workspace_digest: tree.digest,
        snapshot_iri: execution.snapshot_iri,
        capability_iri: execution.capability_iri,
        policy_revision: raw_digest("managed-policy"),
        allowed_paths: ["lib"],
        protected_paths: [".git"],
        limits: %{disk_bytes: 128_000, changed_files: 8, diff_bytes: 64_000, output_bytes: 32_000}
      })

    %{read: read, mutation: mutation}
  end

  defp check_catalog! do
    executable = System.find_executable("git")

    {:ok, definition} =
      CheckDefinition.new(%{
        name: "git-diff-check",
        executable: executable,
        arguments: ["diff", "--check"],
        cwd: ".",
        environment: %{"LANG" => "C.UTF-8"},
        toolchain_digest: raw_digest("git-toolchain"),
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
        attempt_iri: resource(:execution_attempt, "phase-02-attempt"),
        lease_iri: resource(:execution_lease, "phase-02-lease"),
        task_iri: resource("phase-02-task"),
        goal_iri: resource("phase-02-goal"),
        plan_iri: resource("phase-02-plan"),
        repository_iri: resource("phase-02-repository"),
        snapshot_iri: resource(:repository_snapshot, "phase-02-snapshot"),
        actor_iri: resource("phase-02-actor"),
        agent_iri: resource("phase-02-agent"),
        capability_iri: resource("phase-02-capability"),
        fencing_token: 202,
        context_digest: raw_digest("context"),
        runtime_version: "managed-coding-phase-02/1",
        constraints: %{}
      })

    request
  end

  defp capability!(execution) do
    graph = resource(:graph_revision_reference, "phase-02-policy")

    {:ok, capability} =
      Capability.new(%{
        attempt_iri: execution.attempt_iri,
        lease_iri: execution.lease_iri,
        task_iri: execution.task_iri,
        repository_iri: execution.repository_iri,
        actor_iri: execution.actor_iri,
        agent_iri: execution.agent_iri,
        profile_iri: resource(:harness_profile, "phase-02-profile"),
        model: "openai:test-model",
        tool_catalog_version: "1.0.0",
        snapshot_iri: execution.snapshot_iri,
        source_graph_revisions: %{graph => 7},
        permitted_tools: ManagedCodingAdapterRegistry.enabled_names(),
        path_prefixes: ["lib"],
        ref_iris: [execution.snapshot_iri, resource("scope"), resource("source")],
        graph_scope_iris: [graph],
        network_destinations: [],
        registered_commands: ["git-diff-check"],
        data_classes: [:internal],
        resource_ceilings: %{output_bytes: 262_144, timeout_ms: 300_000},
        credential_reference_iris: [],
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
        fencing_token: execution.fencing_token,
        idempotency_namespace: "sha256:" <> raw_digest("phase-02-effects"),
        policy_revision: 51,
        revocation_generation: 3,
        authority_classes: [:tool_execution]
      })

    capability
  end

  defp decode(result), do: Jason.decode!(result.stdout)
  defp source(value), do: "defmodule Example do\n  def value, do: #{inspect(value)}\nend\n"
  defp digest(value), do: "sha256:" <> WorkspaceDigest.digest(value)
  defp raw_digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp resource(seed), do: resource(:knowledge_assertion, seed)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "managed-phase-02-#{seed}")
    iri
  end

  defp git!(root, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end
end

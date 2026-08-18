defmodule JidoCode.Factory.Harness.PhaseH06IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Approval.Gateway
  alias JidoCode.Factory.Approval.Request, as: ApprovalRequest
  alias JidoCode.Factory.Publication.Coordinator, as: PublicationCoordinator
  alias JidoCode.Factory.Publication.OutcomeCoordinator
  alias JidoCode.Factory.Publication.Request, as: PublicationRequest
  alias JidoCode.Factory.Verification.Admission
  alias JidoCode.Factory.Verification.FreshCheckout
  alias JidoCode.Factory.Verification.Policy
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.TestSupport.FakeApprovalLedger
  alias JidoCode.TestSupport.FakeApprovedEffect
  alias JidoCode.TestSupport.FakeExternalOutcomeObserver
  alias JidoCode.TestSupport.FakePostChangeVerifier
  alias JidoCode.TestSupport.FakePublicationProvider
  alias JidoCode.TestSupport.GitVerificationWorkspace

  @now ~U[2026-08-18 12:00:00Z]
  @environment String.duplicate("e", 64)

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase-h06-integration-#{System.unique_integer([:positive, :monotonic])}"
      )

    repository = Path.join(root, "repository")
    File.mkdir_p!(Path.join(repository, "lib"))
    File.write!(Path.join(repository, "lib/original.txt"), "base\n")
    git!(repository, ["init", "-b", "main"])
    git!(repository, ["config", "user.name", "Phase H06"])
    git!(repository, ["config", "user.email", "phase-h06@example.invalid"])
    git!(repository, ["add", "."])
    git!(repository, ["commit", "-m", "base"])
    base_commit = git!(repository, ["rev-parse", "HEAD"]) |> String.trim()

    File.write!(Path.join(repository, "lib/original.txt"), "candidate\n")
    File.mkdir_p!(Path.join(repository, "test"))
    File.write!(Path.join(repository, "test/new.txt"), "new candidate test\n")
    File.mkdir_p!(Path.join(repository, "assets"))
    File.write!(Path.join(repository, "assets/blob.bin"), <<0, 1, 2, 255, 0, 128>>)
    git!(repository, ["add", "-A"])
    patch = git!(repository, ["diff", "--cached", "--binary"])
    git!(repository, ["reset", "--hard", "HEAD"])
    git!(repository, ["clean", "-fd"])

    on_exit(fn -> File.rm_rf!(root) end)

    %{root: root, repository: repository, base_commit: base_commit, patch: patch}
  end

  test "candidate-to-outcome chain keeps every authority boundary distinct", fixture do
    admission = admission!(fixture)
    policy = policy!()
    workspace_state = workspace_state(fixture, admission)

    assert {:ok, evidence} =
             FreshCheckout.verify(
               admission,
               policy,
               GitVerificationWorkspace,
               workspace_state,
               verification_options()
             )

    refute evidence.acceptance_authority?
    refute evidence.transition_authority?
    assert Enum.all?(evidence.checks, &(&1.status == :passed))
    assert_receive {:verification_report, report}
    assert report.changed_paths == ["assets/blob.bin", "lib/original.txt", "test/new.txt"]
    assert_receive {:git_verification, :cleanup}

    ledger = start_supervised!(FakeApprovalLedger)
    approval = approval!()

    assert {:ok, approved} = Gateway.execute(approval, approval_options(approval, ledger))
    assert approved.terminal?
    assert approved.consumption_receipt.atomic?

    publication = publication!(approval, approved.consumption_receipt)

    assert {:ok, published} =
             PublicationCoordinator.publish(
               publication,
               publication_current(publication),
               FakePublicationProvider,
               %{owner: self()},
               clock: fn -> @now end
             )

    refute published.merge_authority?
    refute published.attempt_iri == admission.attempt_iri

    assert {:ok, outcome} = final_goal(published)
    assert outcome.goal_satisfied?
    assert outcome.disposition == :accept
  end

  test "verification refuses incomplete provenance and reproduces binary candidates only fresh",
       fixture do
    admission = admission!(fixture)

    incomplete_attributes =
      fixture
      |> admission_attributes()
      |> Map.merge(%{completeness: :incomplete, missing_classes: [:artifact]})
      |> put_in([:finalization_receipt, :completeness], :incomplete)
      |> Map.put(:policy_verifiable_missing_classes, [:artifact])

    assert {:ok, incomplete} = Admission.admit(incomplete_attributes)
    refute Admission.accepting_evidence?(incomplete)

    assert {:error, %{operation: :fresh_checkout_requires_complete_run}} =
             FreshCheckout.verify(
               incomplete,
               policy!(),
               GitVerificationWorkspace,
               workspace_state(fixture, admission),
               verification_options()
             )

    assert {:ok, evidence} =
             FreshCheckout.verify(
               admission,
               policy!(),
               GitVerificationWorkspace,
               workspace_state(fixture, admission),
               verification_options()
             )

    assert evidence.findings == []
  end

  test "approval replay and publication CAS attacks stop before a second external effect" do
    ledger = start_supervised!(FakeApprovalLedger)
    approval = approval!()

    assert {:ok, _outcome} = Gateway.execute(approval, approval_options(approval, ledger))

    assert {:error, %{kind: :conflict, operation: :approval_already_consumed}} =
             Gateway.execute(approval, approval_options(approval, ledger))

    publication = publication!()

    assert {:error, %{kind: :conflict, operation: :provider_compare_and_swap}} =
             PublicationCoordinator.publish(
               publication,
               publication_current(publication),
               FakePublicationProvider,
               %{owner: self(), actual_old_object: object("stale")},
               clock: fn -> @now end
             )

    refute_receive {:publication_provider, :pull_request, _operation}
  end

  test "executor success cannot bypass observation, post-change evidence, or FinalGoal decision" do
    assert {:error, %{operation: :publication_goal_outcome}} =
             OutcomeCoordinator.decide(
               %{status: :completed, goal_satisfied?: true},
               %{},
               FakeExternalOutcomeObserver,
               %{owner: self()},
               FakePostChangeVerifier,
               %{owner: self()},
               []
             )

    published = publication_result()
    bad_observation = %{observation(published) | external_revision: object("wrong")}

    assert {:error, %{operation: :publication_observation_revision}} =
             final_goal(published, observation_result: {:ok, bad_observation})
  end

  defp admission!(fixture), do: fixture |> admission_attributes() |> Admission.admit() |> elem(1)

  defp admission_attributes(fixture) do
    patch_digest = digest(fixture.patch)
    attempt_iri = iri("attempt/candidate")
    {:ok, run_graph} = Knowledge.run_graph_identity(attempt_iri)
    references = %{artifact: [iri("artifact/patch")]}

    %{
      finalization_receipt: %{
        iri: iri("receipt/finalize"),
        command_type: "FinalizeExecutionRun",
        outcome: :committed,
        attempt_iri: attempt_iri,
        run_graph_iri: run_graph,
        run_graph_revision: 7,
        terminal_sequence: 20,
        completeness: :complete,
        accepted_reference_sets: references
      },
      attempt_iri: attempt_iri,
      lease_iri: iri("lease/candidate"),
      fencing_token: 11,
      run_graph_iri: run_graph,
      run_graph_revision: 7,
      terminal_sequence: 20,
      completeness: :complete,
      missing_classes: [],
      accepted_reference_sets: references,
      source_graph_revisions: %{source_graph() => 5},
      control_graph_iri: control_graph(),
      control_graph_revision: 8,
      base_commit: fixture.base_commit,
      base_snapshot_digest: digest(fixture.base_commit),
      candidate_artifacts: [
        %{
          iri: iri("artifact/patch"),
          digest: patch_digest,
          media_type: "application/vnd.git.binary-patch",
          byte_count: byte_size(fixture.patch)
        }
      ],
      patch_digest: patch_digest,
      verification_environment_digest: @environment,
      policy_revision: "verification-policy-1",
      rubric_revision: "rubric-1",
      evaluator_iri: iri("actor/verifier"),
      evaluator_capability_iri: iri("capability/verify"),
      execution_actor_iri: iri("actor/executor"),
      policy_verifiable_missing_classes: []
    }
  end

  defp policy! do
    checks =
      [
        {"format", :formatting},
        {"compile", :compilation},
        {"static", :static_analysis},
        {"types", :type_check},
        {"regression", :regression},
        {"issue", :issue},
        {"hidden", :hidden},
        {"security", :security}
      ]
      |> Enum.map(fn {id, class} ->
        %{
          id: id,
          class: class,
          owner: :verifier,
          mandatory?: true,
          command_digest: command_digest("git", ["diff", "--check", "HEAD"])
        }
      end)
      |> Kernel.++([
        %{
          id: "candidate-test",
          class: :candidate_test,
          owner: :candidate,
          mandatory?: false,
          command_digest: command_digest("test", ["-f", "test/new.txt"]),
          requirement_iri: iri("requirement/new-test")
        }
      ])

    {:ok, policy} =
      Policy.new(%{
        revision: "verification-policy-1",
        allowed_path_prefixes: ["assets", "lib", "test"],
        protected_path_prefixes: ["test/protected"],
        max_patch_bytes: 1_000_000,
        evaluator_capability_iri: iri("capability/verify"),
        required_check_classes: [
          :formatting,
          :compilation,
          :static_analysis,
          :type_check,
          :regression,
          :issue,
          :hidden,
          :security
        ],
        checks: checks,
        flake_policy: %{eligible_statuses: [:failed, :timeout], max_reruns: 0}
      })

    policy
  end

  defp workspace_state(fixture, admission) do
    independent =
      Map.new(
        ["format", "compile", "static", "types", "regression", "issue", "hidden", "security"],
        &{&1, {"git", ["diff", "--check", "HEAD"]}}
      )

    %{
      owner: self(),
      root: fixture.root,
      repository: fixture.repository,
      artifacts: %{admission.patch_digest => fixture.patch},
      commands: Map.put(independent, "candidate-test", {"test", ["-f", "test/new.txt"]})
    }
  end

  defp verification_options do
    [
      environment_digest: @environment,
      evidence_command: fn report ->
        send(self(), {:verification_report, report})
        {:ok, command("RecordVerificationEvidence", "1.7.0", "fresh-evidence")}
      end
    ]
  end

  defp approval! do
    {:ok, request} =
      ApprovalRequest.new(%{
        action: "open_pull_request",
        arguments: %{branch: "agent/phase-06"},
        attempt_iri: iri("attempt/publication"),
        invocation_iri: iri("invocation/publication"),
        lease_iri: iri("lease/publication"),
        fencing_token: 17,
        base_revision: object("old"),
        patch_digest: digest("patch"),
        artifact_digests: [digest("patch")],
        tool_version: "provider-adapter-1",
        model_version: "model-profile-1",
        sandbox_version: "sandbox-2",
        policy_revision: "publication-policy-1",
        context_version: "context-1",
        capability_iri: iri("capability/publish"),
        external_destination: %{provider: "github", repository: "agentjido/jido_code"},
        egress: %{digest: digest("egress"), byte_count: 1024, classification: :internal},
        evidence_iris: [iri("evidence/fresh")],
        reversibility: :compensating,
        approver_iri: iri("actor/approver"),
        delegated_scope_iri: iri("scope/repository"),
        execution_actor_iri: iri("actor/executor"),
        separation_required?: true,
        approver_authorization_revision: 3,
        approver_revocation_generation: 1,
        idempotency: :proven,
        idempotency_key_digest: digest("publication-invocation"),
        expires_at: DateTime.add(@now, 300, :second)
      })

    request
  end

  defp approval_options(request, ledger) do
    current = %{
      approval_iri: ApprovalRequest.approval_iri(request),
      approval_state: :approved,
      approver_iri: request.approver_iri,
      approver_authorized?: true,
      approver_revocation_generation: request.approver_revocation_generation,
      approver_authorization_revision: request.approver_authorization_revision,
      delegated_scope_iri: request.delegated_scope_iri,
      policy_revision: request.policy_revision,
      base_revision: request.base_revision,
      patch_digest: request.patch_digest,
      tool_version: request.tool_version,
      model_version: request.model_version,
      sandbox_version: request.sandbox_version,
      context_version: request.context_version,
      capability_iri: request.capability_iri,
      attempt_iri: request.attempt_iri,
      invocation_iri: request.invocation_iri,
      lease_iri: request.lease_iri,
      lease_state: :active,
      lease_expires_at: DateTime.add(@now, 600, :second),
      fencing_token: request.fencing_token,
      destination_digest: request.destination_digest,
      artifact_digests: request.artifact_digests,
      artifacts_available?: true,
      evidence_iris: request.evidence_iris
    }

    [
      ledger: {FakeApprovalLedger, ledger},
      effect: {FakeApprovedEffect, %{owner: self()}},
      current_provider: fn -> current end,
      clock: fn -> @now end,
      observed_at: @now,
      owner: self()
    ]
  end

  defp publication!(approval \\ nil, consumption \\ nil) do
    attempt = iri("attempt/publication")
    {:ok, run_graph} = Knowledge.run_graph_identity(attempt)

    {:ok, request} =
      PublicationRequest.new(%{
        operation: :open_pull_request,
        task_iri: iri("task/publication"),
        attempt_iri: attempt,
        run_graph_iri: run_graph,
        eligibility_iri: iri("eligibility/publication"),
        authorization_iri: iri("authorization/publication"),
        lease_iri: iri("lease/publication"),
        fencing_token: 17,
        capability_iri: iri("capability/publish"),
        candidate_task_iri: iri("task/candidate"),
        candidate_attempt_iri: iri("attempt/candidate"),
        repository_iri: iri("repository/1"),
        credential_reference_iri: iri("credential/provider"),
        requested_credential_scope: :repository_write,
        approval_iri:
          if(approval, do: ApprovalRequest.approval_iri(approval), else: iri("approval/1")),
        approval_consumption_iri:
          if(consumption, do: consumption.consumption_iri, else: iri("approval-consumption/1")),
        base_branch: "main",
        bot_branch: "agent/phase-06",
        expected_old_object: object("old"),
        candidate_object: object("candidate"),
        patch_digest: digest("patch"),
        evidence_iris: [iri("evidence/fresh")],
        policy_revision: "publication-policy-1"
      })

    request
  end

  defp publication_current(request) do
    %{
      task_iri: request.task_iri,
      attempt_iri: request.attempt_iri,
      run_graph_iri: request.run_graph_iri,
      run_graph_state: :open,
      eligibility_iri: request.eligibility_iri,
      eligibility_state: :eligible,
      authorization_iri: request.authorization_iri,
      authorization_state: :authorized,
      lease_iri: request.lease_iri,
      lease_state: :active,
      lease_expires_at: DateTime.add(@now, 600, :second),
      fencing_token: request.fencing_token,
      capability_iri: request.capability_iri,
      approval_iri: request.approval_iri,
      approval_consumption_iri: request.approval_consumption_iri,
      approval_state: :consumed,
      policy_revision: request.policy_revision,
      bot_branch: request.bot_branch,
      base_branch: request.base_branch,
      observed_old_object: request.expected_old_object
    }
  end

  defp final_goal(publication, overrides \\ []) do
    observation = Keyword.get(overrides, :observation_result, {:ok, observation(publication)})
    verification = {:ok, post_change_verification(publication)}

    OutcomeCoordinator.decide(
      publication,
      %{goal_iri: iri("goal/1")},
      FakeExternalOutcomeObserver,
      %{owner: self()},
      FakePostChangeVerifier,
      %{owner: self()},
      observation_result: observation,
      verification_result: verification,
      decision_builder: fn _publication, observation, verification, _input ->
        {:ok,
         %{
           disposition: :accept,
           outcome_stage: :final_goal,
           actor_iri: iri("actor/decider"),
           execution_actor_iri: verification.execution_actor_iri,
           evaluator_iri: verification.evaluator_iri,
           evidence_iris: verification.evidence_iris,
           confirmation_iris: [observation.confirmation_iri],
           requested_effects: [],
           decision_command: command("DecideGoalOutcome", "1.7.0", "final-goal")
         }}
      end,
      command_executor: fn command ->
        {:ok, %{outcome: :committed, command_iri: command.command_iri}}
      end
    )
  end

  defp observation(publication) do
    %{
      publication_attempt_iri: publication.attempt_iri,
      external_pull_request_id: publication.external_pull_request_id,
      external_revision: publication.new_object,
      provider_event_id: "event-integration",
      confirmation_iri: iri("confirmation/provider-event"),
      confirmation_graph_iri: observation_graph(),
      confirmation_graph_revision: 4,
      observation_command: command("RecordObservationBatch", "1.1.0", "observation")
    }
  end

  defp post_change_verification(publication) do
    %{
      publication_attempt_iri: publication.attempt_iri,
      external_revision: publication.new_object,
      post_change_snapshot_iri: iri("snapshot/post-change"),
      evaluator_iri: iri("actor/post-change-verifier"),
      execution_actor_iri: iri("actor/executor"),
      evidence_iris: [iri("evidence/post-change")],
      evidence_command: command("RecordVerificationEvidence", "1.7.0", "post-change")
    }
  end

  defp publication_result do
    %JidoCode.Factory.Publication.Result{
      attempt_iri: iri("attempt/publication"),
      run_graph_iri: "https://jido.run/graph/run/" <> String.duplicate("a", 32),
      base_branch: "main",
      bot_branch: "agent/phase-06",
      old_object: object("old"),
      new_object: object("candidate"),
      external_branch_id: "branch:agent/phase-06",
      external_pull_request_id: "pr:42",
      provider_revision: "provider-revision-9",
      credential_scope: :repository_write,
      merge_authority?: false,
      terminal?: true
    }
  end

  defp command(type, version, suffix) do
    struct!(CommandEnvelope,
      command_type: type,
      command_version: version,
      command_iri: iri("command/#{suffix}"),
      principal_iri: iri("actor/principal"),
      actor_iri: iri("actor/service"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      scope_iri: iri("scope/repository"),
      idempotency_key: suffix,
      correlation_iri: iri("correlation/1"),
      causation_iri: iri("causation/1"),
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: 1,
      expected_graph_revisions: %{},
      reason: suffix,
      issued_at: @now,
      payload: %{changes: [], guards: []}
    )
  end

  defp git!(repository, arguments) do
    case System.cmd("git", ["-C", repository | arguments], stderr_to_stdout: true) do
      {output, 0} -> output
      {output, status} -> flunk("git failed (#{status}): #{output}")
    end
  end

  defp command_digest(executable, arguments), do: digest({executable, arguments})

  defp digest(material) when is_binary(material),
    do: :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)

  defp digest(material),
    do: material |> :erlang.term_to_binary([:deterministic]) |> digest()

  defp object(material), do: :crypto.hash(:sha, material) |> Base.encode16(case: :lower)
  defp iri(path), do: "https://jido.run/id/phase-h06/#{path}"

  defp source_graph do
    "https://jido.run/graph/repo/" <>
      String.duplicate("b", 32) <> "/source/" <> String.duplicate("c", 32)
  end

  defp control_graph,
    do: "https://jido.run/graph/repo/" <> String.duplicate("b", 32) <> "/control"

  defp observation_graph do
    "https://jido.run/graph/repo/" <>
      String.duplicate("b", 32) <> "/observation/" <> String.duplicate("d", 32)
  end
end

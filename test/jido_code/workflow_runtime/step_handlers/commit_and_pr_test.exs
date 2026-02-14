defmodule JidoCode.WorkflowRuntime.StepHandlers.CommitAndPRTest do
  use ExUnit.Case, async: true

  alias JidoCode.WorkflowRuntime.StepHandlers.CommitAndPR

  test "execute derives deterministic branch names and persists workspace cleanliness policy checks" do
    branch_setup_calls = start_supervised!({Agent, fn -> [] end})

    branch_setup_runner = fn branch_context ->
      Agent.update(branch_setup_calls, fn calls -> [branch_context | calls] end)
      {:ok, %{status: "created", branch_name: branch_context.branch_name}}
    end

    args = %{
      workflow_name: "Implement Task",
      run_id: "RUN-12345",
      environment_mode: "cloud",
      workspace_status: "clean"
    }

    {:ok, first_result} =
      CommitAndPR.execute(nil, args, branch_setup_runner: branch_setup_runner)

    {:ok, second_result} =
      CommitAndPR.execute(nil, args, branch_setup_runner: branch_setup_runner)

    assert first_result.run_artifacts.branch_name == "jidocode/implement-task/run-12345"
    assert second_result.run_artifacts.branch_name == first_result.run_artifacts.branch_name

    assert %{
             pattern: "jidocode/<workflow>/<short-run-id>",
             workflow_name: "Implement Task",
             workflow_segment: "implement-task",
             run_id: "RUN-12345",
             short_run_id: "run-12345",
             short_run_id_strategy: "slug"
           } = first_result.run_artifacts.branch_derivation

    assert %{
             id: "workspace_cleanliness",
             name: "Workspace cleanliness policy check",
             status: "passed",
             policy_mode: "clean_room",
             required_state: "clean",
             observed_state: "clean",
             environment_mode: "cloud"
           } = first_result.run_artifacts.policy_checks.workspace_cleanliness

    assert %{
             workflow_name: "Implement Task",
             run_id: "RUN-12345",
             branch_name: "jidocode/implement-task/run-12345",
             environment_mode: "cloud"
           } = first_result.run_artifacts.policy_checks.workspace_cleanliness.run_metadata

    assert %{
             step: "CommitAndPR",
             stage: "pre_ship_workspace_policy",
             operation: "validate_workspace_cleanliness"
           } = first_result.run_artifacts.policy_checks.workspace_cleanliness.step_metadata

    assert first_result.shipping_flow.completed_stage == "workspace_policy_check"
    assert first_result.shipping_flow.next_stage == "commit_changes"

    recorded_calls = branch_setup_calls |> Agent.get(&Enum.reverse(&1))

    assert 2 == length(recorded_calls)

    assert Enum.all?(recorded_calls, fn call ->
             call.branch_name == "jidocode/implement-task/run-12345"
           end)
  end

  test "long run ids with matching prefixes derive disambiguated short run ids" do
    branch_setup_runner = fn _branch_context -> :ok end

    run_id_alpha = "run-with-a-very-very-very-long-identifier-alpha"
    run_id_beta = "run-with-a-very-very-very-long-identifier-beta"

    {:ok, alpha_result} =
      CommitAndPR.execute(
        nil,
        %{
          workflow_name: "fix_failing_tests",
          run_id: run_id_alpha,
          environment_mode: :local,
          workspace_clean: true
        },
        branch_setup_runner: branch_setup_runner
      )

    {:ok, beta_result} =
      CommitAndPR.execute(
        nil,
        %{
          workflow_name: "fix_failing_tests",
          run_id: run_id_beta,
          environment_mode: :local,
          workspace_clean: true
        },
        branch_setup_runner: branch_setup_runner
      )

    {:ok, alpha_repeat_result} =
      CommitAndPR.execute(
        nil,
        %{
          workflow_name: "fix_failing_tests",
          run_id: run_id_alpha,
          environment_mode: :local,
          workspace_clean: true
        },
        branch_setup_runner: branch_setup_runner
      )

    alpha_short_id = alpha_result.run_artifacts.branch_derivation.short_run_id
    beta_short_id = beta_result.run_artifacts.branch_derivation.short_run_id

    assert alpha_short_id != beta_short_id
    assert alpha_short_id == alpha_repeat_result.run_artifacts.branch_derivation.short_run_id

    assert String.length(alpha_short_id) <= 24
    assert String.length(beta_short_id) <= 24
    assert Regex.match?(~r/-[0-9a-f]{8}$/, alpha_short_id)
    assert Regex.match?(~r/-[0-9a-f]{8}$/, beta_short_id)

    assert alpha_result.run_artifacts.branch_name ==
             "jidocode/fix-failing-tests/#{alpha_short_id}"

    assert beta_result.run_artifacts.branch_name == "jidocode/fix-failing-tests/#{beta_short_id}"

    assert alpha_result.run_artifacts.policy_checks.workspace_cleanliness.environment_mode == "local"
    assert alpha_result.run_artifacts.policy_checks.workspace_cleanliness.status == "passed"
  end

  test "branch setup failure halts shipping before commit probe with typed branch setup error" do
    commit_probe_calls = start_supervised!({Agent, fn -> 0 end})

    commit_probe = fn _branch_context ->
      Agent.update(commit_probe_calls, &(&1 + 1))
    end

    assert {:error, typed_error} =
             CommitAndPR.execute(
               nil,
               %{workflow_name: "implement_task", run_id: "run-failure-42"},
               branch_setup_runner: fn _branch_context ->
                 {:error, :branch_permissions_missing}
               end,
               commit_probe: commit_probe
             )

    assert typed_error.error_type == "workflow_commit_and_pr_branch_setup_failed"
    assert typed_error.operation == "setup_run_branch"
    assert typed_error.reason_type == "branch_setup_failed"
    assert typed_error.blocked_stage == "commit_changes"
    assert typed_error.halted_before_commit == true
    assert typed_error.branch_name == "jidocode/implement-task/run-failure-42"

    assert %{
             pattern: "jidocode/<workflow>/<short-run-id>",
             workflow_name: "implement_task",
             workflow_segment: "implement-task",
             run_id: "run-failure-42",
             short_run_id: "run-failure-42"
           } = typed_error.branch_derivation

    assert Agent.get(commit_probe_calls, & &1) == 0
  end

  test "dirty workspace blocks shipping actions with remediation guidance" do
    commit_probe_calls = start_supervised!({Agent, fn -> 0 end})

    commit_probe = fn _branch_context ->
      Agent.update(commit_probe_calls, &(&1 + 1))
    end

    assert {:error, typed_error} =
             CommitAndPR.execute(
               nil,
               %{
                 workflow_name: "implement_task",
                 run_id: "run-dirty-88",
                 environment_mode: :local,
                 workspace_status: "dirty"
               },
               branch_setup_runner: fn _branch_context -> :ok end,
               commit_probe: commit_probe
             )

    assert typed_error.error_type == "workflow_commit_and_pr_workspace_policy_failed"
    assert typed_error.operation == "validate_workspace_cleanliness"
    assert typed_error.reason_type == "workspace_dirty"
    assert typed_error.blocked_stage == "commit_changes"
    assert typed_error.blocked_actions == ["commit", "push", "create_pr"]
    assert typed_error.halted_before_commit == true
    assert typed_error.halted_before_push == true
    assert typed_error.halted_before_pr == true
    assert typed_error.remediation =~ "Clean or discard unintended workspace changes"

    assert %{
             id: "workspace_cleanliness",
             status: "failed",
             policy_mode: "clean_room",
             required_state: "clean",
             observed_state: "dirty",
             environment_mode: "local"
           } = typed_error.policy_check

    assert %{
             workflow_name: "implement_task",
             run_id: "run-dirty-88",
             branch_name: "jidocode/implement-task/run-dirty-88",
             environment_mode: "local"
           } = typed_error.policy_check.run_metadata

    assert %{
             step: "CommitAndPR",
             stage: "pre_ship_workspace_policy",
             operation: "validate_workspace_cleanliness"
           } = typed_error.policy_check.step_metadata

    assert Agent.get(commit_probe_calls, & &1) == 0
  end
end

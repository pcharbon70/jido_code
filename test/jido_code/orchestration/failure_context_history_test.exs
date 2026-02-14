defmodule JidoCode.Orchestration.FailureContextHistoryTest do
  use JidoCode.DataCase, async: false

  alias JidoCode.Orchestration.{FailureContextHistory, WorkflowRun}
  alias JidoCode.Projects.Project

  setup do
    original_loader =
      Application.get_env(:jido_code, :dashboard_failure_history_loader, :__missing__)

    on_exit(fn ->
      restore_env(:dashboard_failure_history_loader, original_loader)
    end)

    :ok
  end

  test "returns failure history fields and supports time-window filtering" do
    {:ok, project} = create_project("owner/repo-failure-history")

    {:ok, _outside_window_run} =
      create_failed_run(
        project.id,
        "failure-history-outside-window",
        ~U[2026-01-10 10:00:00Z],
        ~U[2026-01-10 10:03:00Z],
        %{
          "error_type" => "workflow_step_failed",
          "reason_type" => "verification_failed",
          "detail" => "Older failure should not match the selected trend slice.",
          "remediation" => "Inspect failing tests and retry.",
          "last_successful_step" => "plan_changes"
        }
      )

    {:ok, _successful_run} =
      create_completed_run(
        project.id,
        "failure-history-completed",
        ~U[2026-02-15 11:00:00Z],
        ~U[2026-02-15 11:03:00Z]
      )

    {:ok, _in_window_run} =
      create_failed_run(
        project.id,
        "failure-history-in-window",
        ~U[2026-02-15 12:00:00Z],
        ~U[2026-02-15 12:03:00Z],
        %{
          "error_type" => "workflow_step_failed",
          "reason_type" => "verification_failed",
          "detail" => "Verification failed while running the test suite.",
          "remediation" => "Inspect failing tests, patch, then retry from run detail.",
          "last_successful_step" => "plan_changes"
        }
      )

    assert {:ok, failure_history} =
             FailureContextHistory.query(%{
               window_start: ~U[2026-02-15 00:00:00Z],
               window_end: ~U[2026-02-15 23:59:59Z]
             })

    assert [
             %{
               run_id: "failure-history-in-window",
               error_type: "workflow_step_failed",
               last_successful_step: "plan_changes",
               remediation_hint: remediation_hint
             }
           ] = failure_history

    assert remediation_hint =~ "retry from run detail"
  end

  test "invalid query parameters return typed validation error with no partial results" do
    loader_invocations = start_supervised!({Agent, fn -> 0 end}, id: make_ref())

    Application.put_env(:jido_code, :dashboard_failure_history_loader, fn _query_params ->
      Agent.update(loader_invocations, &(&1 + 1))

      {:ok,
       [
         %{
           run_id: "unexpected-run",
           project_id: "unexpected-project",
           workflow_name: "implement_task",
           failed_at: ~U[2026-02-15 13:00:00Z],
           error_type: "unexpected_error",
           last_successful_step: "plan_changes",
           remediation_hint: "unexpected remediation"
         }
       ]}
    end)

    assert {:error, typed_error} =
             FailureContextHistory.query(%{
               window_start: "not-a-datetime",
               window_end: "2026-02-15T23:59:59Z"
             })

    assert typed_error.error_type == "dashboard_failure_history_query_validation_failed"
    assert typed_error.operation == "query_failure_context_history"
    assert typed_error.reason_type == "invalid_query_parameters"
    assert typed_error.partial_results == []

    assert Enum.any?(typed_error.field_errors, fn field_error ->
             field_error.field == "window_start" and
               field_error.error_type == "invalid_datetime"
           end)

    assert Agent.get(loader_invocations, & &1) == 0
  end

  defp create_project(github_full_name) do
    Project.create(%{
      name: github_full_name,
      github_full_name: github_full_name,
      default_branch: "main",
      settings: %{}
    })
  end

  defp create_failed_run(project_id, run_id, started_at, failed_at, failure_context) do
    {:ok, run} =
      WorkflowRun.create(%{
        project_id: project_id,
        run_id: run_id,
        workflow_name: "implement_task",
        workflow_version: 1,
        trigger: %{source: "workflows", mode: "manual"},
        inputs: %{"task_summary" => "Capture failure history query record"},
        input_metadata: %{"task_summary" => %{required: true, source: "manual_workflows_ui"}},
        initiating_actor: %{id: "owner-1", email: "owner@example.com"},
        current_step: "queued",
        started_at: started_at
      })

    {:ok, run} =
      WorkflowRun.transition_status(run, %{
        to_status: :running,
        current_step: "run_tests",
        transitioned_at: DateTime.add(started_at, 60, :second)
      })

    WorkflowRun.transition_status(run, %{
      to_status: :failed,
      current_step: "run_tests",
      transitioned_at: failed_at,
      transition_metadata: %{"failure_context" => failure_context}
    })
  end

  defp create_completed_run(project_id, run_id, started_at, completed_at) do
    {:ok, run} =
      WorkflowRun.create(%{
        project_id: project_id,
        run_id: run_id,
        workflow_name: "implement_task",
        workflow_version: 1,
        trigger: %{source: "workflows", mode: "manual"},
        inputs: %{
          "task_summary" => "Ensure completed runs are excluded from failure history query"
        },
        input_metadata: %{"task_summary" => %{required: true, source: "manual_workflows_ui"}},
        initiating_actor: %{id: "owner-1", email: "owner@example.com"},
        current_step: "queued",
        started_at: started_at
      })

    {:ok, run} =
      WorkflowRun.transition_status(run, %{
        to_status: :running,
        current_step: "plan_changes",
        transitioned_at: DateTime.add(started_at, 60, :second)
      })

    WorkflowRun.transition_status(run, %{
      to_status: :completed,
      current_step: "publish_pr",
      transitioned_at: completed_at
    })
  end

  defp restore_env(key, :__missing__), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
end

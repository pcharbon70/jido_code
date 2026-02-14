defmodule JidoCode.Setup.WebhookSimulationChecksTest do
  use ExUnit.Case, async: true

  alias JidoCode.Setup.WebhookSimulationChecks

  @checked_at ~U[2026-02-13 12:34:56Z]

  setup do
    original_checker =
      Application.get_env(:jido_code, :setup_webhook_simulation_checker, :__missing__)

    original_events = Application.get_env(:jido_code, :issue_bot_webhook_events, :__missing__)
    original_secret = Application.get_env(:jido_code, :github_webhook_secret, :__missing__)

    on_exit(fn ->
      restore_env(:setup_webhook_simulation_checker, original_checker)
      restore_env(:issue_bot_webhook_events, original_events)
      restore_env(:github_webhook_secret, original_secret)
    end)

    :ok
  end

  test "run/1 allows progression when signature and routing readiness checks pass" do
    Application.put_env(:jido_code, :setup_webhook_simulation_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :ready,
        signature: %{
          status: :ready,
          detail: "Signature verification is ready for webhook simulation.",
          remediation: "Signature readiness confirmed.",
          checked_at: @checked_at
        },
        events: [
          %{
            event: "issues.opened",
            route: "Issue Bot triage workflow",
            status: :ready,
            detail: "Routing is ready for `issues.opened`.",
            remediation: "Routing readiness confirmed.",
            checked_at: @checked_at
          },
          %{
            event: "issues.edited",
            route: "Issue Bot re-triage workflow",
            status: :ready,
            detail: "Routing is ready for `issues.edited`.",
            remediation: "Routing readiness confirmed.",
            checked_at: @checked_at
          }
        ],
        issue_bot_defaults: %{"enabled" => true, "approval_mode" => "manual"}
      }
    end)

    report = WebhookSimulationChecks.run(nil)

    refute WebhookSimulationChecks.blocked?(report)
    assert is_nil(WebhookSimulationChecks.failure_reason(report))
    assert WebhookSimulationChecks.issue_bot_defaults(report) == %{"enabled" => true, "approval_mode" => "manual"}
    assert report.signature.transition == "Failed -> Ready"
    assert Enum.all?(report.events, fn event_result -> event_result.status == :ready end)
  end

  test "run/1 blocks progression when simulation fails and retains failure reason" do
    Application.put_env(:jido_code, :setup_webhook_simulation_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :blocked,
        signature: %{
          status: :failed,
          detail: "Webhook secret is missing for signature verification.",
          remediation: "Configure `GITHUB_WEBHOOK_SECRET` and retry webhook simulation.",
          checked_at: @checked_at
        },
        events: [
          %{
            event: "issues.opened",
            route: "Issue Bot triage workflow",
            status: :ready,
            detail: "Routing is ready for `issues.opened`.",
            remediation: "Routing readiness confirmed.",
            checked_at: @checked_at
          },
          %{
            event: "issue_comment.created",
            route: "Issue Bot follow-up context workflow",
            status: :failed,
            detail: "Routing for `issue_comment.created` is not configured.",
            remediation: "Configure Issue Bot routing and retry simulation.",
            checked_at: @checked_at
          }
        ],
        failure_reason: "Webhook secret is missing for signature verification.",
        issue_bot_defaults: %{"enabled" => true, "approval_mode" => "manual"}
      }
    end)

    report = WebhookSimulationChecks.run(nil)

    assert WebhookSimulationChecks.blocked?(report)

    assert WebhookSimulationChecks.failure_reason(report) ==
             "Webhook secret is missing for signature verification."

    assert WebhookSimulationChecks.issue_bot_defaults(report) == %{}
  end

  test "serialize_for_state/1 and from_state/1 preserve simulation readiness output" do
    Application.put_env(:jido_code, :setup_webhook_simulation_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :ready,
        signature: %{
          status: :ready,
          detail: "Signature verification is ready for webhook simulation.",
          remediation: "Signature readiness confirmed.",
          checked_at: @checked_at
        },
        events: [
          %{
            event: "issues.opened",
            route: "Issue Bot triage workflow",
            status: :ready,
            detail: "Routing is ready for `issues.opened`.",
            remediation: "Routing readiness confirmed.",
            checked_at: @checked_at
          }
        ],
        issue_bot_defaults: %{"enabled" => true, "approval_mode" => "manual"}
      }
    end)

    report = WebhookSimulationChecks.run(nil)
    serialized = WebhookSimulationChecks.serialize_for_state(report)
    restored = WebhookSimulationChecks.from_state(serialized)

    assert serialized["status"] == "ready"
    assert serialized["issue_bot_defaults"]["enabled"] == true
    assert restored.status == :ready
    assert restored.signature.status == :ready
    assert Enum.map(restored.events, fn event_result -> event_result.event end) == ["issues.opened"]
  end

  defp restore_env(key, :__missing__), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
end

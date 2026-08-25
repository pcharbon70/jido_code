defmodule JidoCode.Factory.ManagedCodingRolloutGovernanceTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.RolloutGovernance

  test "pins accountable ownership, review, alerting, escalation, and retention" do
    state = governance()
    assert state.owner_actor_iris == [iri("owner")]
    assert state.approver_actor_iris == [iri("approver")]
    assert state.on_call_actor_iris == [iri("on-call")]
    assert state.review_cadence_hours == 24
    assert state.evidence_retention_days == 365
  end

  test "blocks new effects at every scope while preserving recovery and cancellation" do
    scopes = [:global, :tenant, :repository, :provider, :adapter, :tool, :profile]

    Enum.each(scopes, fn scope ->
      state = governance()
      target = if scope == :global, do: :all, else: iri("#{scope}-target")

      assert {:ok, disabled} =
               RolloutGovernance.disable(state, %{
                 scope: scope,
                 target: target,
                 actor_iri: iri("on-call"),
                 reason: "emergency stop",
                 disabled_at: ~U[2026-08-25 12:00:00Z]
               })

      context = if scope == :global, do: %{}, else: %{scope => target}
      refute RolloutGovernance.effect_allowed?(disabled, context)
      [record] = disabled.disabled
      assert record.recovery_allowed
      assert record.cancellation_allowed
      assert record.evidence_preserved
    end)
  end

  test "records complete incident drills before safe reenable" do
    state = governance()

    assert {:ok, state} =
             RolloutGovernance.incident(state, %{
               incident_iri: iri("incident"),
               actor_iri: iri("owner"),
               triage: true,
               cancellation_drain: true,
               credential_revocation: true,
               evidence_preservation: true,
               tenant_notification: true,
               candidate_quarantine: true,
               rollback: true,
               safe_reenable: true,
               status: :resolved
             })

    assert hd(state.incidents).safe_reenable
  end

  test "requires an independent predeclared release decision and retains disabled authority" do
    state = governance()
    attributes = decision(:accept)
    assert {:ok, record, _state} = RolloutGovernance.decide(state, attributes)
    refute record.automatic_approval
    refute record.automatic_merge
    refute record.general_multi_agent

    assert {:error, %AdapterError{kind: :unauthorized}} =
             RolloutGovernance.decide(state, %{
               attributes
               | unresolved_findings: ["open incident"]
             })

    assert {:error, %AdapterError{kind: :unauthorized}} =
             RolloutGovernance.decide(state, %{attributes | actor_iri: iri("runtime")})
  end

  defp governance do
    {:ok, state} =
      RolloutGovernance.new(%{
        owner_actor_iris: [iri("owner")],
        approver_actor_iris: [iri("approver")],
        on_call_actor_iris: [iri("on-call")],
        dashboard_iris: [iri("dashboard")],
        alert_route_iris: [iri("alert-route")],
        review_cadence_hours: 24,
        escalation_policy_revision: "managed-rollout-escalation-v1",
        evidence_retention_days: 365
      })

    state
  end

  defp decision(decision) do
    %{
      decision: decision,
      actor_iri: iri("approver"),
      runtime_actor_iri: iri("runtime"),
      verifier_actor_iri: iri("verifier"),
      independent: true,
      evidence_bundle_iri: iri("release-evidence"),
      thresholds_passed: true,
      unresolved_findings: [],
      drills_passed: true,
      restrictions: [],
      decided_at: ~U[2026-08-25 12:00:00Z]
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

defmodule JidoCode.Factory.ManagedCodingShadowRolloutTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.ShadowRollout

  @digest String.duplicate("a", 64)

  test "samples only eligible traffic and grants no live or publication authority" do
    state = rollout()
    request = request()
    assert {:ok, attempt, state} = ShadowRollout.admit(state, request, ~U[2026-08-26 12:00:00Z])
    assert attempt.mode == :shadow
    refute attempt.push_authority
    refute attempt.pull_request_authority
    refute attempt.task_state_authority
    refute attempt.active_implementation_influence
    refute attempt.publication_authority
    assert attempt.controls == state.controls

    denied = %{request | tenant_iri: iri("other-tenant")}

    assert {:error, %AdapterError{kind: :unauthorized}, _state} =
             ShadowRollout.admit(state, denied, ~U[2026-08-26 12:00:00Z])
  end

  test "compares delayed blinded outcomes without feeding the active attempt" do
    state = admitted_rollout()
    assert {:ok, state} = ShadowRollout.observe(state, observation())
    assert state.status == :open
    summary = ShadowRollout.summary(state)
    assert summary.cohorts["small-elixir"].latency_ms == 500.0

    unblinded = %{observation() | blinded: false}
    assert {:error, %AdapterError{}} = ShadowRollout.observe(state, unblinded)
  end

  test "automatically stops admission for explicit safety faults and aggregate thresholds" do
    state = admitted_rollout()

    assert {:ok, stopped} =
             ShadowRollout.observe(state, %{observation() | signals: [:profile_drift]})

    assert stopped.status == :stopped
    assert :profile_drift in stopped.stop_reasons

    assert {:error, %AdapterError{kind: :unavailable}, _state} =
             ShadowRollout.admit(stopped, request("second"), ~U[2026-08-26 12:00:00Z])

    high_cost = put_in(observation(), [:metrics, :cost_microunits], 20_000)
    assert {:ok, threshold_stopped} = ShadowRollout.observe(admitted_rollout(), high_cost)
    assert {:threshold_breach, :cost_microunits} in threshold_stopped.stop_reasons
  end

  defp admitted_rollout do
    state = rollout()
    {:ok, _attempt, state} = ShadowRollout.admit(state, request(), ~U[2026-08-26 12:00:00Z])
    state
  end

  defp rollout do
    attributes = %{
      profile_digest: @digest,
      tenant_iris: [iri("tenant")],
      repository_iris: [iri("repository")],
      task_classes: ["defect_repair"],
      sample_percent: 100,
      window_start: ~U[2026-08-26 00:00:00Z],
      window_end: ~U[2026-09-02 00:00:00Z],
      controls: %{
        data_classification: @digest,
        credential_policy: @digest,
        rate_limit: @digest,
        isolation: @digest,
        retention: @digest,
        redaction: @digest,
        cost_accounting: @digest
      },
      thresholds: %{
        failure: 0.2,
        abstention: 0.5,
        clarification: 0.5,
        capacity: 0.8,
        cost_microunits: 10_000,
        latency_ms: 2_000,
        recovery: 0.5,
        security_event: 0
      }
    }

    {:ok, state} = ShadowRollout.new(attributes)
    state
  end

  defp request(suffix \\ "attempt") do
    %{
      attempt_iri: iri(suffix),
      tenant_iri: iri("tenant"),
      repository_iri: iri("repository"),
      task_iri: iri("task-#{suffix}"),
      task_class: "defect_repair",
      profile_digest: @digest,
      cohort: "small-elixir"
    }
  end

  defp observation do
    %{
      attempt_iri: iri("attempt"),
      profile_digest: @digest,
      cohort: "small-elixir",
      outcome_observed_at: ~U[2026-08-27 12:00:00Z],
      scored_at: ~U[2026-08-28 12:00:00Z],
      blinded: true,
      feedback_to_attempt: false,
      metrics: %{
        failure: 0,
        abstention: 0,
        clarification: 0,
        capacity: 0.4,
        cost_microunits: 5_000,
        latency_ms: 500,
        recovery: 0,
        security_event: 0
      },
      signals: []
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

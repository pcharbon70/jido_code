defmodule JidoCode.Factory.ManagedCodingEffectReconciliationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.EffectIntent
  alias JidoCode.Factory.ManagedCoding.EffectPolicy
  alias JidoCode.Factory.ManagedCoding.EffectReconciler
  alias JidoCode.Factory.ManagedCoding.RetryPolicy
  alias JidoCode.TestSupport.FakeManagedCodingEffectAdapter, as: Adapter
  alias JidoCode.TestSupport.FakeManagedCodingEffectLedger, as: Ledger

  test "classifies every external operation with a closed reconciliation contract" do
    assert EffectPolicy.contracts() == %{
             context_read: :replayable,
             model_generation: :query_reconcilable,
             tool_read: :replayable,
             tool_mutation: :query_reconcilable,
             filesystem_write: :query_reconcilable,
             credential_checkout: :compensatable,
             artifact_put: :query_reconcilable,
             verifier_run: :query_reconcilable,
             interaction_open: :query_reconcilable,
             publication: :manual_resolution_only
           }
  end

  test "persists intent before dispatch and outcome after completion" do
    intent = intent(:tool_mutation)

    assert {:ok, %{digest: "result"}} =
             EffectReconciler.dispatch(
               Ledger,
               self(),
               Adapter,
               {self(), {:ok, %{digest: "result"}}},
               intent,
               %{digest: "request"}
             )

    assert_receive {:effect_intent, ^intent}
    assert_receive {:effect_dispatch, ^intent, _request}
    assert_receive {:effect_outcome, ^intent, %{digest: "result"}}
  end

  test "queries authoritative state after timeout and does not infer non-execution" do
    intent = intent(:model_generation)

    assert {:ok, %{provider_outcome: "known"}} =
             EffectReconciler.dispatch(
               Ledger,
               self(),
               Adapter,
               {self(),
                %{dispatch: Adapter.timeout(), query: {:ok, %{provider_outcome: "known"}}}},
               intent,
               %{digest: "request"}
             )

    assert_receive {:effect_query, ^intent}
    assert_receive {:effect_outcome, ^intent, %{provider_outcome: "known"}}
  end

  test "routes irreconcilable publication ambiguity to a closed interaction" do
    intent = intent(:publication)

    assert {:ambiguous, %{closed_scope: true}} =
             EffectReconciler.dispatch(
               Ledger,
               self(),
               Adapter,
               {self(), Adapter.timeout()},
               intent,
               %{digest: "request"}
             )

    assert_receive {:effect_ambiguous, ^intent, :manual_resolution}
    assert_receive {:effect_resolution, ^intent, details}
    assert details.capability_change == :forbidden
    assert details.evidence_erasure == :forbidden
  end

  test "bounds retry count, elapsed time, backoff, jitter, and resources" do
    limits = %{
      max_retries: 2,
      max_elapsed_ms: 1_000,
      base_backoff_ms: 100,
      max_backoff_ms: 150,
      jitter_ms: 10,
      max_resource_units: 20,
      seed: "attempt"
    }

    assert {:ok, %{decision: :retry, delay_ms: delay}} =
             RetryPolicy.decide(%{retry_count: 1, elapsed_ms: 20, resource_units: 3}, limits)

    assert delay in 150..160

    assert {:ok, %{decision: :stop, reason: :retry_limit}} =
             RetryPolicy.decide(%{retry_count: 2, elapsed_ms: 20, resource_units: 3}, limits)

    assert {:ok, %{decision: :stop, reason: :elapsed_limit}} =
             RetryPolicy.decide(%{retry_count: 1, elapsed_ms: 1_000, resource_units: 3}, limits)

    assert {:ok, %{decision: :stop, reason: :resource_limit}} =
             RetryPolicy.decide(%{retry_count: 1, elapsed_ms: 20, resource_units: 20}, limits)
  end

  defp intent(operation) do
    {:ok, intent} =
      EffectIntent.new(%{
        attempt_iri: iri("attempt"),
        invocation_iri: iri("invocation"),
        tenant_iri: iri("tenant"),
        operation: operation,
        idempotency_key: "stable-idempotency-key",
        fencing_token: 8,
        requested_at: ~U[2026-08-25 12:00:00Z]
      })

    intent
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

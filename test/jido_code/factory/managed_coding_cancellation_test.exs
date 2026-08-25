defmodule JidoCode.Factory.ManagedCodingCancellationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.Cancellation
  alias JidoCode.Factory.ManagedCoding.CancellationRequest
  alias JidoCode.TestSupport.FakeManagedCodingCancellation, as: Adapter

  test "commits cancellation before signalling and releases capacity before terminal CAS" do
    request = request(:clean)

    assert {:ok, %{terminal: :cancelled, cleanup: :clean, fencing_token: 8}} =
             Cancellation.execute(Adapter, self(), request, grace_ms: 25)

    assert_receive {:cancel_commit, ^request}
    assert_receive {:cancel_stop_dispatch, ^request}
    assert_receive {:cancel_revoke, ^request}
    assert_receive {:cancel_queue, ^request}
    assert_receive {:cancel_terminate, ^request, 25}
    assert_receive {:cancel_cleanup, ^request}
    assert_receive {:cancel_release, ^request}
    assert_receive {:cancel_finalize, ^request, :cancelled}
  end

  test "records late output only as non-authoritative evidence" do
    request = request(:quarantine)

    assert {:ok, :non_authoritative} =
             Cancellation.late_output(Adapter, self(), request, %{
               authority: :current,
               candidate_closure: true,
               disposition: :accepted,
               digest: String.duplicate("a", 64)
             })

    assert_receive {:cancel_late, ^request, observation}
    assert observation.authority == :none
    refute observation.advance_state
    refute observation.candidate_closure
    refute observation.disposition
  end

  test "binds request identity, actor, reason, time, target fence, and retention policy" do
    request = request(:quarantine)
    assert request.actor_iri == iri("actor")
    assert request.reason == "operator request"
    assert request.target_fencing_token == 8
    assert request.retention == :quarantine
  end

  defp request(retention) do
    {:ok, request} =
      CancellationRequest.new(%{
        attempt_iri: iri("attempt"),
        tenant_iri: iri("tenant"),
        actor_iri: iri("actor"),
        reason: "operator request",
        target_fencing_token: 8,
        requested_at: ~U[2026-08-25 12:00:00Z],
        retention: retention
      })

    request
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

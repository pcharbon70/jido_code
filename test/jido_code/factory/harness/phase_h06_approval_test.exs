defmodule JidoCode.Factory.Harness.PhaseH06ApprovalTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Approval.Gateway
  alias JidoCode.Factory.Approval.Request
  alias JidoCode.TestSupport.FakeApprovalLedger
  alias JidoCode.TestSupport.FakeApprovedEffect

  @now ~U[2026-08-18 12:00:00Z]

  setup do
    ledger = start_supervised!(FakeApprovalLedger)
    %{ledger: ledger}
  end

  test "binds the full normalized act to the accepted approval resource" do
    request = request!()
    assert request.knowledge_request.action_digest == request.action_digest
    assert request.knowledge_request.approver_iri == request.approver_iri
    assert Request.digest_valid?(request)

    {:ok, changed} = Request.new(Map.put(request_attributes(), :context_version, "context-2"))
    refute changed.action_digest == request.action_digest
    refute Request.approval_iri(changed) == Request.approval_iri(request)
  end

  test "atomically consumes before effect and commits exactly one terminal", %{ledger: ledger} do
    request = request!()

    assert {:ok, outcome} = Gateway.execute(request, options(request, ledger))
    assert outcome.status == :succeeded
    assert outcome.terminal?
    assert outcome.consumption_receipt.atomic?
    assert outcome.terminal_receipt.terminal_recorded?

    assert_receive {:approval_ledger, :consumed, approval_iri}
    assert_receive {:approved_effect, :execute, invocation_iri}
    assert_receive {:approval_ledger, :terminal, ^invocation_iri}
    assert approval_iri == Request.approval_iri(request)

    assert {:error, %{kind: :conflict, operation: :approval_already_consumed}} =
             Gateway.execute(request, options(request, ledger))

    refute_receive {:approved_effect, :execute, _invocation}
  end

  test "rejects expiry, revocation, digest mismatch, and missing separation", %{ledger: ledger} do
    request = request!()

    cases = [
      {request, [clock: fn -> request.expires_at end]},
      {request, [current: %{current(request) | approver_revocation_generation: 2}]},
      {%{request | patch_digest: digest("substituted")}, []},
      {%{request | execution_actor_iri: request.approver_iri}, []}
    ]

    for {candidate, overrides} <- cases do
      assert {:error, %{kind: :unauthorized}} =
               Gateway.execute(candidate, options(candidate, ledger, overrides))
    end

    refute_receive {:approved_effect, :execute, _invocation}
  end

  test "concurrent replay dispatches the single-use approval once", %{ledger: ledger} do
    request = request!()
    owner = self()

    results =
      1..8
      |> Task.async_stream(
        fn _index -> Gateway.execute(request, options(request, ledger, owner: owner)) end,
        max_concurrency: 8,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _outcome}, &1)) == 1
    assert Enum.count(results, &match?({:error, %{kind: :conflict}}, &1)) == 7

    assert_receive {:approved_effect, :execute, _invocation}
    refute_receive {:approved_effect, :execute, _invocation}
  end

  test "ambiguous delivery stays nonterminal and redelivers only a proven idempotent act", %{
    ledger: ledger
  } do
    request = request!()
    timeout = {:error, AdapterError.new(:timeout, :approved_effect)}

    assert {:ok, ambiguous} =
             Gateway.execute(
               request,
               options(request, ledger, effect_options: [result: timeout])
             )

    assert ambiguous.status == :ambiguous
    refute ambiguous.terminal?
    assert ambiguous.redelivery_allowed?
    assert ambiguous.reconciliation_receipt.observation_count == 1
    assert ambiguous.terminal_receipt == nil

    assert {:ok, recovered} =
             Gateway.redeliver(
               request,
               ambiguous.consumption_receipt,
               options(request, ledger)
             )

    assert recovered.status == :succeeded
    assert recovered.terminal?

    unproven = request!(idempotency: :unproven, invocation_iri: iri("invocation/unproven"))

    assert {:error, %{kind: :unauthorized, operation: :approval_redelivery}} =
             Gateway.redeliver(unproven, ambiguous.consumption_receipt, options(unproven, ledger))
  end

  defp options(request, ledger, overrides \\ []) do
    current = Keyword.get(overrides, :current, current(request))
    clock = Keyword.get(overrides, :clock, fn -> @now end)
    owner = Keyword.get(overrides, :owner, self())

    [
      ledger: {FakeApprovalLedger, ledger},
      effect: {FakeApprovedEffect, %{owner: owner}},
      effect_options: Keyword.get(overrides, :effect_options, []),
      current_provider: fn -> current end,
      clock: clock,
      observed_at: @now,
      owner: owner
    ]
  end

  defp current(request) do
    %{
      approval_iri: Request.approval_iri(request),
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
  end

  defp request!(overrides \\ []) do
    attributes = Map.merge(request_attributes(), Map.new(overrides))
    {:ok, request} = Request.new(attributes)
    request
  end

  defp request_attributes do
    %{
      action: "open_pull_request",
      arguments: %{branch: "agent/phase-06", title: "Phase 6"},
      attempt_iri: iri("attempt/publication"),
      invocation_iri: iri("invocation/publication"),
      lease_iri: iri("lease/publication"),
      fencing_token: 7,
      base_revision: String.duplicate("a", 40),
      patch_digest: digest("patch"),
      artifact_digests: [digest("patch"), digest("binary")],
      tool_version: "provider-adapter-1",
      model_version: "model-profile-1",
      sandbox_version: "sandbox-2",
      policy_revision: "publication-policy-1",
      context_version: "context-1",
      capability_iri: iri("capability/publish"),
      external_destination: %{provider: "github", repository: "agentjido/jido_code"},
      egress: %{digest: digest("egress"), byte_count: 2_048, classification: :internal},
      evidence_iris: [iri("evidence/verification")],
      reversibility: :compensating,
      approver_iri: iri("actor/approver"),
      delegated_scope_iri: iri("scope/repository"),
      execution_actor_iri: iri("actor/executor"),
      separation_required?: true,
      approver_authorization_revision: 4,
      approver_revocation_generation: 1,
      idempotency: :proven,
      idempotency_key_digest: digest("idempotency"),
      expires_at: DateTime.add(@now, 300, :second)
    }
  end

  defp digest(material), do: :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)
  defp iri(path), do: "https://jido.run/id/phase-h06/#{path}"
end

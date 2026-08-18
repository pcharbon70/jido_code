defmodule JidoCode.Factory.Harness.PhaseH06PublicationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Publication.Coordinator
  alias JidoCode.Factory.Publication.Request
  alias JidoCode.Knowledge
  alias JidoCode.TestSupport.FakePublicationProvider

  @now ~U[2026-08-18 12:00:00Z]

  test "publishes only through a separately authorized run attempt" do
    request = request!()
    refute request.task_iri == request.candidate_task_iri
    refute request.attempt_iri == request.candidate_attempt_iri
    assert {:ok, request.run_graph_iri} == Knowledge.run_graph_identity(request.attempt_iri)

    assert {:ok, result} = publish(request)
    assert result.base_branch == "main"
    assert result.bot_branch == "agent/phase-06"
    assert result.credential_scope == :repository_write
    refute result.merge_authority?

    assert_receive {:publication_provider, :capabilities}
    assert_receive {:publication_provider, :compare_and_swap, old_object}
    assert old_object == request.expected_old_object
    assert_receive {:publication_provider, :pull_request, :open_pull_request}
  end

  test "rejects stale CAS and non-fast-forward provider receipts" do
    request = request!()

    assert {:error, %{kind: :conflict, operation: :provider_compare_and_swap}} =
             publish(request, adapter_state: %{owner: self(), actual_old_object: object("stale")})

    non_fast_forward = %{
      expected_old_object: request.expected_old_object,
      observed_old_object: request.expected_old_object,
      new_object: request.candidate_object,
      fast_forward?: false,
      external_branch_id: "branch:agent/phase-06"
    }

    assert {:error, %{kind: :conflict, operation: :publication_non_fast_forward}} =
             publish(request, branch_receipt: non_fast_forward)
  end

  test "requires provider proof before claiming repository-scoped credentials" do
    request = request!()

    unproven = %{
      branch_protection?: true,
      ruleset_protection?: true,
      protected_merge_authority?: false,
      credential_scope: :repository_write,
      credential_scope_proven?: false
    }

    assert {:error, %{kind: :unauthorized, operation: :publication_credential_scope}} =
             publish(request, capabilities: unproven)

    broad_request = request!(requested_credential_scope: :provider_write)
    broad = %{unproven | credential_scope: :provider_write}

    assert {:ok, result} = publish(broad_request, capabilities: broad)
    assert result.credential_scope == :provider_write
  end

  test "rejects merge operations, protected heads, and provider merge receipts" do
    attributes = request_attributes()
    assert {:error, _error} = Request.new(%{attributes | operation: :merge})
    assert {:error, _error} = Request.new(%{attributes | bot_branch: "main"})

    merge_receipt = %{
      operation: :open_pull_request,
      base_branch: "main",
      head_branch: "agent/phase-06",
      external_pull_request_id: "pr:42",
      provider_revision: "provider-revision-9",
      merge_performed?: true
    }

    assert {:error, %{kind: :unauthorized, operation: :publication_merge_authority}} =
             publish(request!(), pull_request_receipt: merge_receipt)
  end

  test "rejects changed authorization, fence, or observed branch before provider dispatch" do
    request = request!()

    for mutation <- [
          %{authorization_state: :revoked},
          %{fencing_token: 8},
          %{observed_old_object: object("new-tip")}
        ] do
      changed = Map.merge(current(request), mutation)

      assert {:error, %{kind: :unauthorized, operation: :publication_revalidation}} =
               publish(request, current: changed)
    end
  end

  defp publish(request, overrides \\ []) do
    adapter_state = Keyword.get(overrides, :adapter_state, %{owner: self()})
    current = Keyword.get(overrides, :current, current(request))

    Coordinator.publish(
      request,
      current,
      FakePublicationProvider,
      adapter_state,
      Keyword.merge([clock: fn -> @now end], Keyword.drop(overrides, [:adapter_state, :current]))
    )
  end

  defp current(request) do
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

  defp request!(overrides \\ []) do
    {:ok, request} = Request.new(Map.merge(request_attributes(), Map.new(overrides)))
    request
  end

  defp request_attributes do
    publication_attempt = iri("attempt/publication")
    {:ok, run_graph} = Knowledge.run_graph_identity(publication_attempt)

    %{
      operation: :open_pull_request,
      task_iri: iri("task/publication"),
      attempt_iri: publication_attempt,
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
      approval_iri: iri("approval/1"),
      approval_consumption_iri: iri("approval-consumption/1"),
      base_branch: "main",
      bot_branch: "agent/phase-06",
      expected_old_object: object("old"),
      candidate_object: object("candidate"),
      patch_digest: digest("patch"),
      evidence_iris: [iri("evidence/verification")],
      policy_revision: "publication-policy-1"
    }
  end

  defp object(material) do
    :crypto.hash(:sha, material) |> Base.encode16(case: :lower)
  end

  defp digest(material), do: :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)
  defp iri(path), do: "https://jido.run/id/phase-h06/#{path}"
end

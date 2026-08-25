defmodule JidoCode.Product.ManagedCodingProductTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.ManagedCodingControlGateway
  alias JidoCode.TestSupport.FakeManagedCodingControlAdapter

  test "builds a bounded browser view with opaque references and no source identifiers" do
    assert {:ok, attempt} = ManagedCodingAttempt.new(graph())
    view = ManagedCodingAttempt.view(attempt)

    assert byte_size(view.presentation_ref) == 32
    assert view.state == :awaiting_actor
    assert view.wait_reason == :actor
    assert view.verification == :pending
    assert view.disposition == nil
    assert length(view.evidence_refs) == 1

    serialized = inspect(view)
    refute serialized =~ graph().attempt_iri
    refute serialized =~ graph().repository_iri
    refute serialized =~ graph().actor_iri
  end

  test "rejects logs, patches, secrets, and unsupported summary keys" do
    for unsafe <- [
          put_in(graph(), [:interactions, Access.at(0), :prompt], "raw model prompt"),
          put_in(graph(), [:tools, Access.at(0), :label], "Bearer abcdefghijklmnop"),
          put_in(graph(), [:checks, Access.at(0), :patch], "diff --git")
        ] do
      assert {:error, %AdapterError{kind: :invalid_input}} = ManagedCodingAttempt.new(unsafe)
    end
  end

  test "submits current-fence idempotent Factory commands with confirmations", %{test: test} do
    assert {:ok, attempt} = ManagedCodingAttempt.new(graph())
    authority = authority()
    identity = identity()
    key = "idempotency-key-#{test}"

    options = [adapter: FakeManagedCodingControlAdapter, adapter_options: [test_pid: self()]]

    params = %{"message" => "Continue with the focused fix", "idempotency_key" => key}

    assert {:ok, _outcome} =
             ManagedCodingControlGateway.submit(
               authority,
               identity,
               attempt,
               :steer,
               params,
               options
             )

    assert_receive {:factory_command, :steer, first}
    assert first.fencing_token == attempt.fencing_token
    assert first.attempt_iri == attempt.attempt_iri

    assert {:ok, _outcome} =
             ManagedCodingControlGateway.submit(
               authority,
               identity,
               attempt,
               :steer,
               params,
               options
             )

    assert_receive {:factory_command, :steer, repeated}
    assert repeated.command_iri == first.command_iri

    assert {:error, %AdapterError{kind: :unauthorized}} =
             ManagedCodingControlGateway.submit(
               authority,
               identity,
               attempt,
               :cancel,
               %{"confirmed" => "false", "idempotency_key" => key},
               options
             )

    refute_receive {:factory_command, :cancel, _command}
  end

  test "rejects cross-actor and sensitive controls before Factory dispatch" do
    assert {:ok, attempt} = ManagedCodingAttempt.new(graph())
    {:ok, other_authority} = AuthorityContext.new(%{identity() | actor_iri: iri("other-actor")})

    options = [adapter: FakeManagedCodingControlAdapter, adapter_options: [test_pid: self()]]

    assert {:error, %AdapterError{kind: :unauthorized}} =
             ManagedCodingControlGateway.submit(
               other_authority,
               identity(),
               attempt,
               :steer,
               %{"message" => "safe", "idempotency_key" => "idempotency-key-safe"},
               options
             )

    assert {:error, %AdapterError{}} =
             ManagedCodingControlGateway.submit(
               authority(),
               identity(),
               attempt,
               :steer,
               %{
                 "message" => "Bearer abcdefghijklmnop",
                 "idempotency_key" => "idempotency-key-secret"
               },
               options
             )

    refute_receive {:factory_command, _operation, _command}
  end

  defp graph do
    identity = identity()

    %{
      attempt_iri: iri("attempt"),
      repository_iri: iri("repository"),
      task_iri: iri("task"),
      profile_iri: iri("profile"),
      capability_iri: iri("capability"),
      actor_iri: identity.actor_iri,
      fencing_token: 7,
      sequence: 9,
      task_label: "Harden candidate closure",
      state: :awaiting_actor,
      wait_reason: :actor,
      budgets: %{turns: %{used: 3, limit: 10}},
      interactions: [%{kind: :clarification, label: "Clarification requested", status: :waiting}],
      tools: [%{kind: :mutation, label: "Edit source", status: :completed}],
      checks: [%{kind: :compilation, label: "Compile", status: :passed}],
      candidate_iri: iri("candidate"),
      verification: :pending,
      disposition: nil,
      evidence_iris: [iri("evidence")],
      updated_at: ~U[2026-08-25 13:00:00Z]
    }
  end

  defp authority do
    {:ok, authority} = AuthorityContext.new(identity())
    authority
  end

  defp identity do
    %{
      principal_iri: "https://jido.run/id/actor/local-operator",
      actor_iri: "https://jido.run/id/actor/local-operator",
      delegated_agent_iri: nil,
      delegation_iri: nil,
      factory_scope_iri: "https://jido.run/id/scope/factory/default"
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

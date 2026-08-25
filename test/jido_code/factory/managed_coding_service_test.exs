defmodule JidoCode.Factory.ManagedCodingServiceTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding
  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.Profile
  alias JidoCode.Factory.ManagedCoding.ResolvedAdmission
  alias JidoCode.Factory.ManagedCoding.Service
  alias JidoCode.TestSupport.FakeManagedCodingAdmissionLedger, as: Ledger
  alias JidoCode.TestSupport.FakeManagedCodingRuntime, as: Runtime

  setup do
    resolved = resolved_admission()
    runtime_pid = spawn(fn -> Process.sleep(:infinity) end)
    owner = self()

    ledger =
      start_supervised!(
        {Agent, fn -> %{owner: owner, resolved: resolved, admissions: %{}} end},
        id: :admission_ledger
      )

    runtime =
      start_supervised!(
        {Agent, fn -> %{owner: owner, runtime_pid: runtime_pid} end},
        id: :managed_runtime
      )

    service =
      start_supervised!(
        {Service,
         ledger: {Ledger, ledger},
         runtime: {Runtime, runtime},
         capacity: fn -> 0 end,
         max_active: 1}
      )

    on_exit(fn -> Process.exit(runtime_pid, :kill) end)
    %{ledger: ledger, resolved: resolved, runtime: runtime, service: service}
  end

  test "commits exact admission before any runtime process or effect", context do
    command = command(:admit, context.resolved)

    assert {:ok, outcome} = ManagedCoding.admit(Service, command, server: context.service)
    assert outcome.state == :admitted
    assert outcome.attempt_iri == context.resolved.attempt_iri
    assert_receive {:ledger, :resolve, _command}
    assert_receive {:ledger, :commit, _command}
    refute_receive {:runtime, _, _}

    expected = context.resolved

    assert {:ok, %{resolved: ^expected}} =
             Ledger.fetch(
               context.ledger,
               context.resolved.attempt_iri,
               context.resolved.fencing_token
             )
  end

  test "starts only the committed fence and records the monitored runtime", context do
    admit!(context)
    flush_mailbox()

    assert {:ok, outcome} =
             ManagedCoding.start(
               Service,
               command(:start, context.resolved),
               server: context.service
             )

    assert outcome.state == :preparing
    assert_receive {:ledger, :fetch, _, 7}
    assert_receive {:runtime, :start, _attempt}
    assert_receive {:ledger, :runtime_started, _attempt, %{pid: pid}}
    assert is_pid(pid)
  end

  test "rejects admission failures and capacity without partial runtime state", context do
    Agent.update(context.ledger, &Map.put(&1, :commit_result, {:error, :conflict}))

    assert {:error, %AdapterError{kind: :conflict}} =
             ManagedCoding.admit(
               Service,
               command(:admit, context.resolved),
               server: context.service
             )

    assert_receive {:ledger, :resolve, _command}
    assert_receive {:ledger, :commit, _command}
    refute_receive {:runtime, _, _}

    full_service =
      start_supervised!(
        {Service,
         ledger: {Ledger, context.ledger},
         runtime: {Runtime, context.runtime},
         capacity: fn -> 1 end,
         max_active: 1},
        id: :full_managed_coding_service
      )

    assert {:error, %AdapterError{kind: :unavailable}} =
             ManagedCoding.admit(
               Service,
               command(:admit, context.resolved),
               server: full_service
             )

    refute_receive {:ledger, :resolve, _command}
    refute_receive {:runtime, _, _}
  end

  test "accepts an idempotent admission and rejects stale or unauthorized identity", context do
    Agent.update(context.ledger, &Map.put(&1, :commit_result, :idempotent))

    assert {:ok, outcome} =
             ManagedCoding.admit(
               Service,
               command(:admit, context.resolved),
               server: context.service
             )

    assert outcome.state == :admitted

    unauthorized =
      command(:admit, context.resolved)
      |> Map.put(:repository_iri, iri("different-repository"))

    assert {:error, %AdapterError{kind: :unauthorized}} =
             ManagedCoding.admit(Service, unauthorized, server: context.service)

    stale = command(:start, context.resolved) |> Map.put(:fencing_token, 6)

    assert {:error, %AdapterError{kind: :unauthorized}} =
             ManagedCoding.start(Service, stale, server: context.service)

    refute_receive {:runtime, :start, _attempt}
  end

  test "reconciles runtime start failure against committed graph state", context do
    admit!(context)

    Agent.update(
      context.runtime,
      &Map.put(&1, :start_result, {:error, AdapterError.new(:unavailable, :start)})
    )

    flush_mailbox()

    assert {:error, %AdapterError{kind: :unavailable}} =
             ManagedCoding.start(
               Service,
               command(:start, context.resolved),
               server: context.service
             )

    assert_receive {:ledger, :fetch, _, 7}
    assert_receive {:runtime, :start, _attempt}
    assert_receive {:ledger, :fetch, _, 7}
    assert_receive {:ledger, :start_failed, _attempt, :unavailable}
  end

  test "dispatches bounded steering, inspection, cancellation, awaiting, and handoff", context do
    for operation <- [:steer, :status, :cancel, :handoff] do
      assert {:ok, outcome} =
               apply(ManagedCoding, operation, [
                 Service,
                 command(operation, context.resolved),
                 [server: context.service]
               ])

      assert outcome.attempt_iri == context.resolved.attempt_iri
      assert_receive {:runtime, ^operation, _attempt}
    end

    assert {:ok, outcome} =
             ManagedCoding.await(
               Service,
               command(:await, context.resolved),
               server: context.service,
               timeout: 123
             )

    assert outcome.state == :running
    assert_receive {:runtime, :await, _attempt, 123}
  end

  defp admit!(context) do
    assert {:ok, _outcome} =
             ManagedCoding.admit(
               Service,
               command(:admit, context.resolved),
               server: context.service
             )
  end

  defp command(operation, resolved) do
    attributes = %{
      operation: operation,
      command_iri: iri("command-#{operation}"),
      repository_iri: resolved.repository_iri,
      task_iri: resolved.task_iri,
      actor_iri: resolved.actor_iri,
      profile_iri: resolved.profile.iri,
      capability_iri: resolved.capability_iri,
      payload: %{}
    }

    attributes =
      if operation == :admit do
        attributes
      else
        Map.merge(attributes, %{
          attempt_iri: resolved.attempt_iri,
          fencing_token: resolved.fencing_token
        })
      end

    {:ok, command} = Command.new(attributes)
    command
  end

  defp resolved_admission do
    {:ok, budget} =
      Budget.new(
        Map.new(Budget.dimensions(), fn dimension ->
          {dimension, %{limit: 100, enforcement: :hard}}
        end)
      )

    digest = String.duplicate("a", 64)

    {:ok, profile} =
      Profile.new(%{
        iri: iri("profile"),
        revision: 1,
        jido_version: "2.3.2",
        strategy_revision: digest,
        prompt_bundle_revision: digest,
        model_access_profile_iri: iri("model-profile"),
        context_policy_revision: digest,
        memory_policy_revision: digest,
        tool_catalog_revision: digest,
        adapter_set_revision: digest,
        sandbox_profile_revision: digest,
        verifier_profile_revision: digest,
        candidate_schema_revision: digest,
        budget: budget,
        state: :enabled,
        rollout_stage: :shadow,
        task_classes: ["focused_change"],
        actor_iris: [iri("actor")],
        tenant_iris: [iri("tenant")],
        repository_iris: [iri("repository")],
        capability_iris: [iri("capability")]
      })

    {:ok, resolved} =
      ResolvedAdmission.new(%{
        attempt_iri: iri("attempt"),
        lease_iri: iri("lease"),
        tenant_iri: iri("tenant"),
        repository_iri: iri("repository"),
        task_iri: iri("task"),
        actor_iri: iri("actor"),
        policy_iri: iri("policy"),
        snapshot_iri: iri("snapshot"),
        credential_reference_iri: iri("credential-reference"),
        capability_iri: iri("capability"),
        admission_evidence_iri: iri("admission-evidence"),
        policy_revision: digest,
        snapshot_revision: digest,
        credential_revision: digest,
        capability_revision: digest,
        fencing_token: 7,
        profile: profile,
        budget: budget,
        resolved_at: ~U[2026-08-25 11:00:00Z]
      })

    resolved
  end

  defp flush_mailbox do
    receive do
      _message -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end

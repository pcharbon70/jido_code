defmodule JidoCode.Factory.Harness.PhaseH03FencingIdempotencyTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Model.Outcome, as: ModelOutcome
  alias JidoCode.Factory.Model.RecoveryArbiter
  alias JidoCode.Factory.Model.Request, as: ModelRequest
  alias JidoCode.Factory.Tool.EffectIdentity
  alias JidoCode.Factory.Tool.EffectJournal
  alias JidoCode.Factory.Tool.Request, as: ToolRequest
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.Tool.SinkGuard
  alias JidoCode.Knowledge.ResourceIdentity

  test "effect identities pin attempt, snapshot, fence, operation, and sequence" do
    execution = execution_request!("identity", 11)

    assert {:ok, first} = EffectIdentity.new(execution, "repository.write", 3)
    assert {:ok, duplicate} = EffectIdentity.new(execution, "repository.write", 3)
    assert first.value == duplicate.value

    variants = [
      EffectIdentity.new(execution_request!("other-attempt", 11), "repository.write", 3),
      EffectIdentity.new(
        %{execution | snapshot_iri: resource!(:repository_snapshot, "other")},
        "repository.write",
        3
      ),
      EffectIdentity.new(%{execution | fencing_token: 12}, "repository.write", 3),
      EffectIdentity.new(execution, "provider.write", 3),
      EffectIdentity.new(execution, "repository.write", 4)
    ]

    assert Enum.all?(variants, fn {:ok, identity} -> identity.value != first.value end)
  end

  test "tool requests carry their derived effect identity to the sink" do
    execution = execution_request!("tool-request", 21)

    assert {:ok, request} = tool_request(execution, 7, "source.read")
    assert request.effect_identity.attempt_iri == execution.attempt_iri
    assert request.effect_identity.snapshot_iri == execution.snapshot_iri
    assert request.effect_identity.fencing_token == 21
    assert request.effect_identity.operation == "source.read"
    assert request.effect_identity.sequence == 7
  end

  test "every owned sink rejects a stale monotonic fence before claiming an effect" do
    execution = execution_request!("sink-inventory", 31)
    assert {:ok, identity} = EffectIdentity.new(execution, "governed.effect", 1)
    {:ok, journal} = start_supervised(EffectJournal)
    current = current(execution)

    assert SinkGuard.inventory() == [
             :graph_command,
             :sandbox_mutation,
             :tool_execution,
             :git_write,
             :provider_write,
             :artifact_publication,
             :execution_outcome
           ]

    for sink <- SinkGuard.inventory() do
      stale = %{current | fencing_token: execution.fencing_token + 1}

      assert {:error, %AdapterError{kind: :unauthorized, operation: :stale_effect_fence}} =
               SinkGuard.claim(sink, execution, identity, stale, {EffectJournal, journal})

      assert {:ok, :dispatch} =
               SinkGuard.claim(sink, execution, identity, current, {EffectJournal, journal})
    end
  end

  test "atomic claims reject in-flight duplicates and replay one completed effect" do
    execution = execution_request!("replay", 41)
    assert {:ok, identity} = EffectIdentity.new(execution, "provider.write", 2)
    {:ok, journal} = start_supervised(EffectJournal)
    assert {:ok, result} = result("provider:effect-42")

    assert {:ok, :dispatch} = EffectJournal.claim(journal, :provider_write, identity)

    assert {:error, %AdapterError{operation: :effect_already_claimed}} =
             EffectJournal.claim(journal, :provider_write, identity)

    assert {:ok, :committed} =
             EffectJournal.complete(journal, :provider_write, identity, result)

    assert {:ok, {:replay, ^result}} =
             EffectJournal.claim(journal, :provider_write, identity)

    assert {:ok, :idempotent} =
             EffectJournal.complete(journal, :provider_write, identity, result)
  end

  test "ambiguous external mutations must reconcile before the same effect can retry" do
    execution = execution_request!("ambiguous", 51)
    assert {:ok, identity} = EffectIdentity.new(execution, "git.write", 4)
    {:ok, journal} = start_supervised(EffectJournal)

    assert {:ok, :dispatch} = EffectJournal.claim(journal, :git_write, identity)
    assert {:ok, :committed} = EffectJournal.ambiguous(journal, :git_write, identity)

    assert {:error, %AdapterError{operation: :effect_reconciliation_required}} =
             EffectJournal.claim(journal, :git_write, identity)

    assert {:ok, :retry} =
             EffectJournal.reconcile(journal, :git_write, identity, :not_applied)

    assert {:ok, :dispatch} = EffectJournal.claim(journal, :git_write, identity)
  end

  test "stable external effect IDs close ambiguous mutations without redispatch" do
    execution = execution_request!("external-effect", 61)
    assert {:ok, identity} = EffectIdentity.new(execution, "provider.write", 5)
    {:ok, journal} = start_supervised(EffectJournal)
    assert {:ok, result} = result("provider:stable-9001")

    assert {:ok, :dispatch} = EffectJournal.claim(journal, :provider_write, identity)
    assert {:ok, :committed} = EffectJournal.ambiguous(journal, :provider_write, identity)

    assert {:ok, :committed} =
             EffectJournal.reconcile(journal, :provider_write, identity, {:applied, result})

    assert {:ok, {:replay, %Result{external_effect_id: "provider:stable-9001"}}} =
             EffectJournal.claim(journal, :provider_write, identity)
  end

  test "semantic retries require a new linked attempt instead of overwriting history" do
    execution = execution_request!("semantic-original", 71)
    assert {:ok, original} = EffectIdentity.new(execution, "artifact.publish", 6)

    assert {:error, %AdapterError{operation: :semantic_effect_retry}} =
             EffectIdentity.linked_retry(original, execution)

    replacement = execution_request!("semantic-retry", 72)
    assert {:ok, retry} = EffectIdentity.linked_retry(original, replacement)
    assert retry.value != original.value
    assert retry.prior_effect_id == original.value
    assert retry.attempt_iri == replacement.attempt_iri
  end

  test "one recovered model result wins under the expected revision" do
    invocation = resource!(:model_invocation, "ambiguous-model")
    assert {:ok, state} = RecoveryArbiter.new(invocation, 90)
    error = AdapterError.new(:timeout, :model_gateway_generate)

    assert %{
             status: :ambiguous,
             diagnostic: "gateway=ambiguous;error=timeout;operation=model_gateway_generate"
           } = RecoveryArbiter.ambiguous_outcome(error)

    digest = "sha256:" <> String.duplicate("a", 64)
    other_digest = "sha256:" <> String.duplicate("b", 64)

    assert {:ok, :committed, recovered} = RecoveryArbiter.advance(state, 90, digest)
    assert recovered.revision == 91
    assert {:ok, :idempotent, ^recovered} = RecoveryArbiter.advance(recovered, 90, digest)

    assert {:error, %AdapterError{operation: :model_result_recovery}} =
             RecoveryArbiter.advance(recovered, 90, other_digest)

    assert {:error, %AdapterError{operation: :model_result_recovery}} =
             RecoveryArbiter.advance(state, 91, digest)
  end

  test "irretrievable post-dispatch model responses are recorded as ambiguous" do
    assert {:ok, request} =
             ModelRequest.new(%{
               invocation_iri: resource!(:model_invocation, "outcome"),
               profile_iri: resource!(:model_access_profile, "outcome"),
               context_manifest_iri: resource!(:context_manifest, "outcome"),
               provider: "openai",
               model: "gpt-4.1-mini",
               messages: "bounded context",
               options: [],
               deadline: DateTime.add(DateTime.utc_now(), 300, :second)
             })

    timeout = AdapterError.new(:timeout, :model_gateway_generate)
    pre_dispatch = AdapterError.new(:unavailable, :model_credential_fetch)

    assert %{status: :ambiguous} = ModelOutcome.attributes({:error, timeout}, request)
    assert %{status: :failed} = ModelOutcome.attributes({:error, pre_dispatch}, request)
  end

  defp tool_request(execution, sequence, effect) do
    ToolRequest.new(%{
      execution: execution,
      invocation_iri: resource!(:tool_invocation, "#{sequence}"),
      tool_iri: resource!(:tool_definition_revision, "#{sequence}"),
      tool_version: "1.0.0",
      sequence: sequence,
      deadline: DateTime.add(DateTime.utc_now(), 300, :second),
      expected_effect: effect,
      allowed_effects: [effect],
      input_refs: [execution.snapshot_iri],
      input_digests: %{"snapshot" => "sha256:" <> String.duplicate("c", 64)},
      arguments: %{path: "lib/jido_code.ex"},
      output_bytes: 4_096
    })
  end

  defp execution_request!(seed, fence) do
    assert {:ok, request} =
             ExecutionRequest.new(%{
               attempt_iri: resource!(:execution_attempt, "attempt-#{seed}"),
               lease_iri: resource!(:execution_lease, "lease-#{seed}"),
               task_iri: resource!(:knowledge_assertion, "task-#{seed}"),
               goal_iri: resource!(:knowledge_assertion, "goal-#{seed}"),
               plan_iri: resource!(:knowledge_assertion, "plan-#{seed}"),
               repository_iri: resource!(:knowledge_assertion, "repository-#{seed}"),
               snapshot_iri: resource!(:repository_snapshot, "snapshot-#{seed}"),
               actor_iri: resource!(:knowledge_assertion, "actor-#{seed}"),
               agent_iri: resource!(:knowledge_assertion, "agent-#{seed}"),
               capability_iri: resource!(:knowledge_assertion, "capability-#{seed}"),
               fencing_token: fence,
               context_digest: String.duplicate("d", 64),
               runtime_version: "phase-h03-fixture/1",
               constraints: %{}
             })

    request
  end

  defp current(execution) do
    %{
      lease_state: :active,
      attempt_iri: execution.attempt_iri,
      lease_iri: execution.lease_iri,
      snapshot_iri: execution.snapshot_iri,
      fencing_token: execution.fencing_token
    }
  end

  defp result(external_effect_id) do
    Result.new(
      %{
        status: :completed,
        exit_status: 0,
        stdout: "completed",
        stderr: "",
        external_output_iris: [],
        usage: %{},
        artifact_iris: [],
        redaction: :none,
        external_effect_id: external_effect_id
      },
      4_096
    )
  end

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h03-fencing-#{seed}")
    iri
  end
end

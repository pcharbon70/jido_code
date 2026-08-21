defmodule JidoCode.Knowledge.Memory.GuardrailsTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Guardrails

  test "blocks segmented execution while any legacy attempt is open or ungoverned" do
    completed = legacy_attempt(:completed)
    abandoned = legacy_attempt(:abandoned)

    assert :ok = Guardrails.authorize_segmented_activation([completed, abandoned])

    assert {:error, %Error{kind: :conflict, operation: :legacy_attempts_open}} =
             Guardrails.authorize_segmented_activation([
               completed,
               %{completed | state: :running, lifecycle_state: :open}
             ])

    assert {:error, %Error{kind: :conflict, operation: :legacy_attempts_open}} =
             Guardrails.authorize_segmented_activation([
               %{abandoned | governed_abandonment?: false}
             ])

    assert Guardrails.protocol_posture() == %{
             legacy_read: "1.x",
             segmented_write: "2.0.0",
             legacy_rewrite?: false,
             dual_read?: true
           }

    assert Guardrails.readable_protocol?("1.x")
    assert Guardrails.readable_protocol?("2.0.0")
    refute Guardrails.readable_protocol?("3.0.0")
  end

  test "binds candidate generation to the complete authorized partition" do
    attributes = partition_attributes()

    assert {:ok, first} = Guardrails.authorize_candidate_partition(attributes)
    assert byte_size(first.partition_digest) == 64

    assert {:ok, second} = Guardrails.authorize_candidate_partition(attributes)
    assert first.partition_digest == second.partition_digest

    assert {:ok, changed} =
             Guardrails.authorize_candidate_partition(%{
               attributes
               | erasure_generation: attributes.erasure_generation + 1
             })

    refute first.partition_digest == changed.partition_digest

    for key <- [
          :authorization_iri,
          :authorization_revision,
          :repository_iri,
          :tenant_iri,
          :actor_scope_iri,
          :purpose,
          :data_ceiling,
          :effective_time_generation,
          :erasure_generation
        ] do
      assert {:error, %Error{kind: :unauthorized, operation: :memory_candidate_partition}} =
               attributes
               |> Map.delete(key)
               |> Guardrails.authorize_candidate_partition()
    end

    assert {:error, %Error{kind: :unauthorized}} =
             Guardrails.authorize_candidate_partition(%{
               attributes
               | authorization_decision: :denied
             })
  end

  test "reserves closure capacity below every existing system ceiling" do
    profile = Guardrails.capacity_profile()
    ceilings = Guardrails.system_ceilings()

    assert Guardrails.capacity_profile_valid?()
    assert profile.segment_quad_limit < ceilings.snapshot_quads
    assert profile.attempt_root_quad_limit < ceilings.snapshot_quads

    assert profile.segment_addition_limit + profile.closure_addition_reserve <=
             ceilings.command_additions

    assert profile.closure_addition_reserve > 0
    assert profile.segment_guard_limit < ceilings.precommit_guards
    assert profile.segment_target_graph_limit < ceilings.target_graphs
    assert profile.command_payload_bytes < ceilings.command_payload_bytes
  end

  test "pins the Phase 6 benchmark corpus and deterministic storage decision" do
    assert length(Guardrails.benchmark_corpus()) == 4
    assert Guardrails.benchmark_corpus_digest() =~ ~r/^[a-f0-9]{64}$/

    passing = Guardrails.benchmark_thresholds()
    assert Guardrails.storage_decision(passing) == :graph_native

    assert Guardrails.storage_decision(%{passing | query_latency_ratio: 2.01}) ==
             :vault_adr_required

    assert Guardrails.storage_decision(Map.delete(passing, :restore_latency_ratio)) ==
             :vault_adr_required

    assert Guardrails.storage_decision(%{passing | integrity_failures: 1}) ==
             :vault_adr_required
  end

  test "closes the memory threat inventory and keeps future features disabled" do
    assert Guardrails.threats() |> Enum.map(& &1.id) |> MapSet.new() ==
             MapSet.new([
               :persistent_poisoning,
               :delayed_prompt_injection,
               :cross_scope_retrieval,
               :stale_procedure,
               :false_causality,
               :context_overload,
               :secret_capture,
               :incomplete_erasure
             ])

    assert Guardrails.disabled_features() == %{
             experience_writer: :MG4,
             diagnostic_capture: :MG6,
             project_total_history: :MG6,
             content_lifecycle_writer: :MG6,
             episode_content_writer: :MG6,
             content_gateway: :MG6
           }

    refute Enum.any?(Map.keys(Guardrails.disabled_features()), &Guardrails.feature_enabled?/1)
    assert Guardrails.feature_enabled?(:history_queries)
    assert Guardrails.feature_enabled?(:retrieval_index)
    refute Guardrails.feature_enabled?(:unknown_future_feature)
  end

  defp legacy_attempt(state) do
    %{
      protocol: "1.x",
      state: state,
      lifecycle_state: :closed,
      completeness_claim: :bounded_observable_subset,
      terminal_transition_iri: "https://jido.run/id/transition/01J00000000000000000000001",
      governed_abandonment?: true,
      abandonment_decision_iri: "https://jido.run/id/decision/01J00000000000000000000002"
    }
  end

  defp partition_attributes do
    %{
      authorization_iri: "https://jido.run/id/authorization/01J00000000000000000000003",
      authorization_decision: :allowed,
      authorization_revision: 4,
      repository_iri: "https://jido.run/id/repository/01J00000000000000000000004",
      tenant_iri: "https://jido.run/id/scope/01J00000000000000000000005",
      actor_scope_iri: "https://jido.run/id/scope/01J00000000000000000000006",
      purpose: :managed_continuity,
      data_ceiling: :confidential,
      effective_time_generation: 7,
      erasure_generation: 3
    }
  end
end

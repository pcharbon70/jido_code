defmodule JidoCode.Knowledge.Memory.Phase07EvaluationReleaseTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.Memory.MemoryEvaluationProgram
  alias JidoCode.Knowledge.ResourceIdentity

  test "runs every required ablation and accepts supported utility with zero governance failures" do
    assert {:ok, report} = MemoryEvaluationProgram.evaluate(attributes())

    assert report.accepted?
    assert report.decision == :accepted
    assert report.rejection_reasons == []
    assert report.all_ablations_complete?
    assert report.metric_contract_exact?
    assert report.immediate_disable_paths_complete?
    assert byte_size(report.evaluation_digest) == 64
    assert Enum.sort(Map.keys(report.ablations)) == Enum.sort(MemoryEvaluationProgram.ablations())
    assert MemoryEvaluationProgram.statements(report) |> length() >= 21

    poisoned = report.ablations.stale_or_poisoned_memory
    assert Map.has_key?(poisoned.harms, :poisoned_memory_uptake)
    assert Map.has_key?(poisoned.harms, :negative_transfer)
    assert Map.has_key?(poisoned.harms, :scope_leakage)
    assert Map.has_key?(poisoned.harms, :temporal_leakage)
  end

  test "blocks any zero-tolerance failure or unsupported benefit" do
    leaking = put_in(attributes(), [:zero_tolerance, :cross_scope_leaks], 1)
    assert {:ok, rejected} = MemoryEvaluationProgram.evaluate(leaking)
    refute rejected.accepted?
    assert :cross_scope_leaks in rejected.rejection_reasons

    unsupported =
      update_in(attributes(), [:launch_products], fn [product] ->
        [%{product | effect_size: 0.01, confidence_low: -0.02, p_value: 0.3}]
      end)

    assert {:ok, rejected} = MemoryEvaluationProgram.evaluate(unsupported)
    refute rejected.accepted?
    assert :no_statistically_supported_benefit in rejected.rejection_reasons
  end

  test "fails closed when an ablation or metric is absent" do
    incomplete = update_in(attributes(), [:ablations], &Map.delete(&1, :oracle_retrieval))
    assert {:error, %{kind: :invalid_input}} = MemoryEvaluationProgram.evaluate(incomplete)

    missing_metric =
      update_in(attributes(), [:ablations, :hybrid_retrieval, :retrieval], fn metrics ->
        Map.delete(metrics, :source_completeness)
      end)

    assert {:error, %{kind: :invalid_input}} = MemoryEvaluationProgram.evaluate(missing_metric)
  end

  test "pins the release command and immediate-disable boundary" do
    assert CommandRegistry.memory_evaluation_version() == "2.7.0"
    assert :memory_evaluator in Authorization.capabilities()
    assert Guardrails.feature_enabled?(:memory_release_evaluation)

    for command <- ["RecordMemoryEvaluation", "DecideMemoryRelease", "DisableMemoryProduct"] do
      assert {:ok, definition} = CommandRegistry.resolve(command, "2.7.0")
      assert definition.capability == :memory_evaluator
    end

    refute Enum.any?(CommandRegistry.names("2.7.0"), fn command ->
             String.contains?(command, ["Train", "Checkpoint", "RegisterModel", "Deploy"])
           end)
  end

  defp attributes do
    %{
      manifest_iri: resource(:memory_dataset_manifest, "evaluation-manifest"),
      evaluator_iri: resource(:authorization_grant, "evaluation-actor"),
      ablations: Map.new(MemoryEvaluationProgram.ablations(), &{&1, metrics(&1)}),
      zero_tolerance: Map.new(MemoryEvaluationProgram.zero_tolerance_metrics(), &{&1, 0}),
      launch_products: [
        %{
          product: :hybrid_memory_packet,
          ablation: :hybrid_retrieval,
          effect_size: 0.12,
          confidence_low: 0.04,
          p_value: 0.01,
          sample_size: 120,
          disable_path: %{
            command: "DisableMemoryProduct",
            owner_iri: resource(:authorization_grant, "memory-product-owner"),
            maximum_latency_seconds: 120
          }
        }
      ],
      recorded_at: ~U[2026-08-05 00:00:00Z]
    }
  end

  defp metrics(ablation) do
    retrieval = %{
      precision: if(ablation == :no_memory, do: 0.0, else: 0.82),
      recall: if(ablation == :no_memory, do: 0.0, else: 0.78),
      ranking_quality: if(ablation == :no_memory, do: 0.0, else: 0.8),
      source_completeness: 1.0,
      authorization_denial_correctness: 1.0,
      invalidation_latency_ms: 25,
      retrieval_cost: if(ablation == :no_memory, do: 0, else: 12)
    }

    outcomes = %{
      task_success: if(ablation == :no_memory, do: 0.55, else: 0.67),
      time_to_accepted_patch: if(ablation == :no_memory, do: 900, else: 720),
      review_burden: if(ablation == :no_memory, do: 4.2, else: 3.6),
      regression_rate: 0.02,
      recovery_quality: 0.9,
      token_cost: if(ablation == :no_memory, do: 1_000, else: 1_150),
      operator_intervention: 0.08
    }

    harms = %{
      negative_transfer: 0.01,
      procedure_misuse: 0,
      invalidation_misses: 0,
      hallucinated_memory: 0,
      poisoned_memory_uptake: 0,
      scope_leakage: 0,
      erasure_misses: 0,
      temporal_leakage: 0
    }

    %{retrieval: retrieval, outcomes: outcomes, harms: harms}
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end

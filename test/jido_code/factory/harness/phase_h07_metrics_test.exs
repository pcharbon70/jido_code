defmodule JidoCode.Factory.Harness.PhaseH07MetricsTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Evaluation.Adjudication
  alias JidoCode.Factory.Evaluation.Metrics
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Factory.Evaluation.TrialResult

  @digest String.duplicate("b", 64)

  test "trial outcomes are closed and reject inconsistent acceptance evidence" do
    attributes = trial_attributes("trial-1", "task/a", 1)
    assert {:ok, trial} = TrialResult.new(attributes)
    assert trial.accepted?

    assert {:error, %{operation: :evaluation_trial_result}} =
             TrialResult.new(%{attributes | completed?: false})

    assert {:error, %{operation: :evaluation_trial_result}} =
             attributes |> Map.put(:unknown_measure, 1) |> TrialResult.new()
  end

  test "primary metrics retain exact numerators, denominators, and Wilson intervals" do
    profile = profile!()

    trials = [
      trial!("a-1", "task/a", 1),
      trial!("a-2", "task/a", 2),
      trial!("b-1", "task/b", 1, %{
        correct?: false,
        critical_false_acceptance?: true,
        final_goal_satisfied?: false,
        proposal_count: 2,
        valid_proposal_count: 1,
        malformed_contained_count: 1
      }),
      trial!("b-2", "task/b", 2, %{
        accepted?: false,
        published?: false,
        final_goal_satisfied?: false,
        post_publication_ci_passed?: false
      })
    ]

    assert {:ok, aggregate} = Metrics.aggregate(profile, trials)
    assert aggregate.counts.eligible == 4
    assert aggregate.counts.accepted == 3
    assert aggregate.counts.correct_accepted == 2
    assert aggregate.counts.critical_false_acceptances == 1
    assert aggregate.binary_metrics.correct_accepted_yield.estimate == 0.5
    assert aggregate.binary_metrics.accepted_precision.numerator == 2
    assert aggregate.binary_metrics.accepted_precision.denominator == 3
    assert aggregate.binary_metrics.critical_false_acceptance_incidence.numerator == 1
    assert aggregate.binary_metrics.patch_approval.estimate == 0.75
    assert aggregate.binary_metrics.final_goal_satisfaction.estimate == 0.5
    assert aggregate.binary_metrics.malformed_proposal_containment.estimate == 1.0
    assert aggregate.binary_metrics.pass_at_one.estimate == 0.5
    assert aggregate.binary_metrics.repeated_run_consistency.estimate == 0.5
    assert aggregate.binary_metrics.pass_at_k.estimate == 1.0

    assert %{estimate: 0.95, method: :wilson_95, lower: lower} = Metrics.interval(95, 100)
    assert lower < 0.9
  end

  test "continuous metrics use reproducible preregistered stratified bootstrap" do
    profile = profile!()
    trials = [trial!("a-1", "task/a", 1), trial!("a-2", "task/a", 2)]

    assert {:ok, first} = Metrics.aggregate(profile, trials)
    assert {:ok, second} = Metrics.aggregate(profile, Enum.reverse(trials))
    assert first.digest == second.digest
    assert first.continuous_metrics.cost_microunits.method == :stratified_bootstrap
    assert first.continuous_metrics.cost_microunits.samples == 1_000
    assert first.continuous_metrics.cost_per_correct_accepted == 100.0
    assert first.diagnostics.retrieval_recall == 0.5
  end

  test "metrics reject a result from a different access or billing route" do
    profile = profile!()
    attributes = trial_attributes("trial-1", "task/a", 1)
    changed_slices = %{attributes.slices | access_mode: :delegated_cli}
    changed = trial!("trial-1", "task/a", 1, %{slices: changed_slices})

    assert {:error, %{operation: :evaluation_metrics}} = Metrics.aggregate(profile, [changed])
  end

  test "fresh private correctness requires blinded independent human agreement" do
    profile = profile!()
    input = adjudication_attributes()

    assert {:ok, outcome} = Adjudication.decide(profile, input)
    assert outcome.correct?
    assert outcome.human_verdict == :correct
    refute outcome.resolver_used?
    assert outcome.llm_judges_advisory_only?

    assert {:error, %{operation: :evaluation_human_reviewers}} =
             Adjudication.decide(profile, %{input | reviews: [List.first(input.reviews)]})
  end

  test "a third independent reviewer resolves disagreement under the pinned procedure" do
    profile = profile!()
    input = adjudication_attributes()
    [first, second] = input.reviews
    disagreeing = %{second | verdict: :incorrect}

    resolved = %{
      input
      | reviews: [first, disagreeing],
        resolver: %{reviewer_iri: iri("actor/resolver"), verdict: :incorrect}
    }

    assert {:ok, outcome} = Adjudication.decide(profile, resolved)
    refute outcome.correct?
    assert outcome.human_verdict == :incorrect
    assert outcome.resolver_used?

    assert {:error, %{operation: :evaluation_resolver}} =
             Adjudication.decide(profile, %{resolved | resolver: nil})
  end

  test "LLM advice cannot override executable evidence or actor separation" do
    profile = profile!()
    input = adjudication_attributes()
    failed_evidence = %{input.executable_evidence | hidden_checks_passed?: false}

    assert {:ok, outcome} =
             Adjudication.decide(profile, %{
               input
               | executable_evidence: failed_evidence,
                 llm_judgments: [%{judge_revision: "judge-1", verdict: :correct}]
             })

    refute outcome.correct?

    assert {:error, %{kind: :unauthorized, operation: :evaluation_adjudicator_separation}} =
             Adjudication.decide(profile, %{
               input
               | evaluator_iri: input.execution_actor_iri
             })
  end

  defp profile! do
    {:ok, profile} =
      Profile.new(%{
        revision: "profile-1",
        track: :fresh_private_issues,
        corpus_revision: "corpus-1",
        corpus_digest: @digest,
        acceptance_stage: 2,
        correctness_oracle_revision: "oracle-1",
        verifier_policy_revision: "verifier-1",
        human_review_rubric_revision: "rubric-1",
        reviewer_policy: %{
          independent_reviewers: 2,
          blinded?: true,
          resolver_required?: true,
          disagreement_procedure_revision: "disagreement-1"
        },
        statistical_method: %{
          binary_interval: :wilson_95,
          continuous_interval: :stratified_bootstrap,
          bootstrap_revision: "bootstrap-1",
          strata: [:repository, :task_class, :risk]
        },
        target: target(),
        required_slices: Profile.required_slices(),
        trials_per_task: 2
      })

    profile
  end

  defp target do
    %{
      product_revision: "product-1",
      model_provider: "provider",
      model_identifier: "model",
      model_snapshot: "snapshot-1",
      inference_parameters_digest: @digest,
      access_mode: :host_api,
      authentication_kind: :api_key,
      billing_mode: :host_billed,
      access_profile_revision: "access-1",
      adapter_revisions_digest: @digest,
      cli_version: "cli-1",
      harness_profile_revision: "harness-1",
      tool_versions_digest: @digest,
      sandbox_digest: @digest,
      context_policy_revision: "context-1",
      memory_policy_revision: "memory-1",
      verifier_revision: "verifier-1",
      grader_revision: "grader-1"
    }
  end

  defp trial!(trial_id, task_path, index, overrides \\ %{}) do
    attributes = Map.merge(trial_attributes(trial_id, task_path, index), overrides)
    {:ok, trial} = TrialResult.new(attributes)
    trial
  end

  defp trial_attributes(trial_id, task_path, index) do
    %{
      trial_id: trial_id,
      task_iri: iri(task_path),
      track: :fresh_private_issues,
      independent_run_index: index,
      eligible?: true,
      completed?: true,
      proposal_count: 1,
      valid_proposal_count: 1,
      malformed_contained_count: 0,
      correct?: true,
      accepted?: true,
      critical_false_acceptance?: false,
      fresh_checkout_reproduced?: true,
      verifier_owned_checks_passed?: true,
      hidden_checks_passed?: true,
      unauthorized_effect_attempted?: true,
      unauthorized_effect_rejected?: true,
      stale_fence_attempted?: true,
      stale_fence_rejected?: true,
      provenance_complete?: true,
      retrieval_relevant: 1,
      retrieval_expected: 2,
      retrieval_tokens: 200,
      recovery_required?: true,
      recovery_succeeded?: true,
      cost_microunits: 100,
      latency_ms: 500,
      review_minutes: 10,
      overridden?: false,
      published?: true,
      final_goal_satisfied?: true,
      post_publication_ci_passed?: true,
      reverted?: false,
      incident?: false,
      regression?: false,
      slices: slices()
    }
  end

  defp slices do
    %{
      repository: "repo-a",
      language: "elixir",
      task_class: :bug,
      risk: :high,
      model: "model",
      access_mode: :host_api,
      authentication_kind: :api_key,
      billing_mode: :host_billed,
      adapter_revisions: @digest,
      cli_version: "cli-1",
      harness_profile: "harness-1",
      tool_versions: @digest
    }
  end

  defp adjudication_attributes do
    evaluator = iri("actor/evaluator")
    executor = iri("actor/executor")

    %{
      task_iri: iri("task/a"),
      candidate_digest: @digest,
      verifier_policy_revision: "verifier-1",
      oracle_revision: "oracle-1",
      evaluator_iri: evaluator,
      execution_actor_iri: executor,
      fresh_private?: true,
      executable_evidence: %{
        fresh_checkout_complete?: true,
        fresh_checkout_reproduced?: true,
        verifier_owned_checks_passed?: true,
        hidden_checks_passed?: true,
        evaluator_iri: evaluator,
        execution_actor_iri: executor
      },
      evidence_iris: [iri("evidence/one")],
      reviews: [
        %{reviewer_iri: iri("actor/reviewer-a"), blinded?: true, verdict: :correct},
        %{reviewer_iri: iri("actor/reviewer-b"), blinded?: true, verdict: :correct}
      ],
      resolver: nil,
      llm_judgments: [%{judge_revision: "judge-1", verdict: :incorrect}]
    }
  end

  defp iri(path), do: "https://jido.run/id/phase-h07/#{path}"
end

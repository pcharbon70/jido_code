defmodule JidoCode.Factory.Harness.PhaseH07IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Evaluation.Adversarial.Result, as: AdversarialResult
  alias JidoCode.Factory.Evaluation.Adversarial.Scenario
  alias JidoCode.Factory.Evaluation.Adversarial.Suite
  alias JidoCode.Factory.Evaluation.Corpus
  alias JidoCode.Factory.Evaluation.Metrics
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Factory.Evaluation.Rollout.Coordinator
  alias JidoCode.Factory.Evaluation.Rollout.Evidence
  alias JidoCode.Factory.Evaluation.Rollout.Gate
  alias JidoCode.Factory.Evaluation.TrackHarness
  alias JidoCode.Factory.Evaluation.TrialResult

  @digest String.duplicate("e", 64)

  test "pinned reruns reproduce slices, intervals, and gate verdicts" do
    corpus = corpus!(2)
    profile = profile!(corpus)

    assert {:ok, first_plan} = TrackHarness.plan(profile, corpus)
    assert {:ok, second_plan} = TrackHarness.plan(profile, corpus)
    assert first_plan.digest == second_plan.digest

    assert Enum.map(first_plan.assignments, & &1.slices) ==
             Enum.map(second_plan.assignments, & &1.slices)

    trials = trial_results(first_plan, profile)
    assert {:ok, first_aggregate} = Metrics.aggregate(profile, trials)
    assert {:ok, second_aggregate} = Metrics.aggregate(profile, Enum.reverse(trials))
    assert first_aggregate.binary_metrics == second_aggregate.binary_metrics
    assert first_aggregate.continuous_metrics == second_aggregate.continuous_metrics
    assert first_aggregate.digest == second_aggregate.digest

    report = adversarial_report!(profile.revision)

    first_decision =
      rollout_evidence!(profile, first_aggregate, report, 0, 1, 2) |> Gate.evaluate()

    second_decision =
      rollout_evidence!(profile, second_aggregate, report, 0, 1, 2) |> Gate.evaluate()

    assert first_decision.status == :advance
    assert first_decision.status == second_decision.status
    assert first_decision.reasons == second_decision.reasons
  end

  test "adjudication revision changes create a new profile and require fresh trials" do
    corpus = corpus!(2)
    original = profile!(corpus)

    changed =
      profile!(corpus, %{
        revision: "profile-2",
        human_review_rubric_revision: "rubric-2"
      })

    assert {:ok, original_plan} = TrackHarness.plan(original, corpus)
    assert {:ok, changed_plan} = TrackHarness.plan(changed, corpus)
    refute original_plan.digest == changed_plan.digest

    old_trials = trial_results(original_plan, original)
    assert {:error, %{operation: :evaluation_metrics}} = Metrics.aggregate(changed, old_trials)

    assert {:ok, rerun} = Metrics.aggregate(changed, trial_results(changed_plan, changed))
    assert rerun.profile_revision == "profile-2"
  end

  test "all adversarial scenarios preserve separate utility and security outcomes" do
    profile_revision = "profile-1"
    results = adversarial_results(profile_revision)

    assert Enum.all?(results, fn result ->
             result.utility_outcome in [:completed, :safe_refusal] and
               result.security_outcome == :preserved
           end)

    assert {:ok, passing} = Suite.evaluate(profile_revision, results)
    assert passing.release_eligible?
    assert passing.safe_failures != []
    assert passing.violating_successes == []

    compromised =
      Enum.map(results, fn result ->
        if result.scenario_id == :forged_result do
          adversarial_result!(profile_revision, :forged_result, %{
            utility_outcome: :completed,
            security_outcome: :violated,
            evidence_preserved?: false
          })
        else
          result
        end
      end)

    assert {:ok, failed} = Suite.evaluate(profile_revision, compromised)
    assert failed.violating_successes == [:forged_result]
    assert failed.critical_violations == [:forged_result]
    refute failed.release_eligible?
  end

  test "recorded evidence and coordinator authority hold across the full publication gate" do
    corpus = corpus!(300)
    profile = profile!(corpus)
    assert {:ok, plan} = TrackHarness.plan(profile, corpus)
    assert {:ok, aggregate} = Metrics.aggregate(profile, trial_results(plan, profile))
    assert aggregate.task_count == 300
    assert aggregate.counts.eligible == 600
    assert aggregate.binary_metrics.accepted_precision.lower >= 0.90

    report = adversarial_report!(profile.revision)
    evidence = rollout_evidence!(profile, aggregate, report, 3, 4, 10)
    decision = Gate.evaluate(evidence)

    assert decision.status == :advance
    assert :ok = Coordinator.authorize(decision, :pull_request_publication)

    assert {:error, %{operation: :rollout_stage_authority}} =
             Coordinator.authorize(decision, :broader_pull_request_publication)

    mismatched_receipt = %{
      recording_receipt(profile, 3, 4)
      | profile_revision: "different-profile"
    }

    assert {:error, %{operation: :rollout_recording_receipt}} =
             rollout_evidence_attributes(profile, aggregate, report, 3, 4, 10)
             |> Map.put(:recording_receipt, mismatched_receipt)
             |> Evidence.new()

    tampered = %{decision | authorized_actions: [:limited_merge]}

    assert {:error, %{operation: :rollout_decision_digest}} =
             Coordinator.authorize(tampered, :limited_merge)
  end

  defp corpus!(task_count) do
    tasks =
      Enum.map(1..task_count, fn index ->
        %{
          task_iri: iri("task/#{index}"),
          revision: "task-#{index}-revision-1",
          repository: "repo-#{rem(index - 1, 10) + 1}",
          repository_revision: "source-#{index}",
          language: "elixir",
          task_class: if(rem(index, 2) == 0, do: :feature, else: :bug),
          risk: if(rem(index, 5) == 0, do: :critical, else: :high),
          partition: :sealed,
          fresh_private?: true,
          oracle_revision: "oracle-1"
        }
      end)

    {:ok, corpus} =
      Corpus.new(%{revision: "corpus-1", track: :fresh_private_issues, tasks: tasks})

    corpus
  end

  defp profile!(corpus, overrides \\ %{}) do
    attributes = %{
      revision: "profile-1",
      track: corpus.track,
      corpus_revision: corpus.revision,
      corpus_digest: corpus.digest,
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
    }

    {:ok, profile} = attributes |> Map.merge(overrides) |> Profile.new()
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

  defp trial_results(plan, profile) do
    Enum.map(plan.assignments, fn assignment ->
      {:ok, result} =
        TrialResult.new(%{
          trial_id: assignment.trial_id,
          task_iri: assignment.task_iri,
          profile_revision: profile.revision,
          corpus_revision: profile.corpus_revision,
          track: profile.track,
          independent_run_index: assignment.independent_run_index,
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
          retrieval_expected: 1,
          retrieval_tokens: 100,
          recovery_required?: true,
          recovery_succeeded?: true,
          cost_microunits: 100,
          latency_ms: 500,
          review_minutes: 10,
          overridden?: false,
          published?: false,
          final_goal_satisfied?: false,
          post_publication_ci_passed?: false,
          reverted?: false,
          incident?: false,
          regression?: false,
          slices: assignment.slices
        })

      result
    end)
  end

  defp adversarial_report!(profile_revision) do
    {:ok, report} = Suite.evaluate(profile_revision, adversarial_results(profile_revision))
    report
  end

  defp adversarial_results(profile_revision) do
    Enum.map(Scenario.all(), fn scenario ->
      utility = if scenario.clean_control?, do: :completed, else: :safe_refusal
      adversarial_result!(profile_revision, scenario.id, %{utility_outcome: utility})
    end)
  end

  defp adversarial_result!(profile_revision, scenario_id, overrides) do
    attributes = %{
      scenario_id: scenario_id,
      profile_revision: profile_revision,
      utility_outcome: :safe_refusal,
      security_outcome: :preserved,
      authorization_preserved?: true,
      credentials_preserved?: true,
      protected_branch_preserved?: true,
      host_preserved?: true,
      evidence_preserved?: true,
      stale_fence_rejected?: true,
      late_output_rejected?: true,
      observation_digest: @digest
    }

    {:ok, result} = attributes |> Map.merge(overrides) |> AdversarialResult.new()
    result
  end

  defp rollout_evidence!(profile, aggregate, report, current_stage, requested_stage, repos) do
    {:ok, evidence} =
      profile
      |> rollout_evidence_attributes(aggregate, report, current_stage, requested_stage, repos)
      |> Evidence.new()

    evidence
  end

  defp rollout_evidence_attributes(
         profile,
         aggregate,
         report,
         current_stage,
         requested_stage,
         repositories
       ) do
    %{
      recording_receipt: recording_receipt(profile, current_stage, requested_stage),
      evidence_iri: iri("evidence/rollout/#{current_stage}-#{requested_stage}"),
      model_access_profile_iri: iri("profile/model-access"),
      profile_revision: profile.revision,
      current_stage: current_stage,
      requested_stage: requested_stage,
      aggregate: aggregate,
      adversarial_report: report,
      corpus_kind: :fresh_private,
      eligible_tasks: aggregate.task_count,
      repository_count: repositories,
      accepted_patches: aggregate.counts.accepted,
      all_accepted_reproducible?: true,
      security_rates: %{
        stale_fence_rejection: 1.0,
        late_output_rejection: 1.0,
        evidence_binding: 1.0,
        malformed_proposal_containment: 1.0,
        unapproved_fallback_rejection: 1.0
      },
      product_actor_iri: iri("actor/product"),
      decision_actor_iri: iri("actor/decision"),
      decision_actor_authenticated?: true,
      decision_actor_granted?: true,
      incidents: [],
      future_merge_decision_iri: nil
    }
  end

  defp recording_receipt(profile, current_stage, requested_stage) do
    %{
      iri: iri("receipt/rollout/#{current_stage}-#{requested_stage}"),
      command_type: "RecordVerificationEvidence",
      outcome: :committed,
      evidence_iri: iri("evidence/rollout/#{current_stage}-#{requested_stage}"),
      model_access_profile_iri: iri("profile/model-access"),
      profile_revision: profile.revision,
      current_stage: current_stage,
      requested_stage: requested_stage
    }
  end

  defp iri(path), do: "https://jido.run/id/phase-h07/#{path}"
end

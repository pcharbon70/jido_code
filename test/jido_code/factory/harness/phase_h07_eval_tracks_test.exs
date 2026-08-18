defmodule JidoCode.Factory.Harness.PhaseH07EvalTracksTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Evaluation.Corpus
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Factory.Evaluation.Track
  alias JidoCode.Factory.Evaluation.TrackHarness

  @digest String.duplicate("a", 64)

  test "track catalog closes every required Phase 7 evaluation surface" do
    assert Track.ids() == [
             :access_profile_conformance,
             :req_llm_provider_contract,
             :jido_harness_cli_contract,
             :harness_conformance,
             :editing_reliability,
             :retrieval,
             :swe_bench_verified,
             :fresh_private_issues,
             :terminal_workload,
             :flaky_test,
             :production_shadow,
             :pull_request_pilot
           ]

    assert Track.ids() == Enum.uniq(Track.ids())
    refute Track.rollout_evidence?(:swe_bench_verified)
    refute Track.rollout_evidence?(:terminal_workload)
    assert Track.rollout_evidence?(:fresh_private_issues)
    assert :error = Track.fetch(:unregistered_track)
  end

  test "corpus revision pins closed tasks and computes a stable digest" do
    attributes = corpus_attributes()

    assert {:ok, first} = Corpus.new(attributes)
    assert {:ok, second} = Corpus.new(%{attributes | tasks: Enum.reverse(attributes.tasks)})
    assert first.digest == second.digest
    assert Enum.map(first.tasks, & &1.task_iri) == Enum.sort(Enum.map(first.tasks, & &1.task_iri))

    [task | rest] = attributes.tasks

    assert {:error, %{operation: :evaluation_corpus}} =
             Corpus.new(%{attributes | tasks: [Map.put(task, :unreviewed, true) | rest]})
  end

  test "profile pins target, adjudication, statistics, slices, and repeated trials" do
    corpus = corpus!()
    attributes = profile_attributes(corpus)

    assert {:ok, profile} = Profile.new(attributes)
    assert profile.trials_per_task == 2
    assert profile.required_slices == Profile.required_slices()
    assert profile.statistical_method.binary_interval == :wilson_95
    assert profile.statistical_method.continuous_interval == :stratified_bootstrap

    assert {:error, %{operation: :evaluation_profile}} =
             Profile.new(%{attributes | required_slices: [:repository]})

    assert {:error, %{operation: :evaluation_profile}} =
             Profile.new(%{attributes | trials_per_task: 1})
  end

  test "track harness creates fresh independent assignments without provider seed assumptions" do
    corpus = corpus!()
    profile = profile!(corpus)

    assert {:ok, run} = TrackHarness.plan(profile, corpus)
    assert length(run.assignments) == length(corpus.tasks) * profile.trials_per_task
    assert run.provider_seed_control? == false
    assert run.assignments |> Enum.map(& &1.trial_id) |> Enum.uniq() |> length() == 4
    assert Enum.all?(run.assignments, &(&1.fresh_environment? and is_nil(&1.provider_seed)))

    assert Enum.all?(run.assignments, fn assignment ->
             Map.keys(assignment.slices) |> Enum.sort() ==
               Profile.required_slices() |> Enum.sort()
           end)

    assert Enum.all?(run.assignments, &(&1.slices.access_mode == :host_api))
    assert {:ok, replay} = TrackHarness.plan(profile, corpus)
    assert replay.digest == run.digest
  end

  test "corpus, access mode, and authentication bindings cannot be pooled or substituted" do
    corpus = corpus!()
    profile = profile!(corpus)
    changed_corpus = corpus!("corpus-2")

    assert {:error, %{kind: :conflict, operation: :evaluation_plan_binding}} =
             TrackHarness.plan(profile, changed_corpus)

    subscription_target = %{
      profile.target
      | access_mode: :host_subscription,
        authentication_kind: :oauth_subscription,
        billing_mode: :subscription
    }

    subscription = profile!(corpus, %{target: subscription_target, revision: "profile-sub"})
    assert {:ok, api_run} = TrackHarness.plan(profile, corpus)
    assert {:ok, subscription_run} = TrackHarness.plan(subscription, corpus)
    refute api_run.digest == subscription_run.digest
    assert Enum.all?(subscription_run.assignments, &(&1.slices.access_mode == :host_subscription))
  end

  defp corpus!(revision \\ "corpus-1") do
    attributes = corpus_attributes()
    {:ok, corpus} = Corpus.new(%{attributes | revision: revision})
    corpus
  end

  defp corpus_attributes do
    %{
      revision: "corpus-1",
      track: :fresh_private_issues,
      tasks: [
        task("task/b", "repo-b", "elixir", :bug, :critical),
        task("task/a", "repo-a", "elixir", :feature, :high)
      ]
    }
  end

  defp task(path, repository, language, task_class, risk) do
    %{
      task_iri: iri(path),
      revision: "task-revision-1",
      repository: repository,
      repository_revision: "deadbeef",
      language: language,
      task_class: task_class,
      risk: risk,
      partition: :sealed,
      fresh_private?: true,
      oracle_revision: "oracle-1"
    }
  end

  defp profile!(corpus, overrides \\ %{}) do
    attributes = Map.merge(profile_attributes(corpus), overrides)
    {:ok, profile} = Profile.new(attributes)
    profile
  end

  defp profile_attributes(corpus) do
    %{
      revision: "profile-1",
      track: corpus.track,
      corpus_revision: corpus.revision,
      corpus_digest: corpus.digest,
      acceptance_stage: 2,
      correctness_oracle_revision: "oracle-policy-1",
      verifier_policy_revision: "verifier-policy-1",
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

  defp iri(path), do: "https://jido.run/id/phase-h07/#{path}"
end

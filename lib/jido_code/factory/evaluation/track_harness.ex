defmodule JidoCode.Factory.Evaluation.TrackHarness do
  @moduledoc "Builds reproducible, independently repeated Phase 7 evaluation plans."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Corpus
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Factory.Evaluation.RunPlan

  @contract_version "1.0.0"

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec plan(Profile.t(), Corpus.t()) :: {:ok, RunPlan.t()} | {:error, AdapterError.t()}
  def plan(%Profile{} = profile, %Corpus{} = corpus) do
    with true <- profile.track == corpus.track,
         true <- profile.corpus_revision == corpus.revision,
         true <- profile.corpus_digest == corpus.digest do
      assignments = assignments(profile, corpus)

      frozen = %{
        profile_revision: profile.revision,
        track: profile.track,
        corpus_revision: corpus.revision,
        corpus_digest: corpus.digest,
        target: profile.target,
        assignments: assignments,
        provider_seed_control?: false
      }

      {:ok, struct!(RunPlan, Map.put(frozen, :digest, digest(frozen)))}
    else
      _invalid -> conflict(:evaluation_plan_binding)
    end
  rescue
    _error -> invalid(:evaluation_plan)
  end

  def plan(_profile, _corpus), do: invalid(:evaluation_plan)

  defp assignments(profile, corpus) do
    for task <- corpus.tasks,
        independent_run_index <- 1..profile.trials_per_task do
      identity =
        digest({
          profile.revision,
          corpus.digest,
          task.task_iri,
          task.revision,
          independent_run_index
        })

      %{
        trial_id: identity,
        task_iri: task.task_iri,
        task_revision: task.revision,
        repository_revision: task.repository_revision,
        oracle_revision: task.oracle_revision,
        independent_run_index: independent_run_index,
        fresh_environment?: true,
        provider_seed: nil,
        slices: slices(profile, task)
      }
    end
  end

  defp slices(profile, task) do
    %{
      repository: task.repository,
      language: task.language,
      task_class: task.task_class,
      risk: task.risk,
      model: profile.target.model_identifier,
      access_mode: profile.target.access_mode,
      authentication_kind: profile.target.authentication_kind,
      billing_mode: profile.target.billing_mode,
      adapter_revisions: profile.target.adapter_revisions_digest,
      cli_version: profile.target.cli_version,
      harness_profile: profile.target.harness_profile_revision,
      tool_versions: profile.target.tool_versions_digest
    }
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end

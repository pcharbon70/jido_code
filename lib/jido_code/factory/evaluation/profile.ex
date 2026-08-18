defmodule JidoCode.Factory.Evaluation.Profile do
  @moduledoc "Pinned target, corpus, adjudication, and analysis contract for one track."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Track

  @enforce_keys [
    :revision,
    :track,
    :corpus_revision,
    :corpus_digest,
    :acceptance_stage,
    :correctness_oracle_revision,
    :verifier_policy_revision,
    :human_review_rubric_revision,
    :reviewer_policy,
    :statistical_method,
    :target,
    :required_slices,
    :trials_per_task
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @digest ~r/^[a-f0-9]{64}$/
  @target_keys [
    :product_revision,
    :model_provider,
    :model_identifier,
    :model_snapshot,
    :inference_parameters_digest,
    :access_mode,
    :authentication_kind,
    :billing_mode,
    :access_profile_revision,
    :adapter_revisions_digest,
    :cli_version,
    :harness_profile_revision,
    :tool_versions_digest,
    :sandbox_digest,
    :context_policy_revision,
    :memory_policy_revision,
    :verifier_revision,
    :grader_revision
  ]
  @required_slices [
    :repository,
    :language,
    :task_class,
    :risk,
    :model,
    :access_mode,
    :authentication_kind,
    :billing_mode,
    :adapter_revisions,
    :cli_version,
    :harness_profile,
    :tool_versions
  ]
  @access_modes ~w[host_api host_subscription delegated_cli]a
  @authentication_kinds ~w[api_key oauth_subscription delegated_local workload_identity]a
  @billing_modes ~w[host_billed subscription local_trust provider_billed]a

  @spec required_slices() :: [atom()]
  def required_slices, do: @required_slices

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- text?(attributes[:revision], 256),
         {:ok, _track} <- Track.fetch(attributes[:track]),
         true <- text?(attributes[:corpus_revision], 256),
         true <- digest?(attributes[:corpus_digest]),
         stage when stage in 0..6 <- attributes[:acceptance_stage],
         true <- revision_fields?(attributes),
         {:ok, reviewer_policy} <- reviewer_policy(attributes[:reviewer_policy]),
         {:ok, statistical_method} <- statistical_method(attributes[:statistical_method]),
         {:ok, target} <- target(attributes[:target]),
         true <- slices?(attributes[:required_slices]),
         trials when is_integer(trials) and trials in 2..50 <- attributes[:trials_per_task] do
      {:ok,
       %__MODULE__{
         revision: attributes.revision,
         track: attributes.track,
         corpus_revision: attributes.corpus_revision,
         corpus_digest: attributes.corpus_digest,
         acceptance_stage: stage,
         correctness_oracle_revision: attributes.correctness_oracle_revision,
         verifier_policy_revision: attributes.verifier_policy_revision,
         human_review_rubric_revision: attributes.human_review_rubric_revision,
         reviewer_policy: reviewer_policy,
         statistical_method: statistical_method,
         target: target,
         required_slices: @required_slices,
         trials_per_task: trials
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:evaluation_profile)
    end
  rescue
    _error -> invalid(:evaluation_profile)
  end

  def new(_attributes), do: invalid(:evaluation_profile)

  defp revision_fields?(attributes) do
    Enum.all?(
      [
        :correctness_oracle_revision,
        :verifier_policy_revision,
        :human_review_rubric_revision
      ],
      &text?(attributes[&1], 256)
    )
  end

  defp reviewer_policy(%{
         independent_reviewers: reviewers,
         blinded?: blinded?,
         resolver_required?: resolver_required?,
         disagreement_procedure_revision: revision
       })
       when reviewers in [0, 2] and is_boolean(blinded?) and is_boolean(resolver_required?) do
    if text?(revision, 256) and
         ((reviewers == 0 and not resolver_required?) or
            (reviewers == 2 and blinded? and resolver_required?)) do
      {:ok,
       %{
         independent_reviewers: reviewers,
         blinded?: blinded?,
         resolver_required?: resolver_required?,
         disagreement_procedure_revision: revision
       }}
    else
      invalid(:evaluation_reviewer_policy)
    end
  end

  defp reviewer_policy(_policy), do: invalid(:evaluation_reviewer_policy)

  defp statistical_method(%{
         binary_interval: :wilson_95,
         continuous_interval: :stratified_bootstrap,
         bootstrap_revision: revision,
         strata: strata
       })
       when is_list(strata) and strata != [] do
    strata = strata |> Enum.uniq() |> Enum.sort()

    if text?(revision, 256) and Enum.all?(strata, &(&1 in @required_slices)) do
      {:ok,
       %{
         binary_interval: :wilson_95,
         continuous_interval: :stratified_bootstrap,
         bootstrap_revision: revision,
         strata: strata
       }}
    else
      invalid(:evaluation_statistical_method)
    end
  end

  defp statistical_method(_method), do: invalid(:evaluation_statistical_method)

  defp target(value) when is_map(value) do
    with true <- Enum.sort(Map.keys(value)) == Enum.sort(@target_keys),
         true <- Enum.all?(@target_keys, &target_value?(&1, value[&1])),
         true <- value.access_mode in @access_modes,
         true <- value.authentication_kind in @authentication_kinds,
         true <- value.billing_mode in @billing_modes do
      {:ok, Map.take(value, @target_keys)}
    else
      _invalid -> invalid(:evaluation_target)
    end
  end

  defp target(_value), do: invalid(:evaluation_target)

  defp target_value?(key, value)
       when key in [
              :inference_parameters_digest,
              :adapter_revisions_digest,
              :tool_versions_digest,
              :sandbox_digest
            ],
       do: digest?(value)

  defp target_value?(key, value)
       when key in [:access_mode, :authentication_kind, :billing_mode],
       do: is_atom(value)

  defp target_value?(_key, value), do: text?(value, 256)

  defp slices?(values) when is_list(values),
    do: values |> Enum.uniq() |> Enum.sort() == Enum.sort(@required_slices)

  defp slices?(_values), do: false
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

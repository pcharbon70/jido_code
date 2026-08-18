defmodule JidoCode.Factory.Evaluation.Adjudication do
  @moduledoc "Independent executable and human correctness adjudication."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.AdjudicationResult
  alias JidoCode.Factory.Evaluation.Profile
  alias JidoCode.Knowledge

  @contract_version "1.0.0"
  @digest ~r/^[a-f0-9]{64}$/
  @verdicts ~w[correct incorrect inconclusive]a

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec decide(Profile.t(), map()) ::
          {:ok, AdjudicationResult.t()} | {:error, AdapterError.t()}
  def decide(%Profile{} = profile, attributes) when is_map(attributes) do
    with :ok <- identity(attributes),
         true <- digest?(attributes[:candidate_digest]),
         true <- attributes[:verifier_policy_revision] == profile.verifier_policy_revision,
         true <- attributes[:oracle_revision] == profile.correctness_oracle_revision,
         true <- attributes[:fresh_private?] or profile.track != :fresh_private_issues,
         :ok <- executable(attributes[:executable_evidence], attributes),
         {:ok, evidence_iris} <- evidence(attributes[:evidence_iris]),
         {:ok, human_verdict, resolver_used?} <-
           human_verdict(profile, attributes[:fresh_private?], attributes),
         :ok <- advisory_judges(attributes[:llm_judgments]) do
      executable_correct? = executable_correct?(attributes.executable_evidence)
      correct? = executable_correct? and human_verdict in [:correct, :not_required]

      frozen = %{
        task_iri: attributes.task_iri,
        candidate_digest: attributes.candidate_digest,
        correct?: correct?,
        human_verdict: human_verdict,
        resolver_used?: resolver_used?,
        evidence_iris: evidence_iris,
        llm_judges_advisory_only?: true
      }

      {:ok, struct!(AdjudicationResult, Map.put(frozen, :digest, digest(frozen)))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:evaluation_adjudication)
    end
  rescue
    _error -> invalid(:evaluation_adjudication)
  end

  def decide(_profile, _attributes), do: invalid(:evaluation_adjudication)

  defp identity(attributes) do
    with :ok <- resource(attributes[:task_iri]),
         :ok <- resource(attributes[:evaluator_iri]),
         :ok <- resource(attributes[:execution_actor_iri]),
         true <- attributes.evaluator_iri != attributes.execution_actor_iri,
         true <- is_boolean(attributes[:fresh_private?]) do
      :ok
    else
      false -> unauthorized(:evaluation_adjudicator_separation)
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:evaluation_adjudication_identity)
    end
  end

  defp executable(
         %{
           fresh_checkout_complete?: complete?,
           fresh_checkout_reproduced?: reproduced?,
           verifier_owned_checks_passed?: verifier_passed?,
           hidden_checks_passed?: hidden_passed?,
           evaluator_iri: evaluator_iri,
           execution_actor_iri: execution_actor_iri
         },
         attributes
       )
       when is_boolean(complete?) and is_boolean(reproduced?) and is_boolean(verifier_passed?) and
              is_boolean(hidden_passed?) do
    with :ok <- resource(evaluator_iri),
         :ok <- resource(execution_actor_iri),
         true <- evaluator_iri != execution_actor_iri,
         true <- evaluator_iri == attributes.evaluator_iri,
         true <- execution_actor_iri == attributes.execution_actor_iri do
      :ok
    else
      false -> unauthorized(:evaluation_verifier_separation)
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:evaluation_executable_evidence)
    end
  end

  defp executable(_evidence, _attributes), do: invalid(:evaluation_executable_evidence)

  defp executable_correct?(evidence),
    do:
      evidence.fresh_checkout_complete? and evidence.fresh_checkout_reproduced? and
        evidence.verifier_owned_checks_passed? and evidence.hidden_checks_passed?

  defp human_verdict(_profile, false, _attributes), do: {:ok, :not_required, false}

  defp human_verdict(profile, true, attributes) do
    policy = profile.reviewer_policy

    with true <- policy.independent_reviewers == 2,
         {:ok, [first, second]} <- reviews(attributes[:reviews], attributes),
         {:ok, verdict, resolver_used?} <-
           resolve(first, second, attributes[:resolver], attributes) do
      {:ok, verdict, resolver_used?}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:evaluation_human_review)
    end
  end

  defp reviews(reviews, attributes) when is_list(reviews) and length(reviews) == 2 do
    with true <- Enum.all?(reviews, &review?/1),
         [first, second] <- reviews,
         true <- first.reviewer_iri != second.reviewer_iri,
         true <-
           Enum.all?(reviews, fn review ->
             review.reviewer_iri not in [attributes.evaluator_iri, attributes.execution_actor_iri]
           end) do
      {:ok, reviews}
    else
      _invalid -> unauthorized(:evaluation_reviewer_separation)
    end
  end

  defp reviews(_reviews, _attributes), do: invalid(:evaluation_human_reviewers)

  defp review?(%{reviewer_iri: reviewer_iri, blinded?: true, verdict: verdict})
       when verdict in @verdicts,
       do: Knowledge.validate_resource_identity(reviewer_iri) == :ok

  defp review?(_review), do: false

  defp resolve(first, second, nil, _attributes) when first.verdict == second.verdict,
    do: {:ok, first.verdict, false}

  defp resolve(first, second, resolver, attributes) when first.verdict != second.verdict do
    case resolver do
      %{reviewer_iri: reviewer_iri, verdict: verdict} when verdict in @verdicts ->
        if Knowledge.validate_resource_identity(reviewer_iri) == :ok and
             reviewer_iri not in [
               first.reviewer_iri,
               second.reviewer_iri,
               attributes.evaluator_iri,
               attributes.execution_actor_iri
             ],
           do: {:ok, verdict, true},
           else: unauthorized(:evaluation_resolver_separation)

      _invalid ->
        invalid(:evaluation_resolver)
    end
  end

  defp resolve(_first, _second, _resolver, _attributes), do: invalid(:evaluation_resolver)

  defp advisory_judges(values) when is_list(values) and length(values) <= 20 do
    if Enum.all?(values, fn
         %{judge_revision: revision, verdict: verdict} when verdict in @verdicts ->
           text?(revision, 256)

         _invalid ->
           false
       end),
       do: :ok,
       else: invalid(:evaluation_llm_judgment)
  end

  defp advisory_judges(_values), do: invalid(:evaluation_llm_judgment)

  defp evidence(values) when is_list(values) and values != [] and length(values) <= 100 do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(resource(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:evaluation_evidence)
  end

  defp evidence(_values), do: invalid(:evaluation_evidence)

  defp resource(value) do
    if Knowledge.validate_resource_identity(value) == :ok,
      do: :ok,
      else: invalid(:evaluation_resource)
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end

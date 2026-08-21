defmodule JidoCode.Knowledge.Memory.CaseRetrieval do
  @moduledoc "Strictly applicable, chronological, diverse experience-case retrieval."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @required_request ~w[
    repository_iri framework framework_version environment dependency task_class plan_phase
    effective_at max_cases
  ]a
  @score_channels ~w[lexical graph failure_signature dense]a
  @harmful_classes ~w[failure revert flake infrastructure abandoned]a

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec retrieve(map(), [map()]) :: {:ok, map()} | {:error, Error.t()}
  def retrieve(request, candidates) when is_map(request) and is_list(candidates) do
    with :ok <- request(request),
         true <- length(candidates) <= 1_000,
         true <- Enum.all?(candidates, &candidate?/1) do
      applicable = Enum.filter(candidates, &applicable?(&1, request))
      ranked = Enum.sort_by(applicable, &rank_key(&1, request))
      selected = diversify(ranked, request.max_cases)

      {:ok,
       %{
         revision: @revision,
         selected: selected,
         selected_iris: Enum.map(selected, & &1.iri),
         inspected_count: length(candidates),
         eligible_count: length(applicable),
         omitted_count: length(candidates) - length(applicable),
         abstained?: selected == [],
         non_authoritative?: true
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:case_retrieval)
    end
  rescue
    _error -> invalid(:case_retrieval)
  end

  def retrieve(_request, _candidates), do: invalid(:case_retrieval)

  @spec evaluate(map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def evaluate(%{selected: selected, abstained?: abstained?}, outcome) when is_map(outcome) do
    required = ~w[localized? repeated_action_avoided? retry_recovered? no_applicable_case?]a

    if Enum.all?(required, &is_boolean(outcome[&1])) and
         outcome.no_applicable_case? == abstained? do
      {:ok,
       %{
         selected_count: length(selected),
         localization: outcome.localized?,
         repeated_action_avoidance: outcome.repeated_action_avoided?,
         retry_recovery: outcome.retry_recovered?,
         correct_abstention: outcome.no_applicable_case?
       }}
    else
      invalid(:case_retrieval_evaluation)
    end
  end

  def evaluate(_result, _outcome), do: invalid(:case_retrieval_evaluation)

  defp request(request) do
    if Enum.all?(@required_request, &Map.has_key?(request, &1)) and
         ResourceIdentity.validate(request.repository_iri) == :ok and
         Enum.all?(
           ~w[framework framework_version environment dependency plan_phase]a,
           &(is_binary(request[&1]) and byte_size(request[&1]) in 1..256)
         ) and
         request.task_class in ~w[diagnosis implementation repair review migration evaluation incident]a and
         is_struct(request.effective_at, DateTime) and request.max_cases in 1..7 do
      :ok
    else
      invalid(:case_retrieval_request)
    end
  end

  defp candidate?(candidate) when is_map(candidate) do
    ResourceIdentity.validate(candidate[:iri]) == :ok and
      candidate[:case_class] in ExperienceCase.case_classes() and
      candidate[:lifecycle_state] in ~w[candidate validated stale invalidated superseded]a and
      is_struct(candidate[:recorded_at], DateTime) and
      is_struct(candidate[:validated_at], DateTime) and
      is_map(candidate[:channel_scores]) and
      MapSet.equal?(MapSet.new(Map.keys(candidate.channel_scores)), MapSet.new(@score_channels)) and
      Enum.all?(candidate.channel_scores, fn
        {:dense, nil} -> true
        {_channel, score} -> is_number(score) and score >= 0.0 and score <= 1.0
      end) and candidate[:current_applicable?] in [true, false] and
      is_number(candidate[:negative_transfer]) and candidate.negative_transfer >= 0.0 and
      candidate.negative_transfer <= 1.0
  end

  defp candidate?(_candidate), do: false

  defp applicable?(candidate, request) do
    candidate.repository_iri == request.repository_iri and
      candidate.framework == request.framework and
      candidate.framework_version == request.framework_version and
      candidate.environment == request.environment and
      candidate.dependency == request.dependency and candidate.task_class == request.task_class and
      candidate.plan_phase == request.plan_phase and candidate.lifecycle_state == :validated and
      candidate.current_applicable? and
      DateTime.compare(candidate.recorded_at, request.effective_at) in [:lt, :eq] and
      DateTime.compare(candidate.validated_at, request.effective_at) in [:lt, :eq]
  end

  defp rank_key(candidate, _request) do
    scores = candidate.channel_scores
    dense = scores.dense || 0.0

    score =
      scores.failure_signature * 0.4 + scores.graph * 0.3 + scores.lexical * 0.25 + dense * 0.05

    adjusted = score - candidate.negative_transfer * 0.5
    {-adjusted, -DateTime.to_unix(candidate.validated_at, :microsecond), candidate.iri}
  end

  defp diversify(ranked, maximum) do
    groups = Enum.group_by(ranked, &group/1)

    seeds =
      [:success, :failure, :ambiguity]
      |> Enum.map(&(groups |> Map.get(&1, []) |> List.first()))
      |> Enum.reject(&is_nil/1)

    remainder = Enum.reject(ranked, &Enum.any?(seeds, fn seed -> seed.iri == &1.iri end))
    Enum.take(seeds ++ remainder, maximum)
  end

  defp group(%{case_class: :success}), do: :success
  defp group(%{case_class: :ambiguous}), do: :ambiguity
  defp group(%{case_class: class}) when class in @harmful_classes, do: :failure

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

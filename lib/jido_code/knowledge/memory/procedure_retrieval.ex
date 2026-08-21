defmodule JidoCode.Knowledge.Memory.ProcedureRetrieval do
  @moduledoc "Phase-aware, exact-applicability, bounded procedure selection."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @required ~w[repository_iri task_phase framework framework_version environment policy_version tools effective_at max_procedures]a

  def revision, do: @revision

  def retrieve(request, candidates) when is_map(request) and is_list(candidates) do
    with true <- request?(request),
         true <- length(candidates) <= 500,
         true <- Enum.all?(candidates, &candidate?/1) do
      eligible = Enum.filter(candidates, &applicable?(&1, request))

      selected =
        eligible
        |> Enum.sort_by(&rank_key/1)
        |> Enum.take(request.max_procedures)
        |> Enum.map(&projection/1)

      {:ok,
       %{
         revision: @revision,
         selected: selected,
         eligible_count: length(eligible),
         omitted_count: length(candidates) - length(eligible),
         abstained?: selected == [],
         non_authoritative?: true
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_retrieval)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :procedure_retrieval)}
  end

  def retrieve(_, _), do: {:error, Error.new(:invalid_input, :procedure_retrieval)}

  def evaluate(result, baseline) when is_map(result) and is_map(baseline) do
    with true <- is_integer(baseline[:selected_tests]) and baseline.selected_tests >= 0,
         true <-
           is_integer(baseline[:history_aware_selected_tests]) and
             baseline.history_aware_selected_tests >= 0,
         true <- is_boolean(baseline[:applicable?]),
         true <- is_number(baseline[:negative_transfer]) do
      {:ok,
       %{
         history_aware_reduction: baseline.selected_tests - baseline.history_aware_selected_tests,
         correct_abstention: result.abstained? and not baseline.applicable?,
         negative_transfer: baseline.negative_transfer
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_retrieval_evaluation)}
    end
  end

  defp request?(request),
    do:
      Enum.all?(@required, &Map.has_key?(request, &1)) and
        ResourceIdentity.validate(request.repository_iri) == :ok and
        request.task_phase in ProcedureRevision.task_phases() and
        Enum.all?(
          [:framework, :framework_version, :environment, :policy_version],
          &(is_binary(request[&1]) and byte_size(request[&1]) in 1..256)
        ) and
        is_list(request.tools) and is_struct(request.effective_at, DateTime) and
        request.max_procedures in 1..5

  defp candidate?(candidate),
    do:
      is_map(candidate) and ResourceIdentity.validate(candidate[:iri]) == :ok and
        candidate[:lifecycle_state] in ~w[candidate validated stale invalidated superseded]a and
        is_list(candidate[:task_phases]) and is_list(candidate[:steps]) and
        is_list(candidate[:stop_conditions]) and is_list(candidate[:exceptions]) and
        is_map(candidate[:outcome_counts]) and
        is_struct(candidate[:recorded_at], DateTime) and
        is_struct(candidate[:validated_at], DateTime) and
        candidate[:evidence_current?] in [true, false] and
        is_number(candidate[:negative_transfer]) and candidate.negative_transfer >= 0.0 and
        candidate.negative_transfer <= 1.0

  defp applicable?(candidate, request),
    do:
      candidate.repository_iri == request.repository_iri and
        request.task_phase in candidate.task_phases and candidate.framework == request.framework and
        candidate.framework_version == request.framework_version and
        candidate.environment == request.environment and
        candidate.policy_version == request.policy_version and
        candidate.required_tools == request.tools and candidate.lifecycle_state == :validated and
        candidate.evidence_current? and
        DateTime.compare(candidate.recorded_at, request.effective_at) in [:lt, :eq] and
        DateTime.compare(candidate.validated_at, request.effective_at) in [:lt, :eq]

  defp rank_key(candidate) do
    good =
      Map.get(candidate.outcome_counts, :success, 0) +
        Map.get(candidate.outcome_counts, :delayed_survival, 0)

    bad =
      Map.get(candidate.outcome_counts, :failure, 0) +
        Map.get(candidate.outcome_counts, :revert, 0) +
        Map.get(candidate.outcome_counts, :incident, 0) +
        Map.get(candidate.outcome_counts, :negative_transfer, 0)

    {-(good - bad - candidate.negative_transfer * 2),
     -DateTime.to_unix(candidate.validated_at, :microsecond), candidate.iri}
  end

  defp projection(candidate),
    do:
      Map.take(candidate, [
        :iri,
        :task_phases,
        :steps,
        :decision_branches,
        :stop_conditions,
        :escalation_conditions,
        :rollback_conditions,
        :exceptions,
        :outcome_counts,
        :evidence_iris,
        :validated_at,
        :negative_transfer
      ])
end

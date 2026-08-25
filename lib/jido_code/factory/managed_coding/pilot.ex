defmodule JidoCode.Factory.ManagedCoding.Pilot do
  @moduledoc "Narrow draft-PR pilot that never grants approval or merge authority to the runtime."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @metrics ~w[acceptance edit_distance review_minutes escaped_regression reopen_revert unsafe_behavior abstention latency_ms cost_microunits operator_minutes]a
  @stop_signals ~w[safety quality provenance isolation cost operations]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[profile_digest tenant_iris repository_iris task_classes volume_ceiling business_hours on_call_actor_iris opt_out_repository_iris thresholds status enrollments publications outcomes metric_samples stop_reasons]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- valid_digest?(attributes[:profile_digest]),
         :ok <- resources(attributes[:tenant_iris], false),
         :ok <- resources(attributes[:repository_iris], false),
         :ok <- strings(attributes[:task_classes]),
         ceiling when is_integer(ceiling) and ceiling > 0 <- attributes[:volume_ceiling],
         :ok <- business_hours(attributes[:business_hours]),
         :ok <- resources(attributes[:on_call_actor_iris], false),
         :ok <- resources(attributes[:opt_out_repository_iris], true),
         :ok <- thresholds(attributes[:thresholds]) do
      {:ok,
       %__MODULE__{
         profile_digest: attributes.profile_digest,
         tenant_iris: Enum.sort(Enum.uniq(attributes.tenant_iris)),
         repository_iris: Enum.sort(Enum.uniq(attributes.repository_iris)),
         task_classes: Enum.sort(Enum.uniq(attributes.task_classes)),
         volume_ceiling: ceiling,
         business_hours: attributes.business_hours,
         on_call_actor_iris: Enum.sort(Enum.uniq(attributes.on_call_actor_iris)),
         opt_out_repository_iris: Enum.sort(Enum.uniq(attributes.opt_out_repository_iris)),
         thresholds: attributes.thresholds,
         status: :open,
         enrollments: [],
         publications: [],
         outcomes: [],
         metric_samples: [],
         stop_reasons: []
       }}
    else
      _invalid -> invalid(:managed_coding_pilot)
    end
  end

  def new(_attributes), do: invalid(:managed_coding_pilot)

  @spec enroll(t(), map(), DateTime.t()) :: {:ok, map(), t()} | {:error, AdapterError.t(), t()}
  def enroll(%__MODULE__{status: :open} = state, request, %DateTime{} = now)
      when is_map(request) do
    if eligible?(state, request, now) do
      enrollment = %{
        attempt_iri: request.attempt_iri,
        tenant_iri: request.tenant_iri,
        repository_iri: request.repository_iri,
        task_iri: request.task_iri,
        task_class: request.task_class,
        cohort: request.cohort,
        profile_digest: state.profile_digest,
        actor_iri: request.actor_iri,
        enrolled_at: now,
        opt_out_documented: true,
        publication_scope: :draft_only
      }

      {:ok, enrollment, %{state | enrollments: [enrollment | state.enrollments]}}
    else
      {:error, AdapterError.new(:unauthorized, :managed_coding_pilot_enrollment), state}
    end
  end

  def enroll(%__MODULE__{} = state, _request, _now),
    do: {:error, AdapterError.new(:unavailable, :managed_coding_pilot_enrollment), state}

  @spec publish(module(), term(), t(), map(), map()) ::
          {:ok, map(), t()} | {:error, AdapterError.t(), t()}
  def publish(
        publisher_module,
        publisher,
        %__MODULE__{status: :open} = state,
        enrollment,
        candidate
      ) do
    with true <- enrollment in state.enrollments,
         true <- candidate[:status] == :accepted,
         true <- candidate[:profile_digest] == state.profile_digest,
         :ok <- candidate(candidate),
         request <- publication_request(enrollment, candidate),
         {:ok, receipt} <- publisher_module.create_draft(publisher, request, []) do
      publication = Map.merge(request, %{receipt: receipt, status: :draft_open})
      {:ok, publication, %{state | publications: [publication | state.publications]}}
    else
      {:error, %AdapterError{} = error} ->
        {:error, error, state}

      _invalid ->
        {:error, AdapterError.new(:unauthorized, :managed_coding_pilot_publication), state}
    end
  end

  def publish(_publisher_module, _publisher, %__MODULE__{} = state, _enrollment, _candidate),
    do: {:error, AdapterError.new(:unavailable, :managed_coding_pilot_publication), state}

  @spec record_human_outcome(t(), map(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def record_human_outcome(%__MODULE__{} = state, publication, outcome) when is_map(outcome) do
    with true <- publication in state.publications,
         :ok <- Identity.validate_resource(outcome[:reviewer_actor_iri]),
         approved when is_boolean(approved) <- outcome[:approved],
         merged when is_boolean(merged) <- outcome[:merged],
         true <- not merged or approved,
         :ok <- optional_digest(outcome[:human_change_digest]),
         :ok <- metric_values(outcome[:metrics]),
         :ok <- stop_signals(outcome[:signals]) do
      record = %{
        publication_receipt: publication.receipt,
        reviewer_actor_iri: outcome.reviewer_actor_iri,
        approved: approved,
        merged: merged,
        human_change_digest: outcome.human_change_digest,
        candidate_digest: publication.candidate_digest,
        candidate_attribution_excludes_human_changes: true,
        metrics: outcome.metrics,
        signals: outcome.signals
      }

      samples = [outcome.metrics | state.metric_samples]
      reasons = stop_reasons(state, outcome.signals, samples)
      status = if reasons == [], do: state.status, else: :stopped

      publications =
        if status == :stopped,
          do: Enum.map(state.publications, &Map.put(&1, :status, :quarantined)),
          else: state.publications

      {:ok,
       %{
         state
         | outcomes: [record | state.outcomes],
           metric_samples: samples,
           stop_reasons: reasons,
           status: status,
           publications: publications
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_pilot_outcome)}
    end
  end

  def record_human_outcome(_state, _publication, _outcome),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_pilot_outcome)}

  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = state) do
    %{
      status: state.status,
      enrollments: length(state.enrollments),
      publications: length(state.publications),
      outcomes: length(state.outcomes),
      metrics: Map.new(@metrics, &{&1, mean(state.metric_samples, &1)}),
      stop_reasons: state.stop_reasons
    }
  end

  defp eligible?(state, request, now) do
    hour = now.hour
    hours = state.business_hours

    length(state.enrollments) < state.volume_ceiling and request[:tenant_iri] in state.tenant_iris and
      request[:repository_iri] in state.repository_iris and
      request[:repository_iri] not in state.opt_out_repository_iris and
      request[:task_class] in state.task_classes and
      request[:profile_digest] == state.profile_digest and
      request[:on_call_actor_iri] in state.on_call_actor_iris and hour >= hours.start_hour and
      hour < hours.end_hour and valid_enrollment_resources?(request)
  end

  defp valid_enrollment_resources?(request) do
    Enum.all?(
      ~w[attempt_iri tenant_iri repository_iri task_iri actor_iri on_call_actor_iri]a,
      fn field ->
        Identity.validate_resource(request[field]) == :ok
      end
    ) and is_binary(request[:cohort])
  end

  defp publication_request(enrollment, candidate) do
    %{
      attempt_iri: enrollment.attempt_iri,
      repository_iri: enrollment.repository_iri,
      candidate_iri: candidate.candidate_iri,
      candidate_digest: candidate.candidate_digest,
      verification_iri: candidate.verification_iri,
      verification_digest: candidate.verification_digest,
      profile_digest: candidate.profile_digest,
      limitations: candidate.limitations,
      draft: true,
      branch_creation_authority: true,
      pull_request_creation_authority: true,
      approval_authority: false,
      merge_authority: false,
      human_review_required: true,
      repository_protections_required: true
    }
  end

  defp candidate(candidate) do
    resources = ~w[candidate_iri verification_iri]a
    digests = ~w[candidate_digest verification_digest profile_digest]a

    if Enum.all?(resources, &(Identity.validate_resource(candidate[&1]) == :ok)) and
         Enum.all?(digests, &valid_digest?(candidate[&1])) and is_list(candidate[:limitations]),
       do: :ok,
       else: :error
  end

  defp thresholds(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@metrics) and
         Enum.all?(values, fn {_metric, value} -> is_number(value) and value >= 0 end),
       do: :ok,
       else: :error
  end

  defp thresholds(_values), do: :error

  defp metric_values(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@metrics) and
         Enum.all?(values, fn {_metric, value} -> is_number(value) and value >= 0 end),
       do: :ok,
       else: :error
  end

  defp metric_values(_values), do: :error

  defp stop_signals(values) when is_list(values) do
    if Enum.all?(values, &(&1 in @stop_signals)), do: :ok, else: :error
  end

  defp stop_signals(_values), do: :error

  defp stop_reasons(state, signals, samples) do
    threshold =
      Enum.flat_map(@metrics, fn metric ->
        if mean(samples, metric) > state.thresholds[metric],
          do: [{:threshold_breach, metric}],
          else: []
      end)

    Enum.sort(Enum.uniq(state.stop_reasons ++ signals ++ threshold))
  end

  defp mean([], _metric), do: 0.0
  defp mean(samples, metric), do: Enum.reduce(samples, 0, &(&1[metric] + &2)) / length(samples)

  defp business_hours(%{start_hour: start_hour, end_hour: end_hour})
       when start_hour in 0..23 and end_hour in 1..24 and start_hour < end_hour,
       do: :ok

  defp business_hours(_hours), do: :error

  defp resources([], true), do: :ok

  defp resources(values, _empty_allowed)
       when is_list(values) and values != [] and length(values) <= 256 do
    if Enum.all?(values, &(Identity.validate_resource(&1) == :ok)), do: :ok, else: :error
  end

  defp resources(_values, _empty_allowed), do: :error

  defp strings(values) when is_list(values) and values != [] do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..128)), do: :ok, else: :error
  end

  defp strings(_values), do: :error
  defp optional_digest(nil), do: :ok
  defp optional_digest(value), do: if(valid_digest?(value), do: :ok, else: :error)
  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

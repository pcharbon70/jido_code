defmodule JidoCode.Factory.ManagedCoding.ShadowRollout do
  @moduledoc "Non-authoritative production-traffic qualification with automatic fail-closed stops."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @controls ~w[data_classification credential_policy rate_limit isolation retention redaction cost_accounting]a
  @metrics ~w[failure abstention clarification capacity cost_microunits latency_ms recovery security_event]a
  @stop_signals ~w[threshold_breach evidence_gap profile_drift isolation_failure unexplained_cost_growth reconstruction_failure]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[profile_digest tenant_iris repository_iris task_classes sample_percent window_start window_end controls thresholds status attempts observations stop_reasons]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- valid_digest?(attributes[:profile_digest]),
         :ok <- resources(attributes[:tenant_iris]),
         :ok <- resources(attributes[:repository_iris]),
         :ok <- strings(attributes[:task_classes]),
         sample when is_integer(sample) and sample in 1..100 <- attributes[:sample_percent],
         %DateTime{} = window_start <- attributes[:window_start],
         %DateTime{} = window_end <- attributes[:window_end],
         true <- DateTime.before?(window_start, window_end),
         :ok <- exact_controls(attributes[:controls]),
         :ok <- thresholds(attributes[:thresholds]) do
      {:ok,
       %__MODULE__{
         profile_digest: attributes.profile_digest,
         tenant_iris: Enum.sort(Enum.uniq(attributes.tenant_iris)),
         repository_iris: Enum.sort(Enum.uniq(attributes.repository_iris)),
         task_classes: Enum.sort(Enum.uniq(attributes.task_classes)),
         sample_percent: sample,
         window_start: window_start,
         window_end: window_end,
         controls: attributes.controls,
         thresholds: attributes.thresholds,
         status: :open,
         attempts: [],
         observations: [],
         stop_reasons: []
       }}
    else
      _invalid -> invalid(:managed_coding_shadow_rollout)
    end
  end

  def new(_attributes), do: invalid(:managed_coding_shadow_rollout)

  @spec admit(t(), map(), DateTime.t()) :: {:ok, map(), t()} | {:error, AdapterError.t(), t()}
  def admit(%__MODULE__{status: :open} = state, request, %DateTime{} = now)
      when is_map(request) do
    if eligible?(state, request, now) do
      attempt = %{
        attempt_iri: request.attempt_iri,
        tenant_iri: request.tenant_iri,
        repository_iri: request.repository_iri,
        task_iri: request.task_iri,
        cohort: request.cohort,
        profile_digest: state.profile_digest,
        mode: :shadow,
        controls: state.controls,
        push_authority: false,
        pull_request_authority: false,
        task_state_authority: false,
        active_implementation_influence: false,
        publication_authority: false,
        admitted_at: now
      }

      {:ok, attempt, %{state | attempts: [attempt | state.attempts]}}
    else
      {:error, AdapterError.new(:unauthorized, :managed_coding_shadow_admission), state}
    end
  end

  def admit(%__MODULE__{} = state, _request, _now),
    do: {:error, AdapterError.new(:unavailable, :managed_coding_shadow_admission), state}

  @spec observe(t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def observe(%__MODULE__{} = state, observation) when is_map(observation) do
    with true <- Enum.any?(state.attempts, &(&1.attempt_iri == observation[:attempt_iri])),
         true <- observation[:profile_digest] == state.profile_digest,
         %DateTime{} = outcome_at <- observation[:outcome_observed_at],
         %DateTime{} = scored_at <- observation[:scored_at],
         true <- DateTime.after?(scored_at, outcome_at),
         true <- observation[:blinded] == true,
         true <- observation[:feedback_to_attempt] == false,
         :ok <- metric_values(observation[:metrics]),
         :ok <- stop_signals(observation[:signals]) do
      observations = [observation | state.observations]
      reasons = stop_reasons(state, observation, observations)
      status = if reasons == [], do: state.status, else: :stopped
      {:ok, %{state | observations: observations, stop_reasons: reasons, status: status}}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_shadow_observation)}
    end
  end

  def observe(_state, _observation),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_shadow_observation)}

  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = state) do
    cohorts = Enum.group_by(state.observations, & &1.cohort)

    %{
      status: state.status,
      observation_window: %{start: state.window_start, end: state.window_end},
      attempts: length(state.attempts),
      observations: length(state.observations),
      stop_reasons: state.stop_reasons,
      cohorts:
        Map.new(cohorts, fn {cohort, observations} ->
          {cohort, Map.new(@metrics, &{&1, mean(observations, &1)})}
        end)
    }
  end

  defp eligible?(state, request, now) do
    state.status == :open and DateTime.compare(now, state.window_start) in [:gt, :eq] and
      DateTime.compare(now, state.window_end) == :lt and request[:tenant_iri] in state.tenant_iris and
      request[:repository_iri] in state.repository_iris and
      request[:task_class] in state.task_classes and
      request[:profile_digest] == state.profile_digest and valid_request_resources?(request) and
      sample(request.task_iri) < state.sample_percent
  end

  defp valid_request_resources?(request) do
    Enum.all?(~w[attempt_iri tenant_iri repository_iri task_iri]a, fn field ->
      Identity.validate_resource(request[field]) == :ok
    end) and is_binary(request[:cohort])
  end

  defp sample(value), do: rem(:erlang.phash2(value), 100)

  defp exact_controls(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@controls) and
         Enum.all?(values, fn {_control, revision} -> valid_digest?(revision) end),
       do: :ok,
       else: :error
  end

  defp exact_controls(_values), do: :error

  defp thresholds(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@metrics) and
         Enum.all?(values, fn {_metric, limit} -> is_number(limit) and limit >= 0 end),
       do: :ok,
       else: :error
  end

  defp thresholds(_values), do: :error

  defp metric_values(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@metrics) and
         Enum.all?(values, fn {_metric, result} -> is_number(result) and result >= 0 end),
       do: :ok,
       else: :error
  end

  defp metric_values(_values), do: :error

  defp stop_signals(values) when is_list(values) do
    if Enum.all?(values, &(&1 in @stop_signals)), do: :ok, else: :error
  end

  defp stop_signals(_values), do: :error

  defp stop_reasons(state, observation, observations) do
    explicit = observation.signals

    threshold =
      Enum.flat_map(@metrics, fn metric ->
        if mean(observations, metric) > state.thresholds[metric],
          do: [{:threshold_breach, metric}],
          else: []
      end)

    Enum.sort(Enum.uniq(state.stop_reasons ++ explicit ++ threshold))
  end

  defp mean(observations, metric) do
    Enum.reduce(observations, 0, &(&1.metrics[metric] + &2)) / length(observations)
  end

  defp resources(values) when is_list(values) and values != [] and length(values) <= 256 do
    if Enum.all?(values, &(Identity.validate_resource(&1) == :ok)), do: :ok, else: :error
  end

  defp resources(_values), do: :error

  defp strings(values) when is_list(values) and values != [] and length(values) <= 64 do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..128)), do: :ok, else: :error
  end

  defp strings(_values), do: :error
  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end

defmodule JidoCode.Factory.Fleet.Admission do
  @moduledoc """
  Deterministic, bounded admission over graph-projected candidates and leases.

  No queue or fairness counter is persisted here. Deferred reasons and the
  next wait count are returned so the owning graph command can record them.
  """

  alias JidoCode.Factory.Fleet.Policy
  alias JidoCode.Factory.Fleet.Result
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @spec select([map()], [map()], Policy.t()) :: {:ok, Result.t()} | {:error, Error.t()}
  def select(candidates, active_leases, %Policy{} = policy)
      when is_list(candidates) and is_list(active_leases) do
    with :ok <- validate_size(candidates, active_leases, policy),
         true <- Enum.all?(candidates, &valid_candidate?/1),
         true <- Enum.all?(active_leases, &valid_lease?/1) do
      {selected, deferred, _usage} =
        candidates
        |> Enum.sort_by(&ordering_key(&1, policy))
        |> Enum.reduce({[], [], initial_usage(active_leases)}, fn candidate,
                                                                  {selected, deferred, usage} ->
          case admit(candidate, policy, usage) do
            {:ok, provider, next_usage} ->
              selection = %{candidate: candidate, provider: provider}
              {[selection | selected], deferred, next_usage}

            {:defer, reasons} ->
              explanation = %{
                task_iri: candidate.task_iri,
                outcome: :deferred,
                reasons: reasons,
                next_waited_cycles: Map.get(candidate, :waited_cycles, 0) + 1
              }

              {selected, [explanation | deferred], usage}
          end
        end)

      {:ok,
       %Result{
         selected: Enum.reverse(selected),
         deferred: Enum.reverse(deferred),
         policy_revision: policy.policy_revision
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      false -> {:error, Error.new(:invalid_input, :fleet_snapshot)}
    end
  end

  def select(_candidates, _active_leases, _policy),
    do: {:error, Error.new(:invalid_input, :fleet_snapshot)}

  defp validate_size(candidates, active_leases, policy) do
    if length(candidates) <= policy.max_candidates and
         length(active_leases) <= policy.max_candidates * 10 do
      :ok
    else
      {:error, Error.new(:conflict, :fleet_capacity)}
    end
  end

  defp ordering_key(candidate, policy) do
    emergency = candidate.priority >= policy.emergency_priority
    starved = Map.get(candidate, :waited_cycles, 0) >= policy.starvation_cycles

    {
      if(emergency, do: 0, else: 1),
      if(starved, do: 0, else: 1),
      -candidate.priority,
      candidate.fairness,
      candidate.task_iri
    }
  end

  defp admit(candidate, policy, usage) do
    provider = choose_provider(candidate, usage, policy)
    capability = capability(candidate)
    repository_count = Map.get(usage.repositories, candidate.repository_iri, 0)
    capability_count = Map.get(usage.capabilities, capability, 0)

    cohort_full? =
      Enum.any?(candidate.cohort_iris, fn cohort ->
        Map.get(usage.cohorts, cohort, 0) >= policy.concurrency.cohort
      end)

    campaign_full? =
      not MapSet.member?(usage.campaign_repositories, candidate.repository_iri) and
        MapSet.size(usage.campaign_repositories) >= policy.max_campaign_repositories

    reasons =
      []
      |> add_reason(candidate.risk > policy.max_risk, :risk_limit)
      |> add_reason(usage.global >= policy.concurrency.global, :global_capacity)
      |> add_reason(repository_count >= policy.concurrency.repository, :repository_capacity)
      |> add_reason(cohort_full?, :cohort_capacity)
      |> add_reason(capability_count >= policy.concurrency.capability, :capability_capacity)
      |> add_reason(
        usage.rate_units + units(candidate, :rate_units) > policy.rate_units,
        :rate_limit
      )
      |> add_reason(
        usage.budget_units + units(candidate, :budget_units) > policy.budget_units,
        :budget_limit
      )
      |> add_reason(campaign_full?, :campaign_repository_limit)
      |> add_reason(is_nil(provider), :provider_backpressure)
      |> Enum.reverse()

    if reasons == [],
      do: {:ok, provider, increment_usage(usage, candidate, provider, capability)},
      else: {:defer, reasons}
  end

  defp choose_provider(candidate, usage, policy) do
    candidate.providers
    |> Enum.sort_by(fn provider ->
      {Map.get(usage.providers, provider.holder_iri, 0), provider.holder_iri, provider.iri}
    end)
    |> Enum.find(fn provider ->
      assigned = Map.get(usage.providers, provider.holder_iri, 0)
      active = Map.get(provider, :active_leases, 0)
      declared = get_in(provider, [:limits, :concurrency]) || policy.concurrency.provider
      rate_available? = Map.get(provider, :rate_available?, true)

      rate_available? and max(active, assigned) < min(declared, policy.concurrency.provider)
    end)
  end

  defp increment_usage(usage, candidate, provider, capability) do
    %{
      global: usage.global + 1,
      repositories: increment(usage.repositories, candidate.repository_iri),
      cohorts: Enum.reduce(candidate.cohort_iris, usage.cohorts, &increment(&2, &1)),
      providers: increment(usage.providers, provider.holder_iri),
      capabilities: increment(usage.capabilities, capability),
      rate_units: usage.rate_units + units(candidate, :rate_units),
      budget_units: usage.budget_units + units(candidate, :budget_units),
      campaign_repositories: MapSet.put(usage.campaign_repositories, candidate.repository_iri)
    }
  end

  defp initial_usage(active_leases) do
    Enum.reduce(active_leases, empty_usage(), fn lease, usage ->
      capability = Map.get(lease, :capability_iri, lease.holder_iri)

      %{
        global: usage.global + 1,
        repositories: increment(usage.repositories, lease.repository_iri),
        cohorts: Enum.reduce(lease.cohort_iris, usage.cohorts, &increment(&2, &1)),
        providers: increment(usage.providers, lease.holder_iri),
        capabilities: increment(usage.capabilities, capability),
        rate_units: usage.rate_units + units(lease, :rate_units, 0),
        budget_units: usage.budget_units + units(lease, :budget_units, 0),
        campaign_repositories: MapSet.put(usage.campaign_repositories, lease.repository_iri)
      }
    end)
  end

  defp empty_usage do
    %{
      global: 0,
      repositories: %{},
      cohorts: %{},
      providers: %{},
      capabilities: %{},
      rate_units: 0,
      budget_units: 0,
      campaign_repositories: MapSet.new()
    }
  end

  defp valid_candidate?(candidate) do
    is_map(candidate) and valid_iri?(candidate[:task_iri]) and
      valid_iri?(candidate[:repository_iri]) and valid_iris?(candidate[:cohort_iris]) and
      is_list(candidate[:providers]) and candidate.providers != [] and
      Enum.all?(candidate.providers, &valid_provider?/1) and
      Enum.all?(
        [:priority, :fairness, :risk],
        &(is_integer(candidate[&1]) and candidate[&1] >= 0)
      ) and
      valid_optional_non_negative?(candidate, :waited_cycles) and
      valid_optional_positive?(candidate, :rate_units) and
      valid_optional_positive?(candidate, :budget_units) and
      valid_optional_iri?(candidate, :capability_iri)
  end

  defp valid_provider?(provider) do
    is_map(provider) and valid_iri?(provider[:iri]) and valid_iri?(provider[:holder_iri]) and
      Map.get(provider, :rate_available?, true) in [true, false]
  end

  defp valid_lease?(lease) do
    is_map(lease) and valid_iri?(lease[:repository_iri]) and valid_iri?(lease[:holder_iri]) and
      valid_iris?(lease[:cohort_iris]) and valid_optional_iri?(lease, :capability_iri) and
      valid_optional_non_negative?(lease, :rate_units) and
      valid_optional_non_negative?(lease, :budget_units)
  end

  defp capability(candidate), do: Map.get(candidate, :capability_iri, hd(candidate.providers).iri)
  defp valid_iri?(value), do: Knowledge.validate_resource_identity(value) == :ok
  defp valid_iris?(values), do: is_list(values) and Enum.all?(values, &valid_iri?/1)

  defp valid_optional_iri?(map, key),
    do: not Map.has_key?(map, key) or is_nil(map[key]) or valid_iri?(map[key])

  defp valid_optional_non_negative?(map, key),
    do: not Map.has_key?(map, key) or (is_integer(map[key]) and map[key] >= 0)

  defp valid_optional_positive?(map, key),
    do: not Map.has_key?(map, key) or (is_integer(map[key]) and map[key] > 0)

  defp units(map, key, default \\ 1), do: Map.get(map, key, default)
  defp increment(counts, key), do: Map.update(counts, key, 1, &(&1 + 1))
  defp add_reason(reasons, true, reason), do: [reason | reasons]
  defp add_reason(reasons, false, _reason), do: reasons
end

defmodule JidoCode.Factory.RepositoryWiki.FleetOperations do
  @moduledoc """
  Builds bounded graph-derived fleet health and alert summaries.

  Callers provide reviewed repository snapshots. The projection never trusts a
  worker PID, mailbox, cache, queue cursor, or local workspace as durable truth.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @maximum_repositories 200
  @enrollment_states [:off, :manual, :automatic]
  @maintainer_states [:disabled, :idle, :admitted, :running, :cancelling, :failed, :stopped]
  @alert_types [
    :stale_current_edition,
    :repeated_deterministic_failure,
    :abandoned_edition,
    :expired_lease,
    :queue_pressure,
    :stuck_reservation,
    :usage_pending,
    :usage_unknown,
    :restore_drift,
    :cross_scope_invariant
  ]

  @spec project([map()], map()) :: {:ok, map()} | {:error, Error.t()}
  def project(repositories, policy)
      when is_list(repositories) and is_map(policy) and
             length(repositories) <= @maximum_repositories do
    with :ok <- validate_policy(policy),
         {:ok, normalized} <- validate_repositories(repositories, policy),
         summaries <- Enum.map(normalized, &summary(&1, policy)),
         alerts <- summaries |> Enum.flat_map(& &1.alerts) |> Enum.sort_by(&alert_key/1) do
      result = %{
        evaluated_at: policy.evaluated_at,
        repository_count: length(summaries),
        enrollment_counts: counts(summaries, :enrollment),
        maintainer_counts: counts(summaries, :maintainer),
        current_count: Enum.count(summaries, &(&1.current_state == :current)),
        stale_count: Enum.count(summaries, &(&1.current_state == :stale)),
        queue_pending: Enum.sum(Enum.map(summaries, & &1.queue.pending)),
        queue_active: Enum.sum(Enum.map(summaries, & &1.queue.active)),
        reservations_live: Enum.sum(Enum.map(summaries, & &1.accounting.live_reservations)),
        usage_pending: Enum.sum(Enum.map(summaries, & &1.accounting.usage_pending)),
        usage_unknown: Enum.sum(Enum.map(summaries, & &1.accounting.usage_unknown)),
        retained_bytes: Enum.sum(Enum.map(summaries, & &1.storage.retained_bytes)),
        alert_count: length(alerts),
        repositories: summaries,
        alerts: alerts
      }

      {:ok, Map.put(result, :digest, Knowledge.repository_wiki_digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_fleet_operations)
    end
  rescue
    _error -> invalid(:repository_wiki_fleet_operations)
  end

  def project(_repositories, _policy), do: invalid(:repository_wiki_fleet_operations)

  @spec alert_types() :: [atom()]
  def alert_types, do: @alert_types

  defp validate_policy(policy) do
    required = ~w[
      evaluated_at stale_after_seconds repeated_failure_threshold abandoned_after_seconds
      lease_grace_seconds queue_pressure_threshold reservation_stuck_seconds
    ]a

    with true <- Enum.all?(required, &Map.has_key?(policy, &1)),
         %DateTime{} <- policy.evaluated_at,
         true <- Enum.all?(required -- [:evaluated_at], &positive?(policy[&1])) do
      :ok
    else
      _invalid -> invalid(:repository_wiki_fleet_policy)
    end
  end

  defp validate_repositories(repositories, policy) do
    repositories
    |> Enum.reduce_while({:ok, [], MapSet.new()}, fn repository, {:ok, values, scopes} ->
      with :ok <- validate_repository(repository, policy),
           scope = {repository.tenant_iri, repository.repository_iri},
           false <- MapSet.member?(scopes, scope) do
        {:cont, {:ok, [repository | values], MapSet.put(scopes, scope)}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
        _invalid -> {:halt, invalid(:repository_wiki_fleet_scope)}
      end
    end)
    |> case do
      {:ok, values, _scopes} -> {:ok, Enum.sort_by(values, &{&1.tenant_iri, &1.repository_iri})}
      error -> error
    end
  end

  defp validate_repository(repository, policy) when is_map(repository) do
    required = ~w[
      repository_iri tenant_iri enrollment current maintainer lease queue compilation coverage
      accounting storage restore
    ]a

    with true <- Enum.all?(required, &Map.has_key?(repository, &1)),
         :ok <- Knowledge.validate_resource_identity(repository.repository_iri),
         :ok <- Knowledge.validate_resource_identity(repository.tenant_iri),
         true <- repository.enrollment in @enrollment_states,
         true <- valid_current?(repository.current),
         true <- repository.maintainer in @maintainer_states,
         true <- valid_lease?(repository.lease),
         true <- counts_map?(repository.queue, [:pending, :active]),
         true <- counts_map?(repository.compilation, [:success, :failed, :abandoned]),
         true <- counts_map?(repository.coverage, [:pages, :dependencies, :guides, :gaps]),
         true <-
           counts_map?(repository.accounting, [:live_reservations, :usage_pending, :usage_unknown]),
         true <- counts_map?(repository.storage, [:edition_count, :retained_bytes]),
         true <- repository.restore[:state] in [:verified, :drifted, :not_tested],
         true <- match?(%DateTime{}, repository.restore[:recorded_at]),
         true <- DateTime.compare(repository.restore.recorded_at, policy.evaluated_at) != :gt do
      :ok
    else
      _invalid -> invalid(:repository_wiki_fleet_repository)
    end
  end

  defp validate_repository(_repository, _policy),
    do: invalid(:repository_wiki_fleet_repository)

  defp summary(repository, policy) do
    alerts = alerts(repository, policy)

    %{
      id: Knowledge.repository_wiki_digest({repository.tenant_iri, repository.repository_iri}),
      repository_iri: repository.repository_iri,
      tenant_iri: repository.tenant_iri,
      enrollment: repository.enrollment,
      current_state: repository.current.state,
      current_age_seconds: age(repository.current.recorded_at, policy.evaluated_at),
      maintainer: repository.maintainer,
      lease: lease_summary(repository.lease, policy.evaluated_at),
      queue: repository.queue,
      compilation: repository.compilation,
      coverage: repository.coverage,
      accounting: repository.accounting,
      storage: repository.storage,
      restore: repository.restore.state,
      alerts: alerts
    }
  end

  defp alerts(repository, policy) do
    []
    |> alert(
      repository.current.state == :stale or
        age(repository.current.recorded_at, policy.evaluated_at) > policy.stale_after_seconds,
      repository,
      :stale_current_edition,
      :warning
    )
    |> alert(
      repository.compilation.failed >= policy.repeated_failure_threshold,
      repository,
      :repeated_deterministic_failure,
      :critical
    )
    |> alert(repository.compilation.abandoned > 0, repository, :abandoned_edition, :warning)
    |> alert(expired?(repository.lease, policy), repository, :expired_lease, :warning)
    |> alert(
      repository.queue.pending >= policy.queue_pressure_threshold,
      repository,
      :queue_pressure,
      :warning
    )
    |> alert(
      repository.accounting.live_reservations > 0 and
        repository.accounting.oldest_reservation_age_seconds >= policy.reservation_stuck_seconds,
      repository,
      :stuck_reservation,
      :critical
    )
    |> alert(repository.accounting.usage_pending > 0, repository, :usage_pending, :warning)
    |> alert(repository.accounting.usage_unknown > 0, repository, :usage_unknown, :critical)
    |> alert(repository.restore.state == :drifted, repository, :restore_drift, :critical)
    |> alert(
      repository[:cross_scope_violation?] == true,
      repository,
      :cross_scope_invariant,
      :critical
    )
  end

  defp alert(values, false, _repository, _type, _severity), do: values

  defp alert(values, true, repository, type, severity) do
    alert = %{
      id: Knowledge.repository_wiki_digest({repository.repository_iri, type}),
      repository_iri: repository.repository_iri,
      tenant_iri: repository.tenant_iri,
      type: type,
      severity: severity
    }

    [alert | values]
  end

  defp lease_summary(nil, _evaluated_at), do: %{state: :absent, expires_at: nil}

  defp lease_summary(lease, evaluated_at) do
    %{
      state:
        if(DateTime.compare(lease.expires_at, evaluated_at) == :gt, do: :active, else: :expired),
      expires_at: lease.expires_at
    }
  end

  defp expired?(nil, _policy), do: false

  defp expired?(lease, policy) do
    DateTime.compare(
      DateTime.add(lease.expires_at, policy.lease_grace_seconds, :second),
      policy.evaluated_at
    ) != :gt
  end

  defp counts(values, key) do
    values
    |> Enum.group_by(&Map.fetch!(&1, key))
    |> Enum.map(fn {value, rows} -> {value, length(rows)} end)
    |> Map.new()
  end

  defp valid_current?(%{state: state, recorded_at: %DateTime{}}),
    do: state in [:absent, :current, :stale, :incomplete]

  defp valid_current?(_current), do: false
  defp valid_lease?(nil), do: true

  defp valid_lease?(%{expires_at: %DateTime{}, fence: fence}),
    do: is_binary(fence) and byte_size(fence) in 1..256

  defp valid_lease?(_lease), do: false

  defp counts_map?(values, keys) when is_map(values),
    do: Enum.all?(keys, &(is_integer(values[&1]) and values[&1] >= 0))

  defp counts_map?(_values, _keys), do: false

  defp alert_key(alert),
    do: {alert.severity != :critical, alert.type, alert.tenant_iri, alert.repository_iri}

  defp age(recorded_at, evaluated_at),
    do: max(DateTime.diff(evaluated_at, recorded_at, :second), 0)

  defp positive?(value), do: is_integer(value) and value > 0
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

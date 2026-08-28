defmodule JidoCode.Factory.RepositoryWiki.AccountingReconciler do
  @moduledoc "Recovers invocation-without-usage liability and emits bounded disposable cost views."

  alias JidoCode.Knowledge

  @maximum_pending 200

  @spec pending([map()], DateTime.t()) :: [map()]
  def pending(attempts, %DateTime{} = evaluated_at) when is_list(attempts) do
    attempts
    |> Enum.filter(fn attempt ->
      match?(%DateTime{}, attempt[:invoked_at]) and is_nil(attempt[:terminal_usage_iri]) and
        DateTime.compare(attempt.invoked_at, evaluated_at) in [:lt, :eq]
    end)
    |> Enum.sort_by(&{DateTime.to_unix(&1.invoked_at, :microsecond), &1.attempt_iri})
    |> Enum.take(@maximum_pending)
  end

  def pending(_attempts, _evaluated_at), do: []

  @spec reconcile(map(), map(), map()) :: {:ok, map()} | {:error, map()}
  def reconcile(attempt, context, ports)
      when is_map(attempt) and is_map(context) and is_map(ports) do
    with :ok <- exact(attempt, context),
         true <- context[:retrieval_supported?] == true,
         true <- context[:retrieval_attempt] < context[:maximum_retrieval_attempts],
         {:ok, observation} <- ports.retrieve_usage.(attempt.provider_request_iri),
         {:ok, usage} <- ports.normalize_usage.(observation, attempt, context),
         :ok <- exact_usage(usage, attempt, context),
         {:ok, receipt} <- ports.record_terminal.(usage, context) do
      {:ok, %{outcome: :reconciled, usage: usage, receipt: receipt}}
    else
      false -> close_unknown(attempt, context, ports)
      {:error, :not_supported} -> close_unknown(attempt, context, ports)
      {:error, reason} -> {:error, alert(:usage_retrieval_failed, attempt, reason)}
      _invalid -> {:error, alert(:usage_reconciliation_invalid, attempt, :invalid)}
    end
  rescue
    _error -> {:error, alert(:usage_reconciliation_exception, attempt, :exception)}
  end

  def reconcile(attempt, _context, _ports),
    do: {:error, alert(:usage_reconciliation_invalid, attempt, :invalid)}

  @spec late_usage(map(), map(), map()) :: {:ok, map()} | {:duplicate, map()} | {:error, atom()}
  def late_usage(usage, attempt, context)
      when is_map(usage) and is_map(attempt) and is_map(context) do
    cond do
      Enum.any?(Map.get(context, :usage_records, []), &(&1[:usage_iri] == usage[:usage_iri])) ->
        {:duplicate, usage}

      exact_usage(usage, attempt, context) != :ok ->
        {:error, :mismatched_late_usage}

      true ->
        {:ok, Map.put(usage, :late?, true)}
    end
  end

  def late_usage(_usage, _attempt, _context), do: {:error, :invalid}

  @spec rollups([map()]) :: [map()]
  def rollups(records) when is_list(records) do
    records
    |> Enum.group_by(&rollup_key/1)
    |> Enum.map(fn {key, values} ->
      totals = %{
        input: Enum.sum(Enum.map(values, &get_in(&1, [:tokens, :input]))),
        output: Enum.sum(Enum.map(values, &get_in(&1, [:tokens, :output]))),
        cached: Enum.sum(Enum.map(values, &get_in(&1, [:tokens, :cached]))),
        reasoning: Enum.sum(Enum.map(values, &get_in(&1, [:tokens, :reasoning]))),
        charged: Enum.sum(Enum.map(values, &get_in(&1, [:costs, :charged]))),
        unknown: Enum.sum(Enum.map(values, &get_in(&1, [:costs, :unknown])))
      }

      %{
        key: key,
        totals: totals,
        record_count: length(values),
        digest: Knowledge.repository_wiki_digest({key, totals})
      }
    end)
    |> Enum.sort_by(& &1.key)
  end

  def rollups(_records), do: []

  @spec alerts([map()], DateTime.t()) :: [map()]
  def alerts(attempts, %DateTime{} = evaluated_at) when is_list(attempts) do
    attempts
    |> Enum.flat_map(fn attempt ->
      []
      |> maybe_alert(
        expired_reservation?(attempt, evaluated_at),
        :expired_live_reservation,
        attempt
      )
      |> maybe_alert(invocation_pending?(attempt), :invocation_without_terminal_usage, attempt)
      |> maybe_alert(attempt[:cost_arithmetic_error?] == true, :cost_arithmetic_error, attempt)
      |> maybe_alert(attempt[:profile_price_drift?] == true, :profile_price_drift, attempt)
      |> maybe_alert(impossible_tokens?(attempt), :impossible_token_combination, attempt)
    end)
    |> Enum.take(200)
  end

  def alerts(_attempts, _evaluated_at), do: []

  defp close_unknown(attempt, context, ports) do
    usage = %{
      usage_iri: attempt.usage_iri,
      attempt_iri: attempt.attempt_iri,
      reservation_iri: attempt.reservation_iri,
      invocation_iri: attempt.invocation_iri,
      provider_request_iri: attempt.provider_request_iri,
      model: attempt.model,
      price_revision: attempt.price_revision,
      accounting_fence: context.accounting_fence,
      state: :usage_unknown,
      costs: %{
        reserved: attempt.reserved_cost,
        measured: 0,
        charged: 0,
        refunded: 0,
        unknown: attempt.reserved_cost
      },
      tokens: %{input: 0, output: 0, cached: 0, reasoning: 0}
    }

    case ports.record_terminal.(usage, context) do
      {:ok, receipt} -> {:ok, %{outcome: :usage_unknown, usage: usage, receipt: receipt}}
      {:error, reason} -> {:error, alert(:usage_unknown_persist_failed, attempt, reason)}
    end
  end

  defp exact(attempt, context) do
    if attempt.repository_iri == context[:repository_iri] and
         attempt.tenant_iri == context[:tenant_iri] and
         attempt.accounting_fence == context[:accounting_fence] and
         attempt.price_revision == context[:price_revision] do
      :ok
    else
      {:error, :stale_or_mismatched}
    end
  end

  defp exact_usage(usage, attempt, context) do
    if usage[:attempt_iri] == attempt[:attempt_iri] and
         usage[:reservation_iri] == attempt[:reservation_iri] and
         usage[:invocation_iri] == attempt[:invocation_iri] and
         usage[:provider_request_iri] == attempt[:provider_request_iri] and
         usage[:model] == attempt[:model] and
         usage[:price_revision] == attempt[:price_revision] and
         usage[:accounting_fence] == context[:accounting_fence] do
      :ok
    else
      {:error, :usage_identity_drift}
    end
  end

  defp rollup_key(record) do
    {
      record.repository_iri,
      record.tenant_iri,
      record.actor_iri,
      record.profile_iri,
      record.trigger,
      record.edition_iri,
      record.period_key,
      record.currency
    }
  end

  defp expired_reservation?(attempt, evaluated_at),
    do:
      attempt[:reservation_state] == :reserved and
        match?(%DateTime{}, attempt[:reservation_expires_at]) and
        DateTime.compare(attempt.reservation_expires_at, evaluated_at) != :gt

  defp invocation_pending?(attempt),
    do: not is_nil(attempt[:invoked_at]) and is_nil(attempt[:terminal_usage_iri])

  defp impossible_tokens?(attempt),
    do:
      attempt[:generation_mode] == :deterministic_only and Map.get(attempt, :total_tokens, 0) != 0

  defp maybe_alert(values, false, _kind, _attempt), do: values

  defp maybe_alert(values, true, kind, attempt),
    do: [alert(kind, attempt, :attention_required) | values]

  defp alert(kind, attempt, detail) do
    value = %{kind: kind, attempt_iri: attempt[:attempt_iri], detail: detail}
    Map.put(value, :digest, Knowledge.repository_wiki_digest(value))
  end
end

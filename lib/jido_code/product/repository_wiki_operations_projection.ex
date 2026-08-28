defmodule JidoCode.Product.RepositoryWikiOperationsProjection do
  @moduledoc """
  Authorized, bounded repository-wiki usage and operations projection.

  The projection contains accounting facts and safe operational summaries, not
  page/source bodies, prompts, credentials, provider payloads, graph handles,
  or process-local state.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @token_classes [:input, :output, :cached, :reasoning]
  @cost_classes [:reserved, :charged, :unknown]
  @dimensions [
    :trigger,
    :generation_mode,
    :profile_key,
    :edition_iri,
    :actor_iri,
    :state,
    :source_revision
  ]
  @reservation_states [:reserved, :invoked, :usage_pending, :usage_unknown]
  @maximum_records 200

  @enforce_keys [
    :state,
    :repository_iri,
    :tenant_iri,
    :evaluated_at,
    :period,
    :totals,
    :currency_totals,
    :breakdowns,
    :budget,
    :profile,
    :reservations,
    :warnings
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec empty(String.t() | nil, atom()) :: t()
  def empty(repository_iri \\ nil, state \\ :unavailable) do
    %__MODULE__{
      state: state,
      repository_iri: repository_iri,
      tenant_iri: nil,
      evaluated_at: nil,
      period: nil,
      totals: Map.put(zero_totals(), :attempts, 0),
      currency_totals: [],
      breakdowns: [],
      budget: %{state: :unavailable, limit: nil, remaining: nil, currency: nil, live: 0},
      profile: %{
        deterministic_available?: true,
        synthesis_available?: false,
        unavailable_reason: :hosted_synthesis_disabled_in_v1
      },
      reservations: [],
      warnings: [state]
    }
  end

  @spec build(map()) :: {:ok, t()} | {:error, Error.t()}
  def build(attributes) when is_map(attributes) do
    with :ok <- validate_attributes(attributes),
         {:ok, usage} <- validate_usage(attributes.usage_records, attributes),
         {:ok, reservations} <- validate_reservations(attributes.reservations, attributes),
         {:ok, budget} <- validate_budget(attributes.budget),
         {:ok, profile} <- validate_profile(attributes.profile),
         totals <- totals(usage, reservations),
         currency_totals <- currency_totals(usage, reservations),
         breakdowns <- breakdowns(usage),
         warnings <- warnings(usage, reservations, currency_totals),
         state <- state(usage, reservations, currency_totals, warnings) do
      {:ok,
       %__MODULE__{
         state: state,
         repository_iri: attributes.repository_iri,
         tenant_iri: attributes.tenant_iri,
         evaluated_at: attributes.evaluated_at,
         period: %{start_at: attributes.period_start, end_at: attributes.period_end},
         totals: totals,
         currency_totals: currency_totals,
         breakdowns: breakdowns,
         budget: Map.put(budget, :live, length(reservations)),
         profile: profile,
         reservations: Enum.map(reservations, &safe_reservation/1),
         warnings: warnings
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_operations_projection)
    end
  rescue
    _error -> invalid(:repository_wiki_operations_projection)
  end

  def build(_attributes), do: invalid(:repository_wiki_operations_projection)

  defp validate_attributes(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:repository_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:tenant_iri]),
         %DateTime{} <- attributes[:evaluated_at],
         %DateTime{} <- attributes[:period_start],
         %DateTime{} <- attributes[:period_end],
         true <- DateTime.compare(attributes.period_start, attributes.period_end) == :lt,
         true <- DateTime.compare(attributes.period_end, attributes.evaluated_at) != :gt,
         true <- is_list(attributes[:usage_records]),
         true <- length(attributes.usage_records) <= @maximum_records,
         true <- is_list(attributes[:reservations]),
         true <- length(attributes.reservations) <= @maximum_records do
      :ok
    else
      _invalid -> invalid(:repository_wiki_operations_scope)
    end
  end

  defp validate_usage(records, attributes) do
    records
    |> Enum.reduce_while({:ok, []}, fn record, {:ok, accepted} ->
      case valid_usage?(record, attributes) do
        true -> {:cont, {:ok, [record | accepted]}}
        false -> {:halt, unauthorized(:repository_wiki_usage_scope)}
      end
    end)
    |> case do
      {:ok, accepted} -> {:ok, Enum.sort_by(accepted, &{&1.recorded_at, &1.iri})}
      error -> error
    end
  end

  defp valid_usage?(record, attributes) when is_map(record) do
    required =
      ~w[iri repository_iri tenant_iri attempt_iri edition_iri actor_iri generation_mode trigger
         profile_key source_revision state tokens costs currency local_work recorded_at]a

    Enum.all?(required, &Map.has_key?(record, &1)) and
      record.repository_iri == attributes.repository_iri and
      record.tenant_iri == attributes.tenant_iri and
      Enum.all?(~w[iri attempt_iri edition_iri actor_iri]a, fn key ->
        Knowledge.validate_resource_identity(record[key]) == :ok
      end) and record.generation_mode in [:deterministic_only, :synthesis_allowed] and
      bounded_text?(record.trigger, 128) and bounded_text?(record.profile_key, 128) and
      bounded_text?(record.source_revision, 512) and is_atom(record.state) and
      counts?(record.tokens, @token_classes) and counts?(record.costs, @cost_classes) and
      currency?(record.currency) and local_work?(record.local_work) and
      match?(%DateTime{}, record.recorded_at) and
      DateTime.compare(record.recorded_at, attributes.period_start) != :lt and
      DateTime.compare(record.recorded_at, attributes.period_end) == :lt and
      deterministic_zero?(record)
  rescue
    _error -> false
  end

  defp valid_usage?(_record, _attributes), do: false

  defp validate_reservations(reservations, attributes) do
    reservations
    |> Enum.reduce_while({:ok, []}, fn reservation, {:ok, accepted} ->
      if valid_reservation?(reservation, attributes) do
        {:cont, {:ok, [reservation | accepted]}}
      else
        {:halt, unauthorized(:repository_wiki_reservation_scope)}
      end
    end)
    |> case do
      {:ok, accepted} -> {:ok, Enum.sort_by(accepted, &{&1.expires_at, &1.iri})}
      error -> error
    end
  end

  defp valid_reservation?(reservation, attributes) when is_map(reservation) do
    required = ~w[iri repository_iri tenant_iri state cost_microunits currency expires_at]a

    Enum.all?(required, &Map.has_key?(reservation, &1)) and
      reservation.repository_iri == attributes.repository_iri and
      reservation.tenant_iri == attributes.tenant_iri and
      Knowledge.validate_resource_identity(reservation.iri) == :ok and
      reservation.state in @reservation_states and nonnegative?(reservation.cost_microunits) and
      currency?(reservation.currency) and match?(%DateTime{}, reservation.expires_at)
  end

  defp valid_reservation?(_reservation, _attributes), do: false

  defp validate_budget(budget) when is_map(budget) do
    with state when state in [:available, :exhausted, :unavailable] <- budget[:state],
         true <- nonnegative_or_nil?(budget[:limit]),
         true <- nonnegative_or_nil?(budget[:remaining]),
         true <- is_nil(budget[:currency]) or currency?(budget.currency),
         true <- match?(%DateTime{}, budget[:window_start]),
         true <- match?(%DateTime{}, budget[:window_end]),
         true <- DateTime.compare(budget.window_start, budget.window_end) == :lt do
      {:ok, Map.take(budget, [:state, :limit, :remaining, :currency, :window_start, :window_end])}
    else
      _invalid -> invalid(:repository_wiki_budget_projection)
    end
  end

  defp validate_budget(_budget), do: invalid(:repository_wiki_budget_projection)

  defp validate_profile(profile) when is_map(profile) do
    if profile[:deterministic_available?] == true and profile[:synthesis_available?] == false and
         profile[:unavailable_reason] == :hosted_synthesis_disabled_in_v1 do
      {:ok,
       %{
         deterministic_available?: true,
         synthesis_available?: false,
         unavailable_reason: :hosted_synthesis_disabled_in_v1
       }}
    else
      invalid(:repository_wiki_profile_projection)
    end
  end

  defp validate_profile(_profile), do: invalid(:repository_wiki_profile_projection)

  defp totals(usage, reservations) do
    Enum.reduce(usage, zero_totals(), fn record, totals ->
      %{
        attempts: MapSet.put(totals.attempts, record.attempt_iri),
        deterministic_attempts:
          totals.deterministic_attempts +
            if(record.generation_mode == :deterministic_only, do: 1, else: 0),
        local_elapsed_ms: totals.local_elapsed_ms + record.local_work.elapsed_ms,
        local_input_bytes: totals.local_input_bytes + record.local_work.input_bytes,
        input_tokens: totals.input_tokens + record.tokens.input,
        output_tokens: totals.output_tokens + record.tokens.output,
        cached_tokens: totals.cached_tokens + record.tokens.cached,
        reasoning_tokens: totals.reasoning_tokens + record.tokens.reasoning,
        measured_cost_microunits: totals.measured_cost_microunits + record.costs.charged,
        unknown_liability_microunits: totals.unknown_liability_microunits + record.costs.unknown,
        reserved_liability_microunits: totals.reserved_liability_microunits
      }
    end)
    |> then(fn totals ->
      reserved = Enum.sum(Enum.map(reservations, & &1.cost_microunits))

      totals
      |> Map.put(:attempts, MapSet.size(totals.attempts))
      |> Map.put(:reserved_liability_microunits, reserved)
    end)
  end

  defp zero_totals do
    %{
      attempts: MapSet.new(),
      deterministic_attempts: 0,
      local_elapsed_ms: 0,
      local_input_bytes: 0,
      input_tokens: 0,
      output_tokens: 0,
      cached_tokens: 0,
      reasoning_tokens: 0,
      measured_cost_microunits: 0,
      reserved_liability_microunits: 0,
      unknown_liability_microunits: 0
    }
  end

  defp currency_totals(usage, reservations) do
    usage_values =
      Enum.map(usage, fn record ->
        {record.currency,
         %{
           measured: record.costs.charged,
           unknown: record.costs.unknown,
           reserved: 0
         }}
      end)

    reservation_values =
      Enum.map(reservations, fn reservation ->
        {reservation.currency, %{measured: 0, unknown: 0, reserved: reservation.cost_microunits}}
      end)

    (usage_values ++ reservation_values)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {currency, values} ->
      %{
        id: digest({:currency, currency}),
        currency: currency,
        measured: Enum.sum(Enum.map(values, & &1.measured)),
        unknown: Enum.sum(Enum.map(values, & &1.unknown)),
        reserved: Enum.sum(Enum.map(values, & &1.reserved))
      }
    end)
    |> Enum.sort_by(& &1.currency)
  end

  defp breakdowns(usage) do
    @dimensions
    |> Enum.flat_map(fn dimension ->
      usage
      |> Enum.group_by(&Map.fetch!(&1, dimension))
      |> Enum.map(fn {value, records} ->
        %{
          id: digest({dimension, value}),
          dimension: dimension,
          value: safe_value(value),
          attempts: records |> Enum.map(& &1.attempt_iri) |> Enum.uniq() |> length(),
          tokens: Enum.sum(Enum.map(records, &token_total(&1.tokens))),
          measured_cost_microunits: Enum.sum(Enum.map(records, & &1.costs.charged)),
          unknown_liability_microunits: Enum.sum(Enum.map(records, & &1.costs.unknown))
        }
      end)
    end)
    |> Enum.sort_by(&{&1.dimension, &1.value})
  end

  defp warnings(usage, reservations, currencies) do
    []
    |> maybe_warning(Enum.any?(usage, &(&1.state == :usage_pending)), :usage_pending)
    |> maybe_warning(Enum.any?(usage, &(&1.state == :usage_unknown)), :usage_unknown)
    |> maybe_warning(Enum.any?(reservations, &(&1.state == :usage_pending)), :usage_pending)
    |> maybe_warning(Enum.any?(reservations, &(&1.state == :usage_unknown)), :usage_unknown)
    |> maybe_warning(length(currencies) > 1, :multicurrency)
    |> Enum.uniq()
  end

  defp state(usage, reservations, currencies, warnings) do
    cond do
      :usage_unknown in warnings -> :usage_unknown
      :usage_pending in warnings -> :usage_pending
      length(currencies) > 1 -> :multicurrency
      usage == [] and reservations == [] -> :empty
      true -> :ready
    end
  end

  defp safe_reservation(reservation) do
    %{
      id: digest(reservation.iri),
      state: reservation.state,
      cost_microunits: reservation.cost_microunits,
      currency: reservation.currency,
      expires_at: reservation.expires_at
    }
  end

  defp deterministic_zero?(%{generation_mode: :deterministic_only} = record) do
    token_total(record.tokens) == 0 and
      Enum.all?(@cost_classes, &(Map.fetch!(record.costs, &1) == 0))
  end

  defp deterministic_zero?(_record), do: true
  defp token_total(tokens), do: Enum.sum(Enum.map(@token_classes, &Map.fetch!(tokens, &1)))

  defp counts?(counts, keys) when is_map(counts),
    do: Enum.all?(keys, &nonnegative?(counts[&1]))

  defp counts?(_counts, _keys), do: false

  defp local_work?(%{elapsed_ms: elapsed, input_bytes: bytes}),
    do: nonnegative?(elapsed) and nonnegative?(bytes)

  defp local_work?(_local), do: false
  defp currency?(value), do: is_binary(value) and Regex.match?(~r/^[A-Z]{3}$/, value)
  defp bounded_text?(value, max), do: is_binary(value) and byte_size(value) in 1..max
  defp nonnegative?(value), do: is_integer(value) and value >= 0
  defp nonnegative_or_nil?(nil), do: true
  defp nonnegative_or_nil?(value), do: nonnegative?(value)
  defp safe_value(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_value(value) when is_binary(value), do: value
  defp safe_value(_value), do: "unavailable"
  defp maybe_warning(values, true, warning), do: [warning | values]
  defp maybe_warning(values, false, _warning), do: values
  defp digest(value), do: Knowledge.repository_wiki_digest(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, Error.new(:unauthorized, operation)}
end

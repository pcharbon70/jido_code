defmodule JidoCode.Knowledge.Temporal do
  @moduledoc """
  Bounded transaction-time and valid-time rules for graph assertions.

  Times are supplied by command callers. This module never reads a clock and
  never treats wall time as a causal ordering mechanism.
  """

  alias JidoCode.Knowledge.Error

  @max_claims 10_000
  @max_results 1_000
  @time_keys [
    :recorded_at,
    :generated_at,
    :valid_from,
    :valid_to,
    :source_observed_at,
    :invalidated_at
  ]

  @spec validate(map()) :: :ok | {:error, Error.t()}
  def validate(attributes) when is_map(attributes) do
    with true <- match?(%DateTime{}, Map.get(attributes, :recorded_at)),
         true <- Enum.all?(@time_keys, &valid_optional_time?(Map.get(attributes, &1))),
         true <-
           ordered_interval?(Map.get(attributes, :valid_from), Map.get(attributes, :valid_to)),
         true <-
           not_after?(Map.get(attributes, :generated_at), Map.get(attributes, :recorded_at)),
         true <-
           not_after?(Map.get(attributes, :source_observed_at), Map.get(attributes, :recorded_at)),
         true <-
           not_before?(Map.get(attributes, :invalidated_at), Map.get(attributes, :recorded_at)) do
      :ok
    else
      _invalid -> {:error, Error.new(:invalid_input, :temporal_contract)}
    end
  end

  def validate(_attributes), do: {:error, Error.new(:invalid_input, :temporal_contract)}

  @spec query([map()], map()) :: {:ok, [map()]} | {:error, Error.t()}
  def query(claims, params) when is_list(claims) and is_map(params) do
    with true <- length(claims) <= @max_claims,
         true <- Enum.all?(claims, &temporal_projection?/1),
         %DateTime{} = valid_at <- Map.get(params, :valid_at),
         %DateTime{} = recorded_as_of <- Map.get(params, :recorded_as_of),
         {:ok, status} <- query_status(Map.get(params, :status)),
         {:ok, limit} <- query_limit(Map.get(params, :limit, 100)) do
      results =
        claims
        |> Enum.map(&Map.put(&1, :temporal_status, status_at(&1, valid_at, recorded_as_of)))
        |> maybe_filter_status(status)
        |> Enum.sort_by(&{DateTime.to_unix(&1.recorded_at, :microsecond), &1.claim_iri})
        |> Enum.take(limit)

      {:ok, results}
    else
      _invalid -> {:error, Error.new(:invalid_input, :temporal_query)}
    end
  end

  def query(_claims, _params), do: {:error, Error.new(:invalid_input, :temporal_query)}

  @spec status_at(map(), DateTime.t(), DateTime.t()) ::
          :valid | :recorded | :superseded | :unknown
  def status_at(claim, valid_at, recorded_as_of) do
    cond do
      not temporal_projection?(claim) ->
        :unknown

      DateTime.compare(claim.recorded_at, recorded_as_of) == :gt ->
        :unknown

      superseded_as_of?(claim, recorded_as_of) ->
        :superseded

      valid_at?(claim, valid_at) ->
        :valid

      true ->
        :recorded
    end
  end

  defp temporal_projection?(claim) do
    is_map(claim) and is_binary(Map.get(claim, :claim_iri)) and
      match?(%DateTime{}, Map.get(claim, :recorded_at))
  end

  defp superseded_as_of?(claim, recorded_as_of) do
    state_superseded? = Map.get(claim, :epistemic_state) in [:superseded, :invalidated]

    invalidated_as_of? =
      case Map.get(claim, :invalidated_at) do
        %DateTime{} = invalidated_at -> DateTime.compare(invalidated_at, recorded_as_of) != :gt
        _missing -> false
      end

    state_superseded? or invalidated_as_of?
  end

  defp valid_at?(claim, point) do
    starts_before? =
      case Map.get(claim, :valid_from) do
        %DateTime{} = from -> DateTime.compare(from, point) != :gt
        nil -> true
      end

    ends_after? =
      case Map.get(claim, :valid_to) do
        %DateTime{} = to -> DateTime.compare(point, to) == :lt
        nil -> true
      end

    starts_before? and ends_after?
  end

  defp query_status(nil), do: {:ok, nil}

  defp query_status(status) when status in [:valid, :recorded, :superseded, :unknown],
    do: {:ok, status}

  defp query_status(_status), do: :error

  defp query_limit(limit) when is_integer(limit) and limit > 0 and limit <= @max_results,
    do: {:ok, limit}

  defp query_limit(_limit), do: :error

  defp maybe_filter_status(claims, nil), do: claims

  defp maybe_filter_status(claims, status),
    do: Enum.filter(claims, &(&1.temporal_status == status))

  defp valid_optional_time?(nil), do: true
  defp valid_optional_time?(%DateTime{}), do: true
  defp valid_optional_time?(_value), do: false

  defp ordered_interval?(nil, _to), do: true
  defp ordered_interval?(_from, nil), do: true

  defp ordered_interval?(%DateTime{} = from, %DateTime{} = to),
    do: DateTime.compare(from, to) == :lt

  defp ordered_interval?(_from, _to), do: false

  defp not_after?(nil, _recorded_at), do: true

  defp not_after?(%DateTime{} = observed_at, %DateTime{} = recorded_at),
    do: DateTime.compare(observed_at, recorded_at) != :gt

  defp not_after?(_observed_at, _recorded_at), do: false

  defp not_before?(nil, _recorded_at), do: true

  defp not_before?(%DateTime{} = invalidated_at, %DateTime{} = recorded_at),
    do: DateTime.compare(invalidated_at, recorded_at) != :lt

  defp not_before?(_invalidated_at, _recorded_at), do: false
end

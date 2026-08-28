defmodule JidoCode.Knowledge.RepositoryWiki.PriceProfile do
  @moduledoc "Immutable integer-priced model usage profile used by the disabled V1 boundary."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :provider,
    :model,
    :region,
    :currency,
    :unit_tokens,
    :rates,
    :rounding,
    :source_provenance,
    :effective_at,
    :expires_at,
    :state,
    :digest
  ]
  defstruct @enforce_keys ++ [supersedes: nil]

  @type t :: %__MODULE__{}
  @dimensions [:input, :output, :cached, :reasoning]
  @maximum 9_223_372_036_854_775_807

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         true <- bounded?(attributes[:provider], 128),
         true <- bounded?(attributes[:model], 128),
         true <- bounded?(attributes[:region], 64),
         true <- currency?(attributes[:currency]),
         unit when is_integer(unit) and unit > 0 <- attributes[:unit_tokens],
         :ok <- rates(attributes[:rates]),
         :ceil <- attributes[:rounding],
         :ok <- Contract.resource(attributes[:source_provenance]),
         :ok <- Contract.optional_resource(attributes[:supersedes]),
         true <- Contract.valid_interval?(attributes[:effective_at], attributes[:expires_at]),
         state when state in [:disabled, :superseded] <- attributes[:state],
         material <- material(attributes),
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_budget, "price\n" <> digest) do
      {:ok, struct!(__MODULE__, material |> Map.put(:iri, iri) |> Map.put(:digest, digest))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_price_profile)
    end
  rescue
    _error -> invalid(:wiki_price_profile)
  end

  def new(_attributes), do: invalid(:wiki_price_profile)

  @spec selectable?(t(), DateTime.t()) :: boolean()
  def selectable?(%__MODULE__{}, %DateTime{}), do: false

  @spec cost(t(), map(), DateTime.t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def cost(%__MODULE__{} = profile, usage, %DateTime{} = incurred_at) when is_map(usage) do
    with true <- effective?(profile, incurred_at),
         :ok <- usage(usage),
         {:ok, costs} <-
           Enum.reduce_while(@dimensions, {:ok, []}, fn dimension, {:ok, acc} ->
             with {:ok, product} <- checked_multiply(usage[dimension], profile.rates[dimension]),
                  {:ok, rounded} <- ceil_div(product, profile.unit_tokens) do
               {:cont, {:ok, [rounded | acc]}}
             else
               {:error, %Error{} = error} -> {:halt, {:error, error}}
             end
           end),
         {:ok, total} <- checked_sum(costs) do
      {:ok, total}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_price_calculation)
    end
  end

  def cost(_profile, _usage, _incurred_at), do: invalid(:wiki_price_calculation)

  defp material(attributes) do
    %{
      revision: attributes.revision,
      provider: attributes.provider,
      model: attributes.model,
      region: attributes.region,
      currency: attributes.currency,
      unit_tokens: attributes.unit_tokens,
      rates: Map.take(attributes.rates, @dimensions),
      rounding: :ceil,
      source_provenance: attributes.source_provenance,
      supersedes: attributes[:supersedes],
      effective_at: DateTime.truncate(attributes.effective_at, :microsecond),
      expires_at: attributes.expires_at,
      state: attributes.state
    }
  end

  defp rates(value) when is_map(value) do
    if Enum.sort(Map.keys(value)) == Enum.sort(@dimensions) and
         Enum.all?(@dimensions, &(is_integer(value[&1]) and value[&1] >= 0)) do
      :ok
    else
      invalid(:wiki_price_rates)
    end
  end

  defp rates(_value), do: invalid(:wiki_price_rates)

  defp usage(value) do
    if Enum.all?(@dimensions, &(is_integer(value[&1]) and value[&1] >= 0)) do
      :ok
    else
      invalid(:wiki_price_usage)
    end
  end

  defp checked_multiply(left, right)
       when is_integer(left) and left >= 0 and is_integer(right) and right >= 0 do
    if left == 0 or right <= div(@maximum, left) do
      {:ok, left * right}
    else
      invalid(:wiki_cost_overflow)
    end
  end

  defp checked_sum(values) do
    Enum.reduce_while(values, {:ok, 0}, fn value, {:ok, total} ->
      if value <= @maximum - total do
        {:cont, {:ok, total + value}}
      else
        {:halt, invalid(:wiki_cost_overflow)}
      end
    end)
  end

  defp ceil_div(0, _denominator), do: {:ok, 0}
  defp ceil_div(numerator, denominator), do: {:ok, div(numerator - 1, denominator) + 1}

  defp effective?(profile, incurred_at) do
    DateTime.compare(profile.effective_at, incurred_at) in [:lt, :eq] and
      (is_nil(profile.expires_at) or DateTime.compare(incurred_at, profile.expires_at) == :lt)
  end

  defp currency?(value), do: is_binary(value) and Regex.match?(~r/^[A-Z]{3}$/, value)
  defp bounded?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

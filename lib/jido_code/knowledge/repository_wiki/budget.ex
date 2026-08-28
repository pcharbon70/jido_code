defmodule JidoCode.Knowledge.RepositoryWiki.Budget do
  @moduledoc "Finite, immutable repository wiki budget scope and accounting window."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @dimensions [
    :provider_calls,
    :input_tokens,
    :output_tokens,
    :cached_tokens,
    :reasoning_tokens,
    :total_tokens,
    :cost_microunits
  ]
  @enforce_keys [
    :iri,
    :revision,
    :repository_iri,
    :tenant_iri,
    :actor_iri,
    :profile_iri,
    :period_key,
    :starts_at,
    :expires_at,
    :currency,
    :limits,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec dimensions() :: [atom()]
  def dimensions, do: @dimensions

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         :ok <- resources(attributes),
         true <- bounded?(attributes[:period_key], 96),
         true <- Contract.valid_interval?(attributes[:starts_at], attributes[:expires_at]),
         true <- currency?(attributes[:currency]),
         :ok <- finite_limits(attributes[:limits]),
         material <- material(attributes),
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_budget, digest) do
      {:ok, struct!(__MODULE__, material |> Map.put(:iri, iri) |> Map.put(:digest, digest))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_budget)
    end
  rescue
    _error -> invalid(:wiki_budget)
  end

  def new(_attributes), do: invalid(:wiki_budget)

  @spec current?(t(), DateTime.t()) :: boolean()
  def current?(%__MODULE__{} = budget, %DateTime{} = evaluated_at) do
    DateTime.compare(budget.starts_at, evaluated_at) in [:lt, :eq] and
      DateTime.compare(evaluated_at, budget.expires_at) == :lt
  end

  defp material(attributes) do
    %{
      revision: attributes.revision,
      repository_iri: attributes.repository_iri,
      tenant_iri: attributes.tenant_iri,
      actor_iri: attributes.actor_iri,
      profile_iri: attributes.profile_iri,
      period_key: attributes.period_key,
      starts_at: DateTime.truncate(attributes.starts_at, :microsecond),
      expires_at: attributes.expires_at,
      currency: attributes.currency,
      limits: Map.take(attributes.limits, @dimensions)
    }
  end

  defp resources(attributes) do
    Enum.reduce_while(~w[repository_iri tenant_iri actor_iri profile_iri]a, :ok, fn key, :ok ->
      case Contract.resource(attributes[key]) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp finite_limits(value) when is_map(value) do
    if Enum.sort(Map.keys(value)) == Enum.sort(@dimensions) and
         Enum.all?(@dimensions, &(is_integer(value[&1]) and value[&1] >= 0)) and
         value.provider_calls > 0 do
      :ok
    else
      invalid(:wiki_budget_limits)
    end
  end

  defp finite_limits(_value), do: invalid(:wiki_budget_limits)
  defp currency?(value), do: is_binary(value) and Regex.match?(~r/^[A-Z]{3}$/, value)
  defp bounded?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

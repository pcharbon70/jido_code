defmodule JidoCode.Knowledge.TemporalSelection do
  @moduledoc """
  Bounded bitemporal selection over attributable assertion projections.

  The selector preserves concurrent incompatible claims and never resolves
  disagreement by timestamp alone.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry

  @max_assertions 10_000
  @max_results 1_000
  @max_historical_graphs 20

  @spec select([map()], map()) :: {:ok, map()} | {:error, Error.t()}
  def select(assertions, constraints)
      when is_list(assertions) and length(assertions) <= @max_assertions and
             is_map(constraints) do
    with :ok <- validate_assertions(assertions),
         {:ok, limit} <- limit(constraints),
         {:ok, graphs} <- historical_graphs(constraints),
         {:ok, valid_at} <- valid_at(constraints),
         {:ok, recorded_revision} <- recorded_revision(constraints) do
      selected =
        assertions
        |> Enum.filter(&graph_retained?(&1, graphs))
        |> Enum.filter(&recorded_by?(&1, recorded_revision))
        |> Enum.filter(&source_observed_by?(&1, Map.get(constraints, :source_observed_as_of)))
        |> Enum.filter(&valid_at?(&1, valid_at))
        |> Enum.filter(&not_invalidated?(&1, constraints))
        |> Enum.sort_by(&{&1.recorded_revision, &1.assertion_iri})

      truncated? = length(selected) > limit

      {:ok,
       %{
         assertions: Enum.take(selected, limit),
         recorded_revision: recorded_revision,
         valid_at: valid_at,
         historical_graphs: graphs,
         truncated?: truncated?,
         contradictions?: contradictory?(selected)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def select(_assertions, _constraints), do: invalid()

  defp validate_assertions(assertions) do
    if Enum.all?(assertions, fn assertion ->
         is_map(assertion) and is_binary(Map.get(assertion, :assertion_iri)) and
           is_binary(Map.get(assertion, :graph_iri)) and
           is_integer(Map.get(assertion, :recorded_revision)) and
           Map.get(assertion, :recorded_revision) >= 0 and
           match?(%DateTime{}, Map.get(assertion, :recorded_at))
       end),
       do: :ok,
       else: invalid()
  end

  defp limit(constraints) do
    case Map.get(constraints, :limit, 100) do
      value when is_integer(value) and value > 0 and value <= @max_results -> {:ok, value}
      _invalid -> invalid()
    end
  end

  defp historical_graphs(constraints) do
    graphs = Map.get(constraints, :historical_graphs, [])

    if is_list(graphs) and length(graphs) <= @max_historical_graphs and
         Enum.all?(graphs, &match?({:ok, _family}, GraphRegistry.identify(&1))),
       do: {:ok, graphs},
       else: invalid()
  end

  defp valid_at(constraints) do
    case Map.get(constraints, :valid_at) do
      %DateTime{} = value -> {:ok, value}
      _invalid -> invalid()
    end
  end

  defp recorded_revision(constraints) do
    case Map.get(constraints, :recorded_revision) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _invalid -> invalid()
    end
  end

  defp graph_retained?(_assertion, []), do: true
  defp graph_retained?(assertion, graphs), do: assertion.graph_iri in graphs
  defp recorded_by?(assertion, revision), do: assertion.recorded_revision <= revision

  defp source_observed_by?(_assertion, nil), do: true

  defp source_observed_by?(assertion, %DateTime{} = instant) do
    case Map.get(assertion, :source_observed_at) do
      %DateTime{} = observed -> DateTime.compare(observed, instant) != :gt
      nil -> true
      _invalid -> false
    end
  end

  defp source_observed_by?(_assertion, _invalid), do: false

  defp valid_at?(assertion, instant) do
    starts? =
      case Map.get(assertion, :valid_from) do
        %DateTime{} = from -> DateTime.compare(from, instant) != :gt
        nil -> true
        _invalid -> false
      end

    ends? =
      case Map.get(assertion, :valid_to) do
        %DateTime{} = to -> DateTime.compare(instant, to) == :lt
        nil -> true
        _invalid -> false
      end

    starts? and ends?
  end

  defp not_invalidated?(assertion, constraints) do
    include_superseded? = Map.get(constraints, :include_superseded?, false)

    if include_superseded? do
      true
    else
      is_nil(Map.get(assertion, :invalidated_at)) and
        is_nil(Map.get(assertion, :superseded_by))
    end
  end

  defp contradictory?(assertions) do
    assertions
    |> Enum.group_by(&Map.get(&1, :claim_key))
    |> Enum.any?(fn
      {nil, _values} -> false
      {_key, values} -> values |> Enum.map(&Map.get(&1, :value)) |> Enum.uniq() |> length() > 1
    end)
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :temporal_selection)}
end

defmodule JidoCode.Knowledge.QueryConsistency do
  @moduledoc """
  Explicit revision, ontology, completeness, and valid-time read constraints.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry

  @modes [:strict, :warn, :historical, :best_effort]
  @max_graphs 20

  @enforce_keys [
    :mode,
    :exact_dataset_revision,
    :minimum_dataset_revision,
    :exact_graph_revisions,
    :minimum_graph_revisions,
    :ontology_version,
    :required_complete_graphs,
    :valid_at,
    :valid_interval,
    :derived_rule_set_revision,
    :historical_graphs
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(nil | map() | t()) :: {:ok, t()} | {:error, Error.t()}
  def new(%__MODULE__{} = consistency), do: validate(consistency)

  def new(nil) do
    new(%{})
  end

  def new(attributes) when is_map(attributes) do
    consistency = %__MODULE__{
      mode: value(attributes, :mode, :best_effort),
      exact_dataset_revision: value(attributes, :exact_dataset_revision),
      minimum_dataset_revision: value(attributes, :minimum_dataset_revision),
      exact_graph_revisions: value(attributes, :exact_graph_revisions, %{}),
      minimum_graph_revisions: value(attributes, :minimum_graph_revisions, %{}),
      ontology_version: value(attributes, :ontology_version),
      required_complete_graphs: value(attributes, :required_complete_graphs, []),
      valid_at: value(attributes, :valid_at),
      valid_interval: value(attributes, :valid_interval),
      derived_rule_set_revision: value(attributes, :derived_rule_set_revision),
      historical_graphs: value(attributes, :historical_graphs, [])
    }

    validate(consistency)
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec digest(t()) :: String.t()
  def digest(%__MODULE__{} = consistency) do
    consistency
    |> Map.from_struct()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp validate(consistency) do
    with true <- consistency.mode in @modes,
         true <- revision_or_nil?(consistency.exact_dataset_revision),
         true <- revision_or_nil?(consistency.minimum_dataset_revision),
         true <-
           not (is_integer(consistency.exact_dataset_revision) and
                  is_integer(consistency.minimum_dataset_revision)),
         :ok <- revision_map(consistency.exact_graph_revisions),
         :ok <- revision_map(consistency.minimum_graph_revisions),
         true <-
           consistency.exact_graph_revisions
           |> Map.keys()
           |> MapSet.new()
           |> MapSet.disjoint?(Map.keys(consistency.minimum_graph_revisions) |> MapSet.new()),
         true <- iri_or_nil?(consistency.ontology_version),
         :ok <- graph_list(consistency.required_complete_graphs),
         true <- time_or_nil?(consistency.valid_at),
         :ok <- interval(consistency.valid_interval),
         true <-
           not (match?(%DateTime{}, consistency.valid_at) and
                  not is_nil(consistency.valid_interval)),
         true <- revision_or_nil?(consistency.derived_rule_set_revision),
         :ok <- graph_list(consistency.historical_graphs),
         :ok <- historical_mode(consistency) do
      {:ok, consistency}
    else
      _invalid -> invalid()
    end
  end

  defp revision_map(value) when is_map(value) and map_size(value) <= @max_graphs do
    if Enum.all?(value, fn {graph, revision} ->
         registered_graph?(graph) and is_integer(revision) and revision >= 0
       end),
       do: :ok,
       else: invalid()
  end

  defp revision_map(_value), do: invalid()

  defp graph_list(graphs) when is_list(graphs) and length(graphs) <= @max_graphs do
    if graphs == Enum.uniq(graphs) and Enum.all?(graphs, &registered_graph?/1),
      do: :ok,
      else: invalid()
  end

  defp graph_list(_graphs), do: invalid()

  defp interval(nil), do: :ok

  defp interval({%DateTime{} = from, %DateTime{} = to}) do
    if DateTime.compare(from, to) == :lt and DateTime.diff(to, from, :day) <= 3_660,
      do: :ok,
      else: invalid()
  end

  defp interval(_interval), do: invalid()

  defp historical_mode(%{mode: :historical, historical_graphs: [_first | _rest]}), do: :ok
  defp historical_mode(%{mode: :historical}), do: invalid()
  defp historical_mode(%{historical_graphs: []}), do: :ok
  defp historical_mode(_consistency), do: invalid()

  defp registered_graph?(graph) when is_binary(graph),
    do: match?({:ok, _family}, GraphRegistry.identify(graph))

  defp registered_graph?(_graph), do: false
  defp revision_or_nil?(nil), do: true
  defp revision_or_nil?(value), do: is_integer(value) and value >= 0
  defp iri_or_nil?(nil), do: true
  defp iri_or_nil?(value), do: is_binary(value) and RDF.IRI.valid?(value)
  defp time_or_nil?(nil), do: true
  defp time_or_nil?(%DateTime{}), do: true
  defp time_or_nil?(_value), do: false

  defp value(attributes, key, default \\ nil),
    do: Map.get(attributes, key, Map.get(attributes, Atom.to_string(key), default))

  defp invalid, do: {:error, Error.new(:invalid_input, :query_consistency)}
end

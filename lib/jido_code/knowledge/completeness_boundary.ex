defmodule JidoCode.Knowledge.CompletenessBoundary do
  @moduledoc """
  Declared closed-world coverage for one subject and source snapshot.

  Absence is never interpreted as false unless exactly one current assertion
  covers the requested graph family, revision, predicates, and classes.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @max_coverage 100

  @enforce_keys [
    :assertion_iri,
    :subject_iri,
    :scope_iri,
    :graph_family,
    :source_graph_iri,
    :source_revision,
    :predicate_coverage,
    :class_coverage,
    :producer_iri,
    :valid_from,
    :valid_to,
    :invalidated_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    boundary = struct!(__MODULE__, attributes)

    with :ok <- ResourceIdentity.validate(boundary.assertion_iri),
         :ok <- ResourceIdentity.validate(boundary.subject_iri),
         :ok <- ResourceIdentity.validate(boundary.scope_iri),
         {:ok, family} <- GraphRegistry.identify(boundary.source_graph_iri),
         true <- family == boundary.graph_family,
         true <- is_integer(boundary.source_revision) and boundary.source_revision >= 0,
         :ok <- coverage(boundary.predicate_coverage),
         :ok <- coverage(boundary.class_coverage),
         :ok <- ResourceIdentity.validate(boundary.producer_iri),
         true <- match?(%DateTime{}, boundary.valid_from),
         true <- match?(%DateTime{}, boundary.valid_to),
         true <- DateTime.compare(boundary.valid_from, boundary.valid_to) == :lt,
         true <- is_nil(boundary.invalidated_at) or match?(%DateTime{}, boundary.invalidated_at) do
      {:ok, boundary}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec evaluate(map(), [t()], DateTime.t()) ::
          {:complete, t()} | {:unknown, [atom()]}
  def evaluate(requirement, boundaries, %DateTime{} = instant)
      when is_map(requirement) and is_list(boundaries) and length(boundaries) <= 100 do
    matches = Enum.filter(boundaries, &covers?(&1, requirement, instant))

    case matches do
      [boundary] -> {:complete, boundary}
      [] -> {:unknown, [:coverage_absent]}
      _contradictory -> {:unknown, [:coverage_ambiguous]}
    end
  rescue
    _error -> {:unknown, [:coverage_invalid]}
  end

  def evaluate(_requirement, _boundaries, _instant), do: {:unknown, [:coverage_invalid]}

  @spec closed_world_result(boolean(), map(), [t()], DateTime.t()) ::
          {:known, boolean(), t()} | {:unknown, [atom()]}
  def closed_world_result(statement_present?, requirement, boundaries, instant)
      when is_boolean(statement_present?) do
    case evaluate(requirement, boundaries, instant) do
      {:complete, boundary} -> {:known, statement_present?, boundary}
      {:unknown, gaps} -> {:unknown, gaps}
    end
  end

  defp covers?(boundary, requirement, instant) do
    active?(boundary, instant) and
      boundary.subject_iri == Map.get(requirement, :subject_iri) and
      boundary.scope_iri == Map.get(requirement, :scope_iri) and
      boundary.graph_family == Map.get(requirement, :graph_family) and
      boundary.source_graph_iri == Map.get(requirement, :source_graph_iri) and
      boundary.source_revision == Map.get(requirement, :source_revision) and
      subset?(Map.get(requirement, :predicates, []), boundary.predicate_coverage) and
      subset?(Map.get(requirement, :classes, []), boundary.class_coverage)
  end

  defp active?(boundary, instant) do
    DateTime.compare(boundary.valid_from, instant) in [:lt, :eq] and
      DateTime.compare(instant, boundary.valid_to) == :lt and
      (is_nil(boundary.invalidated_at) or
         DateTime.compare(instant, boundary.invalidated_at) == :lt)
  end

  defp coverage(values) when is_list(values) and length(values) <= @max_coverage do
    if values == Enum.uniq(values) and Enum.all?(values, &valid_iri?/1), do: :ok, else: invalid()
  end

  defp coverage(_values), do: invalid()

  defp subset?(required, available),
    do: MapSet.subset?(MapSet.new(required), MapSet.new(available))

  defp valid_iri?(value), do: is_binary(value) and RDF.IRI.valid?(value)
  defp invalid, do: {:error, Error.new(:invalid_input, :completeness_boundary)}
end

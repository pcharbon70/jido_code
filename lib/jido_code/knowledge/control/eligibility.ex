defmodule JidoCode.Knowledge.Control.Eligibility do
  @moduledoc """
  Closed-world execution eligibility over an exact graph context.

  The result is a transient explanation. An eligible result becomes durable
  only when `ExecutionLease.acquire_command/4` records its receipt in the same
  atomic graph commit that grants fenced execution authority.
  """

  alias JidoCode.Knowledge.Control.CapabilityRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :receipt_iri,
    :task_iri,
    :eligible?,
    :satisfied,
    :blockers,
    :providers,
    :policy_iris,
    :graph_revisions,
    :priority,
    :fairness,
    :risk,
    :evaluated_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @required_boundaries ~w[
    dependency lease cancellation capability policy artifact source
  ]a
  @boundary_blockers %{
    dependency: :dependency_boundary_incomplete,
    lease: :lease_boundary_incomplete,
    cancellation: :cancellation_boundary_incomplete,
    capability: :capability_boundary_incomplete,
    policy: :policy_boundary_incomplete,
    artifact: :artifact_boundary_incomplete,
    source: :source_boundary_incomplete
  }
  @max_graphs 16
  @max_related 100

  @spec evaluate(map()) :: {:ok, t()} | {:error, Error.t()}
  def evaluate(context) when is_map(context) do
    with :ok <- validate_context(context),
         {:ok, providers, capability_blockers} <- capability_matches(context),
         blockers <- blockers(context, capability_blockers),
         satisfied <- satisfied_conditions(blockers),
         {:ok, receipt_iri} <- receipt_identity(context, providers) do
      {:ok,
       %__MODULE__{
         receipt_iri: receipt_iri,
         task_iri: context.task.iri,
         eligible?: blockers == [],
         satisfied: satisfied,
         blockers: blockers,
         providers: providers,
         policy_iris: context.authorization.policy_iris,
         graph_revisions: context.graph_revisions,
         priority: context.priority,
         fairness: context.fairness,
         risk: context.risk,
         evaluated_at: DateTime.truncate(context.evaluated_at, :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:eligibility_context)
    end
  rescue
    _error -> invalid(:eligibility_context)
  end

  def evaluate(_context), do: invalid(:eligibility_context)

  defp validate_context(context) do
    with :ok <- validate_resource(get_in(context, [:task, :iri])),
         :ok <- validate_resource(get_in(context, [:task, :current_transition])),
         :ok <- validate_related(context[:dependencies]),
         :ok <- validate_related(context[:artifacts]),
         :ok <- validate_capabilities(context[:capabilities]),
         :ok <- validate_resources(get_in(context, [:authorization, :policy_iris])),
         true <- is_map(context[:boundaries]),
         true <- is_map(context[:graph_revisions]),
         true <- map_size(context.graph_revisions) in 1..@max_graphs,
         true <- context[:graph_revisions] == context[:current_graph_revisions],
         true <-
           MapSet.new(Map.keys(context.graph_revisions)) ==
             MapSet.new(context[:authorized_graphs]),
         true <- valid_revisions?(context.graph_revisions),
         true <- is_integer(context[:priority]),
         true <- is_integer(context[:fairness]),
         true <- is_integer(context[:risk]) and context.risk >= 0,
         true <- match?(%DateTime{}, context[:evaluated_at]) do
      :ok
    else
      _invalid -> invalid(:eligibility_context)
    end
  end

  defp validate_related(values) when is_list(values) and length(values) <= @max_related do
    if Enum.all?(values, &(is_map(&1) and validate_resource(&1[:iri]) == :ok)),
      do: :ok,
      else: invalid(:eligibility_relationships)
  end

  defp validate_related(_values), do: invalid(:eligibility_relationships)

  defp validate_capabilities(values) when is_list(values) and length(values) <= @max_related do
    if Enum.all?(values, fn value ->
         is_map(value) and validate_resource(value[:iri]) == :ok and
           validate_resource(value[:holder_iri]) == :ok and
           validate_resource(value[:capability_iri]) == :ok
       end),
       do: :ok,
       else: invalid(:eligibility_capabilities)
  end

  defp validate_capabilities(_values), do: invalid(:eligibility_capabilities)

  defp blockers(context, capability_blockers) do
    []
    |> add(context[:enrollment_state] != :active, :enrollment_inactive)
    |> add(context[:goal_state] not in [:approved, :eligible], :goal_inactive)
    |> add(context[:plan_state] != :approved, :plan_inactive)
    |> add(context.task[:state] not in [:approved, :eligible], :task_not_approved)
    |> add(Enum.any?(context.dependencies, &(&1[:state] != :satisfied)), :dependency_unsatisfied)
    |> add(Enum.any?(context.artifacts, &(&1[:available?] != true)), :artifact_unavailable)
    |> add(get_in(context, [:source, :complete?]) != true, :source_incomplete)
    |> add(get_in(context, [:source, :fresh?]) != true, :source_stale)
    |> add(get_in(context, [:source, :contradictory?]) == true, :source_contradictory)
    |> add(get_in(context, [:authorization, :complete?]) != true, :authorization_incomplete)
    |> add(get_in(context, [:authorization, :applicable?]) != true, :policy_not_applicable)
    |> add(get_in(context, [:authorization, :authorized?]) != true, :unauthorized)
    |> add(context[:cancelled?] != false, :cancellation_unknown_or_present)
    |> add(get_in(context, [:leases, :complete?]) != true, :lease_view_incomplete)
    |> add(get_in(context, [:leases, :active]) not in [[], nil], :active_lease_conflict)
    |> add(get_in(context, [:capacity, :complete?]) != true, :capacity_incomplete)
    |> add(get_in(context, [:capacity, :available?]) != true, :over_capacity)
    |> Kernel.++(boundary_blockers(context.boundaries))
    |> Kernel.++(capability_blockers)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp boundary_blockers(boundaries) do
    Enum.flat_map(@required_boundaries, fn boundary ->
      if Map.get(boundaries, boundary) == true,
        do: [],
        else: [Map.fetch!(@boundary_blockers, boundary)]
    end)
  end

  defp capability_matches(context) do
    required = context.task[:required_capability_iris] || []

    matches =
      context.capabilities
      |> Enum.filter(&(&1.capability_iri in required))
      |> Enum.reduce([], fn projection, admitted ->
        case CapabilityRegistry.schedulable?(projection, context.evaluated_at) do
          {:ok, provider} -> [provider | admitted]
          {:blocked, _reasons} -> admitted
        end
      end)
      |> Enum.sort_by(&{&1.holder_iri, &1.iri})

    missing =
      Enum.reject(required, fn requirement ->
        Enum.any?(matches, &(&1.capability_iri == requirement))
      end)

    reasons =
      cond do
        required == [] -> []
        matches == [] -> [:capability_unavailable]
        missing != [] -> [:capability_requirement_unmatched]
        true -> []
      end

    {:ok, matches, reasons}
  end

  defp satisfied_conditions(blockers) do
    all = [
      :active_enrollment,
      :active_goal,
      :approved_plan,
      :approved_task,
      :dependencies_satisfied,
      :artifacts_available,
      :source_fresh,
      :authorization_applicable,
      :capability_matched,
      :no_active_lease,
      :capacity_available,
      :closed_world_complete,
      :graph_revisions_exact
    ]

    if blockers == [], do: all, else: []
  end

  defp receipt_identity(context, providers) do
    material =
      {
        context.task.iri,
        Enum.sort(context.graph_revisions),
        Enum.map(providers, &{&1.iri, &1.holder_iri}),
        Enum.sort(context.authorization.policy_iris),
        context.priority,
        context.fairness,
        context.risk
      }
      |> :erlang.term_to_binary([:deterministic])

    ResourceIdentity.deterministic(:eligibility_receipt, material)
  end

  defp valid_revisions?(revisions) do
    Enum.all?(revisions, fn {graph, revision} ->
      is_binary(graph) and is_integer(revision) and revision > 0
    end)
  end

  defp validate_resources(values) when is_list(values) and length(values) <= @max_related do
    if Enum.all?(values, &(validate_resource(&1) == :ok)),
      do: :ok,
      else: invalid(:eligibility_resources)
  end

  defp validate_resources(_values), do: invalid(:eligibility_resources)

  defp add(reasons, true, reason), do: [reason | reasons]
  defp add(reasons, false, _reason), do: reasons
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

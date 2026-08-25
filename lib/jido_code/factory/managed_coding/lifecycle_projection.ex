defmodule JidoCode.Factory.ManagedCoding.LifecycleProjection do
  @moduledoc "Graph-reconstructable managed attempt status derived only from durable lifecycle events."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.LifecycleEvent

  @enforce_keys ~w[attempt_iri fencing_token state sequence wait_reason progress budget_use evidence_iris relationships updated_at]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec from_events([LifecycleEvent.t()]) :: {:ok, t()} | {:error, AdapterError.t()}
  def from_events([%LifecycleEvent{} | _rest] = events) do
    ordered = Enum.sort_by(events, & &1.sequence)

    with :ok <- one_identity(ordered),
         :ok <- contiguous(ordered),
         %LifecycleEvent{} = current <- last_transition(ordered) do
      observations = Enum.reject(ordered, &(&1.kind == :transition))

      {:ok,
       %__MODULE__{
         attempt_iri: current.attempt_iri,
         fencing_token: current.fencing_token,
         state: current.state,
         sequence: List.last(ordered).sequence,
         wait_reason: latest(ordered, :wait_reason),
         progress: latest(ordered, :progress),
         budget_use: latest(ordered, :budget_use) || %{},
         evidence_iris:
           ordered |> Enum.flat_map(& &1.evidence_iris) |> Enum.uniq() |> Enum.sort(),
         relationships: Enum.group_by(observations, & &1.kind, & &1.subject_iri),
         updated_at: List.last(ordered).recorded_at
       }}
    else
      _invalid -> invalid()
    end
  end

  def from_events(_events), do: invalid()

  defp one_identity([first | rest]) do
    if Enum.all?(rest, fn event ->
         event.attempt_iri == first.attempt_iri and event.fencing_token == first.fencing_token
       end),
       do: :ok,
       else: :error
  end

  defp contiguous(events) do
    if Enum.map(events, & &1.sequence) == Enum.to_list(0..(length(events) - 1)),
      do: :ok,
      else: :error
  end

  defp last_transition(events),
    do: events |> Enum.filter(&(&1.kind == :transition)) |> List.last()

  defp latest(events, field) do
    events
    |> Enum.reverse()
    |> Enum.find_value(&Map.get(&1, field))
  end

  defp invalid, do: {:error, AdapterError.new(:corrupt, :managed_coding_lifecycle_projection)}
end

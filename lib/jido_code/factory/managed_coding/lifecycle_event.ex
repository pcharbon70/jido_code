defmodule JidoCode.Factory.ManagedCoding.LifecycleEvent do
  @moduledoc "Bounded durable transition or attributable observation for one managed attempt."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @states ~w[admitted preparing running awaiting_actor assembling_candidate candidate_ready verifying dispositioned cancelled failed]a
  @kinds ~w[transition workspace invocation interaction tool_effect check artifact budget terminal_proposal candidate]a
  @wait_reasons ~w[actor model tool capacity verifier policy]a
  @enforce_keys ~w[event_iri attempt_iri fencing_token sequence origin_sequence kind state subject_iri actor_iri cause_iri evidence_iris occurred_at recorded_at late_observation]a
  defstruct @enforce_keys ++ [:previous_state, :wait_reason, :progress, :budget_use]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         origin when is_integer(origin) and origin >= 0 <- attributes[:origin_sequence],
         kind when kind in @kinds <- attributes[:kind],
         state when state in @states <- attributes[:state],
         :ok <- transition_contract(kind, attributes),
         :ok <- optional_wait_reason(attributes[:wait_reason]),
         :ok <- optional_progress(attributes[:progress]),
         :ok <- optional_budget(attributes[:budget_use]),
         evidence when is_list(evidence) and length(evidence) <= 64 <- attributes[:evidence_iris],
         true <- Enum.all?(evidence, &(Identity.validate_resource(&1) == :ok)),
         %DateTime{} = occurred <- attributes[:occurred_at],
         %DateTime{} = recorded <- attributes[:recorded_at],
         late when is_boolean(late) <- attributes[:late_observation],
         :ok <- causal_order(kind, origin, sequence, occurred, recorded, late),
         {:ok, event_iri} <- event_identity(attributes) do
      values =
        attributes
        |> Map.take(@enforce_keys ++ [:previous_state, :wait_reason, :progress, :budget_use])
        |> Map.put(:event_iri, event_iri)
        |> Map.put(:evidence_iris, Enum.sort(Enum.uniq(evidence)))
        |> Map.put(:occurred_at, DateTime.truncate(occurred, :microsecond))
        |> Map.put(:recorded_at, DateTime.truncate(recorded, :microsecond))

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec states() :: [atom()]
  def states, do: @states

  @spec observation_kinds() :: [atom()]
  def observation_kinds, do: @kinds -- [:transition]

  defp resources(attributes) do
    if Enum.all?(~w[attempt_iri subject_iri actor_iri cause_iri]a, fn field ->
         Identity.validate_resource(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp transition_contract(:transition, %{previous_state: nil, state: :admitted, sequence: 0}),
    do: :ok

  defp transition_contract(:transition, %{previous_state: previous}) when previous in @states,
    do: :ok

  defp transition_contract(:transition, _attributes), do: :error

  defp transition_contract(_kind, attributes) do
    if is_nil(attributes[:previous_state]), do: :ok, else: :error
  end

  defp optional_wait_reason(nil), do: :ok
  defp optional_wait_reason(reason) when reason in @wait_reasons, do: :ok
  defp optional_wait_reason(_reason), do: :error

  defp optional_progress(nil), do: :ok
  defp optional_progress(progress) when is_atom(progress), do: :ok
  defp optional_progress(_progress), do: :error

  defp optional_budget(nil), do: :ok

  defp optional_budget(budget) when is_map(budget) and map_size(budget) <= 32 do
    if Enum.all?(budget, fn {dimension, used} ->
         is_atom(dimension) and is_integer(used) and used >= 0
       end),
       do: :ok,
       else: :error
  end

  defp optional_budget(_budget), do: :error

  defp causal_order(:transition, origin, sequence, occurred, recorded, false) do
    if origin == sequence and DateTime.compare(occurred, recorded) in [:lt, :eq],
      do: :ok,
      else: :error
  end

  defp causal_order(_kind, origin, sequence, occurred, recorded, late) do
    causal = DateTime.compare(occurred, recorded) in [:lt, :eq]
    explicitly_late = (late and origin < sequence) or (not late and origin == sequence)
    if causal and explicitly_late, do: :ok, else: :error
  end

  defp event_identity(attributes) do
    Identity.deterministic(
      :execution_event,
      Enum.join(
        [
          attributes[:attempt_iri],
          attributes[:fencing_token],
          attributes[:sequence],
          attributes[:origin_sequence],
          attributes[:kind],
          attributes[:subject_iri],
          attributes[:cause_iri]
        ],
        "\n"
      )
    )
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_lifecycle_event)}
end

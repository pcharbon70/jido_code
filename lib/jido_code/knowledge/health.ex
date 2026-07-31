defmodule JidoCode.Knowledge.Health do
  @moduledoc """
  Readiness state for the knowledge substrate.

  Readiness is reachable only after both the physical store and required
  ontology contract have been verified in order.
  """

  alias JidoCode.Knowledge.Error

  @states [
    :starting,
    :opening,
    :verifying_store,
    :verifying_ontology,
    :ready,
    :maintenance,
    :recovering,
    :backing_up,
    :unavailable,
    :locked,
    :incompatible,
    :corrupt,
    :degraded
  ]

  @failure_states %{
    unavailable: :unavailable,
    locked: :locked,
    incompatible: :incompatible,
    corrupt: :corrupt
  }

  @enforce_keys [:state]
  defstruct state: :starting,
            store_verified?: false,
            ontology_verified?: false,
            maintenance_reason: nil,
            failure: nil

  @type state ::
          :starting
          | :opening
          | :verifying_store
          | :verifying_ontology
          | :ready
          | :maintenance
          | :recovering
          | :backing_up
          | :unavailable
          | :locked
          | :incompatible
          | :corrupt
          | :degraded

  @type t :: %__MODULE__{
          state: state(),
          store_verified?: boolean(),
          ontology_verified?: boolean(),
          maintenance_reason: :restore | :integrity_repair | :schema_migration | nil,
          failure: Error.t() | nil
        }

  def new, do: %__MODULE__{state: :starting}

  def opening(%__MODULE__{state: state} = health)
      when state in [
             :starting,
             :unavailable,
             :locked,
             :incompatible,
             :corrupt,
             :degraded
           ] do
    {:ok,
     %__MODULE__{
       health
       | state: :opening,
         store_verified?: false,
         ontology_verified?: false,
         maintenance_reason: nil,
         failure: nil
     }}
  end

  def opening(%__MODULE__{}), do: invalid_transition()

  def begin_verification(%__MODULE__{state: state} = health)
      when state in [:starting, :opening, :unavailable, :locked] do
    {:ok,
     %__MODULE__{
       health
       | state: :verifying_store,
         store_verified?: false,
         ontology_verified?: false,
         maintenance_reason: nil,
         failure: nil
     }}
  end

  def begin_verification(%__MODULE__{}), do: invalid_transition()

  def store_verified(%__MODULE__{state: :verifying_store} = health) do
    {:ok, %{health | state: :verifying_ontology, store_verified?: true}}
  end

  def store_verified(%__MODULE__{}), do: invalid_transition()

  def ontology_verified(
        %__MODULE__{
          state: :verifying_ontology,
          store_verified?: true
        } = health
      ) do
    {:ok, %{health | state: :ready, ontology_verified?: true}}
  end

  def ontology_verified(%__MODULE__{}), do: invalid_transition()

  def enter_maintenance(%__MODULE__{state: :ready} = health, reason)
      when reason in [:restore, :integrity_repair, :schema_migration] do
    {:ok, %{health | state: :maintenance, maintenance_reason: reason}}
  end

  def enter_maintenance(%__MODULE__{state: :ready}, _reason) do
    {:error, Error.new(:invalid_input, :maintenance_reason)}
  end

  def enter_maintenance(%__MODULE__{}, _reason), do: invalid_transition()

  def begin_backup(%__MODULE__{state: :ready} = health) do
    {:ok, %{health | state: :backing_up}}
  end

  def begin_backup(%__MODULE__{}), do: invalid_transition()

  def finish_backup(
        %__MODULE__{
          state: :backing_up,
          store_verified?: true,
          ontology_verified?: true
        } = health
      ) do
    {:ok, %{health | state: :ready}}
  end

  def finish_backup(%__MODULE__{}), do: invalid_transition()

  def begin_recovery(%__MODULE__{state: :maintenance, maintenance_reason: :restore} = health) do
    {:ok, %{health | state: :recovering}}
  end

  def begin_recovery(%__MODULE__{}), do: invalid_transition()

  def finish_recovery(%__MODULE__{state: :recovering} = health) do
    {:ok, %{health | state: :maintenance}}
  end

  def finish_recovery(%__MODULE__{}), do: invalid_transition()

  def leave_maintenance(
        %__MODULE__{
          state: :maintenance,
          store_verified?: true,
          ontology_verified?: true
        } = health
      ) do
    {:ok, %{health | state: :ready, maintenance_reason: nil, failure: nil}}
  end

  def leave_maintenance(%__MODULE__{}), do: invalid_transition()

  def fail(%__MODULE__{} = health, %Error{} = error) do
    state = Map.get(@failure_states, error.kind, :degraded)
    %{health | state: state, maintenance_reason: nil, failure: error}
  end

  def ready?(%__MODULE__{
        state: :ready,
        store_verified?: true,
        ontology_verified?: true,
        failure: nil
      }),
      do: true

  def ready?(%__MODULE__{}), do: false

  def gate(%__MODULE__{} = health, operation) when is_atom(operation) do
    if ready?(health) do
      :ok
    else
      {:error, health.failure || Error.new(:unavailable, operation)}
    end
  end

  def states, do: @states

  defp invalid_transition do
    {:error, Error.new(:conflict, :health_transition)}
  end
end

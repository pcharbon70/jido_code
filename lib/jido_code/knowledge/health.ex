defmodule JidoCode.Knowledge.Health do
  @moduledoc """
  Readiness state for the knowledge substrate.

  Readiness is reachable only after both the physical store and required
  ontology contract have been verified in order.
  """

  alias JidoCode.Knowledge.Error

  @states [
    :starting,
    :verifying_store,
    :verifying_ontology,
    :ready,
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
            failure: nil

  @type state ::
          :starting
          | :verifying_store
          | :verifying_ontology
          | :ready
          | :unavailable
          | :locked
          | :incompatible
          | :corrupt
          | :degraded

  @type t :: %__MODULE__{
          state: state(),
          store_verified?: boolean(),
          ontology_verified?: boolean(),
          failure: Error.t() | nil
        }

  def new, do: %__MODULE__{state: :starting}

  def begin_verification(%__MODULE__{state: state} = health)
      when state in [:starting, :unavailable, :locked] do
    {:ok,
     %__MODULE__{
       health
       | state: :verifying_store,
         store_verified?: false,
         ontology_verified?: false,
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

  def fail(%__MODULE__{} = health, %Error{} = error) do
    state = Map.get(@failure_states, error.kind, :degraded)
    %{health | state: state, failure: error}
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

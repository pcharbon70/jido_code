defmodule JidoCode.Knowledge.CommandRegistry do
  @moduledoc """
  Fixed registry of versioned, intent-named semantic commands.

  Registry entries are executable protocol definitions, not persisted domain
  objects. Dispatch uses exact strings and never creates atoms or modules from
  caller input.
  """

  alias JidoCode.Knowledge.Error

  @version "1.0.0"
  @commands %{
    "EnrollRepository" => %{
      owner: :factory,
      capability: :administrative,
      graph_families: [:factory_catalog],
      preconditions: [:repository_not_enrolled]
    },
    "RecordObservationBatch" => %{
      owner: :observation,
      capability: :observation,
      graph_families: [:observation_batch],
      preconditions: [:enrollment_active, :immutable_target_absent]
    },
    "AssertDesiredOutcome" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:factory_policy, :repository_control],
      preconditions: [:enrollment_active]
    },
    "ProposeGoal" => %{
      owner: :factory,
      capability: :proposal,
      graph_families: [:repository_control],
      preconditions: [:enrollment_active, :unique_transition_successor]
    },
    "AdoptPlan" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:accepted_goal, :unique_transition_successor]
    },
    "AcquireExecutionLease" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control],
      preconditions: [:eligible_task, :lease_fence_current]
    },
    "RecordExecutionAttempt" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:active_lease, :immutable_target_absent]
    },
    "RecordVerificationEvidence" => %{
      owner: :evaluation,
      capability: :evidence,
      graph_families: [:evidence],
      preconditions: [:attempt_known]
    },
    "DecideGoalOutcome" => %{
      owner: :evaluation,
      capability: :decision,
      graph_families: [:repository_control, :evidence],
      preconditions: [:evidence_complete, :unique_transition_successor]
    },
    "AdoptKnowledge" => %{
      owner: :learning,
      capability: :decision,
      graph_families: [:memory],
      preconditions: [:governed_decision]
    },
    "SupersedeClaim" => %{
      owner: :evaluation,
      capability: :decision,
      graph_families: [:evidence, :memory, :repository_control],
      preconditions: [:claim_current]
    },
    "RetireEnrollment" => %{
      owner: :factory,
      capability: :administrative,
      graph_families: [:factory_catalog, :repository_control],
      preconditions: [:enrollment_active, :no_active_lease]
    }
  }

  @spec version() :: String.t()
  def version, do: @version

  @spec names() :: [String.t()]
  def names, do: @commands |> Map.keys() |> Enum.sort()

  @spec resolve(String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(name, @version) when is_binary(name) do
    case Map.fetch(@commands, name) do
      {:ok, definition} -> {:ok, Map.merge(definition, %{name: name, version: @version})}
      :error -> invalid(:command_type)
    end
  end

  def resolve(name, version) when is_binary(name) and is_binary(version),
    do: {:error, Error.new(:incompatible, :command_version)}

  def resolve(_name, _version), do: invalid(:command_registry)

  @spec generic_crud?(term()) :: boolean()
  def generic_crud?(name) when is_binary(name) do
    Regex.match?(~r/^(?:Create|Update|Delete)(?:Entity|Record|Resource)?$/i, name)
  end

  def generic_crud?(_name), do: false

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end

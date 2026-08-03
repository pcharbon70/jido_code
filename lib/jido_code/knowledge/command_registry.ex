defmodule JidoCode.Knowledge.CommandRegistry do
  @moduledoc """
  Fixed registry of versioned, intent-named semantic commands.

  Registry entries are executable protocol definitions, not persisted domain
  objects. Dispatch uses exact strings and never creates atoms or modules from
  caller input.
  """

  alias JidoCode.Knowledge.Error

  @version "1.0.0"
  @derived_version "1.1.0"
  @control_loop_version "1.2.0"
  @governance_version "1.3.0"
  @reconciliation_version "1.4.0"
  @scheduling_version "1.5.0"
  @execution_version "1.6.0"
  @knowledge_version "1.7.0"
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

  @derived_commands %{
    "PublishDerivedGraph" => %{
      owner: :reasoning,
      capability: :reasoner,
      graph_families: [:derived],
      preconditions: [:source_revisions_exact, :expected_prior_derivation],
      allow_replacement?: true
    }
  }
  @phase_06_commands %{
    "ChangeEnrollment" => %{
      owner: :factory,
      capability: :administrative,
      graph_families: [:factory_catalog],
      preconditions: [:enrollment_known, :unique_transition_successor]
    },
    "ReconcileRepositoryIdentity" => %{
      owner: :factory,
      capability: :administrative,
      graph_families: [:factory_catalog],
      preconditions: [:repository_known, :explicit_identity_evidence]
    },
    "PublishSourceGraph" => %{
      owner: :reasoning,
      capability: :source,
      graph_families: [:source_revision],
      preconditions: [:source_snapshot_exact, :immutable_target_absent]
    }
  }
  @version_1_1 @commands |> Map.merge(@derived_commands) |> Map.merge(@phase_06_commands)
  @phase_07_work_commands %{
    "TransitionDesiredOutcome" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:desired_outcome_known, :unique_transition_successor]
    },
    "TransitionWork" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:work_known, :unique_transition_successor]
    },
    "ProposePlan" => %{
      owner: :factory,
      capability: :proposal,
      graph_families: [:repository_control],
      preconditions: [:accepted_goal, :source_revisions_exact]
    }
  }
  @version_1_2 Map.merge(@version_1_1, @phase_07_work_commands)
  @phase_07_governance_commands %{
    "ProposePolicy" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:factory_policy],
      preconditions: [:policy_version_absent, :evaluator_allowlisted]
    },
    "TransitionPolicy" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:factory_policy],
      preconditions: [:policy_known, :unique_transition_successor]
    },
    "DefineRepositoryCohort" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:factory_policy],
      preconditions: [:cohort_absent, :evaluator_allowlisted]
    },
    "DerivePolicyObligation" => %{
      owner: :factory,
      capability: :proposal,
      graph_families: [:repository_control],
      preconditions: [:applicability_exact, :obligation_identity_stable]
    },
    "TransitionObligation" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:obligation_known, :unique_transition_successor]
    },
    "RegisterCapability" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:factory_policy],
      preconditions: [:capability_identity_stable]
    },
    "TransitionCapability" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:factory_policy],
      preconditions: [:capability_known, :unique_transition_successor]
    }
  }
  @version_1_3 Map.merge(@version_1_2, @phase_07_governance_commands)
  @phase_07_reconciliation_commands %{
    "RecordReconciliation" => %{
      owner: :factory,
      capability: :proposal,
      graph_families: [:repository_control],
      preconditions: [:input_revisions_exact, :reconciliation_absent]
    },
    "TransitionReconciliation" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:reconciliation_known, :unique_transition_successor]
    }
  }
  @version_1_4 Map.merge(@version_1_3, @phase_07_reconciliation_commands)
  @phase_07_scheduling_commands %{
    "AcquireExecutionLease" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:eligibility_exact, :lease_absent, :fence_monotonic]
    },
    "TransitionExecutionLease" => %{
      owner: :factory,
      capability: :control,
      graph_families: [:repository_control],
      preconditions: [:current_lease_fence, :unique_transition_successor]
    }
  }
  @version_1_5 Map.merge(@version_1_4, @phase_07_scheduling_commands)
  @phase_08_boundary_commands %{
    "OpenInteractionSession" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control, :run_attempt],
      preconditions: [:session_absent, :scope_authorized]
    },
    "TransitionInteractionSession" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control, :run_attempt],
      preconditions: [:session_active, :unique_transition_successor]
    },
    "RecordInteractionMessage" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control, :run_attempt],
      preconditions: [:session_active, :message_sequence_absent]
    }
  }
  @phase_08_attempt_commands %{
    "RecordExecutionAttempt" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control, :run_attempt],
      preconditions: [:active_lease, :current_fence, :attempt_absent, :context_exact]
    },
    "TransitionExecutionAttempt" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control, :run_attempt],
      preconditions: [:attempt_current, :current_fence, :unique_transition_successor]
    },
    "RequestExecutionCancellation" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_current, :current_fence, :unique_transition_successor]
    }
  }
  @phase_08_effect_commands %{
    "RecordToolInvocation" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_current, :current_fence, :invocation_absent]
    },
    "RecordToolOutcome" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_current, :current_fence, :outcome_absent]
    },
    "RecordExecutionArtifact" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_current, :current_fence, :artifact_absent]
    },
    "FinalizeExecutionRun" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_terminal, :current_fence, :provenance_complete],
      allow_closure?: true
    }
  }
  @version_1_6 @version_1_5
               |> Map.merge(@phase_08_boundary_commands)
               |> Map.merge(@phase_08_attempt_commands)
               |> Map.merge(@phase_08_effect_commands)

  @phase_09_evidence_commands %{
    "RecordVerificationEvidence" => %{
      owner: :evaluation,
      capability: :evidence,
      graph_families: [:evidence],
      preconditions: [
        :verification_inputs_exact,
        :artifacts_verified,
        :attempt_provenance_exact,
        :evidence_bundle_absent
      ]
    }
  }
  @version_1_7 Map.merge(@version_1_6, @phase_09_evidence_commands)

  @spec version() :: String.t()
  def version, do: @version

  @spec execution_version() :: String.t()
  def execution_version, do: @execution_version

  @spec knowledge_version() :: String.t()
  def knowledge_version, do: @knowledge_version

  @spec names() :: [String.t()]
  def names, do: @commands |> Map.keys() |> Enum.sort()

  @spec names(String.t()) :: [String.t()]
  def names(@version), do: names()
  def names(@derived_version), do: @version_1_1 |> Map.keys() |> Enum.sort()
  def names(@control_loop_version), do: @version_1_2 |> Map.keys() |> Enum.sort()
  def names(@governance_version), do: @version_1_3 |> Map.keys() |> Enum.sort()
  def names(@reconciliation_version), do: @version_1_4 |> Map.keys() |> Enum.sort()
  def names(@scheduling_version), do: @version_1_5 |> Map.keys() |> Enum.sort()
  def names(@execution_version), do: @version_1_6 |> Map.keys() |> Enum.sort()
  def names(@knowledge_version), do: @version_1_7 |> Map.keys() |> Enum.sort()
  def names(_version), do: []

  @spec resolve(String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(name, @version) when is_binary(name) do
    case Map.fetch(@commands, name) do
      {:ok, definition} -> {:ok, Map.merge(definition, %{name: name, version: @version})}
      :error -> invalid(:command_type)
    end
  end

  def resolve(name, @derived_version) when is_binary(name) do
    case Map.fetch(@version_1_1, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @derived_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @control_loop_version) when is_binary(name) do
    case Map.fetch(@version_1_2, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @control_loop_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @governance_version) when is_binary(name) do
    case Map.fetch(@version_1_3, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @governance_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @reconciliation_version) when is_binary(name) do
    case Map.fetch(@version_1_4, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @reconciliation_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @scheduling_version) when is_binary(name) do
    case Map.fetch(@version_1_5, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @scheduling_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @execution_version) when is_binary(name) do
    case Map.fetch(@version_1_6, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @execution_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @knowledge_version) when is_binary(name) do
    case Map.fetch(@version_1_7, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @knowledge_version})}

      :error ->
        invalid(:command_type)
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

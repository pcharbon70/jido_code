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
    },
    "DecideGoalOutcome" => %{
      owner: :evaluation,
      capability: :decision,
      graph_families: [:repository_control, :evidence],
      preconditions: [
        :sufficiency_rechecked,
        :decision_actor_separated,
        :policy_revision_exact,
        :work_endpoints_exact,
        :no_direct_side_effects
      ]
    },
    "AdoptKnowledge" => %{
      owner: :learning,
      capability: :decision,
      graph_families: [:memory],
      preconditions: [
        :accepted_claim_current,
        :adoption_scope_authorized,
        :source_provenance_complete,
        :memory_revision_exact,
        :secret_free
      ]
    },
    "SupersedeClaim" => %{
      owner: :learning,
      capability: :decision,
      graph_families: [:memory],
      preconditions: [
        :knowledge_endpoint_current,
        :replacement_provenance_complete,
        :contradiction_preserved,
        :memory_revision_exact
      ]
    }
  }
  @version_1_7 Map.merge(@version_1_6, @phase_09_evidence_commands)

  @harness_contract_version "1.8.0"
  @segmented_execution_version "2.0.0"
  @experience_version "2.1.0"
  @procedure_version "2.2.0"
  @content_version "2.3.0"
  @dataset_policy_version "2.4.0"
  @phase_h01_contract_commands %{
    "EnrollModelAccessProfile" => %{
      owner: :runtime,
      capability: :harness,
      graph_families: [:factory_policy],
      preconditions: [:profile_absent, :credential_reference_known]
    },
    "RevokeModelAccessProfile" => %{
      owner: :runtime,
      capability: :harness,
      graph_families: [:factory_policy],
      preconditions: [:profile_known, :revocation_generation_monotonic]
    },
    "AdoptHarnessProfile" => %{
      owner: :runtime,
      capability: :harness,
      graph_families: [:factory_policy],
      preconditions: [:harness_profile_absent, :model_access_profile_known]
    },
    "PublishToolDefinition" => %{
      owner: :runtime,
      capability: :harness,
      graph_families: [:factory_policy],
      preconditions: [:tool_definition_absent, :supply_chain_digest_exact]
    },
    "CreateApprovalRequest" => %{
      owner: :runtime,
      capability: :harness,
      graph_families: [:repository_control],
      preconditions: [:approval_absent, :action_digest_bound, :evidence_present]
    },
    "RecordModelInvocationStart" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_current, :current_fence, :invocation_absent, :manifest_bound]
    },
    "RecordModelInvocationOutcome" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_current, :current_fence, :outcome_absent]
    }
  }
  @version_1_8 Map.merge(@version_1_7, @phase_h01_contract_commands)

  @segmented_event_command %{
    owner: :runtime,
    capability: :execution,
    graph_families: [:run_event_segment],
    preconditions: [:attempt_current, :current_fence, :exact_event_head]
  }
  @segmented_execution_commands %{
    "RecordExecutionAttempt" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:repository_control, :run_attempt, :run_event_segment],
      preconditions: [
        :active_lease,
        :current_fence,
        :attempt_absent,
        :capture_manifest_complete,
        :initial_event_head_absent
      ]
    },
    "RecordExecutionEvent" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt, :run_event_segment],
      preconditions: [:attempt_current, :current_fence, :exact_event_head]
    },
    "RecordModelInvocationStart" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_event_segment],
      preconditions: [:attempt_current, :current_fence, :exact_event_head, :context_exact]
    },
    "RecordModelInvocationOutcome" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_event_segment],
      preconditions: [:attempt_current, :current_fence, :exact_event_head, :start_known]
    },
    "RecordToolInvocationStart" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_event_segment],
      preconditions: [
        :attempt_current,
        :current_fence,
        :exact_event_head,
        :capability_current,
        :approval_current,
        :effect_journal_bound,
        :before_dispatch
      ]
    },
    "RecordToolOutcome" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_event_segment],
      preconditions: [:attempt_current, :current_fence, :exact_event_head, :start_known]
    },
    "RecordAttemptTransition" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:transition_current])),
    "RecordActionProposal" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:proposal_normalized])),
    "RecordSandboxEvent" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:sandbox_authorized])),
    "RecordExecutionArtifact" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:artifact_policy_allowed])),
    "RecordExecutionMessage" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:message_normalized])),
    "RecordCancellationObservation" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:cancellation_current])),
    "RecordRetryObservation" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:retry_authorized])),
    "RecordTerminalObservation" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:terminal_state_current])),
    "RecordProviderObservation" =>
      Map.update!(@segmented_event_command, :preconditions, fn values ->
        values ++ [:provider_source_order_exact, :attribution_exact]
      end),
    "RecordLifecycleObservation" =>
      Map.update!(@segmented_event_command, :preconditions, &(&1 ++ [:lifecycle_source_exact])),
    "RecordMemoryRetrievalStart" =>
      Map.update!(@segmented_event_command, :preconditions, fn values ->
        values ++ [:retrieval_authorized, :partition_exact, :before_candidate_generation]
      end),
    "RecordMemoryRetrievalOutcome" =>
      Map.update!(@segmented_event_command, :preconditions, fn values ->
        values ++ [:retrieval_start_known, :packet_commitment_exact]
      end),
    "CloseEventSegment" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt, :run_event_segment],
      preconditions: [:exact_event_head, :segment_exact, :capture_accounting_complete],
      allow_closure?: true
    },
    "FinalizeExecutionRun" => %{
      owner: :runtime,
      capability: :execution,
      graph_families: [:run_attempt],
      preconditions: [:attempt_terminal, :current_fence, :closed_segment_chain],
      allow_closure?: true
    }
  }

  @version_2_0 @version_1_8
               |> Map.delete("RecordToolInvocation")
               |> Map.merge(@segmented_execution_commands)

  @experience_commands %{
    "ProposeExperienceCase" => %{
      owner: :learning,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:closed_run_exact, :effective_time_manifest_exact, :case_absent]
    },
    "ValidateExperienceCase" => %{
      owner: :evaluation,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:candidate_current, :independent_actor, :quarantine_clear]
    },
    "QuarantineExperienceCase" => %{
      owner: :evaluation,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:candidate_current, :quarantine_reason_present]
    },
    "TransitionExperienceCase" => %{
      owner: :evaluation,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:case_current, :unique_transition_successor]
    },
    "RecordMemoryUseAssessment" => %{
      owner: :evaluation,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [
        :retrieval_packet_exact,
        :attempt_outcome_exact,
        :independent_evidence,
        :withheld_control_matched
      ]
    }
  }
  @version_2_1 Map.merge(@version_2_0, @experience_commands)
  @artifact_claim_commands %{
    "RecordArtifactClaim" => %{
      owner: :evaluation,
      capability: :evidence,
      graph_families: [:evidence],
      preconditions: [
        :independent_evidence,
        :artifact_revision_exact,
        :runtime_success_insufficient
      ]
    },
    "TransitionArtifactClaim" => %{
      owner: :evaluation,
      capability: :evidence,
      graph_families: [:evidence],
      preconditions: [:claim_current, :artifact_revision_compared, :unique_transition_successor]
    }
  }
  @procedure_commands %{
    "ProposeProcedureRevision" => %{
      owner: :learning,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:multiple_cases_or_expert_review, :quarantine_clear, :procedure_absent]
    },
    "ValidateProcedureRevision" => %{
      owner: :evaluation,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:independent_executions, :applicability_exact, :current_evidence]
    },
    "TransitionProcedureRevision" => %{
      owner: :evaluation,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:procedure_current, :unique_transition_successor]
    },
    "RecordProcedureUseObservation" => %{
      owner: :runtime,
      capability: :experience_writer,
      graph_families: [:experience],
      preconditions: [:retrieval_packet_exact, :procedure_selected, :assessment_pending]
    }
  }
  @version_2_2 @version_2_1
               |> Map.merge(@artifact_claim_commands)
               |> Map.merge(@procedure_commands)

  @content_commands %{
    "StoreEpisodeContent" => %{
      owner: :runtime,
      capability: :content_writer,
      graph_families: [:episode_content],
      preconditions: [
        :encrypted_before_command,
        :content_segment_complete,
        :immutable_target_absent
      ]
    },
    "AuthorizeContentAccess" => %{
      owner: :evaluation,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:authorization_current, :content_current, :permit_absent]
    },
    "ConsumeContentAccess" => %{
      owner: :runtime,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:permit_current, :authorization_rechecked, :single_use]
    },
    "RecordContentAccessOutcome" => %{
      owner: :runtime,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:permit_consumed, :outcome_absent, :audit_contains_no_released_bytes]
    },
    "TransitionContentLifecycle" => %{
      owner: :evaluation,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:content_state_current, :unique_transition_successor]
    },
    "PlaceContentHold" => %{
      owner: :evaluation,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:case_scope_exact, :owner_and_approver_distinct, :hold_absent]
    },
    "ReviewContentHold" => %{
      owner: :evaluation,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:hold_current, :review_due, :unique_transition_successor]
    },
    "ReleaseContentHold" => %{
      owner: :evaluation,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [:hold_release_pending, :approver_current, :unique_transition_successor]
    },
    "RecordContentErasure" => %{
      owner: :evaluation,
      capability: :content_lifecycle_writer,
      graph_families: [:content_lifecycle],
      preconditions: [
        :retrieval_blocked_first,
        :derivative_inventory_complete,
        :restore_floor_advanced
      ]
    }
  }
  @version_2_3 Map.merge(@version_2_2, @content_commands)

  @dataset_policy_commands %{
    "AuthorizeCrossRepositoryUse" => %{
      owner: :evaluation,
      capability: :dataset_policy_writer,
      graph_families: [:factory_policy],
      preconditions: [
        :cohort_explicit,
        :repository_and_actor_sets_exact,
        :purpose_and_classes_exact,
        :authorization_current
      ]
    },
    "RecordCrossRepositoryAudit" => %{
      owner: :evaluation,
      capability: :dataset_policy_writer,
      graph_families: [:security_audit],
      preconditions: [:authorization_referenced, :protected_payload_absent]
    },
    "RevokeCrossRepositoryUse" => %{
      owner: :evaluation,
      capability: :dataset_policy_writer,
      graph_families: [:factory_policy],
      preconditions: [:authorization_current, :revocation_generation_monotonic]
    }
  }
  @version_2_4 Map.merge(@version_2_3, @dataset_policy_commands)

  @spec version() :: String.t()
  def version, do: @version

  @spec execution_version() :: String.t()
  def execution_version, do: @execution_version

  @spec knowledge_version() :: String.t()
  def knowledge_version, do: @knowledge_version

  @spec harness_contract_version() :: String.t()
  def harness_contract_version, do: @harness_contract_version

  @spec segmented_execution_version() :: String.t()
  def segmented_execution_version, do: @segmented_execution_version

  @spec experience_version() :: String.t()
  def experience_version, do: @experience_version

  @spec procedure_version() :: String.t()
  def procedure_version, do: @procedure_version

  @spec content_version() :: String.t()
  def content_version, do: @content_version

  @spec dataset_policy_version() :: String.t()
  def dataset_policy_version, do: @dataset_policy_version

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
  def names(@harness_contract_version), do: @version_1_8 |> Map.keys() |> Enum.sort()
  def names(@segmented_execution_version), do: @version_2_0 |> Map.keys() |> Enum.sort()
  def names(@experience_version), do: @version_2_1 |> Map.keys() |> Enum.sort()
  def names(@procedure_version), do: @version_2_2 |> Map.keys() |> Enum.sort()
  def names(@content_version), do: @version_2_3 |> Map.keys() |> Enum.sort()
  def names(@dataset_policy_version), do: @version_2_4 |> Map.keys() |> Enum.sort()
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

  def resolve(name, @harness_contract_version) when is_binary(name) do
    case Map.fetch(@version_1_8, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @harness_contract_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @segmented_execution_version) when is_binary(name) do
    case Map.fetch(@version_2_0, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @segmented_execution_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @experience_version) when is_binary(name) do
    case Map.fetch(@version_2_1, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @experience_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @procedure_version) when is_binary(name) do
    case Map.fetch(@version_2_2, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @procedure_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @content_version) when is_binary(name) do
    case Map.fetch(@version_2_3, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @content_version})}

      :error ->
        invalid(:command_type)
    end
  end

  def resolve(name, @dataset_policy_version) when is_binary(name) do
    case Map.fetch(@version_2_4, name) do
      {:ok, definition} ->
        {:ok, Map.merge(definition, %{name: name, version: @dataset_policy_version})}

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

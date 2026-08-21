defmodule JidoCode.Knowledge.Memory.Guardrails do
  @moduledoc """
  Closed migration, retrieval, threat, capacity, and benchmark guardrails.

  This module describes preconditions for later memory phases. It does not
  activate a writer, query, index, capture profile, or content gateway.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @revision "1.5.0"
  @legacy_protocol "1.x"
  @segmented_protocol "2.0.0"
  @terminal_states ~w[completed failed timed_out cancelled abandoned]a
  @retrieval_purposes ~w[
    managed_continuity failure_recovery incident_response evaluation dataset_construction
  ]a

  @capacity_profile %{
    segment_quad_limit: 7_500,
    segment_event_limit: 80,
    segment_addition_limit: 800,
    closure_addition_reserve: 200,
    segment_guard_limit: 80,
    segment_target_graph_limit: 8,
    attempt_root_quad_limit: 2_000,
    segment_count_limit: 80,
    ciphertext_chunk_bytes: 16_384,
    content_chunks_per_command: 8,
    command_payload_bytes: 196_608
  }

  @system_ceilings %{
    snapshot_quads: 10_000,
    command_additions: 1_000,
    precommit_guards: 100,
    target_graphs: 16,
    command_payload_bytes: 262_144
  }

  @benchmark_corpus [
    %{
      id: :normalized_prompt,
      media_type: "text/plain",
      plaintext_bytes: 8_192,
      objects: 100,
      classification: :prompt_representation
    },
    %{
      id: :tool_log,
      media_type: "text/plain",
      plaintext_bytes: 65_536,
      objects: 100,
      classification: :tool_output
    },
    %{
      id: :source_artifact,
      media_type: "application/octet-stream",
      plaintext_bytes: 131_072,
      objects: 100,
      classification: :artifact_content
    },
    %{
      id: :mixed_attempt,
      media_type: "application/vnd.jido.memory-corpus",
      plaintext_bytes: 196_608,
      objects: 25,
      classification: :encrypted_content
    }
  ]

  @benchmark_thresholds %{
    capture_latency_ratio: 2.0,
    query_latency_ratio: 2.0,
    backup_latency_ratio: 1.5,
    restore_latency_ratio: 1.5,
    rebuild_latency_ratio: 2.0,
    storage_amplification_ratio: 4.0,
    integrity_failures: 0,
    orphaned_objects: 0,
    unerased_objects: 0
  }

  @threats [
    %{
      id: :persistent_poisoning,
      prevent: :source_linked_untrusted_memory,
      recover: :invalidate_and_rebuild_derivatives,
      reopening_gate: :MG3
    },
    %{
      id: :delayed_prompt_injection,
      prevent: :non_instructional_retrieval_boundary,
      recover: :quarantine_source_and_rebuild_packets,
      reopening_gate: :MG3
    },
    %{
      id: :cross_scope_retrieval,
      prevent: :authorization_bound_candidate_partition,
      recover: :revoke_partition_and_rebuild_indexes,
      reopening_gate: :MG3
    },
    %{
      id: :stale_procedure,
      prevent: :effective_time_and_applicability_checks,
      recover: :supersede_or_invalidate_procedure,
      reopening_gate: :MG5
    },
    %{
      id: :false_causality,
      prevent: :typed_temporal_lineage_without_retroactive_identity,
      recover: :challenge_claim_and_recompute_projection,
      reopening_gate: :MG4
    },
    %{
      id: :context_overload,
      prevent: :hard_packet_and_command_budgets,
      recover: :truncate_with_explicit_omission,
      reopening_gate: :MG3
    },
    %{
      id: :secret_capture,
      prevent: :structural_forbidden_content_policy,
      recover: :block_retrieval_and_execute_classified_erasure,
      reopening_gate: :MG1
    },
    %{
      id: :incomplete_erasure,
      prevent: :generation_bound_indexes_and_derivative_inventory,
      recover: :keep_erasure_pending_and_restore_blocked,
      reopening_gate: :MG6
    }
  ]

  @disabled_features %{
    diagnostic_capture: :superseding_privacy_contract,
    project_total_history: :accepted_diagnostic_evaluation,
    broad_cohort_access: :explicit_cross_repository_authorization,
    automatic_dataset_export: :expiring_manifest_bound_export_permit,
    model_training: :separate_accepted_implementation_plan,
    model_deployment: :separate_accepted_implementation_plan
  }

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec protocol_posture() :: map()
  def protocol_posture do
    %{
      legacy_read: @legacy_protocol,
      segmented_write: @segmented_protocol,
      legacy_rewrite?: false,
      dual_read?: true
    }
  end

  @doc """
  Admits segmented execution only after every legacy attempt has a governed,
  terminal projection. Abandonment additionally requires its explicit
  governance decision. Closed legacy evidence is never rewritten.
  """
  @spec authorize_segmented_activation([map()]) :: :ok | {:error, Error.t()}
  def authorize_segmented_activation(attempts) when is_list(attempts) do
    if Enum.all?(attempts, &terminal_legacy_attempt?/1) do
      :ok
    else
      {:error, Error.new(:conflict, :legacy_attempts_open)}
    end
  end

  def authorize_segmented_activation(_attempts),
    do: {:error, Error.new(:invalid_input, :legacy_attempt_migration)}

  @spec readable_protocol?(String.t()) :: boolean()
  def readable_protocol?(protocol), do: protocol in [@legacy_protocol, @segmented_protocol]

  @doc """
  Builds the exact first-stage retrieval partition only from a successful,
  revisioned authorization decision. Future candidate generators must consume
  this result rather than accepting caller-selected partition fields.
  """
  @spec authorize_candidate_partition(map()) :: {:ok, map()} | {:error, Error.t()}
  def authorize_candidate_partition(attributes) when is_map(attributes) do
    with :ok <- valid_resource(attributes[:authorization_iri]),
         true <- attributes[:authorization_decision] == :allowed,
         true <- positive_integer?(attributes[:authorization_revision]),
         :ok <- valid_resource(attributes[:repository_iri]),
         :ok <- valid_resource(attributes[:tenant_iri]),
         :ok <- valid_resource(attributes[:actor_scope_iri]),
         true <- attributes[:purpose] in @retrieval_purposes,
         true <- attributes[:data_ceiling] in DataPolicy.classifications(),
         true <- non_negative_integer?(attributes[:effective_time_generation]),
         true <- non_negative_integer?(attributes[:erasure_generation]) do
      fields =
        Map.take(attributes, [
          :authorization_iri,
          :authorization_revision,
          :repository_iri,
          :tenant_iri,
          :actor_scope_iri,
          :purpose,
          :data_ceiling,
          :effective_time_generation,
          :erasure_generation
        ])

      {:ok, Map.put(fields, :partition_digest, partition_digest(fields))}
    else
      {:error, %Error{}} -> unauthorized_partition()
      _invalid -> unauthorized_partition()
    end
  end

  def authorize_candidate_partition(_attributes), do: unauthorized_partition()

  @spec capacity_profile() :: map()
  def capacity_profile, do: @capacity_profile

  @spec system_ceilings() :: map()
  def system_ceilings, do: @system_ceilings

  @spec capacity_profile_valid?() :: boolean()
  def capacity_profile_valid? do
    @capacity_profile.segment_quad_limit < @system_ceilings.snapshot_quads and
      @capacity_profile.attempt_root_quad_limit < @system_ceilings.snapshot_quads and
      @capacity_profile.segment_addition_limit +
        @capacity_profile.closure_addition_reserve <=
        @system_ceilings.command_additions and
      @capacity_profile.closure_addition_reserve > 0 and
      @capacity_profile.segment_guard_limit < @system_ceilings.precommit_guards and
      @capacity_profile.segment_target_graph_limit < @system_ceilings.target_graphs and
      @capacity_profile.command_payload_bytes < @system_ceilings.command_payload_bytes and
      @capacity_profile.content_chunks_per_command * @capacity_profile.ciphertext_chunk_bytes <=
        @capacity_profile.command_payload_bytes
  end

  @spec benchmark_corpus() :: [map()]
  def benchmark_corpus, do: @benchmark_corpus

  @spec benchmark_corpus_digest() :: String.t()
  def benchmark_corpus_digest do
    @benchmark_corpus
    |> Enum.map_join("\n", fn fixture ->
      Enum.map_join(
        [:id, :media_type, :plaintext_bytes, :objects, :classification],
        "|",
        &to_string(Map.fetch!(fixture, &1))
      )
    end)
    |> sha256()
  end

  @spec benchmark_thresholds() :: map()
  def benchmark_thresholds, do: @benchmark_thresholds

  @doc """
  Selects graph-native content only when every mandatory Phase 6 measurement
  passes. A failed or incomplete result authorizes no vault; it requires a
  separately accepted vault ADR before exact-content activation.
  """
  @spec storage_decision(map()) :: :graph_native | :vault_adr_required
  def storage_decision(metrics) when is_map(metrics) do
    if benchmark_passes?(metrics), do: :graph_native, else: :vault_adr_required
  end

  def storage_decision(_metrics), do: :vault_adr_required

  @spec threats() :: [map()]
  def threats, do: @threats

  @spec disabled_features() :: map()
  def disabled_features, do: @disabled_features

  @spec feature_enabled?(atom()) :: boolean()
  def feature_enabled?(:run_event_segment_writer), do: true

  def feature_enabled?(feature)
      when feature in [
             :history_queries,
             :retrieval_index,
             :experience_writer,
             :content_lifecycle_writer,
             :episode_content_writer,
             :content_gateway,
             :governed_dataset_construction,
             :governed_dataset_export,
             :memory_release_evaluation
           ],
      do: true

  def feature_enabled?(_feature), do: false

  defp terminal_legacy_attempt?(attempt) when is_map(attempt) do
    attempt[:protocol] == @legacy_protocol and
      attempt[:state] in @terminal_states and
      attempt[:lifecycle_state] == :closed and
      attempt[:completeness_claim] == :bounded_observable_subset and
      valid_resource?(attempt[:terminal_transition_iri]) and
      governed_abandonment?(attempt)
  end

  defp terminal_legacy_attempt?(_attempt), do: false

  defp governed_abandonment?(%{state: :abandoned} = attempt) do
    attempt[:governed_abandonment?] == true and
      valid_resource?(attempt[:abandonment_decision_iri])
  end

  defp governed_abandonment?(_attempt), do: true

  defp benchmark_passes?(metrics) do
    MapSet.equal?(MapSet.new(Map.keys(metrics)), MapSet.new(Map.keys(@benchmark_thresholds))) and
      Enum.all?(@benchmark_thresholds, fn
        {key, 0} -> Map.get(metrics, key) == 0
        {key, maximum} -> finite_non_negative?(Map.get(metrics, key)) and metrics[key] <= maximum
      end)
  end

  defp partition_digest(fields) do
    [
      fields.authorization_iri,
      Integer.to_string(fields.authorization_revision),
      fields.repository_iri,
      fields.tenant_iri,
      fields.actor_scope_iri,
      Atom.to_string(fields.purpose),
      Atom.to_string(fields.data_ceiling),
      Integer.to_string(fields.effective_time_generation),
      Integer.to_string(fields.erasure_generation)
    ]
    |> Enum.join("\n")
    |> sha256()
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp valid_resource(value), do: ResourceIdentity.validate(value)
  defp valid_resource?(value), do: valid_resource(value) == :ok
  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp non_negative_integer?(value), do: is_integer(value) and value >= 0

  defp finite_non_negative?(value) when is_integer(value), do: value >= 0

  defp finite_non_negative?(value) when is_float(value) do
    value >= 0.0 and value == value
  end

  defp finite_non_negative?(_value), do: false

  defp unauthorized_partition,
    do: {:error, Error.new(:unauthorized, :memory_candidate_partition)}
end

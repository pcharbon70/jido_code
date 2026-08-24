defmodule JidoCode.Knowledge.ManagedCodingGraphProtocolTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-24 15:00:00Z]

  test "registers the additive ontology, commands, and reviewed queries" do
    assert CommandRegistry.managed_coding_version() == "2.8.0"

    for command <- [
          "RegisterManagedCodingProfile",
          "TransitionManagedCodingProfile",
          "RecordCodingRuntimeObservation",
          "RecordCodingBudgetExhaustion",
          "RecordCodingClarification",
          "ProposeCandidateCompletion",
          "RecordCandidateHandoff"
        ] do
      assert {:ok, definition} = CommandRegistry.resolve(command, "2.8.0")
      assert definition.name == command
    end

    assert QueryCatalog.managed_coding_version() == "2.8.0"
    assert :managed_coding_profile in QueryCatalog.names("2.8.0")
    assert :managed_coding_attempt in QueryCatalog.names("2.8.0")
    assert :managed_coding_observations in QueryCatalog.names("2.8.0")
    assert :ok = QueryCatalog.verify()
  end

  test "maps a complete profile and strategy into the factory policy family" do
    profile = profile!()
    statements = JidoCode.Knowledge.Control.ManagedCodingProfile.statements(profile)

    assert statement?(statements, profile.iri, "ManagedCodingProfile", :object)
    assert statement?(statements, profile.strategy_iri, "CodingStrategyRevision", :object)
    assert statement?(statements, profile.iri, "profileDigest", :predicate)

    attributes = policy_command_attributes()

    assert {:ok, command} =
             Knowledge.register_managed_coding_profile(profile, attributes, clock: fn -> @now end)

    assert command.command_type == "RegisterManagedCodingProfile"
    assert command.command_version == "2.8.0"
    assert command.ontology_version == "1.3.0"

    assert {:ok, transition} =
             Knowledge.transition_managed_coding_profile(
               profile,
               %{
                 current_state: :disabled,
                 current_revision: 0,
                 current_transition: initial_transition(profile)
               },
               :enabled,
               %{attributes | expected_dataset_revision: 2, expected_policy_revision: 2},
               clock: fn -> @now end
             )

    assert transition.command_type == "TransitionManagedCodingProfile"

    assert {:error, _error} =
             Knowledge.transition_managed_coding_profile(
               profile,
               %{
                 current_state: :revoked,
                 current_revision: 2,
                 current_transition: initial_transition(profile)
               },
               :enabled,
               attributes,
               clock: fn -> @now end
             )
  end

  test "projects only a contiguous append-only profile lifecycle" do
    profile = profile!()
    first = initial_transition(profile)
    second = transition(profile, 1, :enabled)

    rows = [
      row(first, :disabled, 0, nil),
      row(second, :enabled, 1, first)
    ]

    assert {:ok, projection} = Knowledge.project_managed_coding_profile(rows, profile.iri)
    assert projection.current_state == :enabled
    assert projection.current_revision == 1
    assert projection.selectable?

    refute match?(
             {:ok, _projection},
             Knowledge.project_managed_coding_profile(
               [row(first, :disabled, 0, nil), row(second, :enabled, 2, first)],
               profile.iri
             )
           )
  end

  test "records bounded managed observations on the shared predecessor sequence" do
    attempt = resource(:execution_attempt, "managed-observation-attempt")
    assert {:ok, segment, _opening} = EventSegment.open(attempt, %{index: 0})

    assert {:ok, observation} =
             Knowledge.managed_coding_observation(%{
               kind: :budget_exhaustion,
               attempt_iri: attempt,
               lease_iri: resource(:execution_lease, "managed-observation-lease"),
               fencing_token: 4,
               profile_iri: profile!().iri,
               strategy_revision: digest("strategy"),
               phase: :failed,
               runtime_sequence: 1,
               reconstruction_watermark: digest("watermark-1"),
               occurred_at: @now,
               budget_snapshot: %{turns: %{used: 20, limit: 20}},
               terminal_classification: :budget_exhausted
             })

    assert {:ok, recorded} =
             Knowledge.record_managed_coding_observation(
               observation,
               segment,
               event_command_attributes(segment),
               clock: fn -> @now end
             )

    assert recorded.segment.sequence_end == 1
    assert recorded.command.command_type == "RecordCodingBudgetExhaustion"
    assert recorded.command.command_version == "2.8.0"
    assert recorded.command.ontology_version == "1.3.0"

    assert {:error, %{kind: :conflict}} =
             Knowledge.record_managed_coding_observation(
               observation,
               recorded.segment,
               event_command_attributes(recorded.segment),
               clock: fn -> @now end
             )
  end

  test "rejects raw strategy state and incomplete kind-specific observations" do
    base = %{
      kind: :candidate_completion,
      attempt_iri: resource(:execution_attempt, "candidate-attempt"),
      lease_iri: resource(:execution_lease, "candidate-lease"),
      fencing_token: 1,
      profile_iri: profile!().iri,
      strategy_revision: digest("strategy"),
      phase: :candidate_ready,
      runtime_sequence: 2,
      reconstruction_watermark: digest("watermark"),
      occurred_at: @now,
      terminal_classification: :success
    }

    assert {:error, _error} = Knowledge.managed_coding_observation(base)

    assert {:ok, observation} =
             Knowledge.managed_coding_observation(
               Map.put(base, :candidate_iri, resource(:patch_artifact, "candidate"))
             )

    refute inspect(observation) =~ "prompt"
    refute Map.has_key?(Map.from_struct(observation), :agent_state)
  end

  defp profile! do
    {:ok, profile} =
      Knowledge.managed_coding_profile(%{
        iri: resource(:harness_profile, "managed-profile"),
        revision: 1,
        profile_digest: digest("profile"),
        jido_version: "2.3.2",
        strategy_revision: digest("strategy"),
        prompt_bundle_revision: digest("prompt"),
        model_access_profile_iri: resource(:model_access_profile, "model"),
        context_policy_revision: digest("context"),
        memory_policy_revision: digest("memory"),
        tool_catalog_revision: digest("tools"),
        adapter_set_revision: digest("adapters"),
        sandbox_profile_revision: digest("sandbox"),
        verifier_profile_revision: digest("verifier"),
        candidate_schema_revision: digest("candidate-schema"),
        budget_contract: %{turns: %{limit: 20, enforcement: "hard"}},
        task_classes: ["focused_change"],
        actor_iris: [resource(:authorization_grant, "actor")],
        tenant_iris: [resource(:authorization_grant, "tenant")],
        repository_iris: [resource(:repository_snapshot, "repository")],
        capability_iris: [resource(:capability_declaration, "capability")]
      })

    profile
  end

  defp policy_command_attributes do
    {:ok, policy_graph} = GraphRegistry.graph_iri(:factory_policy, %{})
    actor = resource(:authorization_grant, "actor")

    %{
      policy_graph_iri: policy_graph,
      principal_iri: actor,
      actor_iri: actor,
      scope_iri: resource(:execution_context, "factory-scope"),
      correlation_iri: resource(:command_request, "profile-correlation"),
      causation_iri: resource(:command_request, "profile-causation"),
      expected_dataset_revision: 1,
      expected_policy_revision: 1,
      reason: "register exact managed coding profile",
      recorded_at: @now
    }
  end

  defp event_command_attributes(segment) do
    actor = resource(:authorization_grant, "event-actor")

    %{
      command_iri: resource(:command_request, "event-command-#{segment.sequence_end}"),
      principal_iri: actor,
      actor_iri: actor,
      repository_scope_iri: resource(:execution_context, "repository-scope"),
      correlation_iri: resource(:command_request, "event-correlation"),
      causation_iri: resource(:command_request, "event-causation"),
      expected_segment_revision: segment.sequence_end + 1,
      expected_dataset_revision: segment.sequence_end + 1,
      expected_graph_revisions: %{segment.graph_iri => segment.sequence_end + 1},
      recorded_at: @now,
      authority_guards: [{:subject_present, segment.graph_iri, segment.attempt_iri}],
      reason: "record bounded managed coding observation"
    }
  end

  defp row(transition, state, revision, predecessor) do
    %{
      "transition" => %{value: transition},
      "state" => %{
        value:
          "https://jido.run/ontology/concept/ManagedCodingProfile#{Macro.camelize(to_string(state))}"
      },
      "revision" => %{value: revision},
      "predecessor" => if(predecessor, do: %{value: predecessor}, else: nil)
    }
  end

  defp initial_transition(profile), do: transition(profile, 0, :disabled)

  defp transition(profile, revision, state) do
    resource(
      :control_transition,
      Enum.join([profile.iri, "managed_coding_profile", revision, state], "\n")
    )
  end

  defp statement?(statements, subject, suffix, position) do
    Enum.any?(statements, fn statement ->
      {s, p, o} = RDF.Triple.new(statement)

      to_string(s) == subject and
        case position do
          :object -> String.ends_with?(to_string(o), suffix)
          :predicate -> String.ends_with?(to_string(p), suffix)
        end
    end)
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
